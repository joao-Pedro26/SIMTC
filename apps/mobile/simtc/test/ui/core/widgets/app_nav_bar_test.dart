import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/services/assessment_sync_service.dart';
import 'package:simtc/router.dart';
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/widgets/app_nav_bar.dart';
import 'package:simtc/ui/core/widgets/pill_nav_bar.dart';

import '../../../support/fake_assessment_sync_service.dart';

void main() {
  void screen(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// A aba [current] dentro da moldura do tablet, com as rotas das três abas.
  Future<GoRouter> pumpFrame(
    WidgetTester tester, {
    AppTab current = AppTab.sessions,
    int queued = 0,
  }) async {
    Widget tab(AppTab tab) => Scaffold(
          body: TabletNavFrame(
            current: tab,
            child: ColoredBox(
              key: const Key('conteudo'),
              color: Colors.white,
              child: Text('aba ${tab.name}'),
            ),
          ),
        );
    final router = GoRouter(
      initialLocation: switch (current) {
        AppTab.sessions => AppRoutes.home,
        AppTab.sync => AppRoutes.sync,
        AppTab.profile => AppRoutes.profile,
      },
      routes: [
        GoRoute(
            path: AppRoutes.home, builder: (_, __) => tab(AppTab.sessions)),
        GoRoute(path: AppRoutes.sync, builder: (_, __) => tab(AppTab.sync)),
        GoRoute(
            path: AppRoutes.profile, builder: (_, __) => tab(AppTab.profile)),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AssessmentSyncService>.value(
        value: FakeAssessmentSyncService(
          queue: [for (var i = 0; i < queued; i++) queuedAssessment('$i')],
        ),
        child: FormFactorScope(
          formFactor: FormFactor.tablet,
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    return router;
  }

  group('paisagem (quadro "4c")', () {
    testWidgets('coluna de 88 a 14 da borda, centrada na altura; o conteúdo '
        'começa em 116', (tester) async {
      screen(tester, const Size(1280, 800));
      await pumpFrame(tester);

      final bar = tester.getRect(find.byType(PillNavBar));
      expect(bar.left, 14);
      expect(bar.width, 88);
      expect(bar.center.dy, 400);
      expect(tester.getRect(find.byKey(const Key('conteudo'))).left, 116);
    });

    testWidgets('itens de 64 por 64, "Sincr." no lugar de "Sincronizar"',
        (tester) async {
      screen(tester, const Size(1280, 800));
      await pumpFrame(tester, queued: 3);

      expect(find.text('Sincr.'), findsOneWidget);
      expect(find.text('Sincronizar'), findsNothing);
      expect(find.text('3'), findsOneWidget);
      final item = find.ancestor(
        of: find.text('Sessões'),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(item), const Size(64, 64));
    });

    testWidgets('o item ativo usa primarySurface e primaryDark',
        (tester) async {
      screen(tester, const Size(1280, 800));
      await pumpFrame(tester);

      final label = tester.widget<Text>(find.text('Sessões'));
      expect(label.style!.color, AppColors.primaryDark);
      expect(label.style!.fontSize, 10);
      final other = tester.widget<Text>(find.text('Perfil'));
      expect(other.style!.color, AppColors.text3);
    });

    testWidgets('a lateral leva de uma aba à outra', (tester) async {
      screen(tester, const Size(1280, 800));
      await pumpFrame(tester);

      await tester.tap(find.text('Sincr.'));
      await tester.pumpAndSettle();
      expect(find.text('aba sync'), findsOneWidget);

      await tester.tap(find.text('Sessões'));
      await tester.pumpAndSettle();
      expect(find.text('aba sessions'), findsOneWidget);
    });
  });

  group('retrato (quadro "4u")', () {
    testWidgets('pílula de 68 a 120 das laterais e 16 do fundo; o conteúdo '
        'termina 100 acima', (tester) async {
      screen(tester, const Size(800, 1280));
      await pumpFrame(tester, current: AppTab.sync, queued: 2);

      final bar = tester.getRect(find.byType(PillNavBar));
      expect(bar, const Rect.fromLTRB(120, 1196, 680, 1264));
      expect(tester.getRect(find.byKey(const Key('conteudo'))).bottom, 1180);
      expect(find.text('Sincronizar'), findsOneWidget);
      expect(tester.widget<Text>(find.text('Sincronizar')).style!.fontSize, 11);
      final item = find.ancestor(
        of: find.text('Sessões'),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(item).height, 56);
    });

    testWidgets('em janela estreita (tela dividida) a pílula volta aos 16',
        (tester) async {
      screen(tester, const Size(500, 900));
      await pumpFrame(tester);

      final bar = tester.getRect(find.byType(PillNavBar));
      expect(bar.left, 16);
      expect(bar.right, 484);
    });
  });

  group('aviso passageiro (SnackBar)', () {
    /// Uma aba com a navbar do tablet, mostrando um aviso.
    Future<void> pumpWithSnackBar(WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AssessmentSyncService>.value(
          value: FakeAssessmentSyncService(),
          child: FormFactorScope(
            formFactor: FormFactor.tablet,
            child: MaterialApp(
              home: TabSnackBarArea(
                child: Scaffold(
                  body: Builder(
                    builder: (context) => TabletNavFrame(
                      current: AppTab.sessions,
                      child: TextButton(
                        onPressed: () => ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('aviso'))),
                        child: const Text('mostrar'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('mostrar'));
      await tester.pumpAndSettle();
    }

    testWidgets('no tablet em retrato, flutua acima da pílula, sem cobri-la',
        (tester) async {
      screen(tester, const Size(800, 1280));
      await pumpWithSnackBar(tester);

      // O corpo do aviso: o `SnackBar` inclui o recuo em volta.
      final snack = tester.getRect(find
          .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
          .first);
      final bar = tester.getRect(find.byType(PillNavBar));
      expect(snack.bottom, bar.top - 8);
      expect(snack.left, 120);
      expect(snack.right, 800 - 120);
    });

    testWidgets('em paisagem, com a navbar na lateral, fica embaixo, como sempre',
        (tester) async {
      screen(tester, const Size(1280, 800));
      await pumpWithSnackBar(tester);

      final snack = tester.getRect(find
          .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
          .first);
      expect(snack.bottom, 800);
      expect(snack.width, 1280);
    });
  });

  testWidgets('"Perfil" leva à aba Perfil, que fica marcada; Sessões volta',
      (tester) async {
    screen(tester, const Size(1280, 800));
    await pumpFrame(tester);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('aba profile'), findsOneWidget);
    expect(tester.widget<PillNavBar>(find.byType(PillNavBar)).currentIndex, 2);
    expect(find.text('Disponível em breve.'), findsNothing);

    await tester.tap(find.text('Sessões'));
    await tester.pumpAndSettle();
    expect(find.text('aba sessions'), findsOneWidget);
  });
}
