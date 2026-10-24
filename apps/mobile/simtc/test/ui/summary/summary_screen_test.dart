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
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
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
      consultantId: 'c-eu',
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
  ///
  /// Com [tablet], num tablet desse tamanho.
  Future<void> pumpSummary(
    WidgetTester tester, {
    AssessmentRepository? assessments,
    Size? tablet,
  }) async {
    if (tablet != null) {
      tester.view.physicalSize = tablet;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AssessmentRepository>.value(
            value: assessments ?? assessmentRepository,
          ),
          Provider<ParticipantRepository>.value(value: participantRepository),
          Provider<AssessmentCatalogRepository>.value(value: catalogRepository),
        ],
        child: FormFactorScope(
          formFactor: tablet == null ? FormFactor.phone : FormFactor.tablet,
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

  group('no tablet', () {
    double fontSizeOf(WidgetTester tester, String text) {
      final finder = find.text(text);
      return tester.widget<Text>(finder).style?.fontSize ??
          DefaultTextStyle.of(tester.element(finder)).style.fontSize!;
    }

    Finder confirm() => find.widgetWithText(AppCtaButton, 'Confirmar');

    testWidgets(
        'em paisagem: uma coluna de 940 centrada, com o "Confirmar" de 420×60 '
        'no fim dela, à esquerda, e sem rodapé (quadro "4g")', (tester) async {
      await draftWith({'inf-1': 'inf-1-PM'});
      await pumpSummary(tester, tablet: const Size(1280, 800));

      final column = tester.getRect(find.byKey(const Key('summary-column')));
      expect(column.width, 940);
      expect(column.center.dx, 640);
      expect(tester.getSize(confirm()), const Size(420, 60));
      expect(tester.getTopLeft(confirm()).dx, column.left);
      expect(
        tester.getTopLeft(confirm()).dy,
        greaterThan(tester.getBottomLeft(find.text('Respeito às Regras')).dy),
      );
      expect(tester.getTopLeft(find.text('Pontuação final')).dx, column.left);
      expect(fontSizeOf(tester, '85,0%'), 48);
      expect(fontSizeOf(tester, 'Pontuação final'), 13.5);
      expect(fontSizeOf(tester, 'Aprovado'), 14);
      expect(fontSizeOf(tester, 'Conferir e finalizar'), 18);
      expect(fontSizeOf(tester, 'Controle do Veículo'), 16);
      expect(fontSizeOf(tester, 'Confirmar'), 17);
      // Paisagem: o nome e as infrações lado a lado.
      expect(tester.getCenter(find.text('1 infração')).dy,
          tester.getCenter(find.text('Controle do Veículo')).dy);
      final row = find.byKey(const ValueKey('summary-category-cat-1'));
      expect(tester.getSize(row).height, greaterThanOrEqualTo(76));
    });

    testWidgets(
        'em retrato: recuo de 32, o nome e as infrações um embaixo do outro e o '
        '"Confirmar" no rodapé, na largura toda (quadro "4r")', (tester) async {
      await draftWith({'inf-1': 'inf-1-PM'});
      await pumpSummary(tester, tablet: const Size(800, 1280));

      expect(find.byKey(const Key('summary-column')), findsNothing);
      expect(tester.getTopLeft(find.text('Pontuação final')).dx, 32);
      expect(tester.getSize(confirm()), const Size(800 - 2 * 32, 60));
      expect(tester.getBottomLeft(confirm()).dy, 1280 - 16);
      expect(tester.getTopLeft(find.text('1 infração')).dy,
          greaterThan(tester.getBottomLeft(find.text('Controle do Veículo')).dy));
      expect(tester.getTopRight(find.byKey(const ValueKey('summary-category-cat-1'))).dx,
          800 - 32);
    });

    testWidgets('em paisagem, "Confirmar" do fim da coluna confirma e fecha',
        (tester) async {
      await draftWith({'inf-1': 'inf-1-PM'});
      await pumpSummary(tester, tablet: const Size(1280, 800));

      await tester.tap(confirm());
      await tester.pumpAndSettle();

      expect(closed, isTrue);
      expect(exit, isA<SummaryConfirmed>());
    });

    testWidgets('em paisagem, o erro de confirmar aparece acima do botão',
        (tester) async {
      await draftWith({'inf-1': 'inf-1-PM'});
      await pumpSummary(
        tester,
        assessments: _FailingConfirmRepository(database: db),
        tablet: const Size(1280, 800),
      );

      await tester.tap(confirm());
      await tester.pumpAndSettle();

      const error = 'Não foi possível confirmar a avaliação. Tente de novo.';
      expect(tester.getBottomLeft(find.text(error)).dy,
          lessThan(tester.getTopLeft(confirm()).dy));
    });
  });
}
