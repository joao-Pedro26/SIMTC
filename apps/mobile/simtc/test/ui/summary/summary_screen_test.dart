import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/summary/summary_screen.dart';

class _MockApiClient extends Mock implements ApiClient {}

/// Repositório real com o "Confirmar" falhando — como um disco cheio.
class _FailingConfirmRepository extends AssessmentRepository {
  _FailingConfirmRepository({required super.database});

  @override
  Future<void> confirm(
    String localAssessmentId, {
    required String? participantName,
    required double score,
    DateTime? endTime,
  }) =>
      Future.error(Exception('disco cheio'));
}

void main() {
  late AppDatabase db;
  late AssessmentRepository assessmentRepository;
  late ParticipantRepository participantRepository;
  late AssessmentCatalogRepository catalogRepository;

  /// Como a tela fechou: o valor do `pop`, e se ela fechou.
  SummaryExit? exit;
  var closed = false;

  setUp(() async {
    final api = _MockApiClient();
    // Mesmo motivo do checklist: sem fechar os streams na hora, o `Timer` que
    // o drift agenda ao cancelar um stream ficaria pendente no teste.
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    assessmentRepository = AssessmentRepository(database: db);
    participantRepository = ParticipantRepository(apiClient: api, database: db);
    catalogRepository = AssessmentCatalogRepository(apiClient: api, database: db);
    exit = null;
    closed = false;

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

  Future<void> draftWith(Map<String, String> marks) async {
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
  }

  /// A tela 1.6 empilhada sobre uma origem, guardando como ela fechou.
  Future<void> pumpSummary(
    WidgetTester tester, {
    AssessmentRepository? assessments,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AssessmentRepository>.value(
            value: assessments ?? assessmentRepository,
          ),
          Provider<ParticipantRepository>.value(value: participantRepository),
          Provider<AssessmentCatalogRepository>.value(value: catalogRepository),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  exit = await Navigator.of(context).push<SummaryExit>(
                    MaterialPageRoute(
                      builder: (_) => const SummaryScreen(participantId: 'tp-1'),
                    ),
                  );
                  closed = true;
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'mostra a pontuação, o resultado e cada categoria com o que foi marcado '
      'e o %', (tester) async {
    await draftWith({'inf-1': 'inf-1-PM'});

    await pumpSummary(tester);

    expect(find.text('Conferir e finalizar'), findsOneWidget);
    expect(find.text('Pontuação final'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'^Início \d\d:\d\d · Fim \d\d:\d\d$')),
      findsOneWidget,
    );
    expect(find.text('85,0%'), findsOneWidget);
    expect(find.text('Aprovado'), findsOneWidget);
    expect(
      find.text('Ana Paula Ribeiro · 1 infração · mínimo para aprovação 70%.'),
      findsOneWidget,
    );
    expect(find.text('Por categoria'), findsOneWidget);
    expect(find.text('CV'), findsOneWidget);
    expect(find.text('Controle do Veículo'), findsOneWidget);
    expect(find.text('1 infração'), findsOneWidget);
    expect(find.text('70,0%'), findsOneWidget);
    expect(find.text('RR'), findsOneWidget);
    expect(find.text('sem infração'), findsOneWidget);
    expect(find.text('100,0%'), findsOneWidget);
    expect(find.text('Confirmar'), findsOneWidget);
  });

  testWidgets('abaixo de 70% mostra "Não recomendado"', (tester) async {
    await draftWith({'inf-1': 'inf-1-M', 'inf-2': 'inf-2-M'});

    await pumpSummary(tester);

    expect(find.text('50,0%'), findsOneWidget);
    expect(find.text('Não recomendado'), findsOneWidget);
    expect(
      find.text('Ana Paula Ribeiro · 2 infrações · mínimo para aprovação 70%.'),
      findsOneWidget,
    );
  });

  testWidgets('sem nenhuma marcação, a linha diz "nenhuma infração"',
      (tester) async {
    await draftWith({});

    await pumpSummary(tester);

    expect(
      find.text('Ana Paula Ribeiro · nenhuma infração · mínimo para aprovação 70%.'),
      findsOneWidget,
    );
  });

  testWidgets('"Confirmar" põe na fila e fecha avisando que confirmou',
      (tester) async {
    await draftWith({'inf-1': 'inf-1-PM'});
    await pumpSummary(tester);

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(exit, isA<SummaryConfirmed>());
    expect(find.byType(SummaryScreen), findsNothing);
    final row = await db.select(db.localAssessments).getSingle();
    expect(row.syncStatus, LocalSyncStatus.pendingSync);
  });

  testWidgets('tocar numa categoria fecha levando a categoria para o checklist',
      (tester) async {
    await draftWith({'inf-1': 'inf-1-PM'});
    await pumpSummary(tester);

    await tester.tap(find.text('Respeito às Regras'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(
      exit,
      isA<SummaryReviewCategory>().having((e) => e.categoryId, 'categoryId', 'cat-2'),
    );
    final row = await db.select(db.localAssessments).getSingle();
    expect(row.syncStatus, LocalSyncStatus.draft);
  });

  testWidgets('falha ao confirmar mostra a mensagem e a tela continua aberta',
      (tester) async {
    await draftWith({'inf-1': 'inf-1-PM'});
    await pumpSummary(
      tester,
      assessments: _FailingConfirmRepository(database: db),
    );

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível confirmar a avaliação. Tente de novo.'),
        findsOneWidget);
    expect(find.byType(SummaryScreen), findsOneWidget);
    expect(closed, isFalse);
  });
}
