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
          path: AppRoutes.home,
          builder: (context, state) =>
              const Scaffold(body: Text('lista de sessões')),
        ),
        GoRoute(
          path: '/sessions/:sessionId/edit',
          builder: (context, state) => SessionEditScreen(
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
    router.push(AppRoutes.sessionEdit('sess-1'));
    await tester.pumpAndSettle();
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
  });

  testWidgets(
      'sem conexão: salvar e cancelar ficam desabilitados, com o aviso, e os '
      'campos continuam editáveis', (tester) async {
    await seedSession();
    await goOffline();
    await pumpEdit(tester);

    await tester.enterText(field('campo-cidade'), 'Betim');
    await tester.pump();

    expect(find.text('Sem conexão — salvar precisa de internet.'), findsOneWidget);
    expect(find.text('Disponível quando houver conexão'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
    expect(cancelButton(tester).onPressed, isNull);
    expect(find.text('Betim'), findsOneWidget);
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

    expect(find.text('Sem conexão — salvar precisa de internet.'), findsNothing);
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
