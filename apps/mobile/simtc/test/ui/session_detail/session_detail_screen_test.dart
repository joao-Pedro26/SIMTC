import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/models/session_participant.dart';
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/data/repositories/assessment_catalog_repository.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/repositories/participant_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/router.dart';
import 'package:simtc/ui/add_participant/add_participant_screen.dart';
import 'package:simtc/ui/checklist/checklist_screen.dart';
import 'package:simtc/ui/core/date_labels.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/result/result_screen.dart';
import 'package:simtc/ui/session_detail/participant_row.dart';
import 'package:simtc/ui/session_detail/session_detail_screen.dart';
import 'package:simtc/ui/session_edit/session_edit_screen.dart';
import 'package:simtc/utils/result.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

class _MockParticipantRepository extends Mock implements ParticipantRepository {}

class _MockAssessmentRepository extends Mock implements AssessmentRepository {}

class _MockAssessmentCatalogRepository extends Mock
    implements AssessmentCatalogRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late _MockSessionRepository sessions;
  late _MockParticipantRepository participants;
  late _MockAssessmentRepository assessments;
  late _MockAssessmentCatalogRepository catalog;
  late _MockAuthRepository auth;
  late ConnectivityService connectivity;
  late StreamController<TrainingSession?> sessionStream;
  late StreamController<List<SessionParticipant>> participantsStream;
  late StreamController<List<LocalAssessment>> localStream;

  const consultora = AuthUser(
    id: 'u1',
    name: 'Carla Souza',
    email: 'carla@simtc.com.br',
    role: AppUserRole.consultant,
    consultantId: 'c-eu',
  );
  const admin = AuthUser(
    id: 'u-admin',
    name: 'Sebastião Souza',
    email: 'admin@simtc.com.br',
    role: AppUserRole.admin,
    consultantId: 'c-admin',
  );

  TrainingSession session({
    SessionStatus status = SessionStatus.emAndamento,
    String? responsible = 'c-resp',
    bool downloaded = true,
  }) {
    return TrainingSession(
      id: 'sess-1',
      companyName: 'Bracell Celulose',
      courseName: 'Direção Defensiva — Veículo Pesado',
      city: 'Itabira',
      state: 'MG',
      date: DateTime(2026, 9, 12),
      status: status,
      notes: 'Pátio 3 — apresentar-se na portaria B às 07h30.',
      totalParticipants: 0,
      assessableParticipants: 0,
      assessedParticipants: 0,
      responsibleConsultantId: responsible,
      participantsSyncedAt: downloaded ? DateTime(2026, 9, 23, 8) : null,
    );
  }

  SessionParticipant participant(
    String id,
    String name, {
    ParticipantStatus status = ParticipantStatus.pendente,
    ParticipationType type = ParticipationType.teoricaEPratica,
    String? assignedTo,
    String? assignedName,
    double? score,
  }) {
    return SessionParticipant(
      id: id,
      sessionId: 'sess-1',
      name: name,
      maskedCpf: '042.118.***-**',
      participationType: type,
      status: status,
      assignedConsultantId: assignedTo,
      assignedConsultantName: assignedName,
      score: score,
    );
  }

  setUp(() {
    sessions = _MockSessionRepository();
    participants = _MockParticipantRepository();
    assessments = _MockAssessmentRepository();
    catalog = _MockAssessmentCatalogRepository();
    auth = _MockAuthRepository();
    connectivity = ConnectivityService();
    sessionStream = StreamController<TrainingSession?>.broadcast();
    participantsStream = StreamController<List<SessionParticipant>>.broadcast();
    localStream = StreamController<List<LocalAssessment>>.broadcast();

    when(() => sessions.watchSession('sess-1'))
        .thenAnswer((_) => sessionStream.stream);
    when(() => participants.watchBySession('sess-1'))
        .thenAnswer((_) => participantsStream.stream);
    when(() => assessments.watchSessionAssessments('sess-1', 'u1'))
        .thenAnswer((_) => localStream.stream);
    // O ADMIN dos testes da Fase 6A é outro usuário, com a própria fila.
    when(() => assessments.watchSessionAssessments('sess-1', 'u-admin'))
        .thenAnswer((_) => localStream.stream);
    when(() => participants.syncSession('sess-1'))
        .thenAnswer((_) async => const Success(0));
    when(() => auth.currentUser).thenReturn(consultora);
    when(() => auth.isAuthenticated).thenReturn(true);
    when(() => catalog.loadCatalog()).thenAnswer((_) async => const []);
    // O checklist abre sem avaliação iniciada: só lê, nada é gravado.
    when(() => assessments.findCurrent(
          trainingParticipantId: any(named: 'trainingParticipantId'),
          ownerUserId: any(named: 'ownerUserId'),
        )).thenAnswer((_) async => null);
    when(() => assessments.findInProgressOther(
          ownerUserId: any(named: 'ownerUserId'),
          consultantId: any(named: 'consultantId'),
          exceptTrainingParticipantId: any(named: 'exceptTrainingParticipantId'),
        )).thenAnswer((_) async => null);
  });

  tearDown(() {
    sessionStream.close();
    participantsStream.close();
    localStream.close();
    connectivity.dispose();
  });

  Widget withProviders(Widget child) {
    return MultiProvider(
      providers: [
        Provider<SessionRepository>.value(value: sessions),
        Provider<ParticipantRepository>.value(value: participants),
        Provider<AssessmentRepository>.value(value: assessments),
        Provider<AssessmentCatalogRepository>.value(value: catalog),
        ChangeNotifierProvider<AuthRepository>.value(value: auth),
        ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
      ],
      child: child,
    );
  }

  /// Tela alta: a lista inteira fica montada, sem depender de rolagem.
  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> show(
    WidgetTester tester, {
    TrainingSession? withSession,
    List<SessionParticipant> withParticipants = const [],
    List<LocalAssessment> withLocal = const [],
  }) async {
    tallScreen(tester);
    await tester.pumpWidget(
      withProviders(
        const MaterialApp(home: SessionDetailScreen(sessionId: 'sess-1')),
      ),
    );
    sessionStream.add(withSession ?? session());
    participantsStream.add(withParticipants);
    localStream.add(withLocal);
    await tester.pump();
  }

  /// Avaliação deste aparelho, do jeito que o `AssessmentRepository` guarda.
  LocalAssessment local(
    String participantId,
    LocalSyncStatus status, {
    DateTime? startTime,
    double? score,
    DateTime? lastAttemptAt,
  }) {
    final at = startTime ?? DateTime.now();
    return LocalAssessment(
      id: 'local-$participantId',
      trainingParticipantId: participantId,
      sessionId: 'sess-1',
      date: at,
      startTime: at,
      syncStatus: status,
      attemptCount: 0,
      createdAt: at,
      updatedAt: at,
      ownerUserId: 'u1',
      score: score,
      lastAttemptAt: lastAttemptAt,
    );
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

  testWidgets('mostra skeleton antes da primeira leitura do cache',
      (tester) async {
    await tester.pumpWidget(
      withProviders(
        const MaterialApp(home: SessionDetailScreen(sessionId: 'sess-1')),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('session-detail-skeleton')), findsOneWidget);
  });

  testWidgets(
      'o cabeçalho mostra empresa, curso, local, data, status, observações e '
      'progresso', (tester) async {
    await show(tester, withParticipants: [
      participant('a', 'Ana Paula Ribeiro', status: ParticipantStatus.aprovado, score: 90),
      participant('b', 'Bruno Lima'),
    ]);

    expect(find.text('Bracell Celulose'), findsOneWidget);
    expect(find.text('Direção Defensiva — Veículo Pesado'), findsOneWidget);
    expect(find.text('Itabira/MG'), findsOneWidget);
    expect(find.text('12 set 2026'), findsOneWidget);
    expect(find.text('Em andamento'), findsOneWidget);
    expect(find.text('Pátio 3 — apresentar-se na portaria B às 07h30.'),
        findsOneWidget);
    expect(find.text('1 de 2 participantes avaliados'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('BC'), findsOneWidget, reason: 'iniciais no lugar do logo');
  });

  testWidgets('cada situação de participante tem o seu chip', (tester) async {
    await show(tester, withParticipants: [
      participant('1', 'Ana Paula Ribeiro',
          status: ParticipantStatus.emAvaliacao, assignedTo: 'c-eu'),
      participant('2', 'Carlos Eduardo Nunes'),
      participant('3', 'Marcos Vinícius Alves',
          status: ParticipantStatus.emAvaliacao,
          assignedTo: 'c-2',
          assignedName: 'Rafael Lima'),
      participant('4', 'Juliana Freitas Costa',
          status: ParticipantStatus.aprovado, score: 86.4),
      participant('5', 'Rodrigo Tavares',
          status: ParticipantStatus.necessitaReavaliacao, score: 62),
      participant('6', 'Simone Barbosa', type: ParticipationType.somenteTeorica),
    ]);

    expect(find.text('Avaliando · você'), findsOneWidget);
    expect(find.text('Pendente'), findsOneWidget);
    expect(find.text('Rafael Lima'), findsOneWidget);
    expect(find.text('Em avaliação com outro consultor.'), findsOneWidget);
    expect(find.text('Aprovado · 86%'), findsOneWidget);
    expect(find.text('Reavaliar · 62%'), findsOneWidget);
    expect(find.text('Somente teórica'), findsOneWidget);
    expect(find.text('042.118.***-**'), findsNWidgets(6));
  });

  testWidgets('"Atribuir a mim" chama o repositório com o consultor logado',
      (tester) async {
    when(() => participants.assign('2',
            consultantId: 'c-eu', consultantName: 'Carla Souza'))
        .thenAnswer((_) async => const Success<void>(null));

    await show(tester, withParticipants: [
      participant('2', 'Carlos Eduardo Nunes'),
    ]);

    await tester.tap(find.text('Atribuir a mim'));
    await tester.pump(); // resposta do assign
    await tester.pump(); // post-frame do SnackBar
    await tester.pump(const Duration(milliseconds: 750));

    verify(() => participants.assign('2',
        consultantId: 'c-eu', consultantName: 'Carla Souza')).called(1);
    expect(find.text('Participante atribuído a você.'), findsOneWidget);
  });

  testWidgets('offline, "Atribuir a mim" fica desabilitado e o aviso explica',
      (tester) async {
    await goOffline();

    await show(tester, withParticipants: [
      participant('2', 'Carlos Eduardo Nunes'),
    ]);

    final button = tester.widget<AppCtaButton>(find.byType(AppCtaButton));
    expect(button.onPressed, isNull);
    expect(
      find.text('Sem conexão: dá para ver a lista e abrir quem já é seu, '
          'mas atribuir precisa de internet.'),
      findsOneWidget,
    );
  });

  testWidgets('sessão planejada não oferece "Atribuir a mim"', (tester) async {
    await show(
      tester,
      withSession: session(status: SessionStatus.planejado, responsible: 'c-2'),
      withParticipants: [participant('2', 'Carlos Eduardo Nunes')],
    );

    expect(find.text('Atribuir a mim'), findsNothing);
    expect(find.text('Iniciar sessão'), findsNothing);
    expect(
      find.text('Aguardando o responsável iniciar a sessão para atribuir e '
          'avaliar participantes.'),
      findsOneWidget,
    );
  });

  testWidgets('o responsável inicia a sessão depois de confirmar',
      (tester) async {
    when(() => sessions.start('sess-1'))
        .thenAnswer((_) async => const Success<void>(null));

    await show(
      tester,
      withSession: session(status: SessionStatus.planejado, responsible: 'c-eu'),
    );

    await tester.tap(find.text('Iniciar sessão'));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar a sessão?'), findsOneWidget);

    await tester.tap(find.text('Iniciar'));
    await tester.pumpAndSettle();

    verify(() => sessions.start('sess-1')).called(1);
  });

  testWidgets('sessão nunca baixada avisa, em vez de dizer que está vazia',
      (tester) async {
    await show(tester, withSession: session(downloaded: false));

    expect(
      find.text('Os participantes desta sessão ainda não foram baixados. '
          'Puxe para atualizar quando houver conexão.'),
      findsOneWidget,
    );
    expect(find.text('Nenhum participante inscrito nesta sessão.'), findsNothing);
  });

  testWidgets('os chips filtram a lista', (tester) async {
    await show(tester, withParticipants: [
      participant('2', 'Carlos Eduardo Nunes'),
      participant('4', 'Juliana Freitas Costa',
          status: ParticipantStatus.aprovado, score: 86),
    ]);

    // Com os contadores, os quatro chips não cabem em 420px: traz
    // "Concluídos" para a faixa visível antes do toque.
    await tester.ensureVisible(find.widgetWithText(InkWell, 'Concluídos'));
    await tester.pump();
    await tester.tap(find.widgetWithText(InkWell, 'Concluídos'));
    await tester.pump();

    expect(find.text('Juliana Freitas Costa'), findsOneWidget);
    expect(find.text('Carlos Eduardo Nunes'), findsNothing);
  });

  group('avaliação deste aparelho na linha "comigo"', () {
    SessionParticipant minha() => participant('1', 'Ana Paula Ribeiro',
        status: ParticipantStatus.emAvaliacao, assignedTo: 'c-eu');

    ParticipantRow row(WidgetTester tester) =>
        tester.widget<ParticipantRow>(find.byKey(const ValueKey('participante-1')));

    testWidgets(
        'o rascunho mostra a hora em que a avaliação começou, no "Iniciar '
        'avaliação"',
        (tester) async {
      final start = DateTime.now().subtract(const Duration(minutes: 12, seconds: 41));

      await show(
        tester,
        withParticipants: [minha()],
        withLocal: [local('1', LocalSyncStatus.draft, startTime: start)],
      );

      expect(find.text('Avaliando · você'), findsOneWidget);
      expect(find.text(startedLabel(start, DateTime.now())), findsOneWidget);
      expect(row(tester).onTap, isNotNull, reason: 'o rascunho abre o checklist');
    });

    testWidgets(
        'na fila: chip "Na fila", o % e "aguardando envio" — e a linha não '
        'abre mais o checklist', (tester) async {
      await show(
        tester,
        withParticipants: [minha()],
        withLocal: [local('1', LocalSyncStatus.pendingSync, score: 86.6667)],
      );

      expect(find.text('Na fila'), findsOneWidget);
      expect(find.text('86,7% · aguardando envio'), findsOneWidget);
      expect(find.text('Avaliando · você'), findsNothing);
      expect(row(tester).onTap, isNotNull, reason: 'abre o Resultado');
    });

    testWidgets('com erro no envio: chip "Erro no envio" e quando falhou',
        (tester) async {
      final now = DateTime.now();

      await show(
        tester,
        withParticipants: [minha()],
        withLocal: [
          local(
            '1',
            LocalSyncStatus.error,
            score: 62,
            lastAttemptAt: DateTime(now.year, now.month, now.day, 7, 58),
          ),
        ],
      );

      expect(find.text('Erro no envio'), findsOneWidget);
      expect(find.text('62,0% · falhou às 07:58'), findsOneWidget);
      expect(row(tester).onTap, isNotNull, reason: 'abre o Resultado');
    });

    testWidgets(
        'enviada e aceita, mas a sessão ainda não foi baixada de novo: chip '
        '"Enviada", e a linha abre o Resultado', (tester) async {
      final now = DateTime.now();

      await show(
        tester,
        withParticipants: [minha()],
        withLocal: [
          local(
            '1',
            LocalSyncStatus.synced,
            score: 86.6667,
            lastAttemptAt: DateTime(now.year, now.month, now.day, 8, 12),
          ),
        ],
      );

      expect(find.text('Enviada'), findsOneWidget);
      expect(find.text('86,7% · enviada às 08:12'), findsOneWidget);
      expect(find.text('Avaliando · você'), findsNothing);
      expect(row(tester).onTap, isNotNull, reason: 'abre o Resultado');
    });
  });

  group('ações de ADMIN (Fase 6A)', () {
    AppIconAction action(WidgetTester tester, IconData icon) =>
        tester.widget<AppIconAction>(find.widgetWithIcon(AppIconAction, icon));

    testWidgets('consultor comum não vê o lápis nem o adicionar participante',
        (tester) async {
      await show(tester, withParticipants: [
        participant('2', 'Carlos Eduardo Nunes'),
      ]);

      expect(find.byType(AppIconAction), findsNothing);
      expect(find.byTooltip('Editar dados do treinamento'), findsNothing);
      expect(find.byTooltip('Adicionar participante'), findsNothing);
    });

    testWidgets(
        'ADMIN vê os dois, habilitados, e o cabeçalho continua com o status e '
        'as observações', (tester) async {
      when(() => auth.currentUser).thenReturn(admin);

      await show(tester);

      expect(action(tester, AppIcons.edit).onPressed, isNotNull);
      expect(action(tester, AppIcons.addParticipant).onPressed, isNotNull);
      expect(find.byTooltip('Editar dados do treinamento'), findsOneWidget);
      expect(find.byTooltip('Adicionar participante'), findsOneWidget);
      // O quadro "1f" não desenha os dois, mas o ADMIN precisa de ambos.
      expect(find.text('Em andamento'), findsOneWidget);
      expect(find.text('Pátio 3 — apresentar-se na portaria B às 07h30.'),
          findsOneWidget);
    });

    testWidgets('o adicionar fica na linha do título "Participantes", à direita',
        (tester) async {
      when(() => auth.currentUser).thenReturn(admin);

      await show(tester);

      final title = tester.getCenter(find.text('Participantes'));
      final add = tester.getCenter(find.byTooltip('Adicionar participante'));
      expect(add.dy, closeTo(title.dy, 1));
      expect(add.dx, greaterThan(title.dx));
      expect(tester.getSize(find.widgetWithIcon(AppIconAction, AppIcons.addParticipant)),
          const Size(48, 48));
    });

    testWidgets(
        'a linha do título "Participantes" do ADMIN tem 62 de altura, como a do '
        'quadro "1f" (15 + 32 + 15): o alvo de 48 começa 7 abaixo do topo dela',
        (tester) async {
      when(() => auth.currentUser).thenReturn(admin);

      await show(tester);

      final row = find
          .ancestor(of: find.text('Participantes'), matching: find.byType(Padding))
          .first;
      final target = find.widgetWithIcon(AppIconAction, AppIcons.addParticipant);
      expect(find.descendant(of: row, matching: target), findsOneWidget);
      expect(tester.getSize(row).height, 62);
      expect(tester.getTopLeft(target).dy - tester.getTopLeft(row).dy, 7);
    });

    testWidgets('sessão planejada também aceita as ações de ADMIN',
        (tester) async {
      when(() => auth.currentUser).thenReturn(admin);

      await show(tester, withSession: session(status: SessionStatus.planejado));

      expect(action(tester, AppIcons.edit).onPressed, isNotNull);
      expect(action(tester, AppIcons.addParticipant).onPressed, isNotNull);
    });

    testWidgets(
        'ADMIN sem conexão: os dois continuam à vista, apagados, com o aviso '
        'do canvas', (tester) async {
      when(() => auth.currentUser).thenReturn(admin);
      await goOffline();

      await show(tester, withParticipants: [
        participant('2', 'Carlos Eduardo Nunes'),
      ]);

      expect(action(tester, AppIcons.edit).onPressed, isNull);
      expect(action(tester, AppIcons.addParticipant).onPressed, isNull);
      expect(
        find.text('Ações administrativas precisam de conexão. A avaliação '
            'continua funcionando offline.'),
        findsOneWidget,
      );
      expect(find.textContaining('atribuir precisa de internet'), findsNothing,
          reason: 'um aviso por vez');
    });

    testWidgets(
        'ADMIN em sessão concluída ou cancelada: apagados, e o aviso diz que '
        'os dados não mudam mais', (tester) async {
      when(() => auth.currentUser).thenReturn(admin);

      await show(tester, withSession: session(status: SessionStatus.concluido));

      expect(action(tester, AppIcons.edit).onPressed, isNull);
      expect(action(tester, AppIcons.addParticipant).onPressed, isNull);
      expect(
        find.text('Sessão concluída: os participantes ficam só para consulta, '
            'e os dados não podem mais ser alterados.'),
        findsOneWidget,
      );

      sessionStream.add(session(status: SessionStatus.cancelado));
      await tester.pump();

      expect(action(tester, AppIcons.edit).onPressed, isNull);
      expect(
        find.text('Sessão cancelada: os participantes ficam só para consulta, '
            'e os dados não podem mais ser alterados.'),
        findsOneWidget,
      );
    });

    testWidgets('consultor comum em sessão concluída vê o aviso de sempre',
        (tester) async {
      await show(tester, withSession: session(status: SessionStatus.concluido));

      expect(
        find.text('Sessão concluída: os participantes ficam só para consulta.'),
        findsOneWidget,
      );
    });

    testWidgets('antes de a sessão carregar, o lápis do ADMIN já está lá, apagado',
        (tester) async {
      when(() => auth.currentUser).thenReturn(admin);
      await tester.pumpWidget(
        withProviders(
          const MaterialApp(home: SessionDetailScreen(sessionId: 'sess-1')),
        ),
      );
      await tester.pump();

      expect(action(tester, AppIcons.edit).onPressed, isNull);
    });
  });

  group('navegação pelas rotas reais', () {
    /// O detalhe aberto pelo `createRouter` de produção; devolve o router,
    /// para o teste empilhar outra rota real por cima.
    Future<GoRouter> showWithRouter(
      WidgetTester tester,
      List<SessionParticipant> list,
    ) async {
      tallScreen(tester);
      final router = createRouter(
        auth,
        initialLocation: AppRoutes.sessionDetail('sess-1'),
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        withProviders(MaterialApp.router(routerConfig: router)),
      );
      sessionStream.add(session());
      participantsStream.add(list);
      await tester.pump();
      return router;
    }

    testWidgets('o meu participante abre o checklist de verdade',
        (tester) async {
      final ana = participant('1', 'Ana Paula Ribeiro',
          status: ParticipantStatus.emAvaliacao, assignedTo: 'c-eu');
      when(() => participants.watchParticipant('1'))
          .thenAnswer((_) => Stream.value(ana));
      await showWithRouter(tester, [ana]);

      await tester.tap(find.text('Ana Paula Ribeiro'));
      await tester.pumpAndSettle();

      final screen = tester.widget<ChecklistScreen>(find.byType(ChecklistScreen));
      expect(screen.fromResult, isFalse, reason: 'o voltar leva ao detalhe');
      expect(find.text('Ana Paula Ribeiro'), findsOneWidget);
    });

    testWidgets(
        'o checklist aberto pelo "Reavaliar" do Resultado (?origem=resultado) '
        'sabe que tem o Resultado embaixo', (tester) async {
      final ana = participant('1', 'Ana Paula Ribeiro',
          status: ParticipantStatus.necessitaReavaliacao, score: 62);
      when(() => participants.watchParticipant('1'))
          .thenAnswer((_) => Stream.value(ana));
      final router = await showWithRouter(tester, [ana]);

      // O que o "Reavaliar" do Resultado faz, pela rota de produção.
      router.push(AppRoutes.participantChecklist('sess-1', '1', fromResult: true));
      await tester.pumpAndSettle();

      final screen = tester.widget<ChecklistScreen>(find.byType(ChecklistScreen));
      expect(screen.participantId, '1');
      expect(screen.fromResult, isTrue);
    });

    testWidgets('um concluído abre o Resultado', (tester) async {
      final juliana = participant('4', 'Juliana Freitas Costa',
          status: ParticipantStatus.aprovado, score: 86);
      when(() => participants.watchParticipant('4'))
          .thenAnswer((_) => Stream.value(juliana));
      when(() => participants.fetchAssessment('4'))
          .thenAnswer((_) async => const Success(null));
      when(() => assessments.findByParticipant('4')).thenAnswer((_) async => null);
      await showWithRouter(tester, [juliana]);

      await tester.tap(find.text('Juliana Freitas Costa'));
      await tester.pumpAndSettle();

      final screen = tester.widget<ResultScreen>(find.byType(ResultScreen));
      expect(screen.participantId, '4');
      expect(screen.justConfirmed, isFalse);
      expect(find.text('Avaliação concluída'), findsOneWidget);
      expect(find.text('86,0%'), findsOneWidget);
    });

    testWidgets('a linha "Na fila" abre o Resultado, só para leitura', (tester) async {
      final ana = participant('1', 'Ana Paula Ribeiro',
          status: ParticipantStatus.emAvaliacao, assignedTo: 'c-eu');
      final queued = local('1', LocalSyncStatus.pendingSync, score: 86.6667);
      when(() => participants.watchParticipant('1'))
          .thenAnswer((_) => Stream.value(ana));
      when(() => assessments.findByParticipant('1')).thenAnswer((_) async => queued);
      when(() => assessments.loadItems(queued.id)).thenAnswer((_) async => const []);
      await showWithRouter(tester, [ana]);
      localStream.add([queued]);
      await tester.pump();

      await tester.tap(find.text('Ana Paula Ribeiro'));
      await tester.pumpAndSettle();

      final screen = tester.widget<ResultScreen>(find.byType(ResultScreen));
      expect(screen.justConfirmed, isFalse);
      expect(find.byType(ChecklistScreen), findsNothing);
      expect(find.text('Avaliação concluída'), findsOneWidget);
    });

    testWidgets(
        'o Resultado de logo depois do "Confirmar" (?confirmada=1) traz o '
        '"Próximo participante", que volta ao detalhe', (tester) async {
      final ana = participant('1', 'Ana Paula Ribeiro',
          status: ParticipantStatus.emAvaliacao, assignedTo: 'c-eu');
      final queued = local('1', LocalSyncStatus.pendingSync, score: 86.6667);
      when(() => participants.watchParticipant('1'))
          .thenAnswer((_) => Stream.value(ana));
      when(() => assessments.findByParticipant('1')).thenAnswer((_) async => queued);
      when(() => assessments.loadItems(queued.id)).thenAnswer((_) async => const []);
      final router = await showWithRouter(tester, [ana]);

      // O que o checklist faz depois do "Confirmar", pela rota de produção.
      router.push(AppRoutes.participantResult('sess-1', '1', justConfirmed: true));
      await tester.pumpAndSettle();

      final screen = tester.widget<ResultScreen>(find.byType(ResultScreen));
      expect(screen.participantId, '1');
      expect(screen.justConfirmed, isTrue);
      expect(find.text('Próximo participante'), findsOneWidget);

      await tester.tap(find.text('Próximo participante'));
      await tester.pumpAndSettle();

      expect(find.byType(ResultScreen), findsNothing);
      expect(find.byType(SessionDetailScreen), findsOneWidget);
      expect(find.text('Ana Paula Ribeiro'), findsOneWidget);
    });

    testWidgets('pendente e de outro consultor não abrem nada', (tester) async {
      await showWithRouter(tester, [
        participant('2', 'Carlos Eduardo Nunes'),
        participant('3', 'Marcos Vinícius Alves',
            status: ParticipantStatus.emAvaliacao, assignedTo: 'c-2'),
      ]);

      await tester.tap(find.text('Carlos Eduardo Nunes'));
      await tester.tap(find.text('Marcos Vinícius Alves'));
      await tester.pumpAndSettle();

      expect(find.byType(ResultScreen), findsNothing);
      expect(find.byType(ChecklistScreen), findsNothing);
    });

    group('ADMIN', () {
      /// O detalhe do ADMIN pelas rotas reais. As telas de ADMIN assinam o
      /// mesmo cache depois: cada assinatura recebe a sessão de novo, como o
      /// banco de verdade faz (o stream de transmissão dos outros testes só
      /// entrega a quem já estava ouvindo).
      Future<GoRouter> showAdmin(WidgetTester tester) async {
        when(() => auth.currentUser).thenReturn(admin);
        when(() => sessions.watchSession('sess-1'))
            .thenAnswer((_) => Stream.value(session()));
        when(() => participants.watchBySession('sess-1'))
            .thenAnswer((_) => Stream.value(const []));
        final router = await showWithRouter(tester, const []);
        await tester.pumpAndSettle();
        // Só as chamadas daqui para a frente interessam (a abertura já baixou
        // a sessão uma vez).
        clearInteractions(participants);
        return router;
      }

      testWidgets(
          'o lápis abre "Dados do treinamento"; voltar de lá depois de salvar '
          'baixa a sessão de novo', (tester) async {
        final router = await showAdmin(tester);

        await tester.tap(find.byTooltip('Editar dados do treinamento'));
        await tester.pumpAndSettle();

        expect(find.byType(SessionEditScreen), findsOneWidget);

        router.pop(true);
        await tester.pumpAndSettle();

        expect(find.byType(SessionEditScreen), findsNothing);
        expect(find.byType(SessionDetailScreen), findsOneWidget);
        verify(() => participants.syncSession('sess-1')).called(1);
      });

      testWidgets('voltar de "Dados do treinamento" sem salvar não baixa nada',
          (tester) async {
        final router = await showAdmin(tester);
        await tester.tap(find.byTooltip('Editar dados do treinamento'));
        await tester.pumpAndSettle();

        router.pop();
        await tester.pumpAndSettle();

        expect(find.byType(SessionDetailScreen), findsOneWidget);
        verifyNever(() => participants.syncSession(any()));
      });

      testWidgets(
          'o adicionar abre "Adicionar participante"; fechar com alguém '
          'adicionado baixa a sessão de novo', (tester) async {
        final router = await showAdmin(tester);

        await tester.tap(find.byTooltip('Adicionar participante'));
        await tester.pumpAndSettle();

        expect(find.byType(AddParticipantScreen), findsOneWidget);

        router.pop(true);
        await tester.pumpAndSettle();

        expect(find.byType(AddParticipantScreen), findsNothing);
        verify(() => participants.syncSession('sess-1')).called(1);
      });

      testWidgets('fechar "Adicionar participante" sem adicionar não baixa nada',
          (tester) async {
        final router = await showAdmin(tester);
        await tester.tap(find.byTooltip('Adicionar participante'));
        await tester.pumpAndSettle();

        router.pop(false);
        await tester.pumpAndSettle();

        expect(find.byType(SessionDetailScreen), findsOneWidget);
        verifyNever(() => participants.syncSession(any()));
      });
    });
  });
}
