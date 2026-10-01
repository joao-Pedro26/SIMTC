import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/router.dart';
import 'package:simtc/ui/checklist/checklist_screen.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/summary/summary_screen.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockConnectivity extends Mock implements Connectivity {}

LinearProgressIndicator scoreBar(WidgetTester tester) =>
    tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));

Color scoreBarColor(WidgetTester tester) =>
    (scoreBar(tester).valueColor! as AlwaysStoppedAnimation<Color>).value;

void main() {
  late _MockApiClient api;
  late _MockAuthRepository auth;
  late AppDatabase db;
  late AssessmentRepository assessmentRepository;
  late ParticipantRepository participantRepository;
  late AssessmentCatalogRepository catalogRepository;
  late ConnectivityService connectivity;

  const pmComment = 'Excedeu o limite em trecho sinalizado';

  setUp(() async {
    api = _MockApiClient();
    auth = _MockAuthRepository();
    when(() => auth.currentUser).thenReturn(const AuthUser(
      id: 'user-1',
      name: 'Carla Souza',
      email: 'carla@simtc.com.br',
      role: AppUserRole.consultant,
      consultantId: 'c-eu',
    ));
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
        ChangeNotifierProvider<AuthRepository>.value(value: auth),
        ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
      ],
      child: child,
    );
  }

  /// A avaliação já iniciada, como se o consultor tivesse tocado em "Iniciar
  /// avaliação" antes — o caminho da maioria dos testes.
  Future<void> startEvaluation() {
    return assessmentRepository.openDraft(
      trainingParticipantId: 'tp-1',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
    );
  }

  Future<void> pumpScreen(WidgetTester tester, {bool started = true}) async {
    if (started) await startEvaluation();
    await tester.pumpWidget(withProviders(
      const MaterialApp(
        home: ChecklistScreen(sessionId: 'sess-1', participantId: 'tp-1'),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// O checklist empilhado sobre uma tela de origem, com as rotas reais do
  /// checklist e da conferência — o "Finalizar avaliação" navega pelo
  /// go_router.
  Future<void> pumpOverOrigin(WidgetTester tester, {bool started = true}) async {
    if (started) await startEvaluation();
    final router = GoRouter(
      initialLocation: '/origem',
      routes: [
        GoRoute(
          path: '/origem',
          builder: (context, state) => const Scaffold(body: Text('origem')),
        ),
        GoRoute(
          path: AppRoutes.participantChecklist('sess-1', 'tp-1'),
          builder: (context, state) =>
              const ChecklistScreen(sessionId: 'sess-1', participantId: 'tp-1'),
        ),
        GoRoute(
          path: AppRoutes.participantSummary('sess-1', 'tp-1'),
          builder: (context, state) => const SummaryScreen(participantId: 'tp-1'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(withProviders(MaterialApp.router(routerConfig: router)));
    router.push(AppRoutes.participantChecklist('sess-1', 'tp-1'));
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
    expect(find.textContaining('categorias revisadas'), findsNothing);
    expect(scoreBar(tester).value, 1.0, reason: 'sem marcação, a nota é 100%');
    expect(scoreBarColor(tester), AppColors.primary);
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
    expect(find.textContaining('categorias revisadas'), findsNothing);
    expect(scoreBar(tester).value, 0.0, reason: 'a barra acompanha a nota');
    expect(scoreBarColor(tester), AppColors.dangerInk,
        reason: 'abaixo de 70% a barra avisa que não aprova');
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
    expect(scoreBar(tester).value, 1.0, reason: 'desmarcar devolve a nota');
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
      '"Finalizar avaliação" abre a conferência sem diálogo, mesmo com '
      'categoria sem marcação, e ainda não põe nada na fila', (tester) async {
    await pumpOverOrigin(tester);

    await tester.tap(find.text('Finalizar avaliação'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SummaryScreen), findsOneWidget);
    final row = await db.select(db.localAssessments).getSingle();
    expect(row.syncStatus, LocalSyncStatus.draft);
  });

  testWidgets(
      '"Confirmar" na conferência põe na fila e fecha o checklist junto, '
      'de volta à tela de origem', (tester) async {
    await pumpOverOrigin(tester);
    await tester.tap(find.text('PM'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Finalizar avaliação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(find.byType(SummaryScreen), findsNothing);
    expect(find.byType(ChecklistScreen), findsNothing);
    expect(find.text('origem'), findsOneWidget);
    final row = await db.select(db.localAssessments).getSingle();
    expect(row.syncStatus, LocalSyncStatus.pendingSync);
    expect(row.endTime, isNotNull);
    expect(row.participantName, 'Ana Paula Ribeiro');
  });

  testWidgets('voltar da conferência sem confirmar deixa o rascunho como estava',
      (tester) async {
    await pumpOverOrigin(tester);
    await tester.tap(find.text('Finalizar avaliação'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    expect(find.byType(SummaryScreen), findsNothing);
    expect(find.byType(ChecklistScreen), findsOneWidget);
    final row = await db.select(db.localAssessments).getSingle();
    expect(row.syncStatus, LocalSyncStatus.draft);
  });

  testWidgets(
      'tocar numa categoria da conferência volta ao checklist com ela aberta',
      (tester) async {
    await addSecondCategory();
    await pumpOverOrigin(tester);
    expect(find.text('Excesso de velocidade'), findsOneWidget);

    await tester.tap(find.text('Finalizar avaliação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Respeito às Regras'));
    await tester.pumpAndSettle();

    expect(find.byType(SummaryScreen), findsNothing);
    expect(find.text('Infração da ficha, item 3'), findsOneWidget);
    expect(find.text('Excesso de velocidade'), findsNothing);
  });

  testWidgets('sem catálogo no aparelho, avisa e não oferece "Finalizar"',
      (tester) async {
    await db.delete(db.infractionNotes).go();
    await db.delete(db.infractions).go();
    await db.delete(db.assessmentCategories).go();

    await pumpScreen(tester);

    expect(find.byKey(const Key('checklist-no-catalog')), findsOneWidget);
    expect(find.text('Finalizar avaliação'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  group('antes do "Iniciar avaliação"', () {
    testWidgets(
        'mostra o nome, "não iniciada" e o botão — sem a lista, sem "salvo" '
        'e sem gravar nada', (tester) async {
      await pumpScreen(tester, started: false);

      expect(find.text('Ana Paula Ribeiro'), findsOneWidget);
      expect(find.text('não iniciada'), findsOneWidget);
      expect(find.byKey(const Key('checklist-not-started')), findsOneWidget);
      expect(find.text('A avaliação ainda não começou.'), findsOneWidget);
      expect(find.text('Iniciar avaliação'), findsOneWidget);
      expect(find.text('Excesso de velocidade'), findsNothing);
      expect(find.text('salvo'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Finalizar avaliação'), findsNothing);
      expect(await db.select(db.localAssessments).get(), isEmpty);
    });

    testWidgets(
        'lista "O que será avaliado": o código, o nome e os itens de cada '
        'categoria, sem abrir nada', (tester) async {
      await addSecondCategory();
      await pumpScreen(tester, started: false);

      expect(find.text('O que será avaliado'), findsOneWidget);
      expect(find.text('3 itens'), findsOneWidget, reason: 'o total, no título');
      expect(find.text('CV'), findsOneWidget);
      expect(find.text('Controle do Veículo'), findsOneWidget);
      expect(find.text('1 item'), findsOneWidget);
      expect(find.text('RR'), findsOneWidget);
      expect(find.text('Respeito às Regras'), findsOneWidget);
      expect(find.text('2 itens'), findsOneWidget);
      expect(find.textContaining('pts'), findsNothing, reason: 'o app não tem pontos');

      await tester.tap(find.text('Controle do Veículo'));
      await tester.pumpAndSettle();

      expect(find.text('Excesso de velocidade'), findsNothing,
          reason: 'antes do "Iniciar", a lista é só leitura');
    });

    testWidgets(
        'com outro participante em andamento: aviso com o nome, "Iniciar" '
        'desabilitado e nada gravado', (tester) async {
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

      await pumpScreen(tester, started: false);

      expect(
        find.text('Você já está avaliando Marina Lopes. Finalize essa '
            'avaliação para iniciar outra.'),
        findsOneWidget,
      );
      expect(find.text('O que será avaliado'), findsOneWidget,
          reason: 'a lista continua à vista');
      final button = tester.widget<AppCtaButton>(find.byType(AppCtaButton));
      expect(button.onPressed, isNull);

      await tester.tap(find.text('Iniciar avaliação'), warnIfMissed: false);
      await tester.pumpAndSettle();

      final rows = await db.select(db.localAssessments).get();
      expect(rows.map((r) => r.trainingParticipantId), ['tp-2']);
    });

    testWidgets('abrir sem querer e voltar não deixa rastro', (tester) async {
      await pumpOverOrigin(tester, started: false);

      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();

      expect(find.text('origem'), findsOneWidget);
      expect(await db.select(db.localAssessments).get(), isEmpty);
    });

    testWidgets(
        '"Iniciar avaliação" grava o início e mostra o checklist, com a hora '
        'em que começou', (tester) async {
      await pumpScreen(tester, started: false);

      await tester.tap(find.text('Iniciar avaliação'));
      await tester.pumpAndSettle();

      expect(find.text('Excesso de velocidade'), findsOneWidget);
      expect(find.textContaining('Iniciada às'), findsOneWidget);
      expect(find.text('salvo'), findsOneWidget);
      expect(scoreBar(tester).value, 1.0);
      expect(find.text('Finalizar avaliação'), findsOneWidget);
      expect(find.text('Iniciar avaliação'), findsNothing);
      final row = await db.select(db.localAssessments).getSingle();
      expect(row.syncStatus, LocalSyncStatus.draft);
    });

    testWidgets('sem catálogo no aparelho, nem dá para iniciar', (tester) async {
      await db.delete(db.infractionNotes).go();
      await db.delete(db.infractions).go();
      await db.delete(db.assessmentCategories).go();

      await pumpScreen(tester, started: false);

      expect(find.byKey(const Key('checklist-no-catalog')), findsOneWidget);
      expect(find.text('Iniciar avaliação'), findsNothing);
    });
  });
}
