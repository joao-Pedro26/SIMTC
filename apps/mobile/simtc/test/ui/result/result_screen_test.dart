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
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/router.dart';
import 'package:simtc/ui/checklist/checklist_screen.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/result/result_screen.dart';
import 'package:simtc/ui/summary/summary_screen.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late _MockApiClient api;
  late _MockAuthRepository auth;
  late AppDatabase db;
  late AssessmentRepository assessmentRepository;
  late ParticipantRepository participantRepository;
  late AssessmentCatalogRepository catalogRepository;
  late SessionRepository sessionRepository;
  late ConnectivityService connectivity;

  const resultPath = '/practical-assessments/by-participant/tp-1';
  const comment = 'Ajuste feito somente após solicitação';
  final today = DateTime.now();
  DateTime at(int hour, int minute) =>
      DateTime(today.year, today.month, today.day, hour, minute);

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
    when(() => auth.isAuthenticated).thenReturn(true);
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
            cachedAt: DateTime(2026, 9, 30, 7),
          ),
        );
    // CV com os itens 1 e 4, RR com o item 3.
    for (final (id, code, name, order) in [
      ('cat-cv', 'CV', 'Controle do Veículo', 1),
      ('cat-rr', 'RR', 'Respeito às Regras', 2),
    ]) {
      await db.into(db.assessmentCategories).insert(
            AssessmentCategoriesCompanion.insert(id: id, code: code, name: name, order: order),
          );
    }
    for (final (id, category, order) in [
      ('inf-1', 'cat-cv', 1),
      ('inf-4', 'cat-cv', 4),
      ('inf-3', 'cat-rr', 3),
    ]) {
      await db.into(db.infractions).insert(
            InfractionsCompanion.insert(
              id: id,
              categoryId: category,
              description: 'Infração do item $order',
              order: order,
            ),
          );
      for (final (type, deduction) in [('B', 1), ('PM', 3), ('M', 5)]) {
        await db.into(db.infractionNotes).insert(
              InfractionNotesCompanion.insert(
                id: '$id-$type',
                infractionId: id,
                noteType: type,
                deduction: deduction,
                comment: Value(type == 'PM' ? comment : null),
              ),
            );
      }
    }
  });

  tearDown(() async {
    await db.close();
    connectivity.dispose();
  });

  Future<void> seedParticipant({required String status, double? score}) {
    return db.into(db.participants).insert(
          ParticipantsCompanion.insert(
            id: 'tp-1',
            sessionId: 'sess-1',
            name: 'Ana Paula Ribeiro',
            cpf: '042.118.***-**',
            participationType: 'TEORICA_E_PRATICA',
            status: status,
            score: Value(score),
            cachedAt: DateTime(2026, 9, 30, 7),
          ),
        );
  }

  /// Confirmada neste aparelho, das 08:12 às 08:31 de hoje, com [marks]
  /// (infração → nota).
  Future<void> confirmedHere(Map<String, String> marks, {double score = 85}) async {
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
    await (db.update(db.localAssessments)..where((t) => t.id.equals(draft.id)))
        .write(LocalAssessmentsCompanion(startTime: Value(at(8, 12))));
    await assessmentRepository.confirm(
      draft.id,
      participantName: 'Ana Paula Ribeiro',
      score: score,
      endTime: at(8, 31),
    );
  }

  void serverAnswers(Object? body) {
    when(() => api.get<Object?>(resultPath)).thenAnswer(
      (_) async => Response<Object?>(
        requestOptions: RequestOptions(path: resultPath),
        statusCode: 200,
        data: body,
      ),
    );
  }

  Map<String, dynamic> serverJson() => {
        'id': 'assess-1',
        'startTime': '2026-09-30T11:12:00.000Z',
        'endTime': '2026-09-30T11:31:00.000Z',
        'score': 62.5,
        'items': [
          {
            'infractionNoteId': 'inf-1-M',
            'infractionNote': {
              'id': 'inf-1-M',
              'noteType': 'M',
              'comment': 'Não realizou nenhum ajuste',
              'deduction': 5,
              'infraction': {
                'id': 'inf-1',
                'description': 'Não ajustou o banco, cinto ou espelhos',
                'order': 1,
                'category': {'id': 'cat-cv', 'code': 'CV', 'name': 'Controle do Veículo', 'order': 1},
              },
            },
          },
        ],
      };

  Future<void> goOffline() async {
    final plugin = _MockConnectivity();
    when(plugin.checkConnectivity).thenAnswer((_) async => [ConnectivityResult.none]);
    when(() => plugin.onConnectivityChanged).thenAnswer((_) => const Stream.empty());
    connectivity.dispose();
    connectivity = ConnectivityService(connectivity: plugin);
    await connectivity.initialize();
  }

  Widget withProviders(Widget child) {
    return MultiProvider(
      providers: [
        Provider<AssessmentRepository>.value(value: assessmentRepository),
        Provider<ParticipantRepository>.value(value: participantRepository),
        Provider<AssessmentCatalogRepository>.value(value: catalogRepository),
        Provider<SessionRepository>.value(value: sessionRepository),
        ChangeNotifierProvider<AuthRepository>.value(value: auth),
        ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
      ],
      child: child,
    );
  }

  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// O Resultado empilhado sobre uma origem, pelas rotas reais do Resultado,
  /// do checklist e da conferência.
  Future<void> pumpResult(WidgetTester tester, {bool justConfirmed = false}) async {
    tallScreen(tester);
    final router = GoRouter(
      initialLocation: '/origem',
      routes: [
        GoRoute(
          path: '/origem',
          builder: (context, state) => const Scaffold(body: Text('origem')),
        ),
        GoRoute(
          path: '/sessions/:sessionId/participants/:participantId/result',
          builder: (context, state) => ResultScreen(
            sessionId: state.pathParameters['sessionId']!,
            participantId: state.pathParameters['participantId']!,
            justConfirmed: state.uri.queryParameters['confirmada'] == '1',
          ),
        ),
        GoRoute(
          path: AppRoutes.participantChecklist('sess-1', 'tp-1'),
          builder: (context, state) => ChecklistScreen(
            sessionId: 'sess-1',
            participantId: 'tp-1',
            fromResult: state.uri.queryParameters['origem'] == 'resultado',
          ),
        ),
        GoRoute(
          path: AppRoutes.participantSummary('sess-1', 'tp-1'),
          builder: (context, state) => const SummaryScreen(participantId: 'tp-1'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(withProviders(MaterialApp.router(routerConfig: router)));
    router.push(AppRoutes.participantResult('sess-1', 'tp-1', justConfirmed: justConfirmed));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'logo depois do "Confirmar": a nota, a linha de detalhe, o aviso de '
      'fila, as categorias, as infrações e "Próximo participante"',
      (tester) async {
    await seedParticipant(status: 'EM_AVALIACAO');
    await confirmedHere({'inf-1': 'inf-1-PM'});

    await pumpResult(tester, justConfirmed: true);

    expect(find.text('Avaliação concluída'), findsOneWidget);
    expect(find.byTooltip('Fechar'), findsOneWidget);
    expect(find.text('Pontuação final'), findsOneWidget);
    expect(find.text('85,0%'), findsOneWidget);
    expect(find.text('Aprovado'), findsOneWidget);
    expect(
      find.text('Ana Paula Ribeiro · 042.118.***-** · Início 08:12 · Fim 08:31'),
      findsOneWidget,
    );
    expect(find.text('Na fila de envio — sai sozinha quando houver conexão.'),
        findsOneWidget);
    expect(find.text('Desempenho por categoria'), findsOneWidget);
    expect(find.text('70,0%'), findsOneWidget, reason: 'o selo de CV');
    expect(find.text('100,0%'), findsOneWidget, reason: 'o selo de RR');
    expect(find.text('Infrações registradas'), findsOneWidget);
    expect(find.text('Infração do item 1'), findsOneWidget);
    expect(find.text(comment), findsOneWidget);
    expect(find.text('PM'), findsOneWidget);
    expect(find.textContaining('O número de cada linha é o item'), findsNothing);
    expect(find.text('Próximo participante'), findsOneWidget);
    expect(find.text('Reavaliar'), findsNothing);
    expect(find.textContaining('pts'), findsNothing, reason: 'o app não tem pontos');
  });

  testWidgets(
      'os grupos de "Infrações registradas" abrem e fecham; categoria sem '
      'infração não abre', (tester) async {
    await seedParticipant(status: 'EM_AVALIACAO');
    await confirmedHere({'inf-1': 'inf-1-PM'});
    await pumpResult(tester, justConfirmed: true);

    expect(find.text('Infração do item 1'), findsOneWidget, reason: 'CV abre sozinho');

    await tester.tap(find.byKey(const ValueKey('result-group-cat-cv')));
    await tester.pumpAndSettle();
    expect(find.text('Infração do item 1'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('result-group-cat-cv')));
    await tester.pumpAndSettle();
    expect(find.text('Infração do item 1'), findsOneWidget);

    final rr = find.byKey(const ValueKey('result-group-cat-rr'));
    expect(find.descendant(of: rr, matching: find.text('sem infração')), findsOneWidget);
    expect(tester.widget<InkWell>(rr).onTap, isNull);
  });

  testWidgets(
      'a linha da infração traz o número do item na ficha, não a posição na '
      'lista', (tester) async {
    await seedParticipant(status: 'EM_AVALIACAO');
    // A única infração marcada é o item 4 de CV — a primeira da lista.
    await confirmedHere({'inf-4': 'inf-4-PM'});

    await pumpResult(tester, justConfirmed: true);

    // O número é um texto próprio, ao lado da descrição: a descrição semeada
    // ("Infração do item 4") também traz o número, e não é ela que conta.
    final line = find
        .ancestor(of: find.text('Infração do item 4'), matching: find.byType(Row))
        .first;
    expect(find.descendant(of: line, matching: find.text('4')), findsOneWidget);
    expect(find.text('1'), findsNothing, reason: 'não é a posição na lista');
  });

  testWidgets('sem nenhuma infração: "Nenhuma infração registrada."', (tester) async {
    await seedParticipant(status: 'EM_AVALIACAO');
    await confirmedHere({}, score: 100);

    await pumpResult(tester, justConfirmed: true);

    expect(find.text('Nenhuma infração registrada.'), findsOneWidget);
    expect(find.textContaining('O número de cada linha é o item'), findsNothing);
  });

  testWidgets(
      'avaliação do servidor: a nota dele e as infrações da resposta, sem aviso '
      'de envio', (tester) async {
    await seedParticipant(status: 'NAO_RECOMENDADO', score: 62.5);
    serverAnswers(serverJson());

    await pumpResult(tester);

    expect(find.text('62,5%'), findsOneWidget);
    expect(find.text('Não recomendado'), findsOneWidget);
    expect(find.text('Não ajustou o banco, cinto ou espelhos'), findsOneWidget);
    expect(find.text('Não realizou nenhum ajuste'), findsOneWidget);
    expect(find.textContaining('Na fila de envio'), findsNothing);
    expect(find.text('Reavaliar'), findsOneWidget);
  });

  testWidgets(
      'sem rede e sem avaliação no aparelho: só a nota e o status, com o aviso',
      (tester) async {
    await seedParticipant(status: 'APROVADO', score: 90);
    when(() => api.get<Object?>(resultPath)).thenThrow(
      const ApiException(message: 'Sem conexão', isNetworkError: true),
    );

    await pumpResult(tester);

    expect(find.text('90,0%'), findsOneWidget);
    expect(find.text('Aprovado'), findsOneWidget);
    expect(find.text('Sem conexão: as infrações aparecem quando houver internet.'),
        findsOneWidget);
    expect(find.text('Desempenho por categoria'), findsNothing);
    expect(find.text('Infrações registradas'), findsNothing);
    expect(find.text('Tentar novamente'), findsNothing);
  });

  testWidgets('o servidor falhou: "Tentar novamente" busca de novo', (tester) async {
    await seedParticipant(status: 'NAO_RECOMENDADO', score: 62.5);
    when(() => api.get<Object?>(resultPath)).thenThrow(
      const ApiException(message: 'Internal server error', statusCode: 500),
    );
    await pumpResult(tester);
    expect(find.text('Não foi possível carregar as infrações.'), findsOneWidget);

    serverAnswers(serverJson());
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar as infrações.'), findsNothing);
    expect(find.text('Não ajustou o banco, cinto ou espelhos'), findsOneWidget);
  });

  testWidgets(
      '"Reavaliar" abre o checklist em "não iniciada" por cima do Resultado: '
      'voltar sem iniciar leva de volta a ele, sem reserva', (tester) async {
    await seedParticipant(status: 'NAO_RECOMENDADO', score: 62.5);
    serverAnswers(serverJson());
    await pumpResult(tester);

    await tester.tap(find.text('Reavaliar'));
    await tester.pumpAndSettle();

    expect(find.byType(ChecklistScreen), findsOneWidget);
    expect(find.text('não iniciada'), findsOneWidget);
    expect(find.text('Iniciar avaliação'), findsOneWidget);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    expect(find.byType(ChecklistScreen), findsNothing);
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text('Reavaliar'), findsOneWidget,
        reason: 'o participante continua em "Não recomendado"');
    verifyNever(() => api.post<Map<String, dynamic>>(any(), data: any(named: 'data')));
    final row = await db.select(db.participants).getSingle();
    expect(row.status, 'NAO_RECOMENDADO');
    expect(row.assignedConsultantId, isNull);

    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();
    expect(find.text('origem'), findsOneWidget);
  });

  testWidgets(
      'depois do "Reavaliar", é o "Iniciar avaliação" que reserva o '
      'participante para quem está logado', (tester) async {
    await seedParticipant(status: 'NAO_RECOMENDADO', score: 62.5);
    serverAnswers(serverJson());
    when(() => api.post<Map<String, dynamic>>('/practical-assessments/assign',
        data: any(named: 'data'))).thenAnswer((_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/practical-assessments/assign'),
          statusCode: 201,
          data: {'assigned': 1},
        ));
    await pumpResult(tester);

    await tester.tap(find.text('Reavaliar'));
    await tester.pumpAndSettle();
    verifyNever(() => api.post<Map<String, dynamic>>(any(), data: any(named: 'data')));

    await tester.tap(find.text('Iniciar avaliação'));
    await tester.pumpAndSettle();

    verify(() => api.post<Map<String, dynamic>>('/practical-assessments/assign',
        data: any(named: 'data'))).called(1);
    final row = await db.select(db.participants).getSingle();
    expect(row.status, 'EM_AVALIACAO');
    expect(row.assignedConsultantId, 'c-eu');
    expect(row.assignedConsultantName, 'Carla Souza');
    expect(find.text('Finalizar avaliação'), findsOneWidget);
  });

  testWidgets(
      'depois do "Iniciar avaliação", voltar também leva ao Resultado, já sem '
      'o "Reavaliar"', (tester) async {
    await seedParticipant(status: 'NAO_RECOMENDADO', score: 62.5);
    serverAnswers(serverJson());
    when(() => api.post<Map<String, dynamic>>('/practical-assessments/assign',
        data: any(named: 'data'))).thenAnswer((_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/practical-assessments/assign'),
          statusCode: 201,
          data: {'assigned': 1},
        ));
    await pumpResult(tester);
    await tester.tap(find.text('Reavaliar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar avaliação'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    expect(find.byType(ChecklistScreen), findsNothing);
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text('Reavaliar'), findsNothing,
        reason: 'a reavaliação já está em andamento com quem está logado');
  });

  testWidgets(
      'reavaliação até o "Confirmar": o Resultado novo fica no lugar do '
      'anterior, e o "Próximo participante" volta à tela de origem',
      (tester) async {
    await seedParticipant(status: 'NAO_RECOMENDADO', score: 62.5);
    serverAnswers(serverJson());
    when(() => api.post<Map<String, dynamic>>('/practical-assessments/assign',
        data: any(named: 'data'))).thenAnswer((_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/practical-assessments/assign'),
          statusCode: 201,
          data: {'assigned': 1},
        ));
    await pumpResult(tester);

    await tester.tap(find.text('Reavaliar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar avaliação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalizar avaliação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(find.byType(ChecklistScreen), findsNothing);
    final confirmed = tester.widget<ResultScreen>(find.byType(ResultScreen));
    expect(confirmed.justConfirmed, isTrue);
    expect(find.text('Próximo participante'), findsOneWidget);

    await tester.tap(find.text('Próximo participante'));
    await tester.pumpAndSettle();

    expect(find.byType(ResultScreen), findsNothing,
        reason: 'o Resultado da avaliação anterior não ficou embaixo');
    expect(find.text('origem'), findsOneWidget);
  });

  testWidgets(
      'se a reserva é recusada no "Iniciar avaliação", o checklist continua em '
      '"não iniciada" e mostra o motivo', (tester) async {
    await seedParticipant(status: 'NAO_RECOMENDADO', score: 62.5);
    serverAnswers(serverJson());
    when(() => api.post<Map<String, dynamic>>('/practical-assessments/assign',
        data: any(named: 'data'))).thenThrow(const ApiException(
      message: 'Um ou mais participantes já estão em avaliação com outro consultor',
      statusCode: 409,
    ));
    when(() => api.get<Map<String, dynamic>>(any()))
        .thenThrow(const ApiException(message: 'Sem conexão', isNetworkError: true));
    await pumpResult(tester);
    await tester.tap(find.text('Reavaliar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Iniciar avaliação'));
    await tester.pumpAndSettle();

    expect(
      find.text('Um ou mais participantes já estão em avaliação com outro consultor'),
      findsOneWidget,
    );
    expect(find.text('Iniciar avaliação'), findsOneWidget);
    expect(await db.select(db.localAssessments).get(), isEmpty);
  });

  testWidgets(
      '"Reavaliar" com outra avaliação em andamento: o checklist avisa que só '
      'dá uma por vez, e nada é reservado', (tester) async {
    await seedParticipant(status: 'NAO_RECOMENDADO', score: 62.5);
    await db.into(db.participants).insert(
          ParticipantsCompanion.insert(
            id: 'tp-2',
            sessionId: 'sess-1',
            name: 'Marina Lopes',
            cpf: '111.222.***-**',
            participationType: 'TEORICA_E_PRATICA',
            status: 'EM_AVALIACAO',
            cachedAt: DateTime(2026, 9, 30, 7),
          ),
        );
    await assessmentRepository.openDraft(
      trainingParticipantId: 'tp-2',
      sessionId: 'sess-1',
      ownerUserId: 'user-1',
    );
    serverAnswers(serverJson());
    await pumpResult(tester);

    await tester.tap(find.text('Reavaliar'));
    await tester.pumpAndSettle();

    expect(find.byType(ChecklistScreen), findsOneWidget);
    expect(
      find.text('Você já está avaliando Marina Lopes. Finalize ou descarte essa '
          'avaliação para iniciar outra.'),
      findsOneWidget,
    );
    verifyNever(() => api.post<Map<String, dynamic>>(any(), data: any(named: 'data')));
    final row = await (db.select(db.participants)..where((t) => t.id.equals('tp-1')))
        .getSingle();
    expect(row.status, 'NAO_RECOMENDADO', reason: 'sem iniciar, nada é reservado');
  });

  testWidgets(
      '"Reavaliar" quem foi avaliado neste aparelho, com a avaliação anterior já '
      'enviada: o checklist abre em "não iniciada" e o "Iniciar avaliação" '
      'começa um rascunho novo no lugar dela', (tester) async {
    await seedParticipant(status: 'NAO_RECOMENDADO', score: 62.5);
    // A avaliação anterior: feita aqui, confirmada e já aceita pelo servidor.
    await confirmedHere({'inf-1': 'inf-1-M'}, score: 62.5);
    final previous = await db.select(db.localAssessments).getSingle();
    await assessmentRepository.saveSendResults({previous.id: null}, at: at(8, 45));
    serverAnswers(serverJson());
    when(() => api.post<Map<String, dynamic>>('/practical-assessments/assign',
        data: any(named: 'data'))).thenAnswer((_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/practical-assessments/assign'),
          statusCode: 201,
          data: {'assigned': 1},
        ));
    await pumpResult(tester);

    await tester.tap(find.text('Reavaliar'));
    await tester.pumpAndSettle();

    expect(find.byType(ChecklistScreen), findsOneWidget);
    expect(find.text('não iniciada'), findsOneWidget);
    final untouched = await db.select(db.localAssessments).getSingle();
    expect(untouched.id, previous.id,
        reason: 'abrir o checklist ainda não mexe na avaliação enviada');

    await tester.tap(find.text('Iniciar avaliação'));
    await tester.pumpAndSettle();

    final draft = await db.select(db.localAssessments).getSingle();
    expect(draft.id, isNot(previous.id), reason: 'a enviada deu lugar ao rascunho novo');
    expect(draft.syncStatus, LocalSyncStatus.draft);
    expect(await db.select(db.localAssessmentItems).get(), isEmpty,
        reason: 'as marcações da avaliação anterior saíram com ela');
    expect(find.text('Finalizar avaliação'), findsOneWidget);
  });

  testWidgets('sessão concluída: "Não recomendado" sem "Reavaliar"', (tester) async {
    await (db.update(db.sessions)..where((t) => t.id.equals('sess-1')))
        .write(const SessionsCompanion(status: Value('CONCLUIDO')));
    await seedParticipant(status: 'NAO_RECOMENDADO', score: 62.5);
    serverAnswers(serverJson());

    await pumpResult(tester);

    expect(find.text('Não recomendado'), findsOneWidget);
    expect(find.text('Reavaliar'), findsNothing);
  });

  testWidgets('sem rede, "Reavaliar" fica desabilitado e diz por quê', (tester) async {
    await seedParticipant(status: 'NAO_RECOMENDADO', score: 62.5);
    when(() => api.get<Object?>(resultPath)).thenThrow(
      const ApiException(message: 'Sem conexão', isNetworkError: true),
    );
    await goOffline();

    await pumpResult(tester);

    final button = tester.widget<AppCtaButton>(find.widgetWithText(AppCtaButton, 'Reavaliar'));
    expect(button.onPressed, isNull);
    expect(find.text('Disponível quando houver conexão'), findsOneWidget);
  });

  testWidgets('o X e o "Próximo participante" voltam à tela de origem', (tester) async {
    await seedParticipant(status: 'EM_AVALIACAO');
    await confirmedHere({'inf-1': 'inf-1-PM'});

    await pumpResult(tester, justConfirmed: true);
    await tester.tap(find.text('Próximo participante'));
    await tester.pumpAndSettle();
    expect(find.text('origem'), findsOneWidget);

    await pumpResult(tester, justConfirmed: true);
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();
    expect(find.text('origem'), findsOneWidget);
  });
}
