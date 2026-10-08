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
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/router.dart';
import 'package:simtc/ui/add_participant/add_participant_screen.dart';
import 'package:simtc/ui/core/app_localization.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/theme/app_theme.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/app_text_field.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late _MockApiClient api;
  late _MockAuthRepository auth;
  late AppDatabase db;
  late SessionRepository sessionRepository;
  late ParticipantRepository participantRepository;
  late ConnectivityService connectivity;
  late GoRouter router;

  /// O que a tela devolveu ao fechar: `true` se alguém entrou na sessão.
  late Future<Object?> closed;

  const lookupPath = '/training-sessions/sess-1/participants/lookup';
  const addPath = '/training-sessions/sess-1/participants';

  // CPF com os dígitos verificadores certos.
  const cpf = '52998224725';

  const admin = AuthUser(
    id: 'u-admin',
    name: 'Sebastião Souza',
    email: 'admin@simtc.com.br',
    role: AppUserRole.admin,
    consultantId: 'c-admin',
  );
  const consultora = AuthUser(
    id: 'u1',
    name: 'Carla Souza',
    email: 'carla@simtc.com.br',
    role: AppUserRole.consultant,
    consultantId: 'c-eu',
  );

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
    connectivity = ConnectivityService();
  });

  tearDown(() async {
    await db.close();
    connectivity.dispose();
  });

  Future<void> seedSession({String status = 'EM_ANDAMENTO', bool withDate = true}) {
    return db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 'sess-1',
            companyName: 'Bracell',
            courseName: 'Direção Defensiva — Veículo Pesado',
            city: 'Itabira',
            state: 'MG',
            date: Value(withDate ? DateTime(2026, 9, 12) : null),
            status: status,
            cachedAt: DateTime(2026, 9, 12, 7),
          ),
        );
  }

  void lookupAnswers(Map<String, dynamic> body) {
    when(() => api.post<Map<String, dynamic>>(lookupPath, data: any(named: 'data')))
        .thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: lookupPath),
        statusCode: 200,
        data: body,
      ),
    );
  }

  void cpfIsFree() => lookupAnswers(
        {'registered': false, 'name': null, 'email': null, 'enrolled': false},
      );

  Map<String, dynamic> addedJson({
    String id = 'tp-9',
    String name = 'Fernanda Lopes Meireles',
    String participationType = 'TEORICA_E_PRATICA',
  }) {
    return {
      'id': id,
      'trainingSessionId': 'sess-1',
      'participationType': participationType,
      'status': 'PENDENTE',
      'assignedConsultantId': null,
      'participant': {'id': 'p-$id', 'name': name, 'cpf': cpf, 'email': null},
    };
  }

  void addAnswers(Map<String, dynamic> body) {
    when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
        .thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: addPath),
        statusCode: 201,
        data: body,
      ),
    );
  }

  List<Object?> sentBodies() {
    return verify(
      () => api.post<Map<String, dynamic>>(addPath, data: captureAny(named: 'data')),
    ).captured;
  }

  Future<void> goOffline() async {
    final plugin = _MockConnectivity();
    when(plugin.checkConnectivity).thenAnswer((_) async => [ConnectivityResult.none]);
    when(() => plugin.onConnectivityChanged).thenAnswer((_) => const Stream.empty());
    connectivity.dispose();
    connectivity = ConnectivityService(connectivity: plugin);
    await connectivity.initialize();
  }

  /// A tela empilhada sobre uma origem, pela rota real.
  Future<void> pumpAdd(
    WidgetTester tester, {
    Size screen = const Size(412, 1400),
    double textScale = 1,
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
          path: '/sessions/:sessionId/participants/new',
          builder: (context, state) => AddParticipantScreen(
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
    closed = router.push<Object?>(AppRoutes.addParticipant('sess-1'));
    await tester.pumpAndSettle();
  }

  /// Deixa as animações de rota e de diálogo correrem até o fim. Com um envio
  /// no ar o botão gira sem parar e o `pumpAndSettle` não assenta; então, um
  /// quadro para a animação começar (o `maybePop` decide o pop num microtask)
  /// e outro, de 1 s, para ela acabar — a troca de tela do Android leva 450 ms,
  /// e a tela só sai da árvore quando ela termina.
  Future<void> pumpTransitions(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Finder field(String key) => find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(TextField),
      );

  String textOf(WidgetTester tester, String key) =>
      tester.widget<TextField>(field(key)).controller!.text;

  AppCtaButton addButton(WidgetTester tester) =>
      tester.widget<AppCtaButton>(find.byType(AppCtaButton));

  AppTextButton addAnotherButton(WidgetTester tester) =>
      tester.widget<AppTextButton>(find.byType(AppTextButton));

  /// Digita o CPF e espera a consulta responder.
  Future<void> typeCpf(WidgetTester tester, [String digits = cpf]) async {
    await tester.enterText(field('campo-cpf'), digits);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'mostra o contexto da sessão e os campos, com o CPF primeiro e '
      '"Teórica + prática" marcado', (tester) async {
    await seedSession();
    await pumpAdd(tester);

    expect(find.text('Adicionar participante'), findsNWidgets(2),
        reason: 'o título e o botão');
    expect(find.text('Bracell'), findsOneWidget);
    expect(find.text('Direção Defensiva — Veículo Pesado · 12 set'), findsOneWidget);
    expect(find.text('opcional'), findsOneWidget);
    expect(find.text('para enviar o certificado'), findsOneWidget);
    expect(find.text('Tipo de participação'), findsOneWidget);
    expect(find.text('Salvar e adicionar outro'), findsOneWidget);

    final cpfY = tester.getTopLeft(find.byKey(const Key('campo-cpf'))).dy;
    final nameY = tester.getTopLeft(find.byKey(const Key('campo-nome'))).dy;
    final emailY = tester.getTopLeft(find.byKey(const Key('campo-email'))).dy;
    expect(cpfY, lessThan(nameY));
    expect(nameY, lessThan(emailY));

    Color? borderOf(String key) {
      final box = tester.widget<Container>(
        find.descendant(of: find.byKey(Key(key)), matching: find.byType(Container)),
      );
      return ((box.decoration! as BoxDecoration).border! as Border).top.color;
    }

    expect(borderOf('tipo-teoricaEPratica'), AppColors.primary);
    expect(borderOf('tipo-somenteTeorica'), AppColors.borderStrong);

    expect(addButton(tester).onPressed, isNull, reason: 'nada preenchido');
    expect(addAnotherButton(tester).onPressed, isNull);
    // Atribuir a outro consultor não existe no backend (decisão de 06/10/2026).
    expect(find.text('Consultor responsável'), findsNothing);
  });

  testWidgets('sessão sem data: a faixa de contexto mostra só o curso',
      (tester) async {
    await seedSession(withDate: false);
    await pumpAdd(tester);

    expect(find.text('Direção Defensiva — Veículo Pesado'), findsOneWidget);
  });

  testWidgets(
      'CPF livre: máscara, check e o texto do canvas; adicionar manda os '
      'dados, volta à tela de baixo e avisa', (tester) async {
    await seedSession();
    cpfIsFree();
    addAnswers(addedJson());
    await pumpAdd(tester);

    await typeCpf(tester);

    expect(textOf(tester, 'campo-cpf'), '529.982.247-25');
    expect(find.text('CPF válido e sem cadastro nesta sessão.'), findsOneWidget);
    expect(find.byIcon(AppIcons.approved), findsOneWidget);
    final sentLookup = verify(
      () => api.post<Map<String, dynamic>>(lookupPath, data: captureAny(named: 'data')),
    ).captured.single;
    expect(sentLookup, {'cpf': cpf});
    expect(addButton(tester).onPressed, isNull, reason: 'falta o nome');

    await tester.enterText(field('campo-nome'), 'Fernanda Lopes Meireles');
    await tester.pump();
    await tester.tap(find.widgetWithText(AppCtaButton, 'Adicionar participante'));
    await tester.pumpAndSettle();

    expect(sentBodies().single, {
      'cpf': cpf,
      'name': 'Fernanda Lopes Meireles',
      'participationType': 'TEORICA_E_PRATICA',
    });
    expect(find.text('origem'), findsOneWidget);
    expect(find.byType(AddParticipantScreen), findsNothing);
    expect(find.text('Participante adicionado.'), findsOneWidget);
    expect(await closed, isTrue);
    final row = await db.select(db.participants).getSingle();
    expect(row.name, 'Fernanda Lopes Meireles');
    expect(row.cpf, '529.982.***-**');
  });

  testWidgets(
      'CPF com cadastro de outro treinamento: preenche nome e e-mail e avisa '
      'de onde vieram', (tester) async {
    await seedSession();
    lookupAnswers({
      'registered': true,
      'name': 'Fernanda Lopes Meireles',
      'email': 'fernanda@empresa.com.br',
      'enrolled': false,
    });
    addAnswers(addedJson());
    await pumpAdd(tester);

    await typeCpf(tester);

    expect(textOf(tester, 'campo-nome'), 'Fernanda Lopes Meireles');
    expect(textOf(tester, 'campo-email'), 'fernanda@empresa.com.br');
    expect(
      find.text('Já cadastrado em outro treinamento: nome e e-mail '
          'preenchidos. Altere se precisar.'),
      findsOneWidget,
    );
    expect(addButton(tester).onPressed, isNotNull);

    // Os campos continuam editáveis: o que está na tela é o que vai.
    await tester.enterText(field('campo-nome'), 'Fernanda L. Meireles');
    await tester.pump();
    await tester.tap(find.widgetWithText(AppCtaButton, 'Adicionar participante'));
    await tester.pumpAndSettle();

    expect(sentBodies().single, {
      'cpf': cpf,
      'name': 'Fernanda L. Meireles',
      'email': 'fernanda@empresa.com.br',
      'participationType': 'TEORICA_E_PRATICA',
    });
  });

  testWidgets('trocar o CPF depois do preenchimento limpa o que veio do cadastro',
      (tester) async {
    await seedSession();
    lookupAnswers({
      'registered': true,
      'name': 'Fernanda Lopes Meireles',
      'email': 'fernanda@empresa.com.br',
      'enrolled': false,
    });
    await pumpAdd(tester);
    await typeCpf(tester);

    await tester.enterText(field('campo-cpf'), '5299822472');
    await tester.pumpAndSettle();

    expect(textOf(tester, 'campo-nome'), '');
    expect(textOf(tester, 'campo-email'), '');
    expect(find.textContaining('Já cadastrado em outro treinamento'), findsNothing);
  });

  testWidgets('CPF já nesta sessão: diz quem é e não deixa adicionar',
      (tester) async {
    await seedSession();
    lookupAnswers({
      'registered': true,
      'name': 'Fernanda Lopes Meireles',
      'email': null,
      'enrolled': true,
    });
    await pumpAdd(tester);

    await typeCpf(tester);
    await tester.enterText(field('campo-nome'), 'Fernanda');
    await tester.pump();

    expect(find.text('Fernanda Lopes Meireles já está nesta sessão.'), findsOneWidget);
    expect(addButton(tester).onPressed, isNull);
    expect(addAnotherButton(tester).onPressed, isNull);
  });

  testWidgets('CPF com dígito verificador errado: "CPF inválido.", sem consultar',
      (tester) async {
    await seedSession();
    await pumpAdd(tester);

    await typeCpf(tester, '52998224726');

    expect(find.text('CPF inválido.'), findsOneWidget);
    verifyNever(
      () => api.post<Map<String, dynamic>>(lookupPath, data: any(named: 'data')),
    );
  });

  testWidgets('consulta que falha: avisa e segue como formulário simples',
      (tester) async {
    await seedSession();
    when(() => api.post<Map<String, dynamic>>(lookupPath, data: any(named: 'data')))
        .thenThrow(const ApiException(message: 'Sem conexão', isNetworkError: true));
    addAnswers(addedJson());
    await pumpAdd(tester);

    await typeCpf(tester);
    await tester.enterText(field('campo-nome'), 'Fernanda Lopes Meireles');
    await tester.pump();

    expect(
      find.text('Não foi possível consultar o CPF. Preencha os dados e '
          'adicione assim mesmo.'),
      findsOneWidget,
    );
    expect(addButton(tester).onPressed, isNotNull);
  });

  testWidgets(
      '"Salvar e adicionar outro": limpa o formulário, avisa quem entrou e '
      'fica na tela; ao fechar, a tela de baixo sabe que entrou gente',
      (tester) async {
    await seedSession();
    cpfIsFree();
    addAnswers(addedJson());
    await pumpAdd(tester);
    await typeCpf(tester);
    await tester.enterText(field('campo-nome'), 'Fernanda Lopes Meireles');
    await tester.pump();
    await tester.tap(find.byKey(const Key('tipo-somenteTeorica')));
    await tester.pump();

    await tester.tap(find.text('Salvar e adicionar outro'));
    await tester.pumpAndSettle();

    expect(find.byType(AddParticipantScreen), findsOneWidget);
    expect(find.text('Fernanda Lopes Meireles entrou na sessão.'), findsOneWidget);
    expect(textOf(tester, 'campo-cpf'), '');
    expect(textOf(tester, 'campo-nome'), '');
    expect(textOf(tester, 'campo-email'), '');
    expect(addButton(tester).onPressed, isNull);
    expect(sentBodies().single, {
      'cpf': cpf,
      'name': 'Fernanda Lopes Meireles',
      'participationType': 'SOMENTE_TEORICA',
    });

    // Formulário vazio: o X fecha sem perguntar.
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();

    expect(find.text('origem'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(await closed, isTrue);
  });

  testWidgets('e-mail com erro de digitação: o aviso aparece ao sair do campo',
      (tester) async {
    await seedSession();
    cpfIsFree();
    await pumpAdd(tester);
    await typeCpf(tester);
    await tester.enterText(field('campo-nome'), 'Fernanda Lopes Meireles');

    await tester.tap(field('campo-email'));
    await tester.enterText(field('campo-email'), 'fernanda@empresa');
    await tester.pump();

    expect(find.text('E-mail inválido.'), findsNothing, reason: 'ainda digitando');
    expect(addButton(tester).onPressed, isNull);

    await tester.tap(field('campo-nome'));
    await tester.pump();

    expect(find.text('E-mail inválido.'), findsOneWidget);

    await tester.enterText(field('campo-email'), 'fernanda@empresa.com.br');
    await tester.pump();

    expect(find.text('E-mail inválido.'), findsNothing);
    expect(addButton(tester).onPressed, isNotNull);
  });

  group('fechar a tela', () {
    testWidgets('vazia, fecha direto e avisa a tela de baixo que nada mudou',
        (tester) async {
      await seedSession();
      await pumpAdd(tester);

      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();

      expect(find.text('origem'), findsOneWidget);
      expect(await closed, isFalse);
    });

    testWidgets(
        'com algo preenchido, pergunta: "Continuar preenchendo" fica, '
        '"Descartar" fecha sem adicionar', (tester) async {
      await seedSession();
      await pumpAdd(tester);
      await tester.enterText(field('campo-nome'), 'Fernanda');
      await tester.pump();

      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();
      expect(find.text('Descartar o que foi preenchido?'), findsOneWidget);

      await tester.tap(find.text('Continuar preenchendo'));
      await tester.pumpAndSettle();
      expect(find.byType(AddParticipantScreen), findsOneWidget);
      expect(textOf(tester, 'campo-nome'), 'Fernanda');

      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Descartar'));
      await tester.pumpAndSettle();

      expect(find.text('origem'), findsOneWidget);
      expect(await closed, isFalse);
      verifyNever(
        () => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')),
      );
    });

    testWidgets('o voltar do Android, com algo preenchido, também pergunta',
        (tester) async {
      await seedSession();
      await pumpAdd(tester);
      await tester.enterText(field('campo-nome'), 'Fernanda');
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Descartar o que foi preenchido?'), findsOneWidget);
      expect(find.byType(AddParticipantScreen), findsOneWidget);
    });

    testWidgets(
        'com o envio no ar, o voltar do Android é ignorado: sem diálogo, a '
        'tela fica e, com a resposta, fecha devolvendo `true`', (tester) async {
      await seedSession();
      cpfIsFree();
      final reply = Completer<Response<Map<String, dynamic>>>();
      when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
          .thenAnswer((_) => reply.future);
      await pumpAdd(tester);
      await typeCpf(tester);
      await tester.enterText(field('campo-nome'), 'Fernanda Lopes Meireles');
      await tester.pump();

      await tester.tap(find.widgetWithText(AppCtaButton, 'Adicionar participante'));
      await tester.pump();
      expect(addButton(tester).isLoading, isTrue, reason: 'o envio está no ar');

      await tester.binding.handlePopRoute();
      await pumpTransitions(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(AddParticipantScreen), findsOneWidget);

      reply.complete(
        Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: addPath),
          statusCode: 201,
          data: addedJson(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AddParticipantScreen), findsNothing);
      expect(find.text('origem'), findsOneWidget);
      expect(find.text('Participante adicionado.'), findsOneWidget);
      expect(await closed, isTrue);
    });
  });

  testWidgets(
      'sem conexão: os dois botões ficam desabilitados, com o aviso, e o que '
      'foi digitado fica', (tester) async {
    await seedSession();
    cpfIsFree();
    await goOffline();
    await pumpAdd(tester);
    await typeCpf(tester);
    await tester.enterText(field('campo-nome'), 'Fernanda Lopes Meireles');
    await tester.pump();

    expect(
      find.text('Sem conexão — adicionar participante precisa de internet.'),
      findsOneWidget,
    );
    expect(find.text('Disponível quando houver conexão'), findsOneWidget);
    expect(addButton(tester).onPressed, isNull);
    expect(addAnotherButton(tester).onPressed, isNull);
    expect(textOf(tester, 'campo-nome'), 'Fernanda Lopes Meireles');
  });

  testWidgets(
      'celular estreito com a fonte do sistema ampliada: a tela não estoura, '
      'nem com o aviso do cadastro e os cartões em duas linhas', (tester) async {
    await seedSession();
    lookupAnswers({
      'registered': true,
      'name': 'Fernanda Lopes Meireles de Albuquerque Vasconcelos',
      'email': 'fernanda.lopes.meireles@empresa-de-transportes.com.br',
      'enrolled': false,
    });
    await pumpAdd(tester, screen: const Size(360, 1800), textScale: 1.6);

    await typeCpf(tester);

    expect(find.textContaining('Já cadastrado em outro treinamento'), findsOneWidget);
    expect(find.text('Teórica + prática'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'rodapé como o do canvas "3a": 8 entre o "Adicionar participante" e o '
      '"Salvar e adicionar outro", 16 de recuo embaixo', (tester) async {
    await seedSession();
    await pumpAdd(tester);

    final add = tester.getRect(find.byType(AppCtaButton));
    final addAnother = tester.getRect(
      find.widgetWithText(AppTextButton, 'Salvar e adicionar outro'),
    );
    // O rodapé encosta na base da área segura — que, sem recortes do sistema
    // no teste, é a base da tela.
    final footerBottom = tester.view.physicalSize.height;

    expect(addAnother.top - add.bottom, 8);
    expect(footerBottom - addAnother.bottom, 16);
  });

  group('o servidor recusa', () {
    Future<void> fillAndAdd(WidgetTester tester) async {
      await typeCpf(tester);
      await tester.enterText(field('campo-nome'), 'Fernanda Lopes Meireles');
      await tester.pump();
      await tester.tap(find.widgetWithText(AppCtaButton, 'Adicionar participante'));
      await tester.pumpAndSettle();
    }

    testWidgets('falha de rede: o motivo aparece na tela e os campos ficam',
        (tester) async {
      await seedSession();
      cpfIsFree();
      when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
          .thenThrow(const ApiException(
        message: 'Sem conexão com o servidor. Verifique a internet e tente de novo.',
        isNetworkError: true,
      ));
      await pumpAdd(tester);

      await fillAndAdd(tester);

      expect(find.byType(AddParticipantScreen), findsOneWidget);
      expect(
        find.text('Sem conexão com o servidor. Verifique a internet e tente de novo.'),
        findsOneWidget,
      );
      expect(textOf(tester, 'campo-nome'), 'Fernanda Lopes Meireles');
      expect(addButton(tester).onPressed, isNotNull, reason: 'dá para tentar de novo');
    });

    testWidgets(
        'falha num celular de 360x640: o motivo fica à vista, no rodapé acima '
        'do botão, sem precisar rolar', (tester) async {
      await seedSession();
      cpfIsFree();
      const reason =
          'Sem conexão com o servidor. Verifique a internet e tente de novo.';
      when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
          .thenThrow(const ApiException(message: reason, isNetworkError: true));
      await pumpAdd(tester, screen: const Size(360, 640));

      await fillAndAdd(tester);

      final notice = find.text(reason);
      expect(notice, findsOneWidget);
      final rect = tester.getRect(notice);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(640));
      // Estar montado e com as medidas dentro da tela não basta: a lista corta o
      // que passa da dobra e o rodapé cobre o que ficou embaixo dela. Só um
      // texto à vista recebe o toque no centro dele.
      expect(notice.hitTestable(), findsOneWidget);
      // Junto do botão que o admin acabou de tocar.
      expect(
        rect.bottom,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(AppCtaButton)).dy),
      );
    });

    testWidgets(
        'CPF inscrito por outra pessoa entre a consulta e o toque: o aviso '
        'vai para o CPF', (tester) async {
      await seedSession();
      cpfIsFree();
      when(() => api.post<Map<String, dynamic>>(addPath, data: any(named: 'data')))
          .thenThrow(const ApiException(
        message: 'CPF já inscrito neste treinamento',
        statusCode: 409,
      ));
      await pumpAdd(tester);

      await fillAndAdd(tester);

      expect(find.text('Este CPF já está nesta sessão.'), findsOneWidget);
      expect(addButton(tester).onPressed, isNull);
    });
  });

  group('formulário travado, com o motivo escrito', () {
    testWidgets('consultor comum', (tester) async {
      when(() => auth.currentUser).thenReturn(consultora);
      await seedSession();
      await pumpAdd(tester);

      expect(
        find.text('Só administradores podem adicionar participantes.'),
        findsOneWidget,
      );
      for (final input in tester.widgetList<AppTextField>(find.byType(AppTextField))) {
        expect(input.enabled, isFalse, reason: input.label);
      }
      expect(addButton(tester).onPressed, isNull);
    });

    testWidgets('sessão concluída', (tester) async {
      await seedSession(status: 'CONCLUIDO');
      await pumpAdd(tester);

      expect(
        find.text('Sessão concluída: não dá mais para adicionar participantes.'),
        findsOneWidget,
      );
      expect(addButton(tester).onPressed, isNull);
    });
  });

  testWidgets('sessão que não está no aparelho: só o aviso', (tester) async {
    await pumpAdd(tester);

    expect(
      find.text('Esta sessão não está mais disponível neste aparelho.'),
      findsOneWidget,
    );
    expect(find.byType(AppCtaButton), findsNothing);
  });
}
