import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/form_factor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('formFactorFor', () {
    test('celular abaixo de 600 de lado menor, tablet a partir dele', () {
      expect(formFactorFor(const Size(412, 915)), FormFactor.phone);
      expect(formFactorFor(const Size(360, 640)), FormFactor.phone);
      expect(formFactorFor(const Size(599, 960)), FormFactor.phone);
      expect(formFactorFor(const Size(600, 960)), FormFactor.tablet);
      expect(formFactorFor(const Size(800, 1280)), FormFactor.tablet);
      expect(formFactorFor(const Size(1280, 800)), FormFactor.tablet);
    });

    test('celular deitado continua celular', () {
      expect(formFactorFor(const Size(915, 412)), FormFactor.phone);
    });
  });

  group('applyOrientationPolicy', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('celular trava em retrato', () async {
      await applyOrientationPolicy(FormFactor.phone);

      final call = calls.single;
      expect(call.method, 'SystemChrome.setPreferredOrientations');
      expect(call.arguments, ['DeviceOrientation.portraitUp']);
    });

    test('tablet libera todas as orientações', () async {
      await applyOrientationPolicy(FormFactor.tablet);

      final call = calls.single;
      expect(call.method, 'SystemChrome.setPreferredOrientations');
      expect(call.arguments, isEmpty);
    });
  });

  group('FormFactorScope', () {
    Future<(bool, bool)> read(
      WidgetTester tester, {
      FormFactor? formFactor,
      required Size size,
    }) async {
      late bool tablet;
      late bool expanded;
      final probe = Builder(builder: (context) {
        tablet = context.isTablet;
        expanded = context.isExpandedLayout;
        return const SizedBox();
      });
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size),
          child: formFactor == null
              ? probe
              : FormFactorScope(formFactor: formFactor, child: probe),
        ),
      );
      return (tablet, expanded);
    }

    testWidgets('sem o scope, vale celular mesmo em tela larga',
        (tester) async {
      expect(await read(tester, size: const Size(1280, 800)), (false, false));
    });

    testWidgets('tablet só fica em dois painéis a partir de 840 de largura',
        (tester) async {
      expect(
        await read(tester,
            formFactor: FormFactor.tablet, size: const Size(1280, 800)),
        (true, true),
      );
      expect(
        await read(tester,
            formFactor: FormFactor.tablet, size: const Size(840, 600)),
        (true, true),
      );
      expect(
        await read(tester,
            formFactor: FormFactor.tablet, size: const Size(839, 600)),
        (true, false),
      );
      expect(
        await read(tester,
            formFactor: FormFactor.tablet, size: const Size(800, 1280)),
        (true, false),
      );
    });

    testWidgets('celular nunca fica em dois painéis', (tester) async {
      expect(
        await read(tester,
            formFactor: FormFactor.phone, size: const Size(915, 412)),
        (false, false),
      );
    });
  });
}
