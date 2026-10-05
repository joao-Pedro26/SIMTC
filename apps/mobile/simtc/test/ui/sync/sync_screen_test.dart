import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/services/assessment_sync_service.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/router.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/sync/sync_screen.dart';

import '../../support/fake_assessment_sync_service.dart';

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late ConnectivityService connectivity;
  late FakeAssessmentSyncService sync;
  final agora = DateTime(2026, 9, 29, 9);

  setUp(() => connectivity = ConnectivityService());
  tearDown(() => connectivity.dispose());

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

  /// A aba aberta pela rota real, com a Home atrás dela no go_router.
  Future<void> pump(
    WidgetTester tester, {
    List<LocalAssessment> queue = const [],
    Set<String> sendingIds = const {},
    DateTime? lastSyncedAt,
  }) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    sync = FakeAssessmentSyncService(
      queue: queue,
      sendingIds: sendingIds,
      lastSyncedAt: lastSyncedAt,
    );
    final router = GoRouter(
      initialLocation: AppRoutes.sync,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: AppRoutes.sync,
          builder: (context, state) => SyncScreen(clock: () => agora),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AssessmentSyncService>.value(value: sync),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
  }

  List<LocalAssessment> filaDoCanvas() => [
        queuedAssessment(
          '1',
          participantName: 'Ana Paula Ribeiro',
          score: 86.6667,
          endTime: DateTime(2026, 9, 29, 8, 41),
        ),
        queuedAssessment(
          '2',
          participantName: 'Rodrigo Tavares',
          status: LocalSyncStatus.error,
          lastAttemptAt: DateTime(2026, 9, 29, 7, 58),
          lastError: 'tempo esgotado',
        ),
      ];

  testWidgets(
      'item recusado pelo servidor: "Descartar" pede confirmação e tira a '
      'avaliação da fila', (tester) async {
    final refused = queuedAssessment(
      '3',
      participantName: 'Marcos Vinícius Alves',
      status: LocalSyncStatus.error,
      lastAttemptAt: DateTime(2026, 9, 29, 8, 5),
      lastError: SendFailure.refused,
    );
    await pump(tester, queue: [refused]);

    expect(find.text('Tentar novamente'), findsOneWidget);
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('Descartar a avaliação?'), findsOneWidget);
    expect(
      find.text('A avaliação de Marcos Vinícius Alves não foi aceita pelo '
          'servidor e será apagada deste aparelho.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(sync.discardCalls, isEmpty);

    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Descartar'));
    await tester.pumpAndSettle();

    expect(sync.discardCalls, [refused.id]);
    expect(find.text('Marcos Vinícius Alves'), findsNothing);
  });

  group('"Descartar" que não descarta', () {
    const notDiscarded = 'Não foi possível descartar. Tente de novo.';

    /// A aba com um item recusado, e o "Descartar" dele já confirmado.
    Future<LocalAssessment> confirmDiscard(
      WidgetTester tester, {
      required void Function() arrange,
    }) async {
      final refused = queuedAssessment(
        '3',
        participantName: 'Marcos Vinícius Alves',
        status: LocalSyncStatus.error,
        lastAttemptAt: DateTime(2026, 9, 29, 8, 5),
        lastError: SendFailure.refused,
      );
      await pump(tester, queue: [refused]);
      arrange();

      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Descartar'));
      await tester.pumpAndSettle();
      return refused;
    }

    testWidgets(
        'o serviço não apagou (deixou de ser recusa, ou há envio no ar): avisa, '
        'e o item continua na fila', (tester) async {
      final refused = await confirmDiscard(
        tester,
        arrange: () => sync.discardResult = false,
      );

      expect(sync.discardCalls, [refused.id]);
      expect(find.text(notDiscarded), findsOneWidget);
      expect(find.text('Marcos Vinícius Alves'), findsOneWidget);
    });

    testWidgets('o descarte deu erro: o mesmo aviso, e o item continua na fila',
        (tester) async {
      final refused = await confirmDiscard(
        tester,
        arrange: () => sync.discardError = StateError('banco local indisponível'),
      );

      expect(sync.discardCalls, [refused.id]);
      expect(find.text(notDiscarded), findsOneWidget);
      expect(find.text('Marcos Vinícius Alves'), findsOneWidget);
    });
  });

  testWidgets('falha de rede ou de tempo não tem "Descartar": tenta sozinha',
      (tester) async {
    await pump(tester, queue: filaDoCanvas());

    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.text('Descartar'), findsNothing);
  });

  testWidgets(
      'com um envio no ar, o "Descartar" do item recusado fica desabilitado',
      (tester) async {
    final refused = queuedAssessment(
      '3',
      participantName: 'Marcos Vinícius Alves',
      status: LocalSyncStatus.error,
      lastAttemptAt: DateTime(2026, 9, 29, 8, 5),
      lastError: SendFailure.refused,
    );
    await pump(
      tester,
      queue: [queuedAssessment('1', participantName: 'Ana Paula Ribeiro'), refused],
      sendingIds: {'local-1'},
    );

    expect(find.text('Enviando'), findsOneWidget);
    final discard = tester.widget<OutlinedButton>(
      find.ancestor(of: find.text('Descartar'), matching: find.byType(OutlinedButton)),
    );
    expect(discard.onPressed, isNull);
  });

  AppCtaButton syncNowButton(WidgetTester tester) =>
      tester.widget<AppCtaButton>(find.byType(AppCtaButton));

  testWidgets(
      'com rede: a última sincronização, cada pendente com a sua pílula e '
      '"Sincronizar agora" habilitado', (tester) async {
    await pump(
      tester,
      queue: filaDoCanvas(),
      lastSyncedAt: DateTime(2026, 9, 29, 7, 12),
    );

    expect(find.text('Última sincronização hoje 07:12'), findsOneWidget);
    expect(find.text('Pendentes'), findsOneWidget);
    expect(find.text('Ana Paula Ribeiro'), findsOneWidget);
    expect(find.text('Avaliação prática · 86,7% · 08:41'), findsOneWidget);
    expect(find.text('Na fila'), findsOneWidget);
    expect(find.text('Rodrigo Tavares'), findsOneWidget);
    expect(find.text('Falhou às 07:58 · tempo esgotado'), findsOneWidget);
    expect(find.text('Erro'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.byKey(const Key('sync-offline-card')), findsNothing);
    expect(syncNowButton(tester).onPressed, isNotNull);
    expect(find.text('Disponível quando houver conexão'), findsNothing);
  });

  testWidgets('durante o envio: pílula "Enviando" e o botão ocupado',
      (tester) async {
    await pump(
      tester,
      queue: [queuedAssessment('1', participantName: 'Ana Paula Ribeiro')],
      sendingIds: {'local-1'},
    );

    expect(find.text('Enviando'), findsOneWidget);
    expect(find.text('Na fila'), findsNothing);
    expect(syncNowButton(tester).isLoading, isTrue);
  });

  testWidgets(
      'sem rede: o cartão âmbar com a contagem, e "Sincronizar agora" '
      'desabilitado com a explicação', (tester) async {
    await goOffline();

    await pump(tester, queue: filaDoCanvas());

    expect(find.byKey(const Key('sync-offline-card')), findsOneWidget);
    expect(find.text('2 avaliações na fila'), findsOneWidget);
    expect(
      find.text('Sem conexão agora. Nada é perdido: a fila sobe sozinha quando '
          'o sinal voltar.'),
      findsOneWidget,
    );
    expect(syncNowButton(tester).onPressed, isNull);
    expect(find.text('Disponível quando houver conexão'), findsOneWidget);
    final retry = tester.widget<OutlinedButton>(
      find.ancestor(of: find.text('Tentar novamente'), matching: find.byType(OutlinedButton)),
    );
    expect(retry.onPressed, isNull);
  });

  testWidgets('"Sincronizar agora" e "Tentar novamente" pedem o envio',
      (tester) async {
    await pump(tester, queue: filaDoCanvas());

    await tester.tap(find.text('Sincronizar agora'));
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();

    expect(sync.syncNowCalls, 2);
  });

  testWidgets('fila vazia: tudo enviado, e nada a sincronizar', (tester) async {
    await pump(tester);

    expect(find.byKey(const Key('sync-empty')), findsOneWidget);
    expect(find.text('Nenhuma avaliação na fila'), findsOneWidget);
    expect(find.text('Tudo o que você confirmou já chegou ao servidor.'),
        findsOneWidget);
    expect(find.text('Nenhuma avaliação enviada ainda'), findsOneWidget);
    expect(find.text('Pendentes'), findsNothing);
    expect(syncNowButton(tester).onPressed, isNull);
  });

  testWidgets('a tela acompanha a fila sozinha', (tester) async {
    await pump(tester, queue: filaDoCanvas());

    sync.setQueue(const []);
    await tester.pump();

    expect(find.byKey(const Key('sync-empty')), findsOneWidget);
  });

  testWidgets('"Sessões" na navbar leva para a Home', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Sessões'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('o voltar do Android leva para a Home, em vez de fechar o app',
      (tester) async {
    await pump(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });
}
