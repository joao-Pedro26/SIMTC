import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/checklist/checklist_screen.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late _MockApiClient api;
  late AppDatabase db;
  late AssessmentRepository assessmentRepository;
  late ParticipantRepository participantRepository;
  late AssessmentCatalogRepository catalogRepository;
  late ConnectivityService connectivity;

  const pmComment = 'Excedeu o limite em trecho sinalizado';

  setUp(() async {
    api = _MockApiClient();
    // Ao cancelar um stream, o drift adia o fechamento com um `Timer` de
    // duração zero. Dentro do relógio falso do `testWidgets`, esse timer
    // nasce no dispose da tela (no fim do teste) e nunca roda: o teste
    // reclama de timer pendente e o `db.close()` do tearDown espera por ele
    // para sempre. Fechar os streams na hora elimina o timer.
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    assessmentRepository = AssessmentRepository(database: db);
    participantRepository = ParticipantRepository(apiClient: api, database: db);
    catalogRepository = AssessmentCatalogRepository(apiClient: api, database: db);
    connectivity = ConnectivityService();

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
    for (final n in [
      ('note-b', 'B', 1, null),
      ('note-pm', 'PM', 3, pmComment),
      ('note-m', 'M', 5, null),
    ]) {
      await db.into(db.infractionNotes).insert(
            InfractionNotesCompanion.insert(
              id: n.$1,
              infractionId: 'inf-1',
              noteType: n.$2,
              deduction: n.$3,
              comment: Value(n.$4),
            ),
          );
    }
  });

  tearDown(() async {
    await db.close();
    connectivity.dispose();
  });

  Widget withProviders(Widget child) {
    return MultiProvider(
      providers: [
        Provider<AssessmentRepository>.value(value: assessmentRepository),
        Provider<ParticipantRepository>.value(value: participantRepository),
        Provider<AssessmentCatalogRepository>.value(value: catalogRepository),
        ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
      ],
      child: child,
    );
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(withProviders(
      const MaterialApp(
        home: ChecklistScreen(sessionId: 'sess-1', participantId: 'tp-1'),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// O checklist empilhado sobre uma tela de origem — para ver a volta.
  Future<void> pumpOverOrigin(WidgetTester tester) async {
    await tester.pumpWidget(withProviders(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const ChecklistScreen(sessionId: 'sess-1', participantId: 'tp-1'),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  Future<void> addSecondCategory() async {
    await db.into(db.assessmentCategories).insert(
          AssessmentCategoriesCompanion.insert(
            id: 'cat-2',
            code: 'RR',
            name: 'Respeito às Regras',
            order: 2,
          ),
        );
    for (final (id, order) in [('inf-3', 3), ('inf-7', 7)]) {
      await db.into(db.infractions).insert(
            InfractionsCompanion.insert(
              id: id,
              categoryId: 'cat-2',
              description: 'Infração da ficha, item $order',
              order: order,
            ),
          );
    }
  }

  Future<void> goOffline() async {
    final plugin = _MockConnectivity();
    when(plugin.checkConnectivity)
        .thenAnswer((_) async => [ConnectivityResult.none]);
    when(() => plugin.onConnectivityChanged)
        .thenAnswer((_) => const Stream.empty());
    connectivity.dispose();
    connectivity = ConnectivityService(connectivity: plugin);
    await connectivity.initialize();
  }

  testWidgets('abre com o nome do participante e a primeira categoria aberta',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('Ana Paula Ribeiro'), findsOneWidget);
    expect(find.text('CV'), findsOneWidget);
    expect(find.text('Excesso de velocidade'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('PM'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('salvo'), findsOneWidget);
    expect(find.text('0 de 1 categorias revisadas'), findsOneWidget);
  });

  testWidgets('tocar na categoria aberta fecha, e a fechada mostra "N itens"',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Controle do Veículo'));
    await tester.pumpAndSettle();

    expect(find.text('Excesso de velocidade'), findsNothing);
    expect(find.text('1 item'), findsOneWidget);
  });

  testWidgets(
      'abrir outra categoria fecha a aberta, e o número da infração é o item '
      'da ficha (order), não a posição', (tester) async {
    await addSecondCategory();
    await pumpScreen(tester);
    expect(find.text('2 itens'), findsOneWidget);

    await tester.tap(find.text('Respeito às Regras'));
    await tester.pumpAndSettle();

    expect(find.text('Excesso de velocidade'), findsNothing);
    expect(find.text('1 item'), findsOneWidget);
    expect(find.text('Infração da ficha, item 7'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('2'), findsNothing);
  });

  testWidgets(
      'abrir a próxima categoria rola até o cabeçalho dela — sem isso, a de '
      'cima fecha e a recém-aberta fica acima da tela', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // As duas categorias altas, cada infração com os 3 botões: com uma só
    // alta, a lista encolhe tanto ao fechar a de cima que a rolagem volta
    // sozinha para o topo e o defeito some.
    Future<void> addTallInfractions(String categoryId, int from, int to) async {
      for (var order = from; order <= to; order++) {
        final id = 'inf-$categoryId-$order';
        await db.into(db.infractions).insert(
              InfractionsCompanion.insert(
                id: id,
                categoryId: categoryId,
                description: 'Infração alta, item $order',
                order: order,
              ),
            );
        for (final (type, deduction) in [('B', 1), ('PM', 3), ('M', 5)]) {
          await db.into(db.infractionNotes).insert(
                InfractionNotesCompanion.insert(
                  id: 'note-$id-$type',
                  infractionId: id,
                  noteType: type,
                  deduction: deduction,
                ),
              );
        }
      }
    }

    await addTallInfractions('cat-1', 2, 9);
    await addSecondCategory();
    await addTallInfractions('cat-2', 10, 17);
    await pumpScreen(tester);

    await tester.scrollUntilVisible(find.text('Respeito às Regras'), 200);
    await tester.tap(find.text('Respeito às Regras'));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('Respeito às Regras')).dy,
        greaterThanOrEqualTo(0));
    expect(tester.getBottomLeft(find.text('Infração da ficha, item 3')).dy,
        lessThanOrEqualTo(915));
  });

  testWidgets('marcar a nota M zera o score da categoria e do geral', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('M'));
    await tester.pumpAndSettle();

    expect(find.text('0,0%'), findsNWidgets(2), reason: 'selo da categoria e geral');
    expect(find.text('1 de 1 categorias revisadas'), findsOneWidget);
  });

  testWidgets(
      'a observação da nota escolhida aparece embaixo dos botões, e some ao '
      'desmarcar', (tester) async {
    await pumpScreen(tester);
    expect(find.text(pmComment), findsNothing);

    await tester.tap(find.text('PM'));
    await tester.pumpAndSettle();
    expect(find.text(pmComment), findsOneWidget);

    await tester.tap(find.text('PM'));
    await tester.pumpAndSettle();
    expect(find.text(pmComment), findsNothing);
    expect(find.text('100,0%'), findsNWidgets(2), reason: 'selo da categoria e geral');
    expect(find.text('0 de 1 categorias revisadas'), findsOneWidget);
  });

  testWidgets('sem conexão, a faixa avisa que as marcações continuam salvas',
      (tester) async {
    await goOffline();
    await pumpScreen(tester);

    expect(
      find.text('Sem conexão — as marcações continuam sendo salvas no aparelho.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'finalizar com categoria sem marcação pergunta e, ao confirmar, grava e '
      'volta para a tela anterior', (tester) async {
    await pumpOverOrigin(tester);

    await tester.tap(find.text('Finalizar avaliação'));
    await tester.pumpAndSettle();

    expect(find.text('Finalizar avaliação?'), findsOneWidget);
    expect(
      find.text('1 categoria está sem nenhuma infração marcada e conta como '
          '100% no cálculo. Finalizar assim mesmo?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(find.byType(ChecklistScreen), findsNothing);
    expect(find.text('abrir'), findsOneWidget);
    final row = await db.select(db.localAssessments).getSingle();
    expect(row.syncStatus, LocalSyncStatus.pendingSync);
    expect(row.endTime, isNotNull);
  });

  testWidgets('cancelar o diálogo não finaliza nem sai da tela', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Finalizar avaliação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byType(ChecklistScreen), findsOneWidget);
    final row = await db.select(db.localAssessments).getSingle();
    expect(row.syncStatus, LocalSyncStatus.draft);
  });

  testWidgets('com todas as categorias revisadas, finaliza sem perguntar',
      (tester) async {
    await pumpOverOrigin(tester);
    await tester.tap(find.text('PM'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Finalizar avaliação'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(ChecklistScreen), findsNothing);
    final row = await db.select(db.localAssessments).getSingle();
    expect(row.syncStatus, LocalSyncStatus.pendingSync);
  });

  testWidgets('sem catálogo no aparelho, avisa e não oferece "Finalizar"',
      (tester) async {
    await db.delete(db.infractionNotes).go();
    await db.delete(db.infractions).go();
    await db.delete(db.assessmentCategories).go();

    await pumpScreen(tester);

    expect(find.byKey(const Key('checklist-no-catalog')), findsOneWidget);
    expect(find.text('Finalizar avaliação'), findsNothing);
    expect(find.textContaining('categorias revisadas'), findsNothing);
  });
}
