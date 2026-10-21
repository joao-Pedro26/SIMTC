import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/ui/auth/login_screen.dart';
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository auth;
  late ConnectivityService connectivity;

  setUp(() {
    auth = _MockAuthRepository();
    connectivity = ConnectivityService();
  });

  tearDown(() => connectivity.dispose());

  Future<void> show(
    WidgetTester tester, {
    required Size size,
    FormFactor formFactor = FormFactor.phone,
    double keyboard = 0,
    double textScale = 1,
  }) async {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
        ],
        child: FormFactorScope(
          formFactor: formFactor,
          child: const MaterialApp(home: LoginScreen()),
        ),
      ),
    );
  }

  Rect logo(WidgetTester tester) => tester.getRect(find.byType(Image));
  Rect field(WidgetTester tester, String label) => tester.getRect(
        find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
      );
  Rect button(WidgetTester tester) =>
      tester.getRect(find.byType(AppPrimaryButton));

  testWidgets('celular: logo de 150 em cima do formulário, como antes',
      (tester) async {
    await show(tester, size: const Size(412, 915));

    expect(logo(tester).height, 150);
    expect(button(tester).width, 412 - 2 * 24);
    expect(logo(tester).bottom, lessThan(field(tester, 'E-mail').top));
  });

  testWidgets('tablet em paisagem (quadro "4b"): logo de 230 no painel de 520, '
      'formulário de 440 centrado no resto', (tester) async {
    await show(
      tester,
      size: const Size(1280, 800),
      formFactor: FormFactor.tablet,
    );

    expect(logo(tester).height, 230);
    expect(logo(tester).center, const Offset(260, 400));
    expect(button(tester).width, 440);
    expect(button(tester).center.dx, 520 + (1280 - 520) / 2);
  });

  testWidgets('tablet em retrato (quadro "4p"): logo em cima e formulário de '
      '440 na mesma coluna', (tester) async {
    await show(
      tester,
      size: const Size(800, 1280),
      formFactor: FormFactor.tablet,
    );

    expect(logo(tester).height, 230);
    expect(logo(tester).center.dx, 400);
    expect(button(tester).width, 440);
    expect(button(tester).center.dx, 400);
    expect(field(tester, 'E-mail').top - logo(tester).bottom, 32);
  });

  for (final (name, size) in const [
    ('paisagem', Size(1280, 800)),
    ('retrato', Size(800, 1280)),
  ]) {
    testWidgets('tablet em $name com o teclado aberto e a fonte ampliada: '
        'nada estoura e o "Entrar" continua alcançável', (tester) async {
      await show(
        tester,
        size: size,
        formFactor: FormFactor.tablet,
        keyboard: size.height * 0.55,
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.byType(AppPrimaryButton));
      await tester.pump();
      expect(button(tester).bottom, lessThanOrEqualTo(size.height * 0.45));
    });
  }
}
