import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/splash/splash_screen.dart';
import 'package:simtc/utils/result.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository auth;
  late Completer<Result<AuthUser>> restore;

  setUp(() {
    auth = _MockAuthRepository();
    // A retomada fica no ar: a abertura não sai da tela durante o teste.
    restore = Completer<Result<AuthUser>>();
    when(auth.restoreSession).thenAnswer((_) => restore.future);
  });

  Future<void> show(
    WidgetTester tester, {
    required Size size,
    FormFactor formFactor = FormFactor.phone,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthRepository>.value(
        value: auth,
        child: FormFactorScope(
          formFactor: formFactor,
          child: const MaterialApp(home: SplashScreen()),
        ),
      ),
    );
    await tester.pump();
  }

  Rect logo(WidgetTester tester) => tester.getRect(find.byType(Image));
  Rect bar(WidgetTester tester) =>
      tester.getRect(find.byType(LinearProgressIndicator));

  testWidgets('celular: logo de 130 e barra de 140, 28 abaixo', (tester) async {
    await show(tester, size: const Size(412, 915));

    expect(logo(tester).height, 130);
    expect(bar(tester).width, 140);
    expect(bar(tester).top - logo(tester).bottom, 28);
  });

  for (final size in const [Size(1280, 800), Size(800, 1280)]) {
    testWidgets('tablet ${size.width.toInt()}x${size.height.toInt()} '
        '(quadros "4a" e "4o"): logo de 200 e barra de 220, 66 abaixo',
        (tester) async {
      await show(tester, size: size, formFactor: FormFactor.tablet);

      expect(logo(tester).height, 200);
      expect(bar(tester).width, 220);
      expect(bar(tester).top - logo(tester).bottom, 66);
      expect(bar(tester).center.dx, size.width / 2);
    });
  }
}
