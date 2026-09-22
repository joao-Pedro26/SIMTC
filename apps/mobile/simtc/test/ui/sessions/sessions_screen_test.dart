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
import 'package:simtc/ui/core/theme/app_colors.dart';
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

  bool isChipSelected(WidgetTester tester, String label) {
    final inkWell = tester.widget<InkWell>(find.widgetWithText(InkWell, label));
    final container = inkWell.child! as Container;
    final decoration = container.decoration! as BoxDecoration;
    return decoration.color == AppColors.primary;
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
    // Mais de uma sessão concluída — com só uma, a seção é curta demais para
    // o cabeçalho passar do topo da área rolável mesmo no fim do scroll (o
    // `ListView` não tem conteúdo abaixo dele pra "empurrá-lo" até lá).
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
}
