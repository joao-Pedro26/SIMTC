import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/checklist/checklist_viewmodel.dart';

class _MockApiClient extends Mock implements ApiClient {}

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

  Future<void> seedParticipant({String id = 'tp-1', String name = 'Carlos Eduardo Nunes'}) async {
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
            status: 'EM_AVALIACAO',
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

  ChecklistViewModel buildViewModel({DateTime Function()? now}) {
    return ChecklistViewModel(
      sessionId: 'sess-1',
      participantId: 'tp-1',
      ownerUserId: 'user-1',
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
              cachedAt: DateTime(2026, 9, 25, 8),
            ),
          );
      await assessmentRepository.openDraft(
        trainingParticipantId: 'tp-2',
        sessionId: 'sess-1',
        ownerUserId: 'user-1',
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
