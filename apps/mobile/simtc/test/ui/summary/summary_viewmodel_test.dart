import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
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
    required String participantName,
    required double score,
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

  SummaryViewModel buildViewModel({AssessmentRepository? assessments}) {
    return SummaryViewModel(
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
