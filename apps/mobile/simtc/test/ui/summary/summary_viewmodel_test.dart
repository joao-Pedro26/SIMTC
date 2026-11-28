import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/summary/summary_viewmodel.dart';

class _MockApiClient extends Mock implements ApiClient {}

/// Repositório real com o "Confirmar" falhando — como um disco cheio.
class _FailingConfirmRepository extends AssessmentRepository {
  _FailingConfirmRepository({required super.database});

  @override
  Future<void> confirm(
    String localAssessmentId, {
    required String? participantName,
    required double score,
    DateTime? startTime,
    DateTime? endTime,
  }) =>
      Future.error(Exception('disco cheio'));
}

void main() {
  late AppDatabase db;
  late AssessmentRepository assessmentRepository;
  late ParticipantRepository participantRepository;
  late AssessmentCatalogRepository catalogRepository;

  setUp(() async {
    final api = _MockApiClient();
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    assessmentRepository = AssessmentRepository(database: db);
    participantRepository = ParticipantRepository(apiClient: api, database: db);
    catalogRepository = AssessmentCatalogRepository(apiClient: api, database: db);

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
            id: 'tp-1',
            sessionId: 'sess-1',
            name: 'Ana Paula Ribeiro',
            cpf: '042.118.***-**',
            participationType: 'TEORICA_E_PRATICA',
            status: 'EM_AVALIACAO',
            cachedAt: DateTime(2026, 9, 25, 8),
          ),
        );
    // CV com duas infrações e RR com uma: uma PM em CV dá 70% em CV, 100% em
    // RR e 85% no geral.
    for (final (id, code, name, order) in [
      ('cat-1', 'CV', 'Controle do Veículo', 1),
      ('cat-2', 'RR', 'Respeito às Regras', 2),
    ]) {
      await db.into(db.assessmentCategories).insert(
            AssessmentCategoriesCompanion.insert(
              id: id,
              code: code,
              name: name,
              order: order,
            ),
          );
    }
    for (final (id, category) in [
      ('inf-1', 'cat-1'),
      ('inf-2', 'cat-1'),
      ('inf-3', 'cat-2'),
    ]) {
      await db.into(db.infractions).insert(
            InfractionsCompanion.insert(
              id: id,
              categoryId: category,
              description: 'Infração $id',
              order: 1,
            ),
          );
      for (final (type, deduction) in [('B', 1), ('PM', 3), ('M', 5)]) {
        await db.into(db.infractionNotes).insert(
              InfractionNotesCompanion.insert(
                id: '$id-$type',
                infractionId: id,
                noteType: type,
                deduction: deduction,
              ),
            );
      }
    }
  });

  tearDown(() => db.close());

  Future<LocalAssessment> draftWith(Map<String, String> marks) async {
    final draft = await assessmentRepository.openDraft(
      trainingParticipantId: 'tp-1',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
      consultantId: 'c-eu',
    );
    for (final MapEntry(key: infraction, value: note) in marks.entries) {
      await assessmentRepository.mark(
        localAssessmentId: draft.id,
        infractionId: infraction,
        infractionNoteId: note,
      );
    }
    return draft;
  }

  SummaryViewModel buildViewModel({
    AssessmentRepository? assessments,
    DateTime Function()? now,
  }) {
    return SummaryViewModel(
      now: now,
      participantId: 'tp-1',
      assessmentRepository: assessments ?? assessmentRepository,
      participantRepository: participantRepository,
      catalogRepository: catalogRepository,
    );
  }

  test(
      'mostra o que o checklist mostrava: as categorias, o % geral, o '
      'resultado e as infrações marcadas', () async {
    await draftWith({'inf-1': 'inf-1-PM'});
    final vm = buildViewModel();
    addTearDown(vm.dispose);

    expect(vm.isLoading, isTrue);
    await vm.init();

    expect(vm.isLoading, isFalse);
    expect(vm.participant?.name, 'Ana Paula Ribeiro');
    expect(vm.sections.map((s) => s.code), ['CV', 'RR']);
    expect(vm.sections.map((s) => s.score), [70, 100]);
    expect(vm.overallScore, 85);
    expect(vm.isApproved, isTrue);
    expect(vm.infractionCount, 1);
    expect(vm.canConfirm, isTrue);
  });

  test('abaixo de 70% no geral, não é aprovado', () async {
    await draftWith({'inf-1': 'inf-1-M', 'inf-2': 'inf-2-M'});
    final vm = buildViewModel();
    addTearDown(vm.dispose);

    await vm.init();

    expect(vm.overallScore, 50);
    expect(vm.isApproved, isFalse);
    expect(vm.infractionCount, 2);
  });

  test('confirmar grava o fim, o nome e o % mostrado, e põe na fila', () async {
    final draft = await draftWith({'inf-1': 'inf-1-PM'});
    final vm = buildViewModel();
    addTearDown(vm.dispose);
    await vm.init();

    await vm.confirm();

    expect(vm.isConfirmed, isTrue);
    expect(vm.canConfirm, isFalse);
    final row = await (db.select(db.localAssessments)
          ..where((t) => t.id.equals(draft.id)))
        .getSingle();
    expect(row.syncStatus, LocalSyncStatus.pendingSync);
    expect(row.endTime, isNotNull);
    expect(row.participantName, 'Ana Paula Ribeiro');
    expect(row.score, 85);
  });

  test(
      'o fim é a hora em que a 1.6 abriu: o rótulo mostra início e fim, e o '
      '"Confirmar" grava esse mesmo fim', () async {
    final draft = await draftWith({'inf-1': 'inf-1-PM'});
    await (db.update(db.localAssessments)..where((t) => t.id.equals(draft.id)))
        .write(LocalAssessmentsCompanion(startTime: Value(DateTime(2026, 9, 30, 8, 12))));
    var clock = DateTime(2026, 9, 30, 8, 31);
    final vm = buildViewModel(now: () => clock);
    addTearDown(vm.dispose);
    await vm.init();

    expect(vm.timesLabel, 'Início 08:12 · Fim 08:31');

    clock = DateTime(2026, 9, 30, 9, 5); // o consultor demorou no "Confirmar"
    await vm.confirm();

    expect(vm.timesLabel, 'Início 08:12 · Fim 08:31', reason: 'o fim não anda');
    final row = await (db.select(db.localAssessments)
          ..where((t) => t.id.equals(draft.id)))
        .getSingle();
    expect(row.endTime, DateTime(2026, 9, 30, 8, 31));
  });

  group('ajuste de início e fim', () {
    Future<void> startAt(DateTime start) async {
      await draftWith({'inf-1': 'inf-1-PM'});
      await (db.update(db.localAssessments)
            ..where((t) => t.trainingParticipantId.equals('tp-1')))
          .write(LocalAssessmentsCompanion(startTime: Value(start)));
    }

    test('setEndClock troca a hora do fim, no mesmo dia, com segundos zerados',
        () async {
      await startAt(DateTime(2026, 9, 30, 8, 12));
      final vm = buildViewModel(now: () => DateTime(2026, 9, 30, 8, 31));
      addTearDown(vm.dispose);
      await vm.init();

      vm.setEndClock(8, 25);

      expect(vm.endTime, DateTime(2026, 9, 30, 8, 25));
      expect(vm.timesLabel, 'Início 08:12 · Fim 08:25');
      expect(vm.timesError, isNull);
    });

    test('fim antes do início: erro e não confirma', () async {
      await startAt(DateTime(2026, 9, 30, 8, 12));
      final vm = buildViewModel(now: () => DateTime(2026, 9, 30, 8, 31));
      addTearDown(vm.dispose);
      await vm.init();

      vm.setEndClock(8, 5);

      expect(vm.timesError,
          'A hora de término precisa ser depois da hora de início.');
      expect(vm.canConfirm, isFalse);
    });

    test('fim depois de agora: erro e não confirma', () async {
      await startAt(DateTime(2026, 9, 30, 8, 12));
      final vm = buildViewModel(now: () => DateTime(2026, 9, 30, 8, 31));
      addTearDown(vm.dispose);
      await vm.init();

      vm.setEndClock(8, 40);

      expect(vm.timesError, 'A hora de término não pode ser depois de agora.');
      expect(vm.canConfirm, isFalse);
    });

    test(
        'fim ajustado no futuro libera o "Confirmar" sozinho quando o '
        'horário chega', () async {
      await startAt(DateTime(2026, 9, 30, 8, 12));
      var now = () => DateTime(2026, 9, 30, 8, 31, 40);
      final vm = buildViewModel(now: () => now());
      addTearDown(vm.dispose);
      await vm.init();

      fakeAsync((async) {
        now = async.getClock(DateTime(2026, 9, 30, 8, 31, 40)).now;
        var notified = 0;
        vm.addListener(() => notified++);

        vm.setEndClock(8, 32); // 20 s à frente
        final afterSet = notified;
        expect(vm.canConfirm, isFalse);

        async.elapse(const Duration(seconds: 21));

        expect(notified, greaterThan(afterSet));
        expect(vm.timesError, isNull);
        expect(vm.canConfirm, isTrue);
      });
    });

    test('fim igual a agora, com segundos a menos, não é erro', () async {
      await startAt(DateTime(2026, 9, 30, 8, 12));
      final vm = buildViewModel(now: () => DateTime(2026, 9, 30, 8, 31, 45));
      addTearDown(vm.dispose);
      await vm.init();

      vm.setEndClock(8, 31);

      expect(vm.timesError, isNull);
    });

    test('meia-noite: o fim fica no dia de hoje, depois do início de ontem',
        () async {
      await startAt(DateTime(2026, 9, 29, 23, 50));
      final vm = buildViewModel(now: () => DateTime(2026, 9, 30, 0, 10));
      addTearDown(vm.dispose);
      await vm.init();

      vm.setEndClock(0, 5);

      expect(vm.endTime, DateTime(2026, 9, 30, 0, 5));
      expect(vm.timesError, isNull);
    });

    test('setStartClock e setEndClock, depois confirmar, gravam os dois',
        () async {
      final draft = await draftWith({'inf-1': 'inf-1-PM'});
      await (db.update(db.localAssessments)
            ..where((t) => t.id.equals(draft.id)))
          .write(LocalAssessmentsCompanion(
              startTime: Value(DateTime(2026, 9, 30, 8, 12))));
      final vm = buildViewModel(now: () => DateTime(2026, 9, 30, 8, 31));
      addTearDown(vm.dispose);
      await vm.init();

      vm.setStartClock(8, 10);
      vm.setEndClock(8, 25);
      await vm.confirm();

      final row = await (db.select(db.localAssessments)
            ..where((t) => t.id.equals(draft.id)))
          .getSingle();
      expect(row.startTime, DateTime(2026, 9, 30, 8, 10));
      expect(row.endTime, DateTime(2026, 9, 30, 8, 25));
    });

    test('setStartClock sem confirmar não mexe no que está gravado', () async {
      final draft = await draftWith({'inf-1': 'inf-1-PM'});
      await (db.update(db.localAssessments)
            ..where((t) => t.id.equals(draft.id)))
          .write(LocalAssessmentsCompanion(
              startTime: Value(DateTime(2026, 9, 30, 8, 12))));
      final vm = buildViewModel(now: () => DateTime(2026, 9, 30, 8, 31));
      addTearDown(vm.dispose);
      await vm.init();

      vm.setStartClock(8, 10);

      final stored = await assessmentRepository.findByParticipant('tp-1');
      expect(stored?.startTime, DateTime(2026, 9, 30, 8, 12));
    });
  });

  test('sem rascunho, não há o que confirmar', () async {
    final vm = buildViewModel();
    addTearDown(vm.dispose);
    await vm.init();

    expect(vm.canConfirm, isFalse);
    await vm.confirm();

    expect(vm.isConfirmed, isFalse);
    expect(await db.select(db.localAssessments).get(), isEmpty);
  });

  test(
      'sem catálogo, não confirma — uma avaliação sem categoria nenhuma daria '
      '100%', () async {
    final draft = await draftWith({});
    await db.delete(db.infractionNotes).go();
    await db.delete(db.infractions).go();
    await db.delete(db.assessmentCategories).go();
    final vm = buildViewModel();
    addTearDown(vm.dispose);
    await vm.init();

    expect(vm.canConfirm, isFalse);
    await vm.confirm();

    final row = await (db.select(db.localAssessments)
          ..where((t) => t.id.equals(draft.id)))
        .getSingle();
    expect(row.syncStatus, LocalSyncStatus.draft);
  });

  test(
      'participante fora do cache: confirmar grava o nome nulo, não vazio '
      '(revisão de 30/09/2026 — claimUnowned só preenche quando é nulo)',
      () async {
    final draft = await assessmentRepository.openDraft(
      trainingParticipantId: 'tp-fora-do-cache',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
      consultantId: 'c-eu',
    );
    await assessmentRepository.mark(
      localAssessmentId: draft.id,
      infractionId: 'inf-1',
      infractionNoteId: 'inf-1-PM',
    );
    final vm = SummaryViewModel(
      participantId: 'tp-fora-do-cache',
      assessmentRepository: assessmentRepository,
      participantRepository: participantRepository,
      catalogRepository: catalogRepository,
    );
    addTearDown(vm.dispose);
    await vm.init();
    expect(vm.participant, isNull, reason: 'o participante não está no cache');

    await vm.confirm();

    final row = await (db.select(db.localAssessments)
          ..where((t) => t.id.equals(draft.id)))
        .getSingle();
    expect(row.participantName, isNull);
  });

  test(
      'falha ao gravar mostra a mensagem, não fecha e deixa tentar de novo',
      () async {
    await draftWith({'inf-1': 'inf-1-PM'});
    final vm = buildViewModel(
      assessments: _FailingConfirmRepository(database: db),
    );
    addTearDown(vm.dispose);
    await vm.init();

    await vm.confirm();

    expect(vm.isConfirmed, isFalse);
    expect(vm.errorMessage,
        'Não foi possível confirmar a avaliação. Tente de novo.');
    expect(vm.canConfirm, isTrue);
  });
}
