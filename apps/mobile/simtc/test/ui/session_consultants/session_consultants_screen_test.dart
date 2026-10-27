import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_consultant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/router.dart';
import 'package:simtc/ui/core/app_localization.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/theme/app_theme.dart';
import 'package:simtc/ui/core/theme/app_spacing.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/app_search_field.dart';
import 'package:simtc/ui/core/widgets/app_top_bar.dart';
import 'package:simtc/ui/core/widgets/inline_notice.dart';
import 'package:simtc/ui/core/widgets/session_context_header.dart';
import 'package:simtc/ui/core/widgets/status_chip.dart';
import 'package:simtc/ui/session_consultants/consultant_row.dart';
import 'package:simtc/ui/session_consultants/session_consultants_screen.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockConnectivity extends Mock implements Connectivity {}

/// Os consultores ativos da equipe: nome e e-mail.
const Map<String, (String, String?)> _team = {
  'c-carla': ('Carla Mendes', 'carla.mendes@sim.com.br'),
  'c-diego': ('Diego Barbosa', 'diego.barbosa@sim.com.br'),
  'c-patricia': ('Patrícia Vasconcelos', null),
  'c-rafael': ('Rafael Lima', 'rafael.lima@sim.com.br'),
  'c-tatiane': ('Tatiane Souza', 'tatiane.souza@sim.com.br'),
};

const String _noteRafael =
    'Tem 1 avaliação em andamento. Remover devolve Marcos Vinícius para Pendente.';

void main() {
  late _MockApiClient api;
  late _MockAuthRepository auth;
  late AppDatabase db;
  late SessionRepository sessionRepository;
  late ParticipantRepository participantRepository;
  late SessionConsultantRepository consultantRepository;
  late ConnectivityService connectivity;
  late GoRouter router;

  // O "servidor" dos testes: quem está na sessão, os participantes e o status.
  late List<String> inSession;
  late List<Map<String, dynamic>> serverParticipants;
  late String serverStatus;

  const detailPath = '/training-sessions/sess-1';
  const teamPath = '/consultants';
  const addPath = '/training-sessions/sess-1/consultants';

  const offline = ApiException(
    message: 'Sem conexão com o servidor. Verifique a internet e tente de novo.',
    isNetworkError: true,
  );

  const admin = AuthUser(
    id: 'u-admin',
    name: 'Carla Mendes',
    email: 'carla.mendes@sim.com.br',
    role: AppUserRole.admin,
    consultantId: 'c-carla',
  );
  const consultora = AuthUser(
    id: 'u1',
    name: 'Rafael Lima',
    email: 'rafael.lima@sim.com.br',
    role: AppUserRole.consultant,
    consultantId: 'c-rafael',
  );

  Map<String, dynamic> consultantJson(String id) {
    final (name, email) = _team[id]!;
    return {'id': id, 'name': name, 'email': email, 'active': true};
  }

  Map<String, dynamic> linkJson(String id) {
    return {
      'trainingSessionId': 'sess-1',
      'consultantId': id,
      'consultant': consultantJson(id),
    };
  }

  /// Um participante como vem em `participants[]` do detalhe.
  Map<String, dynamic> participantJson(
    String id,
    String name, {
    String status = 'PENDENTE',
    String? assignedTo,
    String? assessedBy,
    double? score,
  }) {
    return {
      'id': id,
      'participationType': 'TEORICA_E_PRATICA',
      'status': status,
      'assignedConsultantId': assignedTo,
      'assignedConsultant': assignedTo == null
          ? null
          : {'id': assignedTo, 'name': _team[assignedTo]!.$1},
      'participant': {'name': name, 'cpf': '04211833344'},
      'assessment': score == null
          ? null
          : {
              'score': score,
              'consultantId': assessedBy,
              'startTime': '2026-09-12T11:00:00.000Z',
              'endTime': '2026-09-12T11:30:00.000Z',
            },
    };
  }

  /// O corpo de `GET /training-sessions/sess-1`, pelo estado do "servidor".
  Map<String, dynamic> detailJson() {
    return {
      'id': 'sess-1',
      'company': {'name': 'Bracell', 'logoUrl': null},
      'course': {'name': 'Direção Defensiva — Veículo Pesado'},
      'city': 'Itabira',
      'state': 'MG',
      'date': '2026-09-12T00:00:00.000Z',
      'status': serverStatus,
      'notes': null,
      'responsibleConsultantId': 'c-carla',
      'responsibleConsultant': consultantJson('c-carla'),
      'consultants': [for (final id in inSession) linkJson(id)],
      'participants': serverParticipants,
    };
  }

  Response<Map<String, dynamic>> ok(String path, Map<String, dynamic> body) {
    return Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: body,
    );
  }

  /// O que as rotas de consultor devolvem: a lista depois da mudança.
  Map<String, dynamic> changedJson() {
    return {
      'responsibleConsultantId': 'c-carla',
      'consultants': [for (final id in inSession) linkJson(id)],
    };
  }

  /// O servidor aceitando tudo: o detalhe, a equipe, entrar e sair (que
  /// libera quem estava em avaliação com o consultor, como o backend).
  void serverAnswers() {
    when(() => api.get<Map<String, dynamic>>(detailPath))
        .thenAnswer((_) async => ok(detailPath, detailJson()));
    when(() => api.get<List<dynamic>>(
          teamPath,
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer(
      (_) async => Response<List<dynamic>>(
        requestOptions: RequestOptions(path: teamPath),
        statusCode: 200,
        data: [for (final id in _team.keys) consultantJson(id)],
      ),
    );
    when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
        .thenAnswer((invocation) async {
      final body = invocation.namedArguments[#data] as Map<String, dynamic>;
      final id = body['consultantId'] as String;
      if (!inSession.contains(id)) inSession.add(id);
      return ok(addPath, changedJson());
    });
    when(() => api.delete<Map<String, dynamic>>(any())).thenAnswer((invocation) async {
      final path = invocation.positionalArguments.single as String;
      final id = path.split('/').last;
      inSession.remove(id);
      for (final participant in serverParticipants) {
        if (participant['status'] == 'EM_AVALIACAO' &&
            participant['assignedConsultantId'] == id) {
          participant['status'] = 'PENDENTE';
          participant['assignedConsultantId'] = null;
          participant['assignedConsultant'] = null;
        }
      }
      return ok(path, changedJson());
    });
  }

  /// O servidor fora do ar para tudo.
  void serverUnreachable() {
    when(() => api.get<Map<String, dynamic>>(detailPath)).thenThrow(offline);
    when(() => api.get<List<dynamic>>(
          teamPath,
          queryParameters: any(named: 'queryParameters'),
        )).thenThrow(offline);
    when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
        .thenThrow(offline);
    when(() => api.delete<Map<String, dynamic>>(any())).thenThrow(offline);
  }

  setUp(() {
    api = _MockApiClient();
    auth = _MockAuthRepository();
    when(() => auth.currentUser).thenReturn(admin);
    when(() => auth.isAuthenticated).thenReturn(true);
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    sessionRepository = SessionRepository(apiClient: api, database: db);
    participantRepository = ParticipantRepository(apiClient: api, database: db);
    consultantRepository =
        SessionConsultantRepository(apiClient: api, database: db);
    connectivity = ConnectivityService();

    // O quadro "3c": a Carla responde pela sessão e avalia; o Rafael tem uma
    // avaliação em andamento; a Tatiane já concluiu as dela.
    inSession = ['c-carla', 'c-rafael', 'c-tatiane'];
    serverStatus = 'EM_ANDAMENTO';
    serverParticipants = [
      participantJson('tp-ana', 'Ana Paula Ribeiro',
          status: 'EM_AVALIACAO', assignedTo: 'c-carla'),
      participantJson('tp-bruno', 'Bruno Dias',
          status: 'APROVADO', assessedBy: 'c-carla', score: 90),
      participantJson('tp-marcos', 'Marcos Vinícius',
          status: 'EM_AVALIACAO', assignedTo: 'c-rafael'),
      participantJson('tp-juliana', 'Juliana Freitas Costa',
          status: 'APROVADO', assessedBy: 'c-tatiane', score: 86.7),
      participantJson('tp-rodrigo', 'Rodrigo Tavares',
          status: 'APROVADO', assessedBy: 'c-tatiane', score: 78),
    ];
    serverAnswers();
  });

  tearDown(() async {
    await db.close();
    connectivity.dispose();
  });

  /// O detalhe já baixado neste aparelho, como a tela de baixo deixa.
  Future<void> seedFromServer() async {
    final result = await participantRepository.syncSession('sess-1');
    expect(result.isSuccess, isTrue);
  }

  /// A sessão no cache como a Home a grava: sem participantes nem consultores.
  Future<void> seedSessionOnly() {
    return db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 'sess-1',
            companyName: 'Bracell',
            courseName: 'Direção Defensiva — Veículo Pesado',
            city: 'Itabira',
            state: 'MG',
            status: 'EM_ANDAMENTO',
            cachedAt: DateTime(2026, 9, 12, 7),
          ),
        );
  }

  Future<void> goOffline() async {
    final plugin = _MockConnectivity();
    when(plugin.checkConnectivity).thenAnswer((_) async => [ConnectivityResult.none]);
    when(() => plugin.onConnectivityChanged).thenAnswer((_) => const Stream.empty());
    connectivity.dispose();
    connectivity = ConnectivityService(connectivity: plugin);
    await connectivity.initialize();
  }

  /// A tela empilhada sobre uma origem, pela rota real. Com [settle] falso,
  /// para quem deixa uma resposta presa: o esqueleto e o indicador não param
  /// de animar, e o `pumpAndSettle` não assentaria.
  Future<void> pumpScreen(
    WidgetTester tester, {
    Size screen = const Size(412, 1800),
    double textScale = 1,
    bool settle = true,
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    router = GoRouter(
      initialLocation: '/origem',
      routes: [
        GoRoute(
          path: '/origem',
          builder: (context, state) => const Scaffold(body: Text('origem')),
        ),
        GoRoute(
          path: '/sessions/:sessionId/consultants',
          builder: (context, state) => SessionConsultantsScreen(
            sessionId: state.pathParameters['sessionId']!,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SessionRepository>.value(value: sessionRepository),
          Provider<ParticipantRepository>.value(value: participantRepository),
          Provider<SessionConsultantRepository>.value(value: consultantRepository),
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          locale: AppLocalization.locale,
          supportedLocales: AppLocalization.supportedLocales,
          localizationsDelegates: AppLocalization.delegates,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    unawaited(router.push<void>(AppRoutes.sessionConsultants('sess-1')));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await pumpTransitions(tester);
    }
  }

  AppDangerOutlineButton removeButton(WidgetTester tester, String id) =>
      tester.widget<AppDangerOutlineButton>(find.byKey(ValueKey('remover-$id')));

  AppCompactOutlineButton addButton(WidgetTester tester, String id) =>
      tester.widget<AppCompactOutlineButton>(find.byKey(ValueKey('adicionar-$id')));

  Finder rowOf(String key) => find.byKey(ValueKey(key));

  /// Rola a lista até o alvo ficar inteiro na tela: num celular baixo, o que
  /// está abaixo da dobra nem foi montado ainda, e o que foi montado pode
  /// estar só com a ponta à vista.
  Future<void> bringIntoView(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Finder inRow(String key, Finder matching) =>
      find.descendant(of: rowOf(key), matching: matching);

  int teamRequests() => verify(() => api.get<List<dynamic>>(
        teamPath,
        queryParameters: any(named: 'queryParameters'),
      )).callCount;

  testWidgets('antes da primeira leitura do cache, mostra o esqueleto',
      (tester) async {
    await seedFromServer();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SessionRepository>.value(value: sessionRepository),
          Provider<ParticipantRepository>.value(value: participantRepository),
          Provider<SessionConsultantRepository>.value(value: consultantRepository),
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const SessionConsultantsScreen(sessionId: 'sess-1'),
        ),
      ),
    );

    expect(find.byKey(const Key('session-consultants-skeleton')), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('session-consultants-skeleton')), findsNothing);
  });

  testWidgets(
      'mostra o contexto, quem está na sessão, a equipe e a nota do fim, como '
      'o quadro "3c"', (tester) async {
    await seedFromServer();
    await pumpScreen(tester);

    expect(find.text('Consultores'), findsOneWidget);
    // A lupa do quadro, que busca pelo nome (Fase 8B).
    expect(find.byIcon(AppIcons.search), findsOneWidget);
    expect(find.text('Bracell · 12 set'), findsOneWidget);
    expect(find.text('5 participantes · 3 consultores'), findsOneWidget);
    // A faixa de contexto no fundo da tela, como no quadro.
    expect(
      tester.widget<SessionContextHeader>(find.byType(SessionContextHeader)).muted,
      isTrue,
    );

    expect(find.text('Na sessão'), findsOneWidget);
    expect(inRow('consultor-c-carla', find.text('Carla Mendes (você)')), findsOneWidget);
    expect(inRow('consultor-c-carla', find.text('Responsável')), findsOneWidget);
    expect(
      inRow('consultor-c-carla', find.text('2 participantes · 1 em andamento')),
      findsOneWidget,
    );
    // O responsável não sai por aqui, nem tem o aviso.
    expect(inRow('consultor-c-carla', find.byType(AppDangerOutlineButton)), findsNothing);
    expect(inRow('consultor-c-carla', find.byType(InlineNotice)), findsNothing);

    expect(inRow('consultor-c-rafael', find.text('Rafael Lima')), findsOneWidget);
    expect(inRow('consultor-c-rafael', find.text('Consultor')), findsOneWidget);
    expect(
      inRow('consultor-c-rafael', find.text('1 participante · 1 em andamento')),
      findsOneWidget,
    );
    expect(inRow('consultor-c-rafael', find.text(_noteRafael)), findsOneWidget);
    expect(removeButton(tester, 'c-rafael').onPressed, isNotNull);

    expect(
      inRow('consultor-c-tatiane', find.text('2 participantes concluídos')),
      findsOneWidget,
    );
    expect(inRow('consultor-c-tatiane', find.byType(InlineNotice)), findsNothing);
    expect(removeButton(tester, 'c-tatiane').onPressed, isNotNull);
    expect(find.text('Remover da sessão'), findsNWidgets(2));

    expect(find.text('Disponíveis na equipe'), findsOneWidget);
    expect(find.text('SIM Treinamentos'), findsOneWidget);
    expect(inRow('equipe-c-diego', find.text('Diego Barbosa')), findsOneWidget);
    expect(
      inRow('equipe-c-diego', find.text('diego.barbosa@sim.com.br')),
      findsOneWidget,
    );
    // Sem e-mail no cadastro, a linha fica só com o nome.
    expect(inRow('equipe-c-patricia', find.text('Patrícia Vasconcelos')), findsOneWidget);
    expect(addButton(tester, 'c-diego').onPressed, isNotNull);
    expect(addButton(tester, 'c-patricia').onPressed, isNotNull);
    // Quem já está na sessão não aparece na equipe.
    expect(find.text('Adicionar'), findsNWidgets(2));

    expect(
      find.text('Entrar e sair da sessão vale na hora e precisa de conexão. '
          'Offline, a lista fica só de leitura.'),
      findsOneWidget,
    );
    expect(find.textContaining('Sem conexão'), findsNothing);
  });

  testWidgets('a ordem é a do quadro: contexto, "Na sessão" com o responsável '
      'primeiro, a equipe e a nota', (tester) async {
    await seedFromServer();
    await pumpScreen(tester);

    double top(Finder finder) => tester.getTopLeft(finder).dy;

    final order = [
      top(find.text('Bracell · 12 set')),
      top(find.text('Na sessão')),
      top(rowOf('consultor-c-carla')),
      top(rowOf('consultor-c-rafael')),
      top(rowOf('consultor-c-tatiane')),
      top(find.text('Disponíveis na equipe')),
      top(rowOf('equipe-c-diego')),
      top(rowOf('equipe-c-patricia')),
      top(find.textContaining('Entrar e sair da sessão')),
    ];
    expect(order, [...order]..sort());

    // As pastilhas do papel: a do responsável na cor de marca.
    final pills = tester.widgetList<LabelPill>(find.byType(LabelPill)).toList();
    expect(pills.map((p) => p.label), ['Responsável', 'Consultor', 'Consultor']);
    expect(pills.map((p) => p.tone),
        [StatusTone.info, StatusTone.neutral, StatusTone.neutral]);
  });

  testWidgets('os títulos de seção têm os recuos do quadro "3c"', (tester) async {
    await seedFromServer();
    await pumpScreen(tester);

    // "Na sessão": 15 em cima e embaixo, 20 dos lados.
    final sessionTitle = tester.getRect(find.text('Na sessão'));
    final header = tester.getRect(find.byType(SessionContextHeader));
    final firstRow = tester.getRect(rowOf('consultor-c-carla'));
    expect(sessionTitle.left, 20);
    expect(sessionTitle.top - header.bottom, 15);
    expect(firstRow.top - sessionTitle.bottom, 15);

    // "Disponíveis na equipe": 22 em cima, 10 embaixo, e o nome da equipe na
    // margem direita.
    final teamTitle = tester.getRect(find.text('Disponíveis na equipe'));
    final lastRow = tester.getRect(rowOf('consultor-c-tatiane'));
    final teamRow = tester.getRect(rowOf('equipe-c-diego'));
    expect(teamTitle.left, 20);
    expect(teamTitle.top - lastRow.bottom, 22);
    expect(teamRow.top - teamTitle.bottom, closeTo(10, 0.5));
    expect(tester.getRect(find.text('SIM Treinamentos')).right, 412 - 20);
    // Os títulos das seções são cabeçalhos para o leitor de tela (Fase 8C).
    expect(
      tester.getSemantics(find.text('Na sessão')),
      isSemantics(label: 'Na sessão', isHeader: true),
    );
    expect(
      tester.getSemantics(find.text('Disponíveis na equipe')),
      isSemantics(label: 'Disponíveis na equipe', isHeader: true),
    );
    // Texto que se lê: o cinza que passa de 4,5:1 (Fase 8C).
    expect(
      tester.widget<Text>(find.text('SIM Treinamentos')).style!.color,
      AppColors.textSubtle,
    );

    // A nota do fim: 16 acima, 20 dos lados, 24 abaixo.
    final note = tester.getRect(
      find.ancestor(
        of: find.textContaining('Entrar e sair da sessão'),
        matching: find.byType(InlineNotice),
      ),
    );
    final lastTeamRow = tester.getRect(rowOf('equipe-c-patricia'));
    expect(note.top - lastTeamRow.bottom, 16);
    expect(note.left, 20);
    expect(note.right, 412 - 20);
  });

  testWidgets('"Adicionar" manda o consultor na hora, e ele passa para "Na '
      'sessão", com o aviso', (tester) async {
    await seedFromServer();
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('adicionar-c-diego')));
    await tester.pumpAndSettle();

    final sent = verify(
      () => api.post<Map<String, dynamic>>(addPath, data: captureAny(named: 'data')),
    ).captured.single;
    expect(sent, {'consultantId': 'c-diego'});

    expect(find.text('Diego Barbosa entrou na sessão.'), findsOneWidget);
    expect(rowOf('consultor-c-diego'), findsOneWidget);
    expect(inRow('consultor-c-diego', find.text('Sem participantes')), findsOneWidget);
    expect(removeButton(tester, 'c-diego').onPressed, isNotNull);
    expect(rowOf('equipe-c-diego'), findsNothing);
    expect(find.text('5 participantes · 4 consultores'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
      'com a resposta demorando: o botão tocado gira, os outros travam, e '
      'tudo volta quando ela chega', (tester) async {
    await seedFromServer();
    final reply = Completer<Response<Map<String, dynamic>>>();
    when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
        .thenAnswer((_) => reply.future);
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('adicionar-c-diego')));
    await tester.pump();
    // Um quadro no meio do envio.
    await tester.pump(const Duration(milliseconds: 300));

    expect(addButton(tester, 'c-diego').isLoading, isTrue);
    expect(
      inRow('equipe-c-diego', find.byType(CircularProgressIndicator)),
      findsOneWidget,
    );
    expect(addButton(tester, 'c-patricia').onPressed, isNull);
    expect(addButton(tester, 'c-patricia').isLoading, isFalse);
    expect(removeButton(tester, 'c-rafael').onPressed, isNull);
    expect(removeButton(tester, 'c-tatiane').onPressed, isNull);
    expect(find.text('Diego Barbosa entrou na sessão.'), findsNothing);

    // Um segundo toque não manda nada.
    await tester.tap(find.byKey(const ValueKey('adicionar-c-patricia')));
    await tester.pump();

    inSession.add('c-diego');
    reply.complete(ok(addPath, changedJson()));
    await tester.pumpAndSettle();

    verify(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
        .called(1);
    expect(find.text('Diego Barbosa entrou na sessão.'), findsOneWidget);
    expect(addButton(tester, 'c-patricia').onPressed, isNotNull);
    expect(removeButton(tester, 'c-rafael').onPressed, isNotNull);
    expect(removeButton(tester, 'c-diego').onPressed, isNotNull);
  });

  testWidgets('remover quem não tem avaliação em andamento vale no toque, sem '
      'perguntar', (tester) async {
    await seedFromServer();
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('remover-c-tatiane')));
    await tester.pumpAndSettle();

    verify(() => api.delete<Map<String, dynamic>>('$addPath/c-tatiane')).called(1);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Tatiane Souza saiu da sessão.'), findsOneWidget);
    expect(rowOf('consultor-c-tatiane'), findsNothing);
    // Continua na equipe: dá para pôr de volta.
    expect(addButton(tester, 'c-tatiane').onPressed, isNotNull);
    expect(find.text('5 participantes · 2 consultores'), findsOneWidget);
  });

  testWidgets(
      'remover quem tem avaliação em andamento pergunta antes, com a '
      'consequência; "Voltar" não remove', (tester) async {
    await seedFromServer();
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('remover-c-rafael')));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.text('Remover Rafael Lima da sessão?')),
      findsOneWidget,
    );
    expect(find.descendant(of: dialog, matching: find.text(_noteRafael)), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Voltar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    verifyNever(() => api.delete<Map<String, dynamic>>(any()));
    expect(rowOf('consultor-c-rafael'), findsOneWidget);
  });

  testWidgets(
      'confirmando, o consultor sai e quem estava com ele volta para Pendente '
      'no aparelho', (tester) async {
    await seedFromServer();
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('remover-c-rafael')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
    await tester.pumpAndSettle();

    verify(() => api.delete<Map<String, dynamic>>('$addPath/c-rafael')).called(1);
    expect(find.text('Rafael Lima saiu da sessão.'), findsOneWidget);
    expect(rowOf('consultor-c-rafael'), findsNothing);

    // A tela baixou a sessão de novo: o participante liberado está no cache.
    final marcos = await (db.select(db.participants)
          ..where((t) => t.id.equals('tp-marcos')))
        .getSingle();
    expect(marcos.status, 'PENDENTE');
    expect(marcos.assignedConsultantId, isNull);
  });

  testWidgets(
      'recusado pelo servidor: o motivo fica à vista, fora da rolagem, mesmo '
      'com a lista rolada até o fim', (tester) async {
    const reason = 'Consultor inativo não pode entrar em um treinamento';
    await seedFromServer();
    when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
        .thenThrow(const ApiException(message: reason, statusCode: 400));
    await pumpScreen(tester, screen: const Size(412, 640));

    final target = find.byKey(const ValueKey('adicionar-c-patricia'));
    await bringIntoView(tester, target);
    // O contexto, que abre a lista, já saiu da tela.
    expect(find.text('Bracell · 12 set').hitTestable(), findsNothing);
    clearInteractions(api);

    await tester.tap(target);
    await tester.pumpAndSettle();

    final notice = find.widgetWithText(InlineNotice, reason);
    expect(notice, findsOneWidget);
    expect(tester.widget<InlineNotice>(notice).tone, NoticeTone.danger);
    expect(find.ancestor(of: notice, matching: find.byType(ListView)), findsNothing);
    final rect = tester.getRect(notice);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(640));
    expect(find.text(reason).hitTestable(), findsOneWidget);

    // Sem aviso de sucesso, os botões voltam, e o que o aparelho tinha de
    // velho é baixado de novo: a sessão e a equipe.
    expect(find.textContaining('entrou na sessão'), findsNothing);
    expect(addButton(tester, 'c-patricia').onPressed, isNotNull);
    verify(() => api.get<Map<String, dynamic>>(detailPath)).called(1);
    expect(teamRequests(), 1);
  });

  testWidgets('o aviso da falha some na tentativa seguinte', (tester) async {
    await seedFromServer();
    when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
        .thenThrow(const ApiException(message: 'Internal server error', statusCode: 500));
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('adicionar-c-diego')));
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível adicionar o consultor. Tente de novo.'),
      findsOneWidget,
    );

    serverAnswers();
    await tester.tap(find.byKey(const ValueKey('adicionar-c-diego')));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível adicionar o consultor. Tente de novo.'),
      findsNothing,
    );
    expect(find.text('Diego Barbosa entrou na sessão.'), findsOneWidget);
  });

  testWidgets(
      'sem conexão: a faixa diz por quê, quem está na sessão continua à vista '
      'com o remover apagado, e a equipe fica para depois', (tester) async {
    await seedFromServer();
    serverUnreachable();
    await goOffline();
    await pumpScreen(tester);

    expect(
      find.text('Sem conexão — mudar os consultores precisa de internet.'),
      findsOneWidget,
    );
    expect(inRow('consultor-c-rafael', find.text('Rafael Lima')), findsOneWidget);
    expect(inRow('consultor-c-rafael', find.text(_noteRafael)), findsOneWidget);
    expect(removeButton(tester, 'c-rafael').onPressed, isNull);
    expect(removeButton(tester, 'c-tatiane').onPressed, isNull);

    expect(find.text('Disponíveis na equipe'), findsOneWidget);
    expect(find.text('A equipe aparece quando houver conexão.'), findsOneWidget);
    expect(find.text('Adicionar'), findsNothing);
    // A nota do fim continua lá.
    expect(find.textContaining('Offline, a lista fica só de leitura.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('remover-c-tatiane')));
    await tester.pumpAndSettle();
    verifyNever(() => api.delete<Map<String, dynamic>>(any()));
  });

  testWidgets(
      'a conexão cai com a tela aberta: a equipe continua à vista, com o '
      '"Adicionar" apagado; quando volta, tudo reabre e a equipe é buscada de '
      'novo', (tester) async {
    await seedFromServer();
    final changes = StreamController<List<ConnectivityResult>>();
    addTearDown(changes.close);
    final plugin = _MockConnectivity();
    when(plugin.checkConnectivity).thenAnswer((_) async => [ConnectivityResult.wifi]);
    when(() => plugin.onConnectivityChanged).thenAnswer((_) => changes.stream);
    connectivity.dispose();
    connectivity = ConnectivityService(connectivity: plugin);
    await connectivity.initialize();
    await pumpScreen(tester);
    expect(addButton(tester, 'c-diego').onPressed, isNotNull);
    clearInteractions(api);

    changes.add([ConnectivityResult.none]);
    await tester.pumpAndSettle();

    expect(
      find.text('Sem conexão — mudar os consultores precisa de internet.'),
      findsOneWidget,
    );
    expect(inRow('equipe-c-diego', find.text('Diego Barbosa')), findsOneWidget);
    expect(addButton(tester, 'c-diego').onPressed, isNull);
    expect(removeButton(tester, 'c-rafael').onPressed, isNull);

    changes.add([ConnectivityResult.mobile]);
    await tester.pumpAndSettle();

    expect(find.textContaining('Sem conexão'), findsNothing);
    expect(addButton(tester, 'c-diego').onPressed, isNotNull);
    expect(removeButton(tester, 'c-rafael').onPressed, isNotNull);
    expect(teamRequests(), 1);
  });

  testWidgets('enquanto a equipe não chega, mostra o esqueleto no lugar dela',
      (tester) async {
    await seedFromServer();
    final reply = Completer<Response<List<dynamic>>>();
    when(() => api.get<List<dynamic>>(
          teamPath,
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((_) => reply.future);
    await pumpScreen(tester, settle: false);

    expect(find.byKey(const Key('equipe-skeleton')), findsOneWidget);
    expect(find.text('Adicionar'), findsNothing);
    // Quem está na sessão vem do aparelho e não espera a equipe.
    expect(rowOf('consultor-c-rafael'), findsOneWidget);

    reply.complete(
      Response<List<dynamic>>(
        requestOptions: RequestOptions(path: teamPath),
        statusCode: 200,
        data: [consultantJson('c-diego')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('equipe-skeleton')), findsNothing);
    expect(addButton(tester, 'c-diego').onPressed, isNotNull);
  });

  testWidgets('com todos os ativos já na sessão, a equipe diz isso',
      (tester) async {
    inSession = _team.keys.toList();
    await seedFromServer();
    await pumpScreen(tester);

    expect(
      find.text('Todos os consultores ativos da equipe já estão nesta sessão.'),
      findsOneWidget,
    );
    expect(find.text('Adicionar'), findsNothing);
  });

  group('busca de consultores (Fase 8B)', () {
    Future<void> openSearch(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
    }

    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pumpAndSettle();
    }

    testWidgets(
        'a lupa fica à direita do título e abre o campo embaixo do cabeçalho; '
        'o X fecha', (tester) async {
      await seedFromServer();
      await pumpScreen(tester);
      final bar = tester.getRect(find.byType(AppTopBar));
      expect(tester.getRect(find.byTooltip('Buscar')).right, bar.right - 8);

      await openSearch(tester);

      expect(find.byType(AppSearchField), findsOneWidget);
      expect(find.text('Buscar consultor pelo nome'), findsOneWidget);
      expect(
        tester.getRect(find.byType(AppSearchField)).top,
        bar.bottom + AppSpacing.sm,
      );
      expect(find.byTooltip('Buscar'), findsNothing);

      await tester.tap(find.byTooltip('Fechar a busca'));
      await tester.pumpAndSettle();
      expect(find.byType(AppSearchField), findsNothing);
      expect(find.byTooltip('Buscar'), findsOneWidget);
    });

    testWidgets(
        'filtra as duas listas pelo nome; a lista sem ninguém some com o '
        'título', (tester) async {
      await seedFromServer();
      await pumpScreen(tester);
      await openSearch(tester);

      await type(tester, 'TAT');
      expect(rowOf('consultor-c-tatiane'), findsOneWidget);
      expect(rowOf('consultor-c-carla'), findsNothing);
      expect(find.text('Na sessão'), findsOneWidget);
      expect(find.text('Disponíveis na equipe'), findsNothing);

      await type(tester, 'patricia');
      expect(rowOf('equipe-c-patricia'), findsOneWidget);
      expect(rowOf('equipe-c-diego'), findsNothing);
      expect(find.text('Na sessão'), findsNothing);
      expect(find.text('Disponíveis na equipe'), findsOneWidget);
    });

    testWidgets('sem ninguém nas duas, diz que não achou', (tester) async {
      await seedFromServer();
      await pumpScreen(tester);
      await openSearch(tester);

      await type(tester, ' xyz ');

      expect(
        find.text('Nenhum consultor encontrado para “xyz”.'),
        findsOneWidget,
      );
      // A frase é anunciada quando aparece (Fase 8C).
      expect(
        tester.getSemantics(find.text('Nenhum consultor encontrado para “xyz”.')),
        isSemantics(isLiveRegion: true),
      );
      expect(find.text('Na sessão'), findsNothing);
      expect(find.text('Disponíveis na equipe'), findsNothing);
    });

    testWidgets(
        'sem conexão, o aviso da equipe vence a busca: a lista dela continua '
        'com o motivo', (tester) async {
      await seedFromServer();
      serverUnreachable();
      await goOffline();
      await pumpScreen(tester);
      await openSearch(tester);

      await type(tester, 'tat');

      expect(rowOf('consultor-c-tatiane'), findsOneWidget);
      expect(find.text('Disponíveis na equipe'), findsOneWidget);
      expect(find.text('A equipe aparece quando houver conexão.'), findsOneWidget);
    });

    testWidgets(
        'com a equipe ainda carregando, não diz que não achou: espera a equipe',
        (tester) async {
      await seedFromServer();
      final reply = Completer<Response<List<dynamic>>>();
      when(() => api.get<List<dynamic>>(
            teamPath,
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) => reply.future);
      await pumpScreen(tester, settle: false);
      await tester.tap(find.byTooltip('Buscar'));
      await pumpTransitions(tester);
      await tester.enterText(find.byType(TextField), 'diego');
      await pumpTransitions(tester);

      expect(find.textContaining('Nenhum consultor encontrado'), findsNothing);
      expect(find.byKey(const Key('equipe-skeleton')), findsOneWidget);

      reply.complete(
        Response<List<dynamic>>(
          requestOptions: RequestOptions(path: teamPath),
          statusCode: 200,
          data: [consultantJson('c-diego')],
        ),
      );
      await tester.pumpAndSettle();

      expect(rowOf('equipe-c-diego'), findsOneWidget);
      expect(find.textContaining('Nenhum consultor encontrado'), findsNothing);
    });

    testWidgets('o voltar com a busca aberta fecha a busca e fica na tela',
        (tester) async {
      await seedFromServer();
      await pumpScreen(tester);
      await openSearch(tester);
      await type(tester, 'tat');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(AppSearchField), findsNothing);
      expect(find.byType(SessionConsultantsScreen), findsOneWidget);
      expect(rowOf('consultor-c-carla'), findsOneWidget);
    });
  });

  testWidgets('falha ao buscar a equipe: pede para puxar, e puxar traz a equipe',
      (tester) async {
    await seedFromServer();
    when(() => api.get<List<dynamic>>(
          teamPath,
          queryParameters: any(named: 'queryParameters'),
        )).thenThrow(const ApiException(message: 'Internal server error', statusCode: 500));
    await pumpScreen(tester, screen: const Size(412, 900));

    expect(
      find.text('Não foi possível carregar a equipe. Puxe para atualizar.'),
      findsOneWidget,
    );

    serverAnswers();
    await tester.fling(find.text('Na sessão'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível carregar a equipe. Puxe para atualizar.'),
      findsNothing,
    );
    expect(addButton(tester, 'c-diego').onPressed, isNotNull);
  });

  testWidgets('sessão concluída: só leitura, com o motivo, e os botões à vista '
      'e apagados', (tester) async {
    serverStatus = 'CONCLUIDO';
    await seedFromServer();
    await pumpScreen(tester);

    expect(
      find.text('Sessão concluída: os consultores não podem mais ser alterados.'),
      findsOneWidget,
    );
    expect(removeButton(tester, 'c-rafael').onPressed, isNull);
    expect(addButton(tester, 'c-diego').onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('adicionar-c-diego')));
    await tester.pumpAndSettle();
    verifyNever(
      () => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')),
    );
  });

  testWidgets('sessão cancelada: o motivo próprio', (tester) async {
    serverStatus = 'CANCELADO';
    await seedFromServer();
    await pumpScreen(tester);

    expect(
      find.text('Sessão cancelada: os consultores não podem mais ser alterados.'),
      findsOneWidget,
    );
    expect(removeButton(tester, 'c-tatiane').onPressed, isNull);
  });

  testWidgets('quem não é ADMIN vê a lista travada, com o motivo', (tester) async {
    when(() => auth.currentUser).thenReturn(consultora);
    await seedFromServer();
    await pumpScreen(tester);

    expect(
      find.text('Só administradores podem mudar os consultores da sessão.'),
      findsOneWidget,
    );
    // O "(você)" acompanha quem está logado.
    expect(inRow('consultor-c-rafael', find.text('Rafael Lima (você)')), findsOneWidget);
    expect(removeButton(tester, 'c-tatiane').onPressed, isNull);
    expect(addButton(tester, 'c-diego').onPressed, isNull);
  });

  testWidgets('sessão que não está no aparelho: só o aviso', (tester) async {
    serverUnreachable();
    await pumpScreen(tester);

    expect(
      find.text('Esta sessão não está mais disponível neste aparelho.'),
      findsOneWidget,
    );
    expect(find.text('Na sessão'), findsNothing);
    expect(find.byType(ConsultantRow), findsNothing);
  });

  testWidgets(
      'sessão em cache sem os consultores, e sem conexão: avisa que ainda não '
      'foram baixados', (tester) async {
    await seedSessionOnly();
    serverUnreachable();
    await goOffline();
    await pumpScreen(tester);

    expect(
      find.text('Os consultores desta sessão ainda não foram baixados. Puxe '
          'para atualizar quando houver conexão.'),
      findsOneWidget,
    );
    expect(find.byType(ConsultantRow), findsNothing);
    expect(find.text('Na sessão'), findsOneWidget);
  });

  testWidgets(
      'num celular de 360x640 com a fonte ampliada, nada estoura, e dá para '
      'rolar até a nota do fim e adicionar', (tester) async {
    await seedFromServer();
    await pumpScreen(tester, screen: const Size(360, 640), textScale: 1.3);

    expect(tester.takeException(), isNull);
    expect(find.text('Consultores'), findsOneWidget);
    // A linha de apoio de quem está na sessão quebra, em vez de perder o
    // "em andamento" nas reticências.
    expect(
      tester
          .renderObject<RenderParagraph>(
            find.text('2 participantes · 1 em andamento'),
          )
          .didExceedMaxLines,
      isFalse,
    );

    final target = find.byKey(const ValueKey('adicionar-c-patricia'));
    await bringIntoView(tester, target);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(target).height, 48);

    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(find.text('Patrícia Vasconcelos entrou na sessão.'), findsOneWidget);

    await bringIntoView(tester, find.textContaining('Entrar e sair da sessão'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'num celular de 360x640 com a fonte ampliada, o aviso de falha comprido '
      'cabe acima da lista, que continua rolando', (tester) async {
    const reason = 'O consultor responsável não pode ser removido do '
        'treinamento. Troque o responsável antes.';
    await seedFromServer();
    when(() => api.delete<Map<String, dynamic>>(any()))
        .thenThrow(const ApiException(message: reason, statusCode: 400));
    await pumpScreen(tester, screen: const Size(360, 640), textScale: 1.3);

    final target = find.byKey(const ValueKey('remover-c-tatiane'));
    await bringIntoView(tester, target);
    await tester.tap(target);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final rect = tester.getRect(find.widgetWithText(InlineNotice, reason));
    expect(rect.bottom, lessThanOrEqualTo(640));
    // Sobra lista embaixo do aviso.
    expect(tester.getRect(find.byType(Scrollable).first).height, greaterThan(150));
  });

  testWidgets(
      'voltar com o envio ainda no ar: a tela fecha sem derrubar nada, e a '
      'sessão é baixada de novo quando a resposta chega', (tester) async {
    await seedFromServer();
    final reply = Completer<Response<Map<String, dynamic>>>();
    when(() => api.delete<Map<String, dynamic>>('$addPath/c-rafael'))
        .thenAnswer((_) => reply.future);
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('remover-c-rafael')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
    await pumpTransitions(tester);
    expect(removeButton(tester, 'c-rafael').isLoading, isTrue);
    clearInteractions(api);

    await tester.tap(find.byTooltip('Voltar'));
    await pumpTransitions(tester);

    expect(find.byType(SessionConsultantsScreen), findsNothing);
    expect(find.text('origem'), findsOneWidget);

    // O servidor conclui a remoção e libera o participante.
    inSession.remove('c-rafael');
    serverParticipants[2]
      ..['status'] = 'PENDENTE'
      ..['assignedConsultantId'] = null
      ..['assignedConsultant'] = null;
    reply.complete(ok('$addPath/c-rafael', changedJson()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    verify(() => api.get<Map<String, dynamic>>(detailPath)).called(1);
    final marcos = await (db.select(db.participants)
          ..where((t) => t.id.equals('tp-marcos')))
        .getSingle();
    expect(marcos.status, 'PENDENTE');
  });
}

/// Deixa as animações de rota e de diálogo correrem até o fim. Com um envio
/// no ar o botão gira sem parar e o `pumpAndSettle` não assenta; então, um
/// quadro para a animação começar e outro, de 1 s, para ela acabar.
Future<void> pumpTransitions(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}
