import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/models/training_session.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/repositories/session_repository.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/ui/core/widgets/session_card.dart';
import 'package:simtc/ui/sessions/sessions_screen.dart';
import 'package:simtc/utils/result.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockSessionRepository repository;
  late _MockAuthRepository auth;
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
    sessions = StreamController<List<TrainingSession>>.broadcast();
    connectivity = ConnectivityService();

    when(repository.watchSessions).thenAnswer((_) => sessions.stream);
    when(repository.watchLastSyncedAt).thenAnswer((_) => Stream.value(null));
    when(repository.syncAll).thenAnswer((_) async => const Success(0));
    when(() => auth.currentUser).thenReturn(consultor);
  });

  tearDown(() {
    sessions.close();
    connectivity.dispose();
  });

  Future<void> pump(WidgetTester tester) {
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SessionRepository>.value(value: repository),
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
        ],
        child: const MaterialApp(home: SessionsScreen()),
      ),
    );
  }

  String titleText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('sessions-title'))).data!;

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
}
