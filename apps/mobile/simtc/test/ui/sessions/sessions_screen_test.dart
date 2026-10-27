import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_consultant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/assessment_sync_service.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/device_data_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/router.dart';
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/app_spacing.dart';
import 'package:simtc/ui/core/theme/app_typography.dart';
import 'package:simtc/ui/core/widgets/app_search_field.dart';
import 'package:simtc/ui/core/widgets/filter_chip_bar.dart';
import 'package:simtc/ui/core/widgets/pill_nav_bar.dart';
import 'package:simtc/ui/core/widgets/session_card.dart';
import 'package:simtc/ui/core/widgets/sync_status_indicator.dart';
import 'package:simtc/ui/profile/profile_screen.dart';
import 'package:simtc/ui/session_detail/session_detail_screen.dart';
import 'package:simtc/ui/sessions/sessions_screen.dart';
import 'package:simtc/ui/sync/sync_screen.dart';
import 'package:simtc/utils/result.dart';

import '../../support/a11y.dart';
import '../../support/fake_assessment_sync_service.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockCatalogRepository extends Mock implements AssessmentCatalogRepository {}

class _MockParticipantRepository extends Mock implements ParticipantRepository {}

class _MockConsultantRepository extends Mock
    implements SessionConsultantRepository {}

class _MockAssessmentRepository extends Mock implements AssessmentRepository {}

class _MockDeviceData extends Mock implements DeviceDataService {}

void main() {
  late _MockSessionRepository repository;
  late _MockAuthRepository auth;
  late _MockCatalogRepository catalog;
  late StreamController<List<TrainingSession>> sessions;
  late ConnectivityService connectivity;

  const consultor = AuthUser(
    id: 'u1',
    name: 'Carla Souza',
    email: 'carla@simtc.com.br',
    role: AppUserRole.consultant,
    consultantId: 'c1',
  );

  TrainingSession hoje() {
    return TrainingSession(
      id: 'sess-1',
      companyName: 'Bracell Celulose',
      courseName: 'Direção Preventiva',
      city: 'Lençóis Paulista',
      state: 'SP',
      date: DateTime.now(),
      status: SessionStatus.emAndamento,
      totalParticipants: 8,
      assessableParticipants: 8,
      assessedParticipants: 2,
    );
  }

  setUp(() {
    repository = _MockSessionRepository();
    auth = _MockAuthRepository();
    catalog = _MockCatalogRepository();
    sessions = StreamController<List<TrainingSession>>.broadcast();
    connectivity = ConnectivityService();

    when(repository.watchSessions).thenAnswer((_) => sessions.stream);
    when(repository.watchLastSyncedAt).thenAnswer((_) => Stream.value(null));
    when(repository.syncAll).thenAnswer((_) async => const Success(0));
    when(() => auth.currentUser).thenReturn(consultor);
    when(catalog.sync).thenAnswer((_) async => const Success(7));
  });

  tearDown(() {
    sessions.close();
    connectivity.dispose();
  });

  Future<void> pump(
    WidgetTester tester, {
    AssessmentSyncService? sync,
    FormFactor formFactor = FormFactor.phone,
    Widget home = const SessionsScreen(),
  }) {
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SessionRepository>.value(value: repository),
          Provider<AssessmentCatalogRepository>.value(value: catalog),
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
          if (sync != null)
            ChangeNotifierProvider<AssessmentSyncService>.value(value: sync),
        ],
        child: FormFactorScope(
          formFactor: formFactor,
          child: MaterialApp(home: home),
        ),
      ),
    );
  }

  String titleText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('sessions-title'))).data!;

  testWidgets('tudo o que se toca tem 48 e rótulo (Fase 8C)', (tester) async {
    await pump(tester);
    sessions.add([hoje()]);
    await tester.pump();

    await expectAccessibleTargets(tester);
  });

  testWidgets(
      'dois toques rápidos num card abrem um detalhe só (Fase 8C)',
      (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (_, __) => const SessionsScreen(),
        ),
        GoRoute(
          path: '/sessions/:id',
          builder: (_, __) => const Scaffold(body: Text('detalhe')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SessionRepository>.value(value: repository),
          Provider<AssessmentCatalogRepository>.value(value: catalog),
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    sessions.add([hoje()]);
    await tester.pump();

    await tester.tap(find.byType(SessionCard));
    // O segundo toque antes do próximo quadro: a rota nova ainda não
    // está montada.
    await tester.tap(find.byType(SessionCard));
    await tester.pumpAndSettle();

    expect(find.text('detalhe', skipOffstage: false), findsOneWidget);
  });

  testWidgets(
      'a fila de envio aparece no badge da aba Sincronizar e no indicador do '
      'cabeçalho', (tester) async {
    await pump(
      tester,
      sync: FakeAssessmentSyncService(
        queue: [queuedAssessment('1'), queuedAssessment('2'), queuedAssessment('3')],
      ),
    );
    sessions.add([hoje()]);
    await tester.pump();

    expect(find.text('3'), findsNWidgets(2), reason: 'navbar e cabeçalho');
  });

  testWidgets('mostra skeleton antes da primeira leitura do cache',
      (tester) async {
    await pump(tester);
    await tester.pump();

    expect(find.byKey(const Key('sessions-skeleton')), findsOneWidget);
    expect(find.byType(SessionCard), findsNothing);
  });

  testWidgets('mostra a sessão de hoje com o progresso', (tester) async {
    await pump(tester);
    sessions.add([hoje()]);
    await tester.pump();

    expect(find.byType(SessionCard), findsOneWidget);
    expect(find.text('Bracell Celulose'), findsOneWidget);
    expect(find.text('2 de 8 avaliados'), findsOneWidget);
  });

  testWidgets('o card mostra o logo da empresa ou, sem logo, as iniciais',
      (tester) async {
    await pump(tester);
    sessions.add([hoje()]);
    await tester.pump();

    expect(find.text('BC'), findsOneWidget,
        reason: 'Bracell Celulose não tem logo no teste');
  });

  testWidgets('saúda o consultor pelo primeiro nome e usa o título dele',
      (tester) async {
    await pump(tester);
    sessions.add([hoje()]);
    await tester.pump();

    expect(find.textContaining('Carla'), findsOneWidget);
    expect(titleText(tester), 'Minhas sessões');
  });

  testWidgets('para ADMIN o título é "Sessões"', (tester) async {
    when(() => auth.currentUser).thenReturn(const AuthUser(
      id: 'u2',
      name: 'Rita Alves',
      email: 'rita@simtc.com.br',
      role: AppUserRole.admin,
    ));

    await pump(tester);
    sessions.add([hoje()]);
    await tester.pump();

    expect(titleText(tester), 'Sessões');
  });

  testWidgets('falha ao atualizar aparece num SnackBar, sem apagar a lista',
      (tester) async {
    when(repository.syncAll)
        .thenAnswer((_) async => Failure(Exception('sem rede'), 'Sem conexão.'));

    await pump(tester);
    sessions.add([hoje()]);
    await tester.pump(); // entrega do stream e disparo do listener
    await tester.pump(); // post-frame callback que mostra o SnackBar
    await tester.pump(const Duration(milliseconds: 750)); // animação de entrada

    expect(find.text('Sem conexão.'), findsOneWidget);
    expect(find.byType(SessionCard), findsOneWidget);
  });

  testWidgets(
      'a primeira descida falhou com o aparelho vazio: o motivo e "Tentar '
      'novamente", e não as seções vazias (Fase 8C)', (tester) async {
    final reply = Completer<Result<int>>();
    when(repository.syncAll).thenAnswer((_) => reply.future);

    await pump(tester);
    sessions.add(const []);
    await tester.pump();
    reply.complete(Failure(Exception('sem rede'), 'Sem conexão.'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    expect(
      find.text('Não foi possível baixar as sessões. Confira a conexão e '
          'tente de novo.'),
      findsOneWidget,
    );
    expect(find.text('Nenhuma sessão para hoje.'), findsNothing);
    expect(find.byType(SnackBar), findsNothing, reason: 'um aviso só');

    when(repository.syncAll).thenAnswer((_) async => const Success(1));
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    sessions.add([hoje()]);
    await tester.pump();

    verify(repository.syncAll).called(2);
    expect(find.byType(SessionCard), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
  });

  testWidgets('cache vazio mostra as três seções vazias, não o skeleton',
      (tester) async {
    // `watchLastSyncedAt` não nulo garante que este teste cobre o cache
    // genuinamente vazio (já sincronizado antes, sem sessão nenhuma) — e não
    // o caso "nunca sincronizou", que fica de propósito no skeleton até o
    // primeiro sync terminar (ver `sessions_list_viewmodel_test.dart`).
    when(repository.watchLastSyncedAt)
        .thenAnswer((_) => Stream.value(DateTime(2026, 9, 20, 8)));

    await pump(tester);
    sessions.add(const []);
    await tester.pump();

    expect(find.byKey(const Key('sessions-skeleton')), findsNothing);
    expect(find.text('Nenhuma sessão para hoje.'), findsOneWidget);
    expect(find.text('Nada agendado para os próximos 7 dias.'), findsOneWidget);
    expect(find.text('Nenhuma sessão concluída ainda.'), findsOneWidget);
  });

  testWidgets(
      'sem sessão hoje mas com "Outras", mostra o aviso de hoje livre antes '
      'delas, sem esconder "Outras"', (tester) async {
    final atrasada = TrainingSession(
      id: 'atrasada-1',
      companyName: 'Suzano Papel',
      courseName: 'Operação de Empilhadeira',
      city: 'Bauru',
      state: 'SP',
      date: DateTime.now().subtract(const Duration(days: 3)),
      status: SessionStatus.planejado,
      totalParticipants: 3,
      assessableParticipants: 3,
      assessedParticipants: 0,
    );

    await pump(tester);
    sessions.add([atrasada]);
    await tester.pump();

    expect(find.text('Nenhuma sessão para hoje.'), findsOneWidget);
    expect(find.text('Outras · 1'), findsOneWidget);
    expect(find.text('Suzano Papel'), findsOneWidget);
    // O título da tela e os das seções são cabeçalhos (Fase 8C).
    expect(
      tester.getSemantics(find.byKey(const Key('sessions-title'))),
      isSemantics(isHeader: true),
    );
    expect(
      tester.getSemantics(find.textContaining('Hoje · ')),
      isSemantics(isHeader: true),
    );
    // O peso 600 de verdade, do eixo wght (Fase 8C).
    expect(tester.widget<Text>(find.text('Outras · 1')).style,
        AppTypography.blockTitle);

    // O aviso vem ANTES de "Outras" — não depois.
    final noticeY =
        tester.getTopLeft(find.text('Nenhuma sessão para hoje.')).dy;
    final outrasY = tester.getTopLeft(find.text('Outras · 1')).dy;
    expect(noticeY, lessThan(outrasY));
  });

  testWidgets(
      'sessões de hoje e da semana aparecem juntas, sem precisar trocar de chip',
      (tester) async {
    final amanha = TrainingSession(
      id: 'sess-2',
      companyName: 'Suzano Papel',
      courseName: 'Operação de Empilhadeira',
      city: 'Bauru',
      state: 'SP',
      date: DateTime.now().add(const Duration(days: 1)),
      status: SessionStatus.planejado,
      totalParticipants: 3,
      assessableParticipants: 3,
      assessedParticipants: 0,
    );

    await pump(tester);
    sessions.add([hoje(), amanha]);
    await tester.pump();

    expect(find.text('Bracell Celulose'), findsOneWidget);
    expect(find.text('Suzano Papel'), findsOneWidget);
  });

  testWidgets(
      'bloco com mais de 10 sessões mostra "Ver mais", que revela o resto',
      (tester) async {
    final muitas = List.generate(15, (i) {
      return TrainingSession(
        id: 'c$i',
        companyName: 'Empresa $i',
        courseName: 'Curso',
        city: 'Bauru',
        state: 'SP',
        date: DateTime(2026, 8, i % 28 + 1),
        status: SessionStatus.concluido,
        totalParticipants: 1,
        assessableParticipants: 1,
        assessedParticipants: 1,
      );
    });

    await pump(tester);
    sessions.add(muitas);
    await tester.pump();

    expect(find.text('Empresa 0'), findsOneWidget);
    expect(find.text('Empresa 10'), findsNothing);

    // O `ListView` só monta o que cabe na viewport de teste — igual a um
    // aparelho real com mais sessões do que a tela mostra de uma vez, é
    // preciso rolar até o botão pra ele entrar na árvore.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('ver-mais-concluidas')),
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.byKey(const ValueKey('ver-mais-concluidas')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ver-mais-concluidas')));
    await tester.pump();

    expect(find.text('Empresa 10'), findsOneWidget);
    expect(find.byKey(const ValueKey('ver-mais-concluidas')), findsNothing);
  });

  testWidgets(
      'puxar uma lista mais curta que a tela ainda dispara a atualização',
      (tester) async {
    // Viewport bem maior que uma sessão só garante que a lista fica mais
    // curta que a tela — o caso do dia a dia do filtro "Hoje", com uma ou
    // duas sessões.
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pump(tester);
    sessions.add([hoje()]);
    await tester.pump();

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // init() já chamou syncAll uma vez; o arrasto precisa chamar de novo.
    verify(repository.syncAll).called(2);
  });

  bool isChipSelected(WidgetTester tester, String label) {
    // O fundo do chip é do `Material` embaixo do `InkWell` (Fase 8C).
    final material = tester.widget<Material>(find
        .ancestor(
          of: find.widgetWithText(InkWell, label),
          matching: find.byType(Material),
        )
        .first);
    return material.color == AppColors.primary;
  }

  testWidgets('tocar num chip rola até a seção correspondente', (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final muitasHoje = List.generate(
      20,
      (i) => TrainingSession(
        id: 'h$i',
        companyName: 'Empresa Hoje $i',
        courseName: 'Curso',
        city: 'Bauru',
        state: 'SP',
        date: DateTime.now(),
        status: SessionStatus.planejado,
        totalParticipants: 1,
        assessableParticipants: 1,
        assessedParticipants: 0,
      ),
    );
    // Mais de uma sessão concluída — com só uma, a seção "Concluídas" é curta
    // demais para o `ListView` conseguir rolar o cabeçalho até o topo da
    // viewport (não há conteúdo suficiente abaixo dele para "empurrá-lo").
    // Com um punhado de sessões concluídas, o alinhamento no topo é possível
    // de verdade — o que é o cenário realista (empresa com várias sessões).
    final concluidas = List.generate(
      5,
      (i) => TrainingSession(
        id: 'concluida-$i',
        companyName: i == 0 ? 'Empresa Concluída' : 'Empresa Concluída $i',
        courseName: 'Curso',
        city: 'Bauru',
        state: 'SP',
        date: DateTime(2026, 8, 1 + i),
        status: SessionStatus.concluido,
        totalParticipants: 1,
        assessableParticipants: 1,
        assessedParticipants: 1,
      ),
    );

    await pump(tester);
    sessions.add([...muitasHoje, ...concluidas]);
    await tester.pump();

    // Antes de tocar, as 10 primeiras sessões de hoje já preenchem a tela —
    // a seção Concluídas está fora da área visível.
    expect(find.text('Empresa Concluída'), findsNothing);

    // A barra de chips é horizontal e, com os contadores, as três pastilhas
    // não cabem nos 400px — "Concluídas" fica fora da faixa visível até a
    // barra rolar até ela.
    await tester.ensureVisible(find.widgetWithText(InkWell, 'Concluídas'));
    await tester.pump();
    await tester.tap(find.widgetWithText(InkWell, 'Concluídas'));
    await tester.pumpAndSettle();

    expect(find.text('Empresa Concluída'), findsOneWidget);
    // O cabeçalho de "Concluídas" alinha no topo da área rolável, mas a área
    // rolável já começa a ~195px (cabeçalho da tela + faixa de conectividade
    // + barra de chips) — por isso o teto realista não é perto de 0.
    expect(tester.getTopLeft(find.text('Empresa Concluída')).dy, lessThan(300));
  });

  testWidgets('rolar manualmente destaca o chip da seção mais visível',
      (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final muitasHoje = List.generate(
      15,
      (i) => TrainingSession(
        id: 'h$i',
        companyName: 'Empresa Hoje $i',
        courseName: 'Curso',
        city: 'Bauru',
        state: 'SP',
        date: DateTime.now(),
        status: SessionStatus.planejado,
        totalParticipants: 1,
        assessableParticipants: 1,
        assessedParticipants: 0,
      ),
    );
    // Só uma sessão concluída, de propósito: a seção é curta demais para o
    // cabeçalho dela cruzar o topo da área rolável mesmo no fim absoluto do
    // scroll (o `ListView` não tem conteúdo abaixo dela pra "empurrá-la" até
    // lá). Sem o caso especial de fim de scroll em
    // `_updateActiveChipFromScroll`, o chip ficaria preso em "Hoje" mesmo com
    // "Concluídas" inteira na tela — é exatamente o que este teste prova.
    final concluidas = [
      TrainingSession(
        id: 'concluida-0',
        companyName: 'Empresa Concluída 0',
        courseName: 'Curso',
        city: 'Bauru',
        state: 'SP',
        date: DateTime(2026, 8, 1),
        status: SessionStatus.concluido,
        totalParticipants: 1,
        assessableParticipants: 1,
        assessedParticipants: 1,
      ),
    ];

    await pump(tester);
    sessions.add([...muitasHoje, ...concluidas]);
    await tester.pump();

    expect(isChipSelected(tester, 'Hoje'), isTrue);

    // `fling` (não `drag`) de propósito: um único `drag` seguido de um só
    // `pump` faz o `ScrollController` notificar o listener ANTES do layout
    // recalcular a posição das seções — o listener lê geometria de um frame
    // atrás. Um arrasto de verdade gera vários frames intercalados até
    // assentar (como no dispositivo real); `pumpAndSettle` cobre isso.
    await tester.fling(find.byType(ListView), const Offset(0, -2200), 3000);
    await tester.pumpAndSettle();

    expect(isChipSelected(tester, 'Concluídas'), isTrue);
  });

  testWidgets(
      'depois de rolar manualmente, tocar num chip ainda rola pra seção certa '
      'sem piscar', (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final muitasHoje = List.generate(
      15,
      (i) => TrainingSession(
        id: 'h$i',
        companyName: 'Empresa Hoje $i',
        courseName: 'Curso',
        city: 'Bauru',
        state: 'SP',
        date: DateTime.now(),
        status: SessionStatus.planejado,
        totalParticipants: 1,
        assessableParticipants: 1,
        assessedParticipants: 0,
      ),
    );

    await pump(tester);
    sessions.add(muitasHoje);
    await tester.pump();

    // Rola o bastante pra "Empresa Hoje 0" sair da tela — não precisa ser um
    // arrasto grande, só o suficiente pra provar que o toque no chip precisa
    // rolar de volta de verdade, não que ela já estava visível.
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();
    expect(find.text('Empresa Hoje 0'), findsNothing);

    await tester.tap(find.widgetWithText(InkWell, 'Hoje'));
    await tester.pumpAndSettle();

    expect(isChipSelected(tester, 'Hoje'), isTrue);
    expect(find.text('Empresa Hoje 0'), findsOneWidget);
  });

  testWidgets(
      'quando "Hoje" cresce além do cacheExtent, tocar em "Concluídas" ainda '
      'rola até lá', (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final hojePrincipal = List.generate(
      10,
      (i) => TrainingSession(
        id: 'hp$i',
        companyName: 'Empresa Hoje $i',
        courseName: 'Curso',
        city: 'Bauru',
        state: 'SP',
        date: DateTime.now(),
        status: SessionStatus.planejado,
        totalParticipants: 1,
        assessableParticipants: 1,
        assessedParticipants: 0,
      ),
    );
    // "Outras": sessões abertas com data passada — o cenário do consultor que
    // fica dias sem abrir o app e volta com um acúmulo bem maior que os 10
    // exibidos por padrão (por isso 30: dá pra revelar duas vezes).
    final outras = List.generate(
      30,
      (i) => TrainingSession(
        id: 'ou$i',
        companyName: 'Empresa Outras $i',
        courseName: 'Curso',
        city: 'Bauru',
        state: 'SP',
        date: DateTime.now().subtract(Duration(days: 10 + i)),
        status: SessionStatus.planejado,
        totalParticipants: 1,
        assessableParticipants: 1,
        assessedParticipants: 0,
      ),
    );
    final proximos7 = List.generate(
      10,
      (i) => TrainingSession(
        id: 'p7$i',
        companyName: 'Empresa Semana $i',
        courseName: 'Curso',
        city: 'Bauru',
        state: 'SP',
        date: DateTime.now().add(Duration(days: 1 + (i % 7))),
        status: SessionStatus.planejado,
        totalParticipants: 1,
        assessableParticipants: 1,
        assessedParticipants: 0,
      ),
    );
    final concluidas = List.generate(
      5,
      (i) => TrainingSession(
        id: 'concluida-$i',
        companyName: i == 0 ? 'Empresa Concluída' : 'Empresa Concluída $i',
        courseName: 'Curso',
        city: 'Bauru',
        state: 'SP',
        date: DateTime(2026, 8, 1 + i),
        status: SessionStatus.concluido,
        totalParticipants: 1,
        assessableParticipants: 1,
        assessedParticipants: 1,
      ),
    );

    await pump(tester);
    sessions.add([...hojePrincipal, ...outras, ...proximos7, ...concluidas]);
    await tester.pump();

    // Revela todo o bloco "Outras" — mais de 5000px de conteúdo antes mesmo
    // de "Concluídas" começar, o cenário que o revisor apontou como comum
    // (não extremo) num dia de consultor ocupado.
    final scrollable = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    for (var i = 0; i < 2; i++) {
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('ver-mais-hojeOutras')),
        300,
        scrollable: scrollable,
      );
      // `scrollUntilVisible` para com o botão só entrando pela borda de
      // baixo: o centro dele ficava atrás da navbar, e o toque caía em
      // "Sincronizar" (o aviso de hit-test da Fase 3). Com a aba navegando
      // de verdade (Fase 5A), esse toque errado quebra o teste.
      await tester.ensureVisible(find.byKey(const ValueKey('ver-mais-hojeOutras')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('ver-mais-hojeOutras')));
      await tester.pump();
    }

    // Quase pro topo (não exatamente 0) — os chips ficam sempre visíveis lá,
    // então o consultor pode tocar em "Concluídas" de qualquer lugar da
    // lista. O offset 20 (em vez de 0) é de propósito: a 0 exato, o topo do
    // cabeçalho de "Hoje" fica alguns pixels ABAIXO da borda da área rolável
    // (por causa do padding do `ListView`) e a checagem `top <=
    // activationOffset` do listener nunca marca nada como ativo — o que
    // mascararia a regressão do `jumpTo` prematuro em vez de provar a
    // correção. A partir de ~12px de scroll, "Hoje" já cruzou essa linha e
    // o listener, se disparado com geometria desatualizada (o bug), marcaria
    // "Hoje" como ativo por engano. Nesse ponto a seção "Concluídas" está
    // bem fora do `cacheExtent` (confirmado com um teste de depuração:
    // ~9176px de conteúdo total, `GlobalKey` sem `currentContext`) — é o
    // `_onChipTap` quem precisa saltar pro `maxScrollExtent` (Hoje/Concluídas
    // são sempre a primeira/última seção) antes de conseguir montar o alvo e
    // rolar de verdade.
    tester.state<ScrollableState>(scrollable).position.jumpTo(20);
    await tester.pump();
    expect(find.text('Empresa Concluída'), findsNothing);

    await tester.ensureVisible(find.widgetWithText(InkWell, 'Concluídas'));
    await tester.pump();
    await tester.tap(find.widgetWithText(InkWell, 'Concluídas'));
    await tester.pumpAndSettle();

    expect(find.text('Empresa Concluída'), findsOneWidget);
    // O `jumpTo` do fallback dispara `ScrollPosition.forcePixels`, que
    // notifica os listeners de forma síncrona — se o contador de scroll
    // programático só protegesse o `ensureVisible` final (não o fallback
    // inteiro), esse salto reabriria o listener de scroll manual no meio do
    // caminho e destacaria "Hoje" (a seção cujo topo passa primeiro pela
    // ativação, com a geometria desatualizada de antes do salto) em vez de
    // "Concluídas", mesmo com o conteúdo certo rolando pra tela.
    expect(isChipSelected(tester, 'Concluídas'), isTrue);
    expect(isChipSelected(tester, 'Hoje'), isFalse);
  });

  testWidgets(
      'dois toques rápidos em chips diferentes: o destaque final é o do '
      'segundo toque', (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final muitasHoje = List.generate(
      15,
      (i) => TrainingSession(
        id: 'h$i',
        companyName: 'Empresa Hoje $i',
        courseName: 'Curso',
        city: 'Bauru',
        state: 'SP',
        date: DateTime.now(),
        status: SessionStatus.planejado,
        totalParticipants: 1,
        assessableParticipants: 1,
        assessedParticipants: 0,
      ),
    );
    final concluidas = List.generate(
      5,
      (i) => TrainingSession(
        id: 'concluida-$i',
        companyName: 'Empresa Concluída $i',
        courseName: 'Curso',
        city: 'Bauru',
        state: 'SP',
        date: DateTime(2026, 8, 1 + i),
        status: SessionStatus.concluido,
        totalParticipants: 1,
        assessableParticipants: 1,
        assessedParticipants: 1,
      ),
    );

    await pump(tester);
    sessions.add([...muitasHoje, ...concluidas]);
    await tester.pump();

    // "Concluídas" não cabe nos 400px iniciais da barra — traz ela pra faixa
    // visível ANTES da corrida começar (isso não interfere na race: só torna
    // o toque capaz de acertar o InkWell).
    await tester.ensureVisible(find.widgetWithText(InkWell, 'Concluídas'));
    await tester.pump();

    // Nem "Hoje" (padrão inicial) nem "Concluídas" fazem prova de nada
    // sozinhos — "Hoje" já começa selecionado, então um teste que terminasse
    // nele passaria mesmo que os dois toques tivessem sido ignorados. Por
    // isso o segundo toque é em "Próximos 7 dias", que só fica selecionado
    // se o SEGUNDO toque realmente processou.
    //
    // Toca em "Concluídas" e, sem esperar a animação (300ms) terminar, toca
    // em "Próximos 7 dias" — a corrida que o revisor identificou: a animação
    // do primeiro toque é cancelada pela do segundo, o que resolve a
    // `Future` do primeiro `ensureVisible` na hora
    // (`DrivenScrollActivity.dispose()` completa o completer
    // incondicionalmente). Com um booleano ingênuo, isso reabriria o
    // listener de scroll manual com a animação do segundo toque ainda em
    // voo. Sem esperar nada entre os dois toques (nenhum `pump` no meio)
    // garante que a primeira animação ainda está rodando.
    await tester.tap(find.widgetWithText(InkWell, 'Concluídas'));
    await tester.tap(find.widgetWithText(InkWell, 'Próximos 7 dias'));
    await tester.pumpAndSettle();

    expect(isChipSelected(tester, 'Próximos 7 dias'), isTrue);
    expect(isChipSelected(tester, 'Hoje'), isFalse);
    expect(isChipSelected(tester, 'Concluídas'), isFalse);
    expect(find.text('Esta semana'), findsOneWidget);
  });

  testWidgets(
      'dois toques rápidos quando o PRIMEIRO passa pelo fallback (seção '
      'desmontada): o resultado final é o do segundo toque, não uma mistura '
      'dos dois', (tester) async {
    // Viewport larga o bastante pra "Hoje" e "Concluídas" caberem juntos na
    // barra de chips sem precisar rolar — a corrida deste teste é sobre a
    // ORDEM em que os dois toques retomam depois de um `await`, não sobre a
    // barra de chips (achado 2, testado à parte).
    tester.view.physicalSize = const Size(600, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final hojePrincipal = List.generate(
      10,
      (i) => TrainingSession(
        id: 'hp$i',
        companyName: 'Empresa Hoje $i',
        courseName: 'Curso',
        city: 'Bauru',
        state: 'SP',
        date: DateTime.now(),
        status: SessionStatus.planejado,
        totalParticipants: 1,
        assessableParticipants: 1,
        assessedParticipants: 0,
      ),
    );
    // "Outras" grande o bastante (revelada até o fim) pra, junto de "Hoje",
    // empurrar "Concluídas" pra fora do cacheExtent quando a lista está no
    // topo — o pré-requisito pra este toque cair no caminho do FALLBACK, não
    // no caminho direto que o teste anterior já cobre.
    final outras = List.generate(
      30,
      (i) => TrainingSession(
        id: 'ou$i',
        companyName: 'Empresa Outras $i',
        courseName: 'Curso',
        city: 'Bauru',
        state: 'SP',
        date: DateTime.now().subtract(Duration(days: 10 + i)),
        status: SessionStatus.planejado,
        totalParticipants: 1,
        assessableParticipants: 1,
        assessedParticipants: 0,
      ),
    );
    final proximos7 = [
      TrainingSession(
        id: 'p7-0',
        companyName: 'Empresa Semana',
        courseName: 'Curso',
        city: 'Bauru',
        state: 'SP',
        date: DateTime.now().add(const Duration(days: 2)),
        status: SessionStatus.planejado,
        totalParticipants: 1,
        assessableParticipants: 1,
        assessedParticipants: 0,
      ),
    ];
    final concluidas = List.generate(
      5,
      (i) => TrainingSession(
        id: 'concluida-$i',
        companyName: i == 0 ? 'Empresa Concluída' : 'Empresa Concluída $i',
        courseName: 'Curso',
        city: 'Bauru',
        state: 'SP',
        date: DateTime(2026, 8, 1 + i),
        status: SessionStatus.concluido,
        totalParticipants: 1,
        assessableParticipants: 1,
        assessedParticipants: 1,
      ),
    );

    await pump(tester);
    sessions.add([...hojePrincipal, ...outras, ...proximos7, ...concluidas]);
    await tester.pump();

    final scrollable = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    for (var i = 0; i < 2; i++) {
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('ver-mais-hojeOutras')),
        300,
        scrollable: scrollable,
      );
      // `scrollUntilVisible` para com o botão só entrando pela borda de
      // baixo: o centro dele ficava atrás da navbar, e o toque caía em
      // "Sincronizar" (o aviso de hit-test da Fase 3). Com a aba navegando
      // de verdade (Fase 5A), esse toque errado quebra o teste.
      await tester.ensureVisible(find.byKey(const ValueKey('ver-mais-hojeOutras')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('ver-mais-hojeOutras')));
      await tester.pump();
    }

    // Volta pro topo sem passar por `_onChipTap` — só a preparação do
    // cenário, não a corrida que este teste prova. No topo, "Hoje" está
    // sempre montada (é a primeira seção) enquanto "Concluídas" continua fora
    // do cacheExtent — a combinação exata que o achado pede: o primeiro toque
    // cai no fallback, o segundo (num alvo já montado) tem caminho direto.
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.text('Empresa Concluída'), findsNothing);
    expect(isChipSelected(tester, 'Hoje'), isTrue);

    // Toca em "Concluídas" — fora do cacheExtent daqui, então este toque
    // entra no caminho do fallback (`jumpTo` pro fim + `await endOfFrame`,
    // um frame inteiro) — e, sem esperar esse `await` terminar, toca em
    // "Hoje", já montada: caminho direto, chama `ensureVisible` na hora. Sem
    // o contador de geração, quando o primeiro toque retomasse (depois do
    // `endOfFrame`, com "Concluídas" já montada — o próprio salto do
    // fallback levou a lista até o fim), ele chamaria `ensureVisible` pra
    // "Concluídas" por cima da animação do segundo toque, cancelando-a — a
    // lista terminaria em "Concluídas" com o chip marcando "Hoje".
    await tester.tap(find.widgetWithText(InkWell, 'Concluídas'));
    await tester.tap(find.widgetWithText(InkWell, 'Hoje'));
    await tester.pumpAndSettle();

    expect(isChipSelected(tester, 'Hoje'), isTrue);
    expect(isChipSelected(tester, 'Concluídas'), isFalse);
    // Não basta o chip: confirma que a lista realmente mostra "Hoje" NA TELA
    // (não só montada em algum lugar do cacheExtent) — é a prova de que o
    // `ensureVisible` do segundo toque venceu, não o do primeiro.
    expect(
      tester.getTopLeft(find.text('Empresa Hoje 0')).dy,
      inInclusiveRange(0.0, 700.0),
    );
  });

  testWidgets(
      'quando o fallback não acha a seção nem depois do salto, o chip volta '
      'a marcar o filtro que estava ativo antes do toque', (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final hojePrincipal = List.generate(
      10,
      (i) => TrainingSession(
        id: 'hp$i',
        companyName: 'Empresa Hoje $i',
        courseName: 'Curso',
        city: 'Bauru',
        state: 'SP',
        date: DateTime.now(),
        status: SessionStatus.planejado,
        totalParticipants: 1,
        assessableParticipants: 1,
        assessedParticipants: 0,
      ),
    );
    final proximos7 = List.generate(
      10,
      (i) => TrainingSession(
        id: 'p7$i',
        companyName: 'Empresa Semana $i',
        courseName: 'Curso',
        city: 'Bauru',
        state: 'SP',
        date: DateTime.now().add(Duration(days: 1 + (i % 7))),
        status: SessionStatus.planejado,
        totalParticipants: 1,
        assessableParticipants: 1,
        assessedParticipants: 0,
      ),
    );
    // "Concluídas" ganha um total bem maior que o padrão — revelada até
    // quase o fim, sobra tanto conteúdo abaixo de "Esta semana" que, mesmo
    // saltando pro fim absoluto da lista (o que `_onChipTap` faz pra
    // qualquer filtro que não seja "Hoje"), "Esta semana" continua fora do
    // cacheExtent. É o cenário em que o fallback genuinamente falha.
    final concluidas = List.generate(
      45,
      (i) => TrainingSession(
        id: 'concluida-$i',
        companyName: 'Empresa Concluída $i',
        courseName: 'Curso',
        city: 'Bauru',
        state: 'SP',
        date: DateTime(2026, 8, i % 28 + 1),
        status: SessionStatus.concluido,
        totalParticipants: 1,
        assessableParticipants: 1,
        assessedParticipants: 1,
      ),
    );

    await pump(tester);
    sessions.add([...hojePrincipal, ...proximos7, ...concluidas]);
    await tester.pump();

    final scrollable = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    for (var i = 0; i < 3; i++) {
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('ver-mais-concluidas')),
        300,
        scrollable: scrollable,
      );
      // `scrollUntilVisible` para assim que o botão fica parcialmente
      // visível — o suficiente pra passar no hit-test em alguns casos, mas
      // não sempre. `ensureVisible` garante que ele fica inteiramente dentro
      // da viewport antes do toque.
      await tester.ensureVisible(find.byKey(const ValueKey('ver-mais-concluidas')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('ver-mais-concluidas')));
      await tester.pump();
    }

    // Rola direto pro fim absoluto — sem passar por `_onChipTap` — só pra
    // preparar o cenário. O scroll manual já destaca "Concluídas" por conta
    // própria (é a seção mais visível no fim da lista).
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(isChipSelected(tester, 'Concluídas'), isTrue);
    // Confirma a premissa do teste: "Esta semana" está mesmo fora da árvore
    // aqui — não só fora da viewport.
    expect(find.text('Esta semana'), findsNothing);

    await tester.ensureVisible(find.widgetWithText(InkWell, 'Próximos 7 dias'));
    await tester.pump();
    await tester.tap(find.widgetWithText(InkWell, 'Próximos 7 dias'));
    await tester.pumpAndSettle();

    // O fallback saltou pro fim (onde já estava) e não achou "Esta semana"
    // mesmo assim — o chip volta a marcar "Concluídas", o filtro que estava
    // ativo antes deste toque, não "Próximos 7 dias".
    expect(isChipSelected(tester, 'Concluídas'), isTrue);
    expect(isChipSelected(tester, 'Próximos 7 dias'), isFalse);
  });

  testWidgets('tocar no card abre o detalhe daquela sessão', (tester) async {
    final participants = _MockParticipantRepository();
    final assessments = _MockAssessmentRepository();
    when(() => auth.isAuthenticated).thenReturn(true);
    when(() => repository.watchSession('sess-1'))
        .thenAnswer((_) => Stream.value(hoje()));
    when(() => participants.watchBySession('sess-1'))
        .thenAnswer((_) => Stream.value(const <SessionParticipant>[]));
    when(() => participants.syncSession('sess-1'))
        .thenAnswer((_) async => const Success(0));
    when(() => assessments.watchSessionAssessments('sess-1', 'u1'))
        .thenAnswer((_) => Stream.value(const <LocalAssessment>[]));

    final router = createRouter(auth, initialLocation: AppRoutes.home);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SessionRepository>.value(value: repository),
          Provider<AssessmentCatalogRepository>.value(value: catalog),
          Provider<ParticipantRepository>.value(value: participants),
          // O detalhe só o usa para o ADMIN; aqui quem abre é a consultora.
          Provider<SessionConsultantRepository>.value(
            value: _MockConsultantRepository(),
          ),
          Provider<AssessmentRepository>.value(value: assessments),
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    sessions.add([hoje()]);
    await tester.pump();

    await tester.tap(find.byType(SessionCard));
    await tester.pumpAndSettle();

    final detail =
        tester.widget<SessionDetailScreen>(find.byType(SessionDetailScreen));
    expect(detail.sessionId, 'sess-1');
  });

  testWidgets(
      '"Sincronizar" na navbar e o indicador do cabeçalho abrem a aba, e '
      '"Sessões" volta', (tester) async {
    when(() => auth.isAuthenticated).thenReturn(true);
    final router = createRouter(auth, initialLocation: AppRoutes.home);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SessionRepository>.value(value: repository),
          Provider<AssessmentCatalogRepository>.value(value: catalog),
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
          ChangeNotifierProvider<AssessmentSyncService>.value(
            value: FakeAssessmentSyncService(queue: [queuedAssessment('1')]),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    sessions.add([hoje()]);
    await tester.pump();

    await tester.tap(find.text('Sincronizar'));
    await tester.pumpAndSettle();
    expect(find.byType(SyncScreen), findsOneWidget);

    // A Home volta com o skeleton animado até a lista chegar de novo: um
    // `pumpAndSettle` aqui não assentaria nunca.
    await tester.tap(find.text('Sessões'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SessionsScreen), findsOneWidget);
    sessions.add([hoje()]);
    await tester.pump();

    await tester.tap(find.byType(SyncStatusIndicator));
    await tester.pumpAndSettle();
    expect(find.byType(SyncScreen), findsOneWidget);
  });

  testWidgets('"Perfil" na navbar abre a aba, e "Sessões" volta',
      (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'SIMTC',
      packageName: 'br.com.simtc.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    final deviceData = _MockDeviceData();
    when(deviceData.downloadedBytes).thenAnswer((_) async => 0);
    when(() => auth.isAuthenticated).thenReturn(true);
    final router = createRouter(auth, initialLocation: AppRoutes.home);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SessionRepository>.value(value: repository),
          Provider<AssessmentCatalogRepository>.value(value: catalog),
          Provider<AssessmentRepository>.value(value: _MockAssessmentRepository()),
          Provider<DeviceDataService>.value(value: deviceData),
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
          ChangeNotifierProvider<AssessmentSyncService>.value(
            value: FakeAssessmentSyncService(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    sessions.add([hoje()]);
    await tester.pump();

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);

    await tester.tap(find.text('Sessões'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SessionsScreen), findsOneWidget);
  });

  group('busca de sessões pela empresa (Fase 8B)', () {
    TrainingSession sessao(
      String id,
      String company, {
      int daysFromToday = 0,
      SessionStatus status = SessionStatus.emAndamento,
    }) {
      return TrainingSession(
        id: id,
        companyName: company,
        courseName: 'Direção Preventiva',
        city: 'Lençóis Paulista',
        state: 'SP',
        date: DateTime.now().add(Duration(days: daysFromToday)),
        status: status,
        totalParticipants: 8,
        assessableParticipants: 8,
        assessedParticipants: 2,
      );
    }

    Future<void> showSessions(
      WidgetTester tester,
      List<TrainingSession> list,
    ) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(tester);
      sessions.add(list);
      await tester.pump();
    }

    Future<void> search(WidgetTester tester, String text) async {
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
    }

    testWidgets(
        'a lupa, ao lado do indicador de envio, abre o campo no lugar da '
        'saudação e do título; os chips saem; o X volta tudo', (tester) async {
      await showSessions(tester, [sessao('s1', 'Bracell Celulose')]);
      final lupa = tester.getRect(find.byTooltip('Buscar'));
      final indicador = tester.getRect(find.byType(SyncStatusIndicator));
      expect(indicador.left - lupa.right, AppSpacing.xs);

      await tester.tap(find.byTooltip('Buscar'));
      await tester.pump();

      expect(find.byType(AppSearchField), findsOneWidget);
      expect(find.text('Buscar pela empresa'), findsOneWidget);
      expect(find.byKey(const Key('sessions-title')), findsNothing);
      expect(find.text('Bom dia, Carla'), findsNothing);
      expect(find.textContaining(', Carla'), findsNothing);
      expect(find.byType(FilterChipBar), findsNothing);
      expect(find.byType(SyncStatusIndicator), findsOneWidget);
      expect(find.byTooltip('Buscar'), findsNothing);

      await tester.tap(find.byTooltip('Fechar a busca'));
      await tester.pump();

      expect(find.byKey(const Key('sessions-title')), findsOneWidget);
      expect(find.byType(FilterChipBar), findsOneWidget);
      expect(find.byType(AppSearchField), findsNothing);
    });

    testWidgets(
        'filtra pela empresa, sem acento nem maiúscula; a seção sem resultado '
        'some', (tester) async {
      await showSessions(tester, [
        sessao('s1', 'Bracell Celulose'),
        sessao('s2', 'Suzano Papel'),
        sessao('s3', 'Bracell Celulose',
            daysFromToday: -3, status: SessionStatus.concluido),
        sessao('s4', 'Suzano Papel', daysFromToday: 2),
      ]);

      await search(tester, 'BRÁC');

      expect(find.text('Bracell Celulose'), findsNWidgets(2));
      expect(find.text('Suzano Papel'), findsNothing);
      expect(find.textContaining('Hoje · '), findsOneWidget);
      expect(find.text('Esta semana'), findsNothing,
          reason: 'a semana só tem a Suzano');
      expect(find.text('Concluídas'), findsOneWidget);
      expect(find.text('Nada agendado para os próximos 7 dias.'), findsNothing);
    });

    testWidgets('todas as que batem aparecem, sem "Ver mais"', (tester) async {
      await showSessions(tester, [
        for (var i = 0; i < 12; i++) sessao('s$i', 'Bracell Unidade $i'),
      ]);
      expect(find.text('Ver mais', skipOffstage: false), findsOneWidget);

      await search(tester, 'bracell');

      expect(find.byType(SessionCard, skipOffstage: false), findsNWidgets(12));
      expect(find.text('Ver mais', skipOffstage: false), findsNothing);
    });

    testWidgets('sem resultado, diz que não achou', (tester) async {
      await showSessions(tester, [sessao('s1', 'Bracell Celulose')]);

      await search(tester, ' xyz ');

      expect(
        find.text('Nenhuma sessão encontrada para “xyz”.'),
        findsOneWidget,
      );
      expect(find.textContaining('Hoje · '), findsNothing);
      // A frase é anunciada quando aparece (Fase 8C).
      expect(
        tester.getSemantics(find.text('Nenhuma sessão encontrada para “xyz”.')),
        isSemantics(isLiveRegion: true),
      );
    });

    testWidgets('aberta e vazia, a lista é a de sempre', (tester) async {
      await showSessions(tester, [sessao('s1', 'Bracell Celulose')]);

      await tester.tap(find.byTooltip('Buscar'));
      await tester.pump();

      expect(find.text('Bracell Celulose'), findsOneWidget);
      expect(find.text('Esta semana'), findsOneWidget);
      expect(find.text('Nada agendado para os próximos 7 dias.'), findsOneWidget);
    });

    testWidgets('no celular, o voltar com a busca aberta fecha a busca',
        (tester) async {
      await showSessions(tester, [
        sessao('s1', 'Bracell Celulose'),
        sessao('s2', 'Suzano Papel'),
      ]);
      await search(tester, 'brac');

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(find.byType(AppSearchField), findsNothing);
      expect(find.text('Suzano Papel'), findsOneWidget);
    });
  });

  group('tablet (Fase 7A)', () {
    void screen(WidgetTester tester, Size size) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('retrato: a lista do celular, com a pílula do tablet na base',
        (tester) async {
      screen(tester, const Size(800, 1280));
      await pump(tester, formFactor: FormFactor.tablet);
      sessions.add([hoje()]);
      await tester.pump();

      final bar = tester.widget<PillNavBar>(find.byType(PillNavBar));
      expect(bar.layout, PillNavLayout.tabletBottom);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).bottomNavigationBar,
        isNull,
      );
      expect(tester.getRect(find.byType(SessionCard)).width, 800);
      expect(
        tester.widget<Text>(find.byKey(const Key('sessions-title'))).style!.fontSize,
        24,
      );
    });

    testWidgets('painel de paisagem (quadro "4c"): sem navbar própria, '
        'saudação de 13 e título de 22', (tester) async {
      screen(tester, const Size(392, 800));
      await pump(
        tester,
        formFactor: FormFactor.tablet,
        home: const SessionsScreen(embedded: true),
      );
      sessions.add([hoje()]);
      await tester.pump();

      expect(find.byType(PillNavBar), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('sessions-title'))).style!.fontSize,
        22,
      );
      expect(tester.widget<Text>(find.textContaining('Carla')).style!.fontSize, 13);
      expect(tester.getRect(find.byKey(const Key('sessions-title'))).left, 20);
    });

    testWidgets('o card da sessão aberta fica destacado, sem mudar de tamanho',
        (tester) async {
      screen(tester, const Size(392, 1600));
      final outra = TrainingSession(
        id: 'sess-2',
        companyName: 'Transportes Vale Norte',
        courseName: 'Operação de Empilhadeira',
        city: 'Betim',
        state: 'MG',
        date: DateTime.now(),
        status: SessionStatus.planejado,
        totalParticipants: 8,
        assessableParticipants: 8,
        assessedParticipants: 0,
      );
      await pump(
        tester,
        formFactor: FormFactor.tablet,
        home: const SessionsScreen(embedded: true, selectedSessionId: 'sess-1'),
      );
      sessions.add([hoje(), outra]);
      await tester.pump();

      SessionCard card(String company) => tester.widget<SessionCard>(
            find.ancestor(
              of: find.text(company),
              matching: find.byType(SessionCard),
            ),
          );
      expect(card('Bracell Celulose').selected, isTrue);
      expect(card('Transportes Vale Norte').selected, isFalse);

      final selected = find.ancestor(
        of: find.text('Bracell Celulose'),
        matching: find.byType(Container),
      );
      final decoration =
          tester.widget<Container>(selected.first).decoration! as BoxDecoration;
      // O fundo é do `Material` embaixo do toque (Fase 8C).
      expect(
        tester
            .widget<Material>(find
                .ancestor(of: selected.first, matching: find.byType(Material))
                .first)
            .color,
        AppColors.categoryExpandedBg,
      );
      final border = decoration.border! as Border;
      expect(border.left, const BorderSide(color: AppColors.primary, width: 3));
      expect(border.top.color, AppColors.selectedCardBorder);
      expect(border.top.width, 1.5);
      expect(border.bottom.width, 1.5);
      final semantics = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(SessionCard).first,
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(semantics.properties.selected, isTrue);
    });

    testWidgets('com onOpenSession, o toque no card avisa em vez de empilhar',
        (tester) async {
      screen(tester, const Size(392, 1600));
      String? opened;
      await pump(
        tester,
        formFactor: FormFactor.tablet,
        home: SessionsScreen(embedded: true, onOpenSession: (id) => opened = id),
      );
      sessions.add([hoje()]);
      await tester.pump();

      await tester.tap(find.byType(SessionCard));
      await tester.pump();

      expect(opened, 'sess-1');
    });
  });
}
