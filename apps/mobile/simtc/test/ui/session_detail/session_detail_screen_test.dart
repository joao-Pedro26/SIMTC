import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:simtc/ui/checklist/checklist_screen.dart';
import 'package:simtc/ui/core/date_labels.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/result/result_screen.dart';
import 'package:simtc/ui/session_detail/participant_row.dart';
import 'package:simtc/ui/session_detail/session_detail_screen.dart';
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

  group('navegação pelas rotas reais', () {
    Future<void> showWithRouter(
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

      expect(find.byType(ChecklistScreen), findsOneWidget);
      expect(find.text('Ana Paula Ribeiro'), findsOneWidget);
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
  });
}
