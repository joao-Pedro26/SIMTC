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
import 'package:simtc/ui/core/app_localization.dart';
import 'package:simtc/ui/core/theme/app_theme.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/app_text_field.dart';
import 'package:simtc/ui/core/widgets/session_context_header.dart';
import 'package:simtc/ui/session_edit/session_edit_screen.dart';

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

  /// O que a tela devolve à de baixo quando fecha: `true` se salvou (é o que
  /// faz o detalhe baixar a sessão de novo). Guardado pelo `pumpEdit`.
  late Future<bool?> editResult;

  const path = '/training-sessions/sess-1';
  const cancelPath = '/training-sessions/sess-1/cancel';

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

  Future<void> seedSession({
    String status = 'EM_ANDAMENTO',
    bool withDate = true,
    DateTime? date,
    String? notes = 'Pátio 3 — portaria B.',
  }) {
    return db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 'sess-1',
            companyName: 'Bracell',
            courseName: 'Direção Defensiva — Veículo Pesado',
            city: 'Itabira',
            state: 'MG',
            date: Value(withDate ? (date ?? DateTime(2026, 9, 12)) : null),
            status: status,
            notes: Value(notes),
            cachedAt: DateTime(2026, 9, 12, 7),
          ),
        );
  }

  Future<void> seedParticipant(String id, String status) {
    return db.into(db.participants).insert(
          ParticipantsCompanion.insert(
            id: id,
            sessionId: 'sess-1',
            name: 'Participante $id',
            cpf: '042.118.***-**',
            participationType: 'TEORICA_E_PRATICA',
            status: status,
            cachedAt: DateTime(2026, 9, 12, 7),
          ),
        );
  }

  Response<Map<String, dynamic>> ok(String requestPath) {
    return Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: requestPath),
      statusCode: 200,
      data: {'id': 'sess-1'},
    );
  }

  void patchAnswers() {
    when(() => api.patch<Map<String, dynamic>>(path, data: any(named: 'data')))
        .thenAnswer((_) async => ok(path));
  }

  Object? sentBody() {
    return verify(
      () => api.patch<Map<String, dynamic>>(path, data: captureAny(named: 'data')),
    ).captured.single;
  }

  Future<void> goOffline() async {
    final plugin = _MockConnectivity();
    when(plugin.checkConnectivity).thenAnswer((_) async => [ConnectivityResult.none]);
    when(() => plugin.onConnectivityChanged).thenAnswer((_) => const Stream.empty());
    connectivity.dispose();
    connectivity = ConnectivityService(connectivity: plugin);
    await connectivity.initialize();
  }

  /// A tela empilhada sobre uma origem, pela rota real; a lista de sessões é
  /// para onde o "Cancelar sessão" leva.
  Future<void> pumpEdit(
    WidgetTester tester, {
    Size screen = const Size(412, 1400),
    double textScale = 1,
    DateTime Function()? clock,
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    router = GoRouter(
      initialLocation: '/origem',
      routes: [
        GoRoute(
          path: '/origem',
          builder: (context, state) => const Scaffold(body: Text('origem')),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) =>
              const Scaffold(body: Text('lista de sessões')),
        ),
        GoRoute(
          path: '/sessions/:sessionId/edit',
          builder: (context, state) => SessionEditScreen(
            sessionId: state.pathParameters['sessionId']!,
            clock: clock,
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
    editResult = router.push<bool>(AppRoutes.sessionEdit('sess-1'));
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

  /// O teclado do sistema aberto, com [height] de altura (ou fechado, com 0).
  Future<void> setKeyboard(WidgetTester tester, double height) async {
    tester.view.viewInsets = FakeViewPadding(bottom: height);
    await tester.pump();
  }

  Finder field(String key) => find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(TextField),
      );

  AppCtaButton saveButton(WidgetTester tester) =>
      tester.widget<AppCtaButton>(find.byType(AppCtaButton));

  AppDangerOutlineButton cancelButton(WidgetTester tester) =>
      tester.widget<AppDangerOutlineButton>(find.byType(AppDangerOutlineButton));

  testWidgets('mostra o contexto da sessão e os campos com os valores dela',
      (tester) async {
    await seedSession();
    await pumpEdit(tester);

    expect(find.text('Dados do treinamento'), findsOneWidget);
    expect(find.text('Bracell'), findsOneWidget);
    expect(find.text('Direção Defensiva — Veículo Pesado'), findsOneWidget);
    expect(find.text('12 set 2026'), findsOneWidget);
    expect(find.text('Itabira'), findsOneWidget);
    expect(find.text('MG'), findsOneWidget);
    expect(find.text('Pátio 3 — portaria B.'), findsOneWidget);
    expect(find.text('Observações para os consultores'), findsOneWidget);
    // A data é um nó só para o leitor de tela: "Data, 12 set 2026, botão"
    // (Fase 8C).
    expect(
      tester.getSemantics(find.byKey(const Key('campo-data'))),
      isSemantics(
        label: 'Data',
        value: '12 set 2026',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    expect(find.bySemanticsLabel('Data'), findsOneWidget);
    // A faixa de contexto do quadro "3b" (Fase 8C).
    expect(
      tester.widget<SessionContextHeader>(find.byType(SessionContextHeader)).spacious,
      isTrue,
    );

    expect(saveButton(tester).onPressed, isNull, reason: 'nada mudou ainda');
    expect(cancelButton(tester).onPressed, isNotNull);
    expect(find.text('Descartar'), findsOneWidget);
    // Fora do contrato, e por isso fora da tela (decisões de 06/10/2026).
    expect(find.text('Início'), findsNothing);
    expect(find.text('Local'), findsNothing);
  });

  testWidgets('sessão sem data mostra "Sem data" no campo', (tester) async {
    await seedSession(withDate: false);
    await pumpEdit(tester);

    expect(find.text('Sem data'), findsOneWidget);
  });

  testWidgets(
      'editar a cidade e salvar: manda só o que mudou, volta à tela de baixo '
      'e avisa', (tester) async {
    await seedSession();
    patchAnswers();
    await pumpEdit(tester);

    await tester.enterText(field('campo-cidade'), 'Betim');
    await tester.pump();
    expect(saveButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect(sentBody(), {'city': 'Betim'});
    expect(find.text('origem'), findsOneWidget);
    expect(find.byType(SessionEditScreen), findsNothing);
    expect(find.text('Dados do treinamento atualizados.'), findsOneWidget);
    final row = await db.select(db.sessions).getSingle();
    expect(row.city, 'Betim');
  });

  testWidgets('a data é escolhida no calendário, em português', (tester) async {
    await seedSession();
    patchAnswers();
    await pumpEdit(tester);

    await tester.tapAt(tester.getCenter(find.text('12 set 2026')));
    await tester.pumpAndSettle();

    expect(find.text('Data do treinamento'), findsOneWidget);
    expect(find.text('setembro de 2026'), findsOneWidget);

    await tester.tap(find.text('15'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('15 set 2026'), findsOneWidget);

    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect(sentBody(), {'date': '2026-09-15'});
  });

  // A lista de sessões só baixa as dos últimos 90 dias (decisão de
  // 09/10/2026). A sessão dos testes é de 12/09/2026.
  group('data com mais de 90 dias', () {
    const title = 'Esta data é de mais de 90 dias atrás.';
    const warning =
        'A sessão vai sair da lista do app em todos os aparelhos; depois '
        'disso, só o painel web consegue alterá-la. Salvar assim mesmo?';

    /// Troca a data para o dia 15 do mês da sessão e toca em "Salvar
    /// alterações".
    Future<void> pickDay15AndSave(WidgetTester tester) async {
      await tester.tapAt(tester.getCenter(find.text('12 set 2026')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();
    }

    testWidgets('mudar a data para antes da janela pergunta antes de salvar; '
        '"Voltar" não salva e deixa a tela como estava', (tester) async {
      await seedSession();
      patchAnswers();
      // Em 20/01/2027, a janela começa em 22/10/2026.
      await pumpEdit(tester, clock: () => DateTime(2027, 1, 20, 9));

      await pickDay15AndSave(tester);

      final dialog = find.byType(AlertDialog);
      expect(find.descendant(of: dialog, matching: find.text(title)), findsOneWidget);
      expect(find.descendant(of: dialog, matching: find.text(warning)), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Voltar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SessionEditScreen), findsOneWidget);
      expect(find.text('15 set 2026'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNotNull);
      verifyNever(() => api.patch<Map<String, dynamic>>(path, data: any(named: 'data')));
    });

    testWidgets('confirmando, salva a data antiga e fecha a tela', (tester) async {
      await seedSession();
      patchAnswers();
      await pumpEdit(tester, clock: () => DateTime(2027, 1, 20, 9));

      await pickDay15AndSave(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();

      expect(sentBody(), {'date': '2026-09-15'});
      expect(find.text('origem'), findsOneWidget);
      expect(find.text('Dados do treinamento atualizados.'), findsOneWidget);
    });

    testWidgets('data dentro da janela salva direto, sem perguntar',
        (tester) async {
      await seedSession();
      patchAnswers();
      // Em 20/09/2026, 15/09 é da semana passada.
      await pumpEdit(tester, clock: () => DateTime(2026, 9, 20, 9));

      await pickDay15AndSave(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(sentBody(), {'date': '2026-09-15'});
      expect(find.text('origem'), findsOneWidget);
    });

    testWidgets(
        'a data antiga já estava lá: mudar só a cidade salva direto, sem '
        'perguntar', (tester) async {
      await seedSession();
      patchAnswers();
      await pumpEdit(tester, clock: () => DateTime(2027, 1, 20, 9));

      await tester.enterText(field('campo-cidade'), 'Betim');
      await tester.pump();
      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(sentBody(), {'city': 'Betim'});
    });

    testWidgets(
        'num celular de 360x640 com a fonte ampliada, a pergunta cabe na tela',
        (tester) async {
      await seedSession();
      patchAnswers();
      await pumpEdit(
        tester,
        screen: const Size(360, 640),
        textScale: 1.3,
        clock: () => DateTime(2027, 1, 20, 9),
      );

      await pickDay15AndSave(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(title), findsOneWidget);
      final save = tester.getRect(find.widgetWithText(FilledButton, 'Salvar'));
      expect(save.bottom, lessThanOrEqualTo(640));
    });
  });

  testWidgets(
      'sessão com data fora do intervalo do calendário (cadastro antigo): o '
      'calendário abre mesmo assim', (tester) async {
    await seedSession(date: DateTime(2019, 5, 10));
    await pumpEdit(tester);

    await tester.tapAt(tester.getCenter(find.text('10 mai 2019')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Data do treinamento'), findsOneWidget);
  });

  testWidgets('fechar o calendário sem escolher não muda nada', (tester) async {
    await seedSession();
    await pumpEdit(tester);

    await tester.tapAt(tester.getCenter(find.text('12 set 2026')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('12 set 2026'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets(
      'UF: fica em maiúsculas, com duas letras, e a sigla que não existe '
      'impede o salvar', (tester) async {
    await seedSession();
    patchAnswers();
    await pumpEdit(tester);

    await tester.enterText(field('campo-uf'), 'xx9');
    await tester.pump();

    expect(find.text('XX'), findsOneWidget);
    expect(find.text('UF inválida.'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);

    await tester.enterText(field('campo-uf'), 'sp');
    await tester.pump();

    expect(find.text('UF inválida.'), findsNothing);
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect(sentBody(), {'state': 'SP'});
  });

  testWidgets('cidade apagada mostra o motivo e impede o salvar', (tester) async {
    await seedSession();
    await pumpEdit(tester);

    await tester.enterText(field('campo-cidade'), '');
    await tester.pump();

    expect(find.text('Informe a cidade.'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('apagar as observações limpa o campo no servidor', (tester) async {
    await seedSession();
    patchAnswers();
    await pumpEdit(tester);

    await tester.enterText(field('campo-observacoes'), '');
    await tester.pump();
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect(sentBody(), {'notes': ''});
  });

  testWidgets('falha ao salvar: o motivo aparece na tela e o que foi digitado fica',
      (tester) async {
    await seedSession();
    when(() => api.patch<Map<String, dynamic>>(path, data: any(named: 'data')))
        .thenThrow(const ApiException(
      message: 'Sem conexão com o servidor. Verifique a internet e tente de novo.',
      isNetworkError: true,
    ));
    await pumpEdit(tester);

    await tester.enterText(field('campo-cidade'), 'Betim');
    await tester.pump();
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionEditScreen), findsOneWidget);
    expect(
      find.text('Sem conexão com o servidor. Verifique a internet e tente de novo.'),
      findsOneWidget,
    );
    expect(find.text('Betim'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull, reason: 'dá para tentar de novo');
  });

  testWidgets(
      'falha ao salvar num celular de 360x640: o motivo fica à vista, no '
      'rodapé acima do botão, sem precisar rolar', (tester) async {
    await seedSession();
    const reason =
        'Sem conexão com o servidor. Verifique a internet e tente de novo.';
    when(() => api.patch<Map<String, dynamic>>(path, data: any(named: 'data')))
        .thenThrow(const ApiException(message: reason, isNetworkError: true));
    await pumpEdit(tester, screen: const Size(360, 640));

    await tester.enterText(field('campo-cidade'), 'Betim');
    await tester.pump();
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

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
      'com o teclado aberto num celular de 360x640 e a fonte ampliada, o '
      'rodapé não estoura e esconde o aviso de falha; fechado o teclado, o '
      'aviso volta', (tester) async {
    await seedSession();
    const reason =
        'Sem conexão com o servidor. Verifique a internet e tente de novo.';
    when(() => api.patch<Map<String, dynamic>>(path, data: any(named: 'data')))
        .thenThrow(const ApiException(message: reason, isNetworkError: true));
    await pumpEdit(tester, screen: const Size(360, 640), textScale: 1.6);

    await tester.enterText(field('campo-cidade'), 'Betim');
    await tester.pump();
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();
    expect(find.text(reason), findsOneWidget, reason: 'o teclado está fechado');

    // O admin toca num campo para corrigir: o teclado sobe com o aviso ainda
    // na tela. Sem tirá-lo, o rodapé não cabe no que sobra (RenderFlex).
    await setKeyboard(tester, 280);

    expect(tester.takeException(), isNull);
    expect(find.text(reason), findsNothing);
    expect(saveButton(tester).onPressed, isNotNull, reason: 'dá para tentar de novo');

    await setKeyboard(tester, 0);

    expect(tester.takeException(), isNull);
    expect(find.text(reason), findsOneWidget);
  });

  testWidgets(
      'salvar recusado pelo servidor (403): o motivo aparece, a sessão é '
      'baixada de novo e os campos e botões travam, com o que foi digitado',
      (tester) async {
    await seedSession();
    when(() => api.patch<Map<String, dynamic>>(path, data: any(named: 'data')))
        .thenThrow(const ApiException(
      message: 'Não é possível editar um treinamento concluído ou cancelado',
      statusCode: 403,
    ));
    // O que o servidor devolve agora: a mesma sessão, já concluída.
    when(() => api.get<Map<String, dynamic>>(path)).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: {
          'id': 'sess-1',
          'city': 'Itabira',
          'state': 'MG',
          'date': '2026-09-12T00:00:00.000Z',
          'status': 'CONCLUIDO',
          'company': {'id': 'emp-1', 'name': 'Bracell'},
          'course': {
            'id': 'cur-1',
            'name': 'Direção Defensiva — Veículo Pesado',
          },
          'participants': <Map<String, dynamic>>[],
        },
      ),
    );
    await pumpEdit(tester);

    await tester.enterText(field('campo-cidade'), 'Betim');
    await tester.pump();
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionEditScreen), findsOneWidget);
    expect(
      find.text('Não é possível editar um treinamento concluído ou cancelado'),
      findsOneWidget,
    );
    expect(
      find.text('Sessão concluída: os dados não podem mais ser alterados.'),
      findsOneWidget,
    );
    final inputs = tester.widgetList<AppTextField>(find.byType(AppTextField)).toList();
    expect(inputs, hasLength(4), reason: 'data, cidade, UF e observações');
    for (final input in inputs) {
      expect(input.enabled, isFalse, reason: input.label);
    }
    expect(saveButton(tester).onPressed, isNull);
    expect(cancelButton(tester).onPressed, isNull);
    expect(find.text('Betim'), findsOneWidget, reason: 'o que o admin digitou fica');
    verify(() => api.get<Map<String, dynamic>>(path)).called(1);
  });

  testWidgets(
      'rodapé como o do canvas "3b": 8 entre o salvar e o "Descartar", 16 de '
      'recuo embaixo', (tester) async {
    await seedSession();
    await pumpEdit(tester);

    final save = tester.getRect(find.byType(AppCtaButton));
    final discard =
        tester.getRect(find.widgetWithText(AppTextButton, 'Descartar'));
    // O rodapé encosta na base da área segura — que, sem recortes do sistema
    // no teste, é a base da tela.
    final footerBottom = tester.view.physicalSize.height;

    expect(discard.top - save.bottom, 8);
    expect(footerBottom - discard.bottom, 16);
  });

  group('sair da tela', () {
    testWidgets('sem mudança, o voltar sai direto', (tester) async {
      await seedSession();
      await pumpEdit(tester);

      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();

      expect(find.text('origem'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets(
        'com mudança, o voltar pergunta: "Continuar editando" fica, '
        '"Descartar" sai sem salvar', (tester) async {
      await seedSession();
      await pumpEdit(tester);
      await tester.enterText(field('campo-cidade'), 'Betim');
      await tester.pump();

      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      expect(find.text('Descartar as alterações?'), findsOneWidget);

      await tester.tap(find.text('Continuar editando'));
      await tester.pumpAndSettle();
      expect(find.byType(SessionEditScreen), findsOneWidget);
      expect(find.text('Betim'), findsOneWidget);

      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Descartar'));
      await tester.pumpAndSettle();

      expect(find.text('origem'), findsOneWidget);
      verifyNever(
        () => api.patch<Map<String, dynamic>>(any(), data: any(named: 'data')),
      );
    });

    testWidgets('o voltar do Android, com mudança, também pergunta',
        (tester) async {
      await seedSession();
      await pumpEdit(tester);
      await tester.enterText(field('campo-cidade'), 'Betim');
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Descartar as alterações?'), findsOneWidget);
      expect(find.byType(SessionEditScreen), findsOneWidget);
    });

    testWidgets('"Descartar" do rodapé sai sem perguntar e sem salvar',
        (tester) async {
      await seedSession();
      await pumpEdit(tester);
      await tester.enterText(field('campo-cidade'), 'Betim');
      await tester.pump();

      await tester.tap(find.widgetWithText(AppTextButton, 'Descartar'));
      await tester.pumpAndSettle();

      expect(find.text('origem'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(
        () => api.patch<Map<String, dynamic>>(any(), data: any(named: 'data')),
      );
    });

    testWidgets(
        'com o salvar no ar, o voltar do Android é ignorado: sem diálogo, a '
        'tela fica e, com a resposta, fecha devolvendo `true`', (tester) async {
      await seedSession();
      final reply = Completer<Response<Map<String, dynamic>>>();
      when(() => api.patch<Map<String, dynamic>>(path, data: any(named: 'data')))
          .thenAnswer((_) => reply.future);
      await pumpEdit(tester);
      await tester.enterText(field('campo-cidade'), 'Betim');
      await tester.pump();

      await tester.tap(find.text('Salvar alterações'));
      await tester.pump();
      expect(saveButton(tester).isLoading, isTrue, reason: 'o salvar está no ar');

      await tester.binding.handlePopRoute();
      await pumpTransitions(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SessionEditScreen), findsOneWidget);

      reply.complete(ok(path));
      await tester.pumpAndSettle();

      expect(find.byType(SessionEditScreen), findsNothing);
      expect(find.text('origem'), findsOneWidget);
      expect(find.text('Dados do treinamento atualizados.'), findsOneWidget);
      expect(await editResult, isTrue);
    });

    testWidgets(
        'com o cancelar no ar, o voltar da barra é ignorado: a tela fica e, '
        'com a resposta, vai para a lista de sessões', (tester) async {
      await seedSession();
      final reply = Completer<Response<Map<String, dynamic>>>();
      when(() => api.patch<Map<String, dynamic>>(cancelPath))
          .thenAnswer((_) => reply.future);
      await pumpEdit(tester);

      await tester.tap(find.text('Cancelar sessão'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cancelar sessão'));
      // O diálogo fecha e o pedido sai; só depois da animação de saída a barra
      // volta a receber o toque.
      await pumpTransitions(tester);
      expect(
        cancelButton(tester).isLoading,
        isTrue,
        reason: 'o cancelar está no ar',
      );

      await tester.tap(find.byTooltip('Voltar'));
      await pumpTransitions(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SessionEditScreen), findsOneWidget);

      reply.complete(ok(cancelPath));
      await tester.pumpAndSettle();

      expect(find.text('lista de sessões'), findsOneWidget);
      expect(find.text('Sessão cancelada.'), findsOneWidget);
    });
  });

  testWidgets(
      'sem conexão: salvar e cancelar ficam desabilitados, com o aviso, e os '
      'campos continuam editáveis', (tester) async {
    await seedSession();
    await goOffline();
    await pumpEdit(tester);

    await tester.enterText(field('campo-cidade'), 'Betim');
    await tester.pump();

    expect(
      find.text('Sem conexão — salvar e cancelar precisam de internet.'),
      findsOneWidget,
    );
    expect(find.text('Disponível quando houver conexão'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
    expect(cancelButton(tester).onPressed, isNull);
    expect(find.text('Betim'), findsOneWidget);
  });

  testWidgets(
      'sem conexão, a dica "Disponível quando houver conexão" some com o '
      'teclado aberto e volta com ele fechado; os botões ficam como estão',
      (tester) async {
    await seedSession();
    await goOffline();
    await pumpEdit(tester, screen: const Size(360, 640));
    await tester.enterText(field('campo-cidade'), 'Betim');
    await tester.pump();
    expect(find.text('Disponível quando houver conexão'), findsOneWidget);

    await setKeyboard(tester, 280);

    expect(tester.takeException(), isNull);
    expect(find.text('Disponível quando houver conexão'), findsNothing);
    // O motivo segue escrito na faixa do topo, e os botões seguem apagados.
    expect(
      find.text('Sem conexão — salvar e cancelar precisam de internet.'),
      findsOneWidget,
    );
    expect(saveButton(tester).onPressed, isNull);
    expect(find.widgetWithText(AppTextButton, 'Descartar'), findsOneWidget);

    await setKeyboard(tester, 0);

    expect(find.text('Disponível quando houver conexão'), findsOneWidget);
  });

  testWidgets(
      'a conexão volta com a tela aberta: o salvar reabilita, e o que foi '
      'digitado continua', (tester) async {
    await seedSession();
    final changes = StreamController<List<ConnectivityResult>>();
    addTearDown(changes.close);
    final plugin = _MockConnectivity();
    when(plugin.checkConnectivity).thenAnswer((_) async => [ConnectivityResult.none]);
    when(() => plugin.onConnectivityChanged).thenAnswer((_) => changes.stream);
    connectivity.dispose();
    connectivity = ConnectivityService(connectivity: plugin);
    await connectivity.initialize();
    await pumpEdit(tester);
    await tester.enterText(field('campo-cidade'), 'Betim');
    await tester.pump();
    expect(saveButton(tester).onPressed, isNull);

    changes.add([ConnectivityResult.mobile]);
    await tester.pumpAndSettle();

    expect(find.textContaining('Sem conexão'), findsNothing);
    expect(find.text('Betim'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull);
    expect(cancelButton(tester).onPressed, isNotNull);
  });

  testWidgets(
      'celular estreito com a fonte do sistema ampliada: a tela não estoura, '
      'nem com os dois erros à vista', (tester) async {
    await seedSession();
    await pumpEdit(tester, screen: const Size(360, 1600), textScale: 1.6);

    await tester.enterText(field('campo-cidade'), '');
    await tester.enterText(field('campo-uf'), 'XX');
    await tester.pump();

    expect(find.text('Informe a cidade.'), findsOneWidget);
    expect(find.text('UF inválida.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('cancelar sessão', () {
    testWidgets(
        'o diálogo diz a consequência e quem está em avaliação; confirmar '
        'cancela, avisa e leva à lista de sessões', (tester) async {
      await seedSession();
      await seedParticipant('tp-1', 'EM_AVALIACAO');
      await seedParticipant('tp-2', 'EM_AVALIACAO');
      await seedParticipant('tp-3', 'PENDENTE');
      when(() => api.patch<Map<String, dynamic>>(cancelPath))
          .thenAnswer((_) async => ok(cancelPath));
      await pumpEdit(tester);

      await tester.tap(find.text('Cancelar sessão'));
      await tester.pumpAndSettle();

      expect(find.text('Cancelar a sessão?'), findsOneWidget);
      expect(
        find.text(
          'Ninguém mais poderá ser avaliado nesta sessão, e ela sai da lista '
          'de sessões do app. Não dá para desfazer. Há 2 participantes em '
          'avaliação agora.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Cancelar sessão'));
      await tester.pumpAndSettle();

      verify(() => api.patch<Map<String, dynamic>>(cancelPath)).called(1);
      expect(find.text('lista de sessões'), findsOneWidget);
      expect(find.text('Sessão cancelada.'), findsOneWidget);
      final row = await db.select(db.sessions).getSingle();
      expect(row.status, 'CANCELADO');
    });

    testWidgets('com um só em avaliação, o aviso fica no singular; sem ninguém, some',
        (tester) async {
      await seedSession();
      await seedParticipant('tp-1', 'EM_AVALIACAO');
      await pumpEdit(tester);

      await tester.tap(find.text('Cancelar sessão'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Há 1 participante em avaliação agora.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();
      await (db.update(db.participants)..where((t) => t.id.equals('tp-1')))
          .write(const ParticipantsCompanion(status: Value('APROVADO')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar sessão'));
      await tester.pumpAndSettle();

      expect(find.textContaining('em avaliação agora'), findsNothing);
      expect(find.textContaining('Não dá para desfazer.'), findsOneWidget);
    });

    testWidgets('"Voltar" fecha o diálogo sem cancelar', (tester) async {
      await seedSession();
      await pumpEdit(tester);

      await tester.tap(find.text('Cancelar sessão'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();

      expect(find.byType(SessionEditScreen), findsOneWidget);
      verifyNever(() => api.patch<Map<String, dynamic>>(cancelPath));
    });

    testWidgets('recusado pelo servidor: o motivo aparece, e a tela fica',
        (tester) async {
      await seedSession();
      when(() => api.patch<Map<String, dynamic>>(cancelPath)).thenThrow(
        const ApiException(
          message: 'Não é possível cancelar um treinamento já concluído',
          statusCode: 403,
        ),
      );
      when(() => api.get<Map<String, dynamic>>(path)).thenThrow(
        const ApiException(message: 'Sem conexão', isNetworkError: true),
      );
      await pumpEdit(tester);

      await tester.tap(find.text('Cancelar sessão'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cancelar sessão'));
      await tester.pumpAndSettle();

      expect(find.byType(SessionEditScreen), findsOneWidget);
      expect(
        find.text('Não é possível cancelar um treinamento já concluído'),
        findsOneWidget,
      );
      expect(find.text('lista de sessões'), findsNothing);
    });
  });

  group('campos travados, com o motivo escrito', () {
    testWidgets('consultor comum', (tester) async {
      when(() => auth.currentUser).thenReturn(consultora);
      await seedSession();
      await pumpEdit(tester);

      expect(
        find.text('Só administradores podem alterar os dados do treinamento.'),
        findsOneWidget,
      );
      expect(find.text('Itabira'), findsOneWidget, reason: 'os campos não somem');
      for (final input in tester.widgetList<AppTextField>(find.byType(AppTextField))) {
        expect(input.enabled, isFalse, reason: input.label);
      }
      expect(saveButton(tester).onPressed, isNull);
      expect(cancelButton(tester).onPressed, isNull);
    });

    testWidgets('sessão concluída', (tester) async {
      await seedSession(status: 'CONCLUIDO');
      await pumpEdit(tester);

      expect(
        find.text('Sessão concluída: os dados não podem mais ser alterados.'),
        findsOneWidget,
      );
      expect(saveButton(tester).onPressed, isNull);
      expect(cancelButton(tester).onPressed, isNull);
    });
  });

  testWidgets('sessão que não está no aparelho: só o aviso', (tester) async {
    await pumpEdit(tester);

    expect(
      find.text('Esta sessão não está mais disponível neste aparelho.'),
      findsOneWidget,
    );
    expect(find.byType(AppCtaButton), findsNothing);
  });
}
