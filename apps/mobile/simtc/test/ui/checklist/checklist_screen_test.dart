import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
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
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/router.dart';
import 'package:simtc/ui/checklist/checklist_screen.dart';
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/inline_notice.dart';
import 'package:simtc/ui/result/result_screen.dart';
import 'package:simtc/ui/summary/summary_screen.dart';

import '../../support/ripple.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockConnectivity extends Mock implements Connectivity {}

LinearProgressIndicator scoreBar(WidgetTester tester) =>
    tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));

Color scoreBarColor(WidgetTester tester) =>
    (scoreBar(tester).valueColor! as AlwaysStoppedAnimation<Color>).value;

const _landscape = Size(1280, 800);
const _portrait = Size(800, 1280);

/// O tamanho da fonte de um texto — o do próprio `Text` ou, num botão, o
/// que o botão passa adiante.
double fontSizeOf(WidgetTester tester, String text) {
  final finder = find.text(text);
  return tester.widget<Text>(finder).style?.fontSize ??
      DefaultTextStyle.of(tester.element(finder)).style.fontSize!;
}

void main() {
  late _MockApiClient api;
  late _MockAuthRepository auth;
  late AppDatabase db;
  late AssessmentRepository assessmentRepository;
  late ParticipantRepository participantRepository;
  late AssessmentCatalogRepository catalogRepository;
  late SessionRepository sessionRepository;
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
    sessionRepository = SessionRepository(apiClient: api, database: db);
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
        // O "Confirmar" abre o Resultado, que segue a sessão.
        Provider<SessionRepository>.value(value: sessionRepository),
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
      consultantId: 'c-eu',
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
        GoRoute(
          path: '/sessions/:sessionId/participants/:participantId/result',
          builder: (context, state) => ResultScreen(
            sessionId: state.pathParameters['sessionId']!,
            participantId: state.pathParameters['participantId']!,
            justConfirmed: state.uri.queryParameters['confirmada'] == '1',
          ),
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

  /// O participante reservado para a consultora logada (`c-eu`).
  Future<void> assignToMe() {
    return (db.update(db.participants)..where((t) => t.id.equals('tp-1')))
        .write(const ParticipantsCompanion(assignedConsultantId: Value('c-eu')));
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
      'o cabeçalho da categoria aberta e os botões B/PM/M mostram a '
      'ondulação do toque (Fase 8C)', (tester) async {
    await pumpScreen(tester);

    Finder inkOf(String text) =>
        find.ancestor(of: find.text(text), matching: find.byType(InkWell)).first;

    expectVisibleRipple(tester, inkOf('Controle do Veículo'),
        background: AppColors.categoryExpandedBg);
    expectVisibleRipple(tester, inkOf('B'), background: AppColors.noteBBg);

    await tester.tap(find.text('PM'));
    await tester.pumpAndSettle();
    expectVisibleRipple(tester, inkOf('PM'), background: AppColors.notePmFill);
  });

  testWidgets(
      'o leitor de tela diz qual dos B/PM/M está marcado (Fase 8C)',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('PM'));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.text('PM')),
      isSemantics(label: 'PM', isButton: true, isSelected: true),
    );
    expect(
      tester.getSemantics(find.text('B')),
      isSemantics(label: 'B', isButton: true, isSelected: false),
    );
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
      'dois toques rápidos em "Finalizar avaliação" abrem uma conferência só '
      '(Fase 8C)', (tester) async {
    await pumpOverOrigin(tester);

    await tester.tap(find.text('Finalizar avaliação'));
    // O segundo toque antes do próximo quadro: a rota nova ainda não
    // está montada.
    await tester.tap(find.text('Finalizar avaliação'));
    await tester.pumpAndSettle();

    expect(find.byType(SummaryScreen, skipOffstage: false), findsOneWidget);
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
      '"Confirmar" na conferência põe na fila e troca o checklist pelo '
      'Resultado; "Próximo participante" volta à tela de origem', (tester) async {
    await pumpOverOrigin(tester);
    await tester.tap(find.text('PM'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Finalizar avaliação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(find.byType(SummaryScreen), findsNothing);
    expect(find.byType(ChecklistScreen), findsNothing);
    final result = tester.widget<ResultScreen>(find.byType(ResultScreen));
    expect(result.justConfirmed, isTrue);
    expect(find.text('Avaliação concluída'), findsOneWidget);
    expect(find.text('Na fila de envio — sai sozinha quando houver conexão.'),
        findsOneWidget);
    final row = await db.select(db.localAssessments).getSingle();
    expect(row.syncStatus, LocalSyncStatus.pendingSync);
    expect(row.endTime, isNotNull);
    expect(row.participantName, 'Ana Paula Ribeiro');

    await tester.tap(find.text('Próximo participante'));
    await tester.pumpAndSettle();

    expect(find.text('origem'), findsOneWidget);
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

  testWidgets(
      'menu ⋮ "Descartar avaliação" pede confirmação: "Cancelar" não muda '
      'nada, "Descartar" volta a "não iniciada"', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('PM'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('checklist-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar avaliação'));
    await tester.pumpAndSettle();

    expect(find.text('Descartar a avaliação?'), findsOneWidget);
    expect(
      find.text('As marcações e a hora de início de Ana Paula Ribeiro serão '
          'apagadas. O participante continua com você.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text(pmComment), findsOneWidget, reason: 'nada mudou');

    await tester.tap(find.byKey(const Key('checklist-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar avaliação'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Descartar'));
    await tester.pumpAndSettle();

    expect(find.text('não iniciada'), findsOneWidget);
    expect(find.text('Iniciar avaliação'), findsOneWidget);
    expect(find.text('Excesso de velocidade'), findsNothing);
    expect(await db.select(db.localAssessments).get(), isEmpty);
    expect(await db.select(db.localAssessmentItems).get(), isEmpty);
  });

  testWidgets(
      'sem o nome do participante no aparelho, a confirmação do descarte diz '
      '"deste participante"', (tester) async {
    // O cache da sessão foi podado: a avaliação iniciada continua no aparelho.
    await db.delete(db.participants).go();
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('checklist-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar avaliação'));
    await tester.pumpAndSettle();

    expect(
      find.text('As marcações e a hora de início deste participante serão '
          'apagadas. O participante continua com você.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'avaliação já confirmada: as marcações à vista, sem mudar nota, sem '
      '"Finalizar" e sem menu', (tester) async {
    final draft = await assessmentRepository.openDraft(
      trainingParticipantId: 'tp-1',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
      consultantId: 'c-eu',
    );
    await assessmentRepository.mark(
      localAssessmentId: draft.id,
      infractionId: 'inf-1',
      infractionNoteId: 'note-pm',
    );
    await assessmentRepository.confirm(draft.id, participantName: 'Ana', score: 88);

    await pumpScreen(tester, started: false);

    expect(find.text('Avaliação confirmada — não pode mais ser alterada.'),
        findsOneWidget);
    expect(find.text(pmComment), findsOneWidget, reason: 'a nota marcada aparece');
    expect(find.text('Finalizar avaliação'), findsNothing);
    expect(find.byKey(const Key('checklist-menu')), findsNothing);

    await tester.tap(find.text('M'));
    await tester.pumpAndSettle();

    final item = await db.select(db.localAssessmentItems).getSingle();
    expect(item.infractionNoteId, 'note-pm');
  });

  testWidgets(
      '"Desatribuir participante" avisa que a avaliação iniciada será '
      'descartada e, confirmado, fecha o checklist', (tester) async {
    await assignToMe();
    when(() => api.post<Map<String, dynamic>>('/practical-assessments/unassign',
        data: any(named: 'data'))).thenAnswer((_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/practical-assessments/unassign'),
          statusCode: 201,
          data: {'unassigned': 1},
        ));
    await pumpOverOrigin(tester);

    await tester.tap(find.byKey(const Key('checklist-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desatribuir participante'));
    await tester.pumpAndSettle();

    expect(find.text('Desatribuir Ana Paula Ribeiro?'), findsOneWidget);
    expect(
      find.text('Ana Paula Ribeiro volta para "Pendente" e fica disponível para '
          'outro consultor. A avaliação iniciada será descartada.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Desatribuir'));
    await tester.pumpAndSettle();

    expect(find.text('origem'), findsOneWidget);
    expect(find.text('Participante desatribuído.'), findsOneWidget);
    expect(await db.select(db.localAssessments).get(), isEmpty);
    final row = await db.select(db.participants).getSingle();
    expect(row.status, 'PENDENTE');
  });

  testWidgets(
      'com o desatribuir esperando o backend, o menu ⋮ e o "Finalizar" ficam '
      'desabilitados', (tester) async {
    await assignToMe();
    final post = Completer<Response<Map<String, dynamic>>>();
    when(() => api.post<Map<String, dynamic>>('/practical-assessments/unassign',
        data: any(named: 'data'))).thenAnswer((_) => post.future);
    await pumpOverOrigin(tester);

    await tester.tap(find.byKey(const Key('checklist-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desatribuir participante'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Desatribuir'));
    await tester.pumpAndSettle();

    final menu = tester.widget<PopupMenuButton<Object?>>(
      find.byKey(const Key('checklist-menu')),
    );
    expect(menu.enabled, isFalse);
    final finish = tester.widget<AppCtaButton>(
      find.widgetWithText(AppCtaButton, 'Finalizar avaliação'),
    );
    expect(finish.onPressed, isNull);

    post.complete(Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: '/practical-assessments/unassign'),
      statusCode: 201,
      data: {'unassigned': 1},
    ));
    await tester.pumpAndSettle();

    expect(find.text('origem'), findsOneWidget);
  });

  testWidgets('sem rede, "Desatribuir participante" fica desabilitado',
      (tester) async {
    await assignToMe();
    await goOffline();
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('checklist-menu')));
    await tester.pumpAndSettle();

    expect(find.text('Disponível quando houver conexão'), findsOneWidget);
    final item = tester.widget<PopupMenuItem<Object?>>(find.ancestor(
      of: find.text('Desatribuir participante'),
      matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
    ));
    expect(item.enabled, isFalse);
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

  // O participante saiu das mãos do consultor com a avaliação pela metade e
  // depois voltou: continua de onde parou (decisão de 09/10/2026).
  group('avaliação antiga que volta', () {
    const assignPath = '/practical-assessments/assign';
    const released =
        'Este participante não está mais com você. Atribua de novo para continuar.';

    /// A avaliação começada às 08:12 de 25/09, com a nota PM marcada.
    Future<void> seedOldDraft({String participantId = 'tp-1', int minute = 12}) async {
      final id = 'draft-$participantId';
      final at = DateTime(2026, 9, 25, 8, minute);
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
      if (participantId == 'tp-1') {
        await assessmentRepository.mark(
          localAssessmentId: id,
          infractionId: 'inf-1',
          infractionNoteId: 'note-pm',
        );
      }
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

    AppCtaButton cta(WidgetTester tester, String label) =>
        tester.widget<AppCtaButton>(find.widgetWithText(AppCtaButton, label));

    testWidgets(
        'fora das mãos do consultor, a tela oferece continuar: diz quando '
        'começou e que as respostas voltam', (tester) async {
      await seedOldDraft();
      await setParticipant(status: 'NAO_RECOMENDADO');

      await pumpScreen(tester, started: false);

      expect(
        find.text('Você começou esta avaliação em 25/09 às 08:12.'),
        findsOneWidget,
      );
      expect(find.text('As respostas voltam ao continuar.'), findsOneWidget);
      expect(cta(tester, 'Continuar avaliação').onPressed, isNotNull);
      // No lugar do que a tela diz de quem nem começou.
      expect(find.text('A avaliação ainda não começou.'), findsNothing);
      expect(find.textContaining('A hora de início é registrada'), findsNothing);
      expect(find.text('Iniciar avaliação'), findsNothing);
      expect(find.text('não iniciada'), findsNothing);
      expect(find.textContaining('Iniciada em 25 set'), findsOneWidget);
      // Ainda é a tela de antes do checklist: sem as notas, sem "salvo".
      expect(find.byKey(const Key('checklist-not-started')), findsOneWidget);
      expect(find.text('O que será avaliado'), findsOneWidget);
      // O título da lista é cabeçalho para o leitor de tela (Fase 8C).
      expect(tester.getSemantics(find.text('O que será avaliado')),
          isSemantics(isHeader: true));
      expect(find.text('PM'), findsNothing);
      expect(find.text('salvo'), findsNothing);
      expect(find.text('Finalizar avaliação'), findsNothing);
    });

    testWidgets(
        '"Continuar avaliação" reserva o participante e abre o checklist com '
        'as respostas de antes', (tester) async {
      await seedOldDraft();
      await setParticipant(status: 'NAO_RECOMENDADO');
      when(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: assignPath),
          statusCode: 201,
          data: const {},
        ),
      );
      await pumpScreen(tester, started: false);

      await tester.tap(find.text('Continuar avaliação'));
      await tester.pumpAndSettle();

      verify(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .called(1);
      expect(find.text('Excesso de velocidade'), findsOneWidget);
      // A observação da nota PM só aparece com a nota marcada.
      expect(find.text(pmComment), findsOneWidget);
      expect(find.textContaining('Iniciada em 25 set'), findsOneWidget);
      expect(find.text('salvo'), findsOneWidget);
      expect(cta(tester, 'Finalizar avaliação').onPressed, isNotNull);
      expect(find.text(released), findsNothing);
      expect(await db.select(db.localAssessments).get(), hasLength(1));
    });

    testWidgets('com a reserva demorando, o botão gira e o checklist ainda não '
        'abre', (tester) async {
      await seedOldDraft();
      await setParticipant(status: 'NAO_RECOMENDADO');
      final reply = Completer<Response<Map<String, dynamic>>>();
      when(() => api.post<Map<String, dynamic>>(assignPath, data: any(named: 'data')))
          .thenAnswer((_) => reply.future);
      await pumpScreen(tester, started: false);

      await tester.tap(find.text('Continuar avaliação'));
      await tester.pump();
      // Um quadro no meio do envio.
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.widget<AppCtaButton>(find.byType(AppCtaButton)).isLoading, isTrue);
      expect(find.text('Excesso de velocidade'), findsNothing);
      expect(
        find.text('Você começou esta avaliação em 25/09 às 08:12.'),
        findsOneWidget,
      );

      reply.complete(
        Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: assignPath),
          statusCode: 201,
          data: const {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Excesso de velocidade'), findsOneWidget);
      expect(find.text(pmComment), findsOneWidget);
    });

    testWidgets(
        'com outra avaliação começada depois, o continuar fica travado, com o '
        'aviso de sempre', (tester) async {
      await seedOldDraft();
      await assignToMe();
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
      await seedOldDraft(participantId: 'tp-2', minute: 30);

      await pumpScreen(tester, started: false);

      expect(
        find.text('Você já está avaliando Marina Lopes. Finalize ou descarte '
            'essa avaliação para iniciar outra.'),
        findsOneWidget,
      );
      expect(cta(tester, 'Continuar avaliação').onPressed, isNull);
      expect(find.text('Excesso de velocidade'), findsNothing);
    });

    testWidgets(
        'o ⋮ oferece "Descartar avaliação" para começar limpo — sem dizer que '
        'o participante continua com você', (tester) async {
      await seedOldDraft();
      await setParticipant(status: 'PENDENTE');
      await pumpScreen(tester, started: false);

      await tester.tap(find.byKey(const Key('checklist-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar avaliação'));
      await tester.pumpAndSettle();

      expect(
        find.text('As marcações e a hora de início de Ana Paula Ribeiro serão '
            'apagadas.'),
        findsOneWidget,
      );
      expect(find.textContaining('continua com você'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Descartar'));
      await tester.pumpAndSettle();

      expect(find.text('A avaliação ainda não começou.'), findsOneWidget);
      expect(find.text('não iniciada'), findsOneWidget);
      expect(cta(tester, 'Iniciar avaliação').onPressed, isNotNull);
      expect(find.text('Continuar avaliação'), findsNothing);
      expect(await db.select(db.localAssessments).get(), isEmpty);
    });

    testWidgets(
        'participante liberado com o checklist aberto: o "Finalizar avaliação" '
        'desabilita, com o aviso — e volta quando ele é atribuído de novo',
        (tester) async {
      await assignToMe();
      await pumpScreen(tester);
      await tester.tap(find.text('PM'));
      await tester.pumpAndSettle();
      expect(cta(tester, 'Finalizar avaliação').onPressed, isNotNull);
      expect(find.text(released), findsNothing);

      // Um ADMIN desatribuiu, e o detalhe (embaixo) baixou a sessão de novo.
      await setParticipant(status: 'PENDENTE');
      await tester.pumpAndSettle();

      final notice = tester.widget<InlineNotice>(
        find.widgetWithText(InlineNotice, released),
      );
      expect(notice.tone, NoticeTone.warning);
      expect(cta(tester, 'Finalizar avaliação').onPressed, isNull);
      // As marcações continuam na tela.
      expect(find.text(pmComment), findsOneWidget);

      await setParticipant(status: 'EM_AVALIACAO', consultant: 'c-eu');
      await tester.pumpAndSettle();

      expect(find.text(released), findsNothing);
      expect(cta(tester, 'Finalizar avaliação').onPressed, isNotNull);
    });

    testWidgets(
        'num celular de 360x640 com a fonte ampliada, a tela de continuar e o '
        'rodapé com o aviso de liberado não estouram', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await seedOldDraft();
      await setParticipant(status: 'PENDENTE');

      Future<void> pumpLarge() async {
        await tester.pumpWidget(withProviders(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: const ChecklistScreen(sessionId: 'sess-1', participantId: 'tp-1'),
          ),
        ));
        await tester.pumpAndSettle();
      }

      await pumpLarge();
      expect(tester.takeException(), isNull);
      expect(find.text('Continuar avaliação'), findsOneWidget);
      expect(
        find.text('Você começou esta avaliação em 25/09 às 08:12.'),
        findsOneWidget,
      );

      // Agora com o checklist aberto e o participante liberado.
      await tester.pumpWidget(const SizedBox.shrink());
      await setParticipant(status: 'EM_AVALIACAO', consultant: 'c-eu');
      await pumpLarge();
      await setParticipant(status: 'PENDENTE');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(released), findsOneWidget);
      final footer = tester.getRect(find.widgetWithText(AppCtaButton, 'Finalizar avaliação'));
      expect(footer.bottom, lessThanOrEqualTo(640));
    });

    testWidgets(
        'desatribuir com a avaliação antiga à espera avisa que ela será '
        'descartada', (tester) async {
      await seedOldDraft();
      await assignToMe();
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
      await seedOldDraft(participantId: 'tp-2', minute: 30);
      await pumpScreen(tester, started: false);

      await tester.tap(find.byKey(const Key('checklist-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desatribuir participante'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('A avaliação iniciada será descartada.'),
        findsOneWidget,
      );
    });
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

      await pumpScreen(tester, started: false);

      expect(
        find.text('Você já está avaliando Marina Lopes. Finalize ou descarte '
            'essa avaliação para iniciar outra.'),
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

    testWidgets(
        'antes de iniciar, o menu ⋮ só tem "Desatribuir participante" — não '
        'há o que descartar', (tester) async {
      await assignToMe();
      await pumpScreen(tester, started: false);

      await tester.tap(find.byKey(const Key('checklist-menu')));
      await tester.pumpAndSettle();

      expect(find.text('Desatribuir participante'), findsOneWidget);
      expect(find.text('Descartar avaliação'), findsNothing);
    });

    testWidgets('de outro consultor, sem menu ⋮', (tester) async {
      await pumpScreen(tester, started: false);

      expect(find.byKey(const Key('checklist-menu')), findsNothing);
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

  group('no tablet', () {
    /// O checklist num tablet de [size], com o formato que o app decide na
    /// abertura.
    Future<void> pumpTablet(
      WidgetTester tester,
      Size size, {
      bool started = true,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      if (started) await startEvaluation();
      await tester.pumpWidget(withProviders(
        const FormFactorScope(
          formFactor: FormFactor.tablet,
          child: MaterialApp(
            home: ChecklistScreen(sessionId: 'sess-1', participantId: 'tp-1'),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'em paisagem, antes do "Iniciar": uma coluna de 760 centrada, com o '
        'botão de 420×60 no fim dela, sem rodapé (quadro "6b")', (tester) async {
      await addSecondCategory();
      await pumpTablet(tester, _landscape, started: false);

      final column = tester.getRect(find.byKey(const Key('checklist-not-started-column')));
      expect(column.width, 760);
      expect(column.center.dx, 640);

      final cta = find.widgetWithText(AppCtaButton, 'Iniciar avaliação');
      expect(tester.getSize(cta), const Size(420, 60));
      expect(tester.getCenter(cta).dx, 640);
      expect(
        find.descendant(
          of: find.byKey(const Key('checklist-not-started')),
          matching: cta,
        ),
        findsOneWidget,
        reason: 'o botão está na rolagem, no fim da coluna',
      );
      expect(
        tester.getTopLeft(cta).dy,
        greaterThan(tester.getBottomLeft(find.text('Respeito às Regras')).dy),
      );

      expect(tester.getTopLeft(find.text('CV')).dx - column.left, 7,
          reason: 'a linha não tem recuo próprio: o chip começa na coluna (7 é o recuo do chip)');
      expect(fontSizeOf(tester, 'Ana Paula Ribeiro'), 18);
      expect(fontSizeOf(tester, 'A avaliação ainda não começou.'), 18);
      expect(fontSizeOf(tester, 'O que será avaliado'), 13.5);
      expect(fontSizeOf(tester, 'Controle do Veículo'), 16);
      expect(tester.getSize(find.byIcon(AppIcons.timer).last).height, 44);
    });

    testWidgets(
        'em retrato, antes do "Iniciar": recuo de 32 e o botão no rodapé, na '
        'largura toda, com 60 de altura (quadro "6c")', (tester) async {
      await pumpTablet(tester, _portrait, started: false);

      expect(find.byKey(const Key('checklist-not-started-column')), findsNothing);
      expect(tester.getTopLeft(find.text('CV')).dx, 32 + 7);
      expect(tester.getTopLeft(find.text('O que será avaliado')).dx, 32);

      final cta = find.widgetWithText(AppCtaButton, 'Iniciar avaliação');
      expect(tester.getSize(cta), const Size(800 - 2 * 32, 60));
      expect(tester.getBottomLeft(cta).dy, 1280 - 16);
      expect(
        find.descendant(
          of: find.byKey(const Key('checklist-not-started')),
          matching: cta,
        ),
        findsNothing,
        reason: 'o botão fica fora da rolagem',
      );
      expect(fontSizeOf(tester, 'A avaliação ainda não começou.'), 19);
      expect(tester.getSize(find.byIcon(AppIcons.timer).last).height, 48);
    });

    testWidgets(
        'em paisagem, com outra avaliação em andamento, o aviso fica acima do '
        'botão, na coluna', (tester) async {
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

      await pumpTablet(tester, _landscape, started: false);

      final notice = find.byType(InlineNotice);
      final cta = find.widgetWithText(AppCtaButton, 'Iniciar avaliação');
      expect(tester.getBottomLeft(notice).dy + 12, tester.getTopLeft(cta).dy);
      expect(tester.getSize(notice).width, 760);
      expect(tester.widget<AppCtaButton>(cta).onPressed, isNull);
    });

    testWidgets('"Iniciar avaliação" no tablet começa a avaliação', (tester) async {
      await pumpTablet(tester, _landscape, started: false);

      await tester.tap(find.text('Iniciar avaliação'));
      await tester.pumpAndSettle();

      expect(find.text('Excesso de velocidade'), findsOneWidget);
      expect(find.text('salvo'), findsOneWidget);
    });

    Finder finish() => find.widgetWithText(AppCtaButton, 'Finalizar avaliação');

    testWidgets(
        'em paisagem, "Finalizar avaliação" fica no cabeçalho, numa linha com '
        'o nome e a nota, e não há rodapé (quadro "4f")', (tester) async {
      await pumpTablet(tester, _landscape);

      final button = finish();
      expect(tester.getSize(button).height, 48);
      expect(tester.getCenter(button).dy, tester.getCenter(find.byTooltip('Voltar')).dy);
      expect(tester.getTopRight(find.byKey(const Key('checklist-menu'))).dx, 1280 - 24,
          reason: 'o ⋮ fica na ponta, a 24 da borda');
      expect(
        tester.getTopLeft(find.byKey(const Key('checklist-menu'))).dx -
            tester.getTopRight(button).dx,
        8,
      );
      expect(tester.getSize(find.byType(LinearProgressIndicator)).width, 360);
      final bar = tester.getRect(find.byType(LinearProgressIndicator));
      expect(bar.left, greaterThan(tester.getTopRight(find.text('Ana Paula Ribeiro')).dx));
      expect(bar.right, lessThan(tester.getTopLeft(button).dx));
      expect(tester.getBottomLeft(button).dy, lessThan(100),
          reason: 'nada de botão no rodapé');
      expect(fontSizeOf(tester, 'Finalizar avaliação'), 15);
    });

    testWidgets(
        'em retrato, o cabeçalho tem duas faixas: nome e "Finalizar" em cima, a '
        'nota embaixo, com 12 de recuo (quadro "4q")', (tester) async {
      await pumpTablet(tester, _portrait);

      final button = finish();
      final bar = tester.getRect(find.byType(LinearProgressIndicator));
      expect(bar.left, 8 + 12);
      expect(bar.right, 800 - 20 - 12);
      expect(bar.top, greaterThan(tester.getBottomLeft(button).dy));
      expect(tester.getCenter(button).dy, tester.getCenter(find.byTooltip('Voltar')).dy);
      expect(tester.getTopRight(find.byKey(const Key('checklist-menu'))).dx, 800 - 20);
    });

    testWidgets(
        'a linha de infração no tablet: B/PM/M à direita da descrição, em 312 '
        'de largura em paisagem e 264 em retrato (quadros "4f" e "4q")', (tester) async {
      await pumpTablet(tester, _landscape);

      Rect notes() => tester.getRect(find.ancestor(
            of: find.text('PM'),
            matching: find.byWidgetPredicate(
              (w) => w is SizedBox && (w.width == 312 || w.width == 264),
            ),
          ));

      expect(notes().width, 312);
      expect(notes().right, 1280 - 24);
      expect(tester.getSize(find.text('B')).height, lessThan(56));
      expect(
        tester.getSize(find.ancestor(of: find.text('B'), matching: find.byType(InkWell)).first).height,
        56,
      );
      expect(tester.getTopLeft(find.text('Excesso de velocidade')).dx, 24 + 18 + 24);
      expect(tester.getTopLeft(find.text('Excesso de velocidade')).dy, notes().top,
          reason: 'a descrição e os botões começam na mesma altura');
      expect(tester.getTopLeft(find.text('CV')).dx, 24 + 7);
      expect(fontSizeOf(tester, 'Controle do Veículo'), 16);

      tester.view.physicalSize = _portrait;
      await tester.pumpAndSettle();

      expect(notes().width, 264);
      expect(notes().right, 800 - 24);
      expect(tester.getTopLeft(find.text('Excesso de velocidade')).dx, 24 + 18 + 16);
    });

    testWidgets(
        'a observação da nota fica embaixo da descrição, com no máximo 620 em '
        'paisagem', (tester) async {
      await pumpTablet(tester, _landscape);

      await tester.tap(find.text('PM'));
      await tester.pumpAndSettle();

      final comment = find.ancestor(of: find.text(pmComment), matching: find.byType(Container)).first;
      expect(tester.getSize(comment).width, 620);
      expect(tester.getTopLeft(comment).dy,
          greaterThan(tester.getBottomLeft(find.text('Excesso de velocidade')).dy));
    });

    testWidgets(
        'participante que saiu das mãos do consultor: o aviso vai para o topo '
        'da lista e o "Finalizar" do cabeçalho fica desabilitado', (tester) async {
      await assignToMe();
      await pumpTablet(tester, _landscape);
      await (db.update(db.participants)..where((t) => t.id.equals('tp-1')))
          .write(const ParticipantsCompanion(status: Value('PENDENTE')));
      await tester.pumpAndSettle();

      const released =
          'Este participante não está mais com você. Atribua de novo para continuar.';
      expect(find.text(released), findsOneWidget);
      expect(tester.getTopLeft(find.text(released)).dy,
          lessThan(tester.getTopLeft(find.text('Controle do Veículo')).dy));
      expect(tester.widget<AppCtaButton>(finish()).onPressed, isNull);
    });

    testWidgets(
        'numa janela estreita (tela dividida), o checklist volta ao do '
        'celular: botões embaixo da descrição e "Finalizar" no rodapé', (tester) async {
      await pumpTablet(tester, const Size(500, 800));

      expect(
        tester.getTopLeft(find.text('PM')).dy,
        greaterThan(tester.getBottomLeft(find.text('Excesso de velocidade')).dy),
      );
      expect(tester.getBottomLeft(finish()).dy, 800 - 16);
      expect(tester.getSize(finish()).width, 500 - 2 * 16);
    });

    testWidgets(
        '"Finalizar avaliação" do cabeçalho abre a conferência', (tester) async {
      tester.view.physicalSize = _landscape;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await startEvaluation();
      final router = GoRouter(
        initialLocation: AppRoutes.participantChecklist('sess-1', 'tp-1'),
        routes: [
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
      await tester.pumpWidget(withProviders(FormFactorScope(
        formFactor: FormFactor.tablet,
        child: MaterialApp.router(routerConfig: router),
      )));
      await tester.pumpAndSettle();

      await tester.tap(finish());
      await tester.pumpAndSettle();

      expect(find.text('Conferir e finalizar'), findsOneWidget);
    });

    testWidgets(
        'girar com o menu ⋮ aberto não perde a escolha', (tester) async {
      await pumpTablet(tester, _landscape);

      await tester.tap(find.byKey(const Key('checklist-menu')));
      await tester.pumpAndSettle();
      tester.view.physicalSize = _portrait;
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar avaliação'));
      await tester.pumpAndSettle();

      expect(find.text('Descartar a avaliação?'), findsOneWidget);
    });
  });
}
