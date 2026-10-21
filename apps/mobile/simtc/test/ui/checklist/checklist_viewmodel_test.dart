import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/checklist/checklist_viewmodel.dart';

class _MockApiClient extends Mock implements ApiClient {}

/// O participante só chega pelo stream quando o teste mandar: no aparelho, o
/// stream pode entregar depois de a tela já ter lido a avaliação do banco.
class _LateStreamParticipantRepository extends ParticipantRepository {
  _LateStreamParticipantRepository({
    required super.apiClient,
    required super.database,
  });

  final StreamController<SessionParticipant?> late =
      StreamController<SessionParticipant?>();

  @override
  Stream<SessionParticipant?> watchParticipant(String participantId) =>
      late.stream;
}

void main() {
  late _MockApiClient api;
  late AppDatabase db;
  late AssessmentRepository assessmentRepository;
  late ParticipantRepository participantRepository;
  late AssessmentCatalogRepository catalogRepository;

  setUp(() {
    api = _MockApiClient();
    // Um dos testes é `testWidgets` (relógio falso): sem fechar os streams na
    // hora, o `Timer` de duração zero que o drift agenda ao cancelar um
    // stream ficaria pendente e derrubaria o teste.
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    assessmentRepository = AssessmentRepository(database: db);
    participantRepository = ParticipantRepository(apiClient: api, database: db);
    catalogRepository = AssessmentCatalogRepository(apiClient: api, database: db);
  });

  tearDown(() => db.close());

  Future<void> seedParticipant({
    String id = 'tp-1',
    String name = 'Carlos Eduardo Nunes',
    String status = 'EM_AVALIACAO',
    String? assignedConsultantId,
  }) async {
    await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 'sess-1',
            companyName: 'Bracell',
            courseName: 'Direção Defensiva',
            city: 'Itabira',
            state: 'MG',
            status: 'EM_ANDAMENTO',
            cachedAt: DateTime(2026, 9, 25, 8),
          ),
        );
    await db.into(db.participants).insert(
          ParticipantsCompanion.insert(
            id: id,
            sessionId: 'sess-1',
            name: name,
            cpf: '187.443.***-**',
            participationType: 'TEORICA_E_PRATICA',
            status: status,
            assignedConsultantId: Value(assignedConsultantId),
            cachedAt: DateTime(2026, 9, 25, 8),
          ),
        );
  }

  Future<void> seedCatalog() async {
    await db.into(db.assessmentCategories).insert(
          AssessmentCategoriesCompanion.insert(
            id: 'cat-1',
            code: 'CV',
            name: 'Controle do Veículo',
            order: 1,
          ),
        );
    await db.into(db.infractions).insert(
          InfractionsCompanion.insert(
            id: 'inf-1',
            categoryId: 'cat-1',
            description: 'Excesso de velocidade',
            order: 1,
          ),
        );
    for (final n in [('note-b', 'B', 1), ('note-pm', 'PM', 3), ('note-m', 'M', 5)]) {
      await db.into(db.infractionNotes).insert(
            InfractionNotesCompanion.insert(
              id: n.$1,
              infractionId: 'inf-1',
              noteType: n.$2,
              deduction: n.$3,
            ),
          );
    }
  }

  ChecklistViewModel buildViewModel({
    DateTime Function()? now,
    String? consultantId = 'c-eu',
  }) {
    return ChecklistViewModel(
      sessionId: 'sess-1',
      participantId: 'tp-1',
      ownerUserId: 'user-1',
      consultantId: consultantId,
      consultantName: 'Carla Souza',
      assessmentRepository: assessmentRepository,
      participantRepository: participantRepository,
      catalogRepository: catalogRepository,
      now: now,
    );
  }

  group('init e start', () {
    test(
        'abrir só lê: carrega o participante e o catálogo, sem gravar nada — '
        'um participante aberto sem querer não começa', () async {
      await seedParticipant();
      await seedCatalog();
      final vm = buildViewModel();
      addTearDown(vm.dispose);

      expect(vm.isLoading, isTrue);
      await vm.init();

      expect(vm.isLoading, isFalse);
      expect(vm.isStarted, isFalse);
      expect(vm.participant?.name, 'Carlos Eduardo Nunes');
      expect(vm.sections, hasLength(1));
      expect(vm.expandedCategoryId, isNull);
      expect(await db.select(db.localAssessments).get(), isEmpty);
    });

    test(
        '"Iniciar avaliação" grava o início agora e abre a primeira categoria',
        () async {
      await seedParticipant();
      await seedCatalog();
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      final before = DateTime.now();

      await vm.start();

      expect(vm.isStarted, isTrue);
      expect(vm.isStarting, isFalse);
      expect(vm.expandedCategoryId, 'cat-1', reason: 'abre com a primeira categoria aberta');
      final row = await db.select(db.localAssessments).getSingle();
      expect(row.ownerUserId, 'user-1');
      expect(row.syncStatus, LocalSyncStatus.draft);
      // O banco guarda segundos: o início é o toque, com essa precisão.
      expect(row.startTime.isBefore(before.subtract(const Duration(seconds: 1))), isFalse);
    });

    test('um segundo toque em "Iniciar" não recomeça a avaliação', () async {
      await seedParticipant();
      await seedCatalog();
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      await vm.start();
      final first = await db.select(db.localAssessments).getSingle();

      await vm.start();

      final again = await db.select(db.localAssessments).getSingle();
      expect(again.id, first.id);
      expect(again.startTime, first.startTime);
    });

    test(
        'reabrir uma avaliação iniciada volta direto ao checklist, com as '
        'marcações', () async {
      await seedParticipant();
      await seedCatalog();

      final first = buildViewModel();
      await first.init();
      await first.start();
      await first.toggleNote('inf-1', 'note-pm');
      first.dispose();

      final second = buildViewModel();
      addTearDown(second.dispose);
      await second.init();

      expect(second.isStarted, isTrue);
      expect(second.expandedCategoryId, 'cat-1');
      expect(second.sections.single.infractions.single.selectedNoteId, 'note-pm');
    });
  });

  // O "Reavaliar" do Resultado só abre o checklist: é o "Iniciar avaliação"
  // que reserva o participante (decisão de 06/10/2026).
  group('"Iniciar avaliação" de quem ainda não está com o consultor', () {
    const assignPath = '/practical-assessments/assign';

    Response<Map<String, dynamic>> reserved() => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: assignPath),
          statusCode: 201,
          data: {'assigned': 1},
        );

    test(
        'reavaliação: o "Iniciar" reserva o participante no backend e só então '
        'grava o início', () async {
      await seedParticipant(status: 'NAO_RECOMENDADO');
      await seedCatalog();
      when(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .thenAnswer((_) async => reserved());
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      verifyNever(() => api.post<Map<String, dynamic>>(any(), data: any(named: 'data')));

      await vm.start();

      final sent = verify(
        () => api.post<Map<String, dynamic>>(assignPath, data: captureAny(named: 'data')),
      ).captured;
      expect(sent.single, {
        'participantIds': ['tp-1'],
      });
      final row = await db.select(db.participants).getSingle();
      expect(row.status, 'EM_AVALIACAO');
      expect(row.assignedConsultantId, 'c-eu');
      expect(row.assignedConsultantName, 'Carla Souza');
      expect(vm.isStarted, isTrue);
      final draft = await db.select(db.localAssessments).getSingle();
      expect(draft.syncStatus, LocalSyncStatus.draft);
    });

    test(
        'se o backend recusa a reserva, a avaliação não começa: o motivo '
        'aparece e a sessão é baixada de novo', () async {
      await seedParticipant(status: 'NAO_RECOMENDADO');
      await seedCatalog();
      when(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .thenThrow(const ApiException(
        message: 'Um ou mais participantes já estão em avaliação com outro consultor',
        statusCode: 409,
      ));
      when(() => api.get<Map<String, dynamic>>(any()))
          .thenThrow(const ApiException(message: 'Sem conexão', isNetworkError: true));
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();

      await vm.start();

      expect(vm.isStarted, isFalse);
      expect(vm.isStarting, isFalse);
      expect(vm.message, 'Um ou mais participantes já estão em avaliação com outro consultor');
      expect(await db.select(db.localAssessments).get(), isEmpty);
      final row = await db.select(db.participants).getSingle();
      expect(row.status, 'NAO_RECOMENDADO');
      verify(() => api.get<Map<String, dynamic>>('/training-sessions/sess-1')).called(1);
    });

    test('sem rede, a reavaliação não começa e o aviso diz o que fazer', () async {
      await seedParticipant(status: 'NAO_RECOMENDADO');
      await seedCatalog();
      when(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .thenThrow(const ApiException(
        message: 'Sem conexão com o servidor. Verifique a internet e tente de novo.',
        isNetworkError: true,
      ));
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();

      await vm.start();

      expect(vm.isStarted, isFalse);
      expect(vm.message, 'Sem conexão com o servidor. Verifique a internet e tente de novo.');
      expect(await db.select(db.localAssessments).get(), isEmpty);
      verifyNever(() => api.get<Map<String, dynamic>>(any()));
    });

    test('dois toques rápidos no "Iniciar" reservam uma vez só', () async {
      await seedParticipant(status: 'NAO_RECOMENDADO');
      await seedCatalog();
      final post = Completer<Response<Map<String, dynamic>>>();
      when(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .thenAnswer((_) => post.future);
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();

      final first = vm.start();
      final second = vm.start();
      post.complete(reserved());
      await Future.wait([first, second]);

      verify(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .called(1);
      expect(await db.select(db.localAssessments).get(), hasLength(1));
    });

    test(
        'quem está com outro consultor não começa: o backend recusa e o motivo '
        'aparece', () async {
      await seedParticipant(assignedConsultantId: 'c-outro');
      await seedCatalog();
      when(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .thenThrow(const ApiException(
        message: 'Um ou mais participantes já estão em avaliação com outro consultor',
        statusCode: 409,
      ));
      when(() => api.get<Map<String, dynamic>>(any()))
          .thenThrow(const ApiException(message: 'Sem conexão', isNetworkError: true));
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();

      await vm.start();

      expect(vm.isStarted, isFalse);
      expect(vm.message, 'Um ou mais participantes já estão em avaliação com outro consultor');
      expect(await db.select(db.localAssessments).get(), isEmpty);
    });

    test('quem já está com o consultor inicia sem falar com o backend', () async {
      await seedParticipant(assignedConsultantId: 'c-eu');
      await seedCatalog();
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();

      await vm.start();

      expect(vm.isStarted, isTrue);
      verifyNever(() => api.post<Map<String, dynamic>>(any(), data: any(named: 'data')));
    });
  });

  group('toggleNote', () {
    test('marca a infração e o score da categoria cai', () async {
      await seedParticipant();
      await seedCatalog();
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      await vm.start();

      await vm.toggleNote('inf-1', 'note-m');

      expect(vm.sections.single.infractions.single.selectedNoteId, 'note-m');
      expect(vm.sections.single.score, 0);
      expect(vm.overallScore, 0);
      expect(vm.isApproved, isFalse);
    });

    test('apertar a mesma nota de novo desmarca a infração', () async {
      await seedParticipant();
      await seedCatalog();
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      await vm.start();
      await vm.toggleNote('inf-1', 'note-b');

      await vm.toggleNote('inf-1', 'note-b');

      expect(vm.sections.single.infractions.single.selectedNoteId, isNull);
      expect(vm.sections.single.score, 100);
      expect(vm.overallScore, 100);
      expect(vm.isApproved, isTrue);
    });
  });

  group('toggleCategory', () {
    test('abrir outra categoria fecha a aberta; tocar na aberta fecha', () async {
      await seedParticipant();
      await seedCatalog();
      await db.into(db.assessmentCategories).insert(
            AssessmentCategoriesCompanion.insert(
              id: 'cat-2',
              code: 'RR',
              name: 'Respeito às Regras',
              order: 2,
            ),
          );
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      await vm.start();
      expect(vm.expandedCategoryId, 'cat-1');

      vm.toggleCategory('cat-2');
      expect(vm.expandedCategoryId, 'cat-2');

      vm.toggleCategory('cat-2');
      expect(vm.expandedCategoryId, isNull);
    });
  });

  group('um por vez', () {
    Future<void> startOtherParticipant() async {
      await db.into(db.participants).insert(
            ParticipantsCompanion.insert(
              id: 'tp-2',
              sessionId: 'sess-1',
              name: 'Marina Lopes',
              cpf: '111.222.***-**',
              participationType: 'TEORICA_E_PRATICA',
              status: 'EM_AVALIACAO',
              assignedConsultantId: const Value('c-eu'),
              cachedAt: DateTime(2026, 9, 25, 8),
            ),
          );
      await assessmentRepository.openDraft(
        trainingParticipantId: 'tp-2',
        sessionId: 'sess-1',
        ownerUserId: 'user-1',
        consultantId: 'c-eu',
      );
    }

    test('com outro participante em andamento, não inicia e diz quem é',
        () async {
      await seedParticipant();
      await seedCatalog();
      await startOtherParticipant();
      final vm = buildViewModel();
      addTearDown(vm.dispose);

      await vm.init();

      expect(vm.isBlocked, isTrue);
      expect(vm.blockingParticipantName, 'Marina Lopes');

      await vm.start();

      expect(vm.isStarted, isFalse);
      final rows = await db.select(db.localAssessments).get();
      expect(rows.map((r) => r.trainingParticipantId), ['tp-2']);
    });

    test('quem já está em andamento não se bloqueia a si mesmo', () async {
      await seedParticipant();
      await seedCatalog();
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      await vm.start();

      final again = buildViewModel();
      addTearDown(again.dispose);
      await again.init();

      expect(again.isStarted, isTrue);
      expect(again.isBlocked, isFalse);
    });

    test('se outro começou depois de a tela abrir, o "Iniciar" é recusado e '
        'a tela passa a avisar', () async {
      await seedParticipant();
      await seedCatalog();
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      expect(vm.isBlocked, isFalse);
      await startOtherParticipant();

      await vm.start();

      expect(vm.isStarted, isFalse);
      expect(vm.isBlocked, isTrue);
      expect(vm.blockingParticipantName, 'Marina Lopes');
      final rows = await db.select(db.localAssessments).get();
      expect(rows.map((r) => r.trainingParticipantId), ['tp-2']);
    });

    test(
        'avaliação presa — a de um participante que não está mais com o '
        'consultor — não bloqueia, e continua guardada', () async {
      await seedParticipant();
      await seedCatalog();
      await startOtherParticipant();
      // O painel passou a Marina para outro consultor.
      await (db.update(db.participants)..where((t) => t.id.equals('tp-2')))
          .write(
        const ParticipantsCompanion(assignedConsultantId: Value('c-outro')),
      );
      final vm = buildViewModel();
      addTearDown(vm.dispose);

      await vm.init();
      expect(vm.isBlocked, isFalse);

      await vm.start();

      expect(vm.isStarted, isTrue);
      final rows = await db.select(db.localAssessments).get();
      expect(
        rows.map((r) => r.trainingParticipantId),
        unorderedEquals(['tp-1', 'tp-2']),
      );
    });
  });

  // O participante saiu das mãos do consultor com a avaliação pela metade
  // (um ADMIN o desatribuiu, ou o consultor foi tirado da sessão) e depois
  // voltou: continua de onde parou (decisão de 09/10/2026).
  group('avaliação antiga que volta', () {
    const assignPath = '/practical-assessments/assign';
    const detailPath = '/training-sessions/sess-1';

    Response<Map<String, dynamic>> ok(String path) {
      return Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: path),
        statusCode: 201,
        data: const {},
      );
    }

    /// A avaliação começada às 08:12 de 25/09, com a nota PM marcada.
    Future<LocalAssessment> seedOldDraft({String participantId = 'tp-1'}) async {
      final id = 'draft-$participantId';
      final at = DateTime(2026, 9, 25, 8, 12);
      await db.into(db.localAssessments).insert(
            LocalAssessmentsCompanion.insert(
              id: id,
              trainingParticipantId: participantId,
              sessionId: 'sess-1',
              date: DateTime(2026, 9, 25),
              startTime: at,
              syncStatus: LocalSyncStatus.draft,
              createdAt: at,
              updatedAt: at,
              ownerUserId: const Value('user-1'),
            ),
          );
      await assessmentRepository.mark(
        localAssessmentId: id,
        infractionId: 'inf-1',
        infractionNoteId: 'note-pm',
      );
      return (db.select(db.localAssessments)..where((t) => t.id.equals(id)))
          .getSingle();
    }

    /// Outro participante do mesmo consultor, com a avaliação começada às
    /// 08:30 — depois da antiga.
    Future<void> seedNewerDraft() async {
      await db.into(db.participants).insert(
            ParticipantsCompanion.insert(
              id: 'tp-2',
              sessionId: 'sess-1',
              name: 'Marina Lopes',
              cpf: '111.222.***-**',
              participationType: 'TEORICA_E_PRATICA',
              status: 'EM_AVALIACAO',
              assignedConsultantId: const Value('c-eu'),
              cachedAt: DateTime(2026, 9, 25, 8),
            ),
          );
      final at = DateTime(2026, 9, 25, 8, 30);
      await db.into(db.localAssessments).insert(
            LocalAssessmentsCompanion.insert(
              id: 'draft-tp-2',
              trainingParticipantId: 'tp-2',
              sessionId: 'sess-1',
              date: DateTime(2026, 9, 25),
              startTime: at,
              syncStatus: LocalSyncStatus.draft,
              createdAt: at,
              updatedAt: at,
              ownerUserId: const Value('user-1'),
            ),
          );
    }

    Future<void> setParticipant({required String status, String? consultant}) {
      return (db.update(db.participants)..where((t) => t.id.equals('tp-1')))
          .write(
        ParticipantsCompanion(
          status: Value(status),
          assignedConsultantId: Value(consultant),
        ),
      );
    }

    Future<ChecklistViewModel> open() async {
      final vm = buildViewModel(now: () => DateTime(2026, 9, 26, 9));
      addTearDown(vm.dispose);
      await vm.init();
      return vm;
    }

    test('de volta com o consultor (pela linha): abre direto na avaliação '
        'antiga, com as respostas e a hora de início', () async {
      await seedParticipant(assignedConsultantId: 'c-eu');
      await seedCatalog();
      await seedOldDraft();

      final vm = await open();

      expect(vm.isStarted, isTrue);
      expect(vm.isResumable, isFalse);
      expect(vm.isReleased, isFalse);
      expect(vm.startedText, 'Iniciada em 25 set 08:12');
      expect(vm.sections.single.infractions.single.selectedNoteId, 'note-pm');
      expect(vm.expandedCategoryId, 'cat-1');
    });

    for (final (status, consultant, why) in const [
      ('NAO_RECOMENDADO', null, 'chegou pelo "Reavaliar"'),
      ('PENDENTE', null, 'foi liberado'),
      ('EM_AVALIACAO', 'c-outro', 'está com outro consultor'),
    ]) {
      test('ainda fora das mãos do consultor ($why): a tela oferece continuar, '
          'sem abrir as respostas', () async {
        await seedParticipant(status: status, assignedConsultantId: consultant);
        await seedCatalog();
        await seedOldDraft();

        final vm = await open();

        expect(vm.isLoading, isFalse);
        expect(vm.isStarted, isFalse);
        expect(vm.isResumable, isTrue);
        expect(vm.isBlocked, isFalse);
        expect(vm.resumableStartedAt, '25/09 às 08:12');
        expect(vm.startedText, 'Iniciada em 25 set 08:12');
        expect(vm.isWithMe, isFalse);
        // As respostas só voltam ao continuar.
        expect(vm.sections.single.infractions.single.selectedNoteId, isNull);
        expect(vm.expandedCategoryId, isNull);
        verifyNever(() => api.post<Map<String, dynamic>>(any(), data: any(named: 'data')));
      });
    }

    test('a decisão de esperar não depende de o stream do participante já '
        'ter entregado', () async {
      await seedParticipant(status: 'PENDENTE');
      await seedCatalog();
      await seedOldDraft();
      final slow = _LateStreamParticipantRepository(apiClient: api, database: db);
      addTearDown(slow.late.close);
      final vm = ChecklistViewModel(
        sessionId: 'sess-1',
        participantId: 'tp-1',
        ownerUserId: 'user-1',
        consultantId: 'c-eu',
        consultantName: 'Carla Souza',
        assessmentRepository: assessmentRepository,
        participantRepository: slow,
        catalogRepository: catalogRepository,
      );
      addTearDown(vm.dispose);

      await vm.init();

      expect(vm.isResumable, isTrue);
      expect(vm.isStarted, isFalse);
      expect(vm.participant?.name, 'Carlos Eduardo Nunes');
    });

    test('depois de reservar, a tela já sabe que o participante está com o '
        'consultor, sem esperar o stream', () async {
      await seedParticipant(status: 'NAO_RECOMENDADO');
      await seedCatalog();
      await seedOldDraft();
      when(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .thenAnswer((_) async => ok(assignPath));
      final slow = _LateStreamParticipantRepository(apiClient: api, database: db);
      addTearDown(slow.late.close);
      final vm = ChecklistViewModel(
        sessionId: 'sess-1',
        participantId: 'tp-1',
        ownerUserId: 'user-1',
        consultantId: 'c-eu',
        consultantName: 'Carla Souza',
        assessmentRepository: assessmentRepository,
        participantRepository: slow,
        catalogRepository: catalogRepository,
      );
      addTearDown(vm.dispose);
      await vm.init();

      await vm.start();

      expect(vm.isStarted, isTrue);
      expect(vm.isReleased, isFalse);
      expect(vm.isWithMe, isTrue);
    });

    test('"Continuar avaliação" reserva o participante e reabre a antiga: a '
        'mesma hora de início, as mesmas respostas, nenhuma avaliação nova',
        () async {
      await seedParticipant(status: 'NAO_RECOMENDADO');
      await seedCatalog();
      final old = await seedOldDraft();
      when(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .thenAnswer((_) async => ok(assignPath));
      final vm = await open();

      await vm.start();

      final sent = verify(
        () => api.post<Map<String, dynamic>>(assignPath, data: captureAny(named: 'data')),
      ).captured.single;
      expect(sent, {
        'participantIds': ['tp-1'],
      });
      expect(vm.isStarted, isTrue);
      expect(vm.isResumable, isFalse);
      expect(vm.resumableStartedAt, isNull, reason: 'não está mais parada');
      // Já no fim do toque: a tela não acusa "não está mais com você".
      expect(vm.isReleased, isFalse);
      expect(vm.isWithMe, isTrue);
      expect(vm.message, isNull);
      expect(vm.expandedCategoryId, 'cat-1');
      expect(vm.sections.single.infractions.single.selectedNoteId, 'note-pm');
      final rows = await db.select(db.localAssessments).get();
      expect(rows.map((r) => r.id), [old.id]);
      expect(rows.single.startTime, old.startTime);
    });

    test('sem rede, o continuar não reabre: avisa, e a avaliação antiga '
        'continua guardada', () async {
      await seedParticipant(status: 'NAO_RECOMENDADO');
      await seedCatalog();
      final old = await seedOldDraft();
      when(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .thenThrow(const ApiException(
        message: 'Sem conexão com o servidor. Verifique a internet e tente de novo.',
        isNetworkError: true,
      ));
      final vm = await open();

      await vm.start();

      expect(vm.isStarted, isFalse);
      expect(vm.isResumable, isTrue);
      expect(
        vm.message,
        'Sem conexão com o servidor. Verifique a internet e tente de novo.',
      );
      final rows = await db.select(db.localAssessments).get();
      expect(rows.map((r) => r.id), [old.id]);
      expect(await assessmentRepository.loadItems(old.id), hasLength(1));
    });

    test('recusado (409, outro consultor ficou com ele): avisa, baixa a '
        'sessão, e a avaliação antiga continua guardada', () async {
      await seedParticipant(status: 'NAO_RECOMENDADO');
      await seedCatalog();
      final old = await seedOldDraft();
      when(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .thenThrow(const ApiException(
        message: 'Um ou mais participantes já estão em avaliação com outro consultor',
        statusCode: 409,
      ));
      when(() => api.get<Map<String, dynamic>>(detailPath))
          .thenThrow(const ApiException(message: 'x', statusCode: 500));
      final vm = await open();

      await vm.start();
      await pumpEventQueue();

      expect(vm.isStarted, isFalse);
      expect(vm.isResumable, isTrue);
      expect(
        vm.message,
        'Um ou mais participantes já estão em avaliação com outro consultor',
      );
      verify(() => api.get<Map<String, dynamic>>(detailPath)).called(1);
      expect((await db.select(db.localAssessments).get()).map((r) => r.id), [old.id]);
    });

    group('uma por vez', () {
      test('com outra avaliação começada depois, a antiga espera — mesmo com '
          'o participante de volta', () async {
        await seedParticipant(assignedConsultantId: 'c-eu');
        await seedCatalog();
        await seedOldDraft();
        await seedNewerDraft();

        final vm = await open();

        expect(vm.isStarted, isFalse);
        expect(vm.isResumable, isTrue);
        expect(vm.isBlocked, isTrue);
        expect(vm.blockingParticipantName, 'Marina Lopes');
        expect(vm.isWithMe, isTrue);

        await vm.start();

        expect(vm.isStarted, isFalse);
        verifyNever(() => api.post<Map<String, dynamic>>(any(), data: any(named: 'data')));
      });

      test('a avaliação mais nova abre sem esperar pela antiga', () async {
        await seedParticipant(assignedConsultantId: 'c-eu');
        await seedCatalog();
        await seedOldDraft();
        await seedNewerDraft();
        final vm = ChecklistViewModel(
          sessionId: 'sess-1',
          participantId: 'tp-2',
          ownerUserId: 'user-1',
          consultantId: 'c-eu',
          consultantName: 'Carla Souza',
          assessmentRepository: assessmentRepository,
          participantRepository: participantRepository,
          catalogRepository: catalogRepository,
        );
        addTearDown(vm.dispose);

        await vm.init();

        expect(vm.isStarted, isTrue);
        expect(vm.isResumable, isFalse);
        expect(vm.isBlocked, isFalse);
      });

      test('com a outra confirmada, a antiga volta a abrir direto', () async {
        await seedParticipant(assignedConsultantId: 'c-eu');
        await seedCatalog();
        await seedOldDraft();
        await seedNewerDraft();
        await assessmentRepository.confirm(
          'draft-tp-2',
          participantName: 'Marina Lopes',
          score: 90,
        );

        final vm = await open();

        expect(vm.isStarted, isTrue);
        expect(vm.isBlocked, isFalse);
        expect(vm.sections.single.infractions.single.selectedNoteId, 'note-pm');
      });

      test('fora das mãos do consultor e com outra em andamento: o continuar '
          'fica travado, sem reservar ninguém', () async {
        await seedParticipant(status: 'NAO_RECOMENDADO');
        await seedCatalog();
        await seedOldDraft();
        await seedNewerDraft();

        final vm = await open();
        expect(vm.isResumable, isTrue);
        expect(vm.isBlocked, isTrue);

        await vm.start();

        expect(vm.isStarted, isFalse);
        verifyNever(() => api.post<Map<String, dynamic>>(any(), data: any(named: 'data')));
      });

      test('se a outra começou depois de a tela abrir, o continuar é recusado '
          'e a tela passa a avisar', () async {
        await seedParticipant(assignedConsultantId: 'c-eu');
        await seedCatalog();
        await seedOldDraft();
        // Na abertura, a antiga espera por estar fora das mãos do consultor.
        await setParticipant(status: 'PENDENTE');
        final vm = await open();
        expect(vm.isResumable, isTrue);
        expect(vm.isBlocked, isFalse);
        // O participante volta, e outra avaliação começa nesse meio-tempo.
        await setParticipant(status: 'EM_AVALIACAO', consultant: 'c-eu');
        await seedNewerDraft();
        await pumpEventQueue();

        await vm.start();

        expect(vm.isStarted, isFalse);
        expect(vm.isBlocked, isTrue);
        expect(vm.blockingParticipantName, 'Marina Lopes');
      });
    });

    test('descartar a avaliação antiga começa limpo: some o continuar, e o '
        '"Iniciar avaliação" volta a valer', () async {
      await seedParticipant(status: 'PENDENTE');
      await seedCatalog();
      final old = await seedOldDraft();
      final vm = await open();
      expect(vm.canDiscard, isTrue);

      await vm.discard();

      expect(vm.isResumable, isFalse);
      expect(vm.canDiscard, isFalse);
      expect(vm.resumableStartedAt, isNull);
      expect(vm.startedText, isNull);
      expect(await db.select(db.localAssessments).get(), isEmpty);
      expect(await assessmentRepository.loadItems(old.id), isEmpty);
    });

    test('avaliação já confirmada não vira "continuar", mesmo com o '
        'participante fora das mãos do consultor', () async {
      await seedParticipant(status: 'PENDENTE');
      await seedCatalog();
      final old = await seedOldDraft();
      await assessmentRepository.confirm(old.id, participantName: 'Carlos', score: 80);

      final vm = await open();

      expect(vm.isStarted, isTrue);
      expect(vm.isConfirmed, isTrue);
      expect(vm.isResumable, isFalse);
      expect(vm.isReleased, isFalse);
    });

    test('participante liberado com o checklist aberto: não dá mais para '
        'finalizar — e volta a dar quando ele é atribuído de novo', () async {
      await seedParticipant(assignedConsultantId: 'c-eu');
      await seedCatalog();
      await seedOldDraft();
      final vm = await open();
      expect(vm.isReleased, isFalse);

      await setParticipant(status: 'PENDENTE');
      await pumpEventQueue();

      expect(vm.isStarted, isTrue, reason: 'as marcações continuam na tela');
      expect(vm.isReleased, isTrue);
      expect(vm.isWithMe, isFalse);

      await setParticipant(status: 'EM_AVALIACAO', consultant: 'c-outro');
      await pumpEventQueue();
      expect(vm.isReleased, isTrue, reason: 'com outro consultor');

      await setParticipant(status: 'EM_AVALIACAO', consultant: 'c-eu');
      await pumpEventQueue();
      expect(vm.isReleased, isFalse);
    });

    test('desatribuir com a avaliação antiga à espera também a apaga',
        () async {
      await seedParticipant(assignedConsultantId: 'c-eu');
      await seedCatalog();
      await seedOldDraft();
      await seedNewerDraft();
      when(() => api.post<Map<String, dynamic>>(
            '/practical-assessments/unassign',
            data: any(named: 'data'),
          )).thenAnswer((_) async => ok('/practical-assessments/unassign'));
      final vm = await open();
      expect(vm.isResumable, isTrue);
      expect(vm.canUnassign, isTrue);

      final released = await vm.unassign();

      expect(released, isTrue);
      expect(vm.isResumable, isFalse);
      final rows = await db.select(db.localAssessments).get();
      expect(rows.map((r) => r.trainingParticipantId), ['tp-2']);
    });
  });

  group('descartar', () {
    test(
        'descartar apaga o rascunho e volta a "não iniciada" — e o "Iniciar" '
        'volta a valer', () async {
      await seedParticipant();
      await seedCatalog();
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      await vm.start();
      await vm.toggleNote('inf-1', 'note-m');
      expect(vm.canDiscard, isTrue);

      await vm.discard();

      expect(vm.isStarted, isFalse);
      expect(vm.canDiscard, isFalse);
      expect(vm.startedText, isNull);
      expect(vm.overallScore, 100, reason: 'as marcações saíram junto');
      expect(await db.select(db.localAssessments).get(), isEmpty);
      expect(await db.select(db.localAssessmentItems).get(), isEmpty);

      await vm.start();

      expect(vm.isStarted, isTrue);
      expect(vm.overallScore, 100);
    });

    test(
        'avaliação confirmada abre só para leitura: não muda nota nem é '
        'descartada', () async {
      await seedParticipant();
      await seedCatalog();
      final draft = await assessmentRepository.openDraft(
        trainingParticipantId: 'tp-1',
        sessionId: 'sess-1',
        ownerUserId: 'user-1',
        consultantId: 'c-eu',
      );
      await assessmentRepository.mark(
        localAssessmentId: draft.id,
        infractionId: 'inf-1',
        infractionNoteId: 'note-b',
      );
      await assessmentRepository.confirm(draft.id, participantName: 'Carlos', score: 96);
      final vm = buildViewModel();
      addTearDown(vm.dispose);

      await vm.init();

      expect(vm.isStarted, isTrue);
      expect(vm.isConfirmed, isTrue);
      expect(vm.canDiscard, isFalse);

      await vm.toggleNote('inf-1', 'note-m');
      await vm.discard();

      final item = await db.select(db.localAssessmentItems).getSingle();
      expect(item.infractionNoteId, 'note-b', reason: 'a nota não mudou');
      final row = await db.select(db.localAssessments).getSingle();
      expect(row.syncStatus, LocalSyncStatus.pendingSync);
    });
  });

  group('desatribuir', () {
    const unassignPath = '/practical-assessments/unassign';

    Future<void> assignTo(String consultantId) {
      return (db.update(db.participants)..where((t) => t.id.equals('tp-1')))
          .write(ParticipantsCompanion(assignedConsultantId: Value(consultantId)));
    }

    test(
        'desatribuir libera o participante no backend e apaga a avaliação '
        'iniciada', () async {
      await seedParticipant();
      await seedCatalog();
      await assignTo('c-eu');
      when(() => api.post<Map<String, dynamic>>(unassignPath, data: any(named: 'data')))
          .thenAnswer((_) async => Response<Map<String, dynamic>>(
                requestOptions: RequestOptions(path: unassignPath),
                statusCode: 201,
                data: {'unassigned': 1},
              ));
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      await vm.start();
      await vm.toggleNote('inf-1', 'note-b');
      expect(vm.canUnassign, isTrue);

      final unassigned = await vm.unassign();

      expect(unassigned, isTrue);
      expect(await db.select(db.localAssessments).get(), isEmpty);
      expect(await db.select(db.localAssessmentItems).get(), isEmpty);
      final row = await db.select(db.participants).getSingle();
      expect(row.status, 'PENDENTE');
      expect(row.assignedConsultantId, isNull);
    });

    test('só quem está com o participante pode desatribuir', () async {
      await seedParticipant();
      await seedCatalog();
      await assignTo('c-outro');
      final ofOther = buildViewModel();
      addTearDown(ofOther.dispose);
      await ofOther.init();
      expect(ofOther.canUnassign, isFalse, reason: 'está com outro consultor');

      await assignTo('c-eu');
      final noProfile = buildViewModel(consultantId: null);
      addTearDown(noProfile.dispose);
      await noProfile.init();
      expect(noProfile.canUnassign, isFalse, reason: 'sem perfil de consultor');

      final mine = buildViewModel();
      addTearDown(mine.dispose);
      await mine.init();
      expect(mine.canUnassign, isTrue, reason: 'antes de iniciar também');
    });

    test(
        'se o backend recusa, nada muda no aparelho, o motivo aparece e a '
        'sessão é baixada de novo', () async {
      await seedParticipant();
      await seedCatalog();
      await assignTo('c-eu');
      when(() => api.post<Map<String, dynamic>>(unassignPath, data: any(named: 'data')))
          .thenThrow(const ApiException(
        message: 'Um ou mais participantes não estão atribuídos a você',
        statusCode: 409,
      ));
      when(() => api.get<Map<String, dynamic>>(any()))
          .thenThrow(const ApiException(message: 'Sem conexão', isNetworkError: true));
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      await vm.start();

      final unassigned = await vm.unassign();

      expect(unassigned, isFalse);
      expect(vm.message, 'Um ou mais participantes não estão atribuídos a você');
      expect(vm.isStarted, isTrue);
      expect(await db.select(db.localAssessments).get(), hasLength(1));
      verify(() => api.get<Map<String, dynamic>>('/training-sessions/sess-1')).called(1);
    });

    group('com o backend ainda sem responder', () {
      /// O POST do desatribuir preso: o backend só responde quando o teste
      /// completa o que esta função devolve (rede lenta).
      Completer<Response<Map<String, dynamic>>> holdUnassign() {
        final post = Completer<Response<Map<String, dynamic>>>();
        when(() => api.post<Map<String, dynamic>>(unassignPath, data: any(named: 'data')))
            .thenAnswer((_) => post.future);
        return post;
      }

      Response<Map<String, dynamic>> accepted() => Response<Map<String, dynamic>>(
            requestOptions: RequestOptions(path: unassignPath),
            statusCode: 201,
            data: {'unassigned': 1},
          );

      test(
          'descartar e mudar nota não mexem na avaliação; depois do sucesso, o '
          'checklist fica sem ela', () async {
        await seedParticipant();
        await seedCatalog();
        await assignTo('c-eu');
        final post = holdUnassign();
        final vm = buildViewModel();
        addTearDown(vm.dispose);
        await vm.init();
        await vm.start();
        await vm.toggleNote('inf-1', 'note-b');

        final unassigning = vm.unassign();
        expect(vm.isUnassigning, isTrue);
        await vm.discard();
        await vm.toggleNote('inf-1', 'note-m');

        expect(await db.select(db.localAssessments).get(), hasLength(1));
        final item = await db.select(db.localAssessmentItems).getSingle();
        expect(item.infractionNoteId, 'note-b', reason: 'a nota não mudou');

        post.complete(accepted());

        expect(await unassigning, isTrue);
        expect(vm.isStarted, isFalse);
        expect(vm.message, isNull);
        expect(await db.select(db.localAssessments).get(), isEmpty);
        expect(await db.select(db.localAssessmentItems).get(), isEmpty);
      });

      test('"Iniciar avaliação" não grava nada', () async {
        await seedParticipant();
        await seedCatalog();
        await assignTo('c-eu');
        final post = holdUnassign();
        final vm = buildViewModel();
        addTearDown(vm.dispose);
        await vm.init();

        final unassigning = vm.unassign();
        await vm.start();

        expect(vm.isStarted, isFalse);
        expect(await db.select(db.localAssessments).get(), isEmpty);

        post.complete(accepted());
        expect(await unassigning, isTrue);
      });

      test(
          'se a avaliação deixou de ser rascunho nesse meio-tempo, avisa que '
          'ela não foi apagada do aparelho', () async {
        await seedParticipant();
        await seedCatalog();
        await assignTo('c-eu');
        final post = holdUnassign();
        final vm = buildViewModel();
        addTearDown(vm.dispose);
        await vm.init();
        await vm.start();
        final draft = await db.select(db.localAssessments).getSingle();

        final unassigning = vm.unassign();
        // Confirmada por fora desta tela, com o POST ainda no ar.
        await assessmentRepository.confirm(draft.id, participantName: 'Carlos', score: 100);
        post.complete(accepted());

        expect(await unassigning, isTrue);
        expect(
          vm.message,
          'Participante desatribuído, mas a avaliação iniciada não foi apagada '
          'do aparelho.',
        );
        final row = await db.select(db.localAssessments).getSingle();
        expect(row.syncStatus, LocalSyncStatus.pendingSync, reason: 'a confirmada continua');
      });
    });
  });

  group('startedText', () {
    test('diz quando a avaliação começou — nada antes do "Iniciar"', () async {
      await seedParticipant();
      await seedCatalog();
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      expect(vm.startedText, isNull, reason: 'antes do "Iniciar"');

      await vm.start();

      expect(vm.startedText, matches(RegExp(r'^Iniciada às \d\d:\d\d$')));
    });
  });

  group('expandCategory', () {
    test('abre a categoria pedida sem alternar — abrir a já aberta não fecha',
        () async {
      await seedParticipant();
      await seedCatalog();
      await db.into(db.assessmentCategories).insert(
            AssessmentCategoriesCompanion.insert(
              id: 'cat-2',
              code: 'RR',
              name: 'Respeito às Regras',
              order: 2,
            ),
          );
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      await vm.start();

      vm.expandCategory('cat-2');
      expect(vm.expandedCategoryId, 'cat-2');

      vm.expandCategory('cat-2');
      expect(vm.expandedCategoryId, 'cat-2');
    });
  });

  group('hasCatalog', () {
    test('sem catálogo no aparelho, não há o que avaliar', () async {
      await seedParticipant();
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      await vm.start();

      expect(vm.hasCatalog, isFalse);
      expect(vm.isStarted, isFalse, reason: 'sem catálogo, o "Iniciar" não grava');
      expect(await db.select(db.localAssessments).get(), isEmpty);
    });

    test(
        'catálogo só com categoria sem id vale como sem catálogo — nada a '
        'avaliar', () async {
      await seedParticipant();
      await db.into(db.assessmentCategories).insert(
            AssessmentCategoriesCompanion.insert(
              id: '',
              code: '??',
              name: 'Categoria sem id',
              order: 1,
            ),
          );
      final vm = buildViewModel();
      addTearDown(vm.dispose);
      await vm.init();
      await vm.start();

      expect(vm.hasCatalog, isFalse);
      expect(vm.isStarted, isFalse, reason: 'sem catálogo, o "Iniciar" não grava');
      expect(await db.select(db.localAssessments).get(), isEmpty);
    });
  });

  test('uma escrita que termina depois do dispose não notifica a tela morta',
      () async {
    await seedParticipant();
    await seedCatalog();
    final vm = buildViewModel();
    await vm.init();
    await vm.start();

    final pending = vm.toggleNote('inf-1', 'note-b');
    vm.dispose();

    // Sem a guarda, o `notifyListeners` do fim do `toggleNote` lançaria
    // "used after being disposed" e esta escrita terminaria com erro.
    await expectLater(pending, completes);
  });
}
