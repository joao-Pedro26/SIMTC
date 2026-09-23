import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/theme/app_theme.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/app_checkbox.dart';
import 'package:simtc/ui/core/widgets/app_text_field.dart';
import 'package:simtc/ui/core/widgets/inline_notice.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
    ),
  );
}

void main() {
  group('AppTextField', () {
    testWidgets('mostra rótulo, aceita digitação e exibe o erro', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _pump(
        tester,
        AppTextField(
          label: 'E-mail',
          controller: controller,
          icon: AppIcons.email,
          errorText: 'E-mail ou senha incorretos',
        ),
      );

      expect(find.text('E-mail'), findsOneWidget);
      expect(find.text('E-mail ou senha incorretos'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'carla@simtc.com.br');
      expect(controller.text, 'carla@simtc.com.br');
    });

    testWidgets('o alternador de senha aparece só quando há callback e dispara o evento',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var toggles = 0;

      await _pump(
        tester,
        AppTextField(
          label: 'Senha',
          controller: controller,
          icon: AppIcons.password,
          obscureText: true,
          onToggleObscure: () => toggles++,
        ),
      );

      expect(find.byIcon(AppIcons.showPassword), findsOneWidget);
      await tester.tap(find.byIcon(AppIcons.showPassword));
      expect(toggles, 1);
    });

    testWidgets('o alternador de senha respeita o alvo de toque de 48 dp', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _pump(
        tester,
        AppTextField(
          label: 'Senha',
          controller: controller,
          icon: AppIcons.password,
          obscureText: true,
          onToggleObscure: () {},
        ),
      );

      final toggleSize = tester.getSize(
        find.ancestor(
          of: find.byIcon(AppIcons.showPassword),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(toggleSize.width, greaterThanOrEqualTo(48));
      expect(toggleSize.height, greaterThanOrEqualTo(48));
    });
  });

  group('AppPrimaryButton', () {
    testWidgets('dispara a ação quando habilitado', (tester) async {
      var taps = 0;
      await _pump(tester, AppPrimaryButton(label: 'Entrar', onPressed: () => taps++));

      await tester.tap(find.text('Entrar'));
      expect(taps, 1);
    });

    testWidgets('em carregamento mostra o indicador, esconde o rótulo e não responde ao toque',
        (tester) async {
      var taps = 0;
      await _pump(
        tester,
        AppPrimaryButton(label: 'Entrar', isLoading: true, onPressed: () => taps++),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Entrar'), findsNothing);

      await tester.tap(find.byType(AppPrimaryButton));
      expect(taps, 0);
    });

    testWidgets('sem ação, fica desabilitado', (tester) async {
      await _pump(tester, const AppPrimaryButton(label: 'Entrar'));

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });
  });

  group('AppCtaButton', () {
    testWidgets('dispara a ação e tem pelo menos o alvo mínimo de toque',
        (tester) async {
      var taps = 0;
      await _pump(
        tester,
        AppCtaButton(
          label: 'Atribuir a mim',
          icon: AppIcons.assign,
          onPressed: () => taps++,
        ),
      );

      await tester.tap(find.text('Atribuir a mim'));
      expect(taps, 1);
      expect(tester.getSize(find.byType(AppCtaButton)).height,
          greaterThanOrEqualTo(48));
    });

    testWidgets('em carregamento mostra o indicador e não responde ao toque',
        (tester) async {
      var taps = 0;
      await _pump(
        tester,
        AppCtaButton(
          label: 'Atribuir a mim',
          isLoading: true,
          onPressed: () => taps++,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(AppCtaButton));
      expect(taps, 0);
    });

    testWidgets('sem ação, fica desabilitado', (tester) async {
      await _pump(tester, const AppCtaButton(label: 'Atribuir a mim'));

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });
  });

  group('AppCheckbox', () {
    testWidgets('o toque devolve o valor invertido', (tester) async {
      bool? received;
      await _pump(
        tester,
        AppCheckbox(
          value: false,
          label: 'Manter conectado',
          onChanged: (v) => received = v,
        ),
      );

      await tester.tap(find.text('Manter conectado'));
      expect(received, isTrue);
    });

    testWidgets('marcado, mostra o check', (tester) async {
      await _pump(
        tester,
        AppCheckbox(value: true, label: 'Manter conectado', onChanged: (_) {}),
      );

      expect(find.byIcon(AppIcons.check), findsOneWidget);
    });
  });

  group('InlineNotice', () {
    testWidgets('mostra ícone e mensagem, e colore conforme o tom', (tester) async {
      await _pump(
        tester,
        const InlineNotice(
          icon: AppIcons.noSignal,
          message: 'Sem conexão no momento.',
          tone: NoticeTone.warning,
        ),
      );

      expect(find.byIcon(AppIcons.noSignal), findsOneWidget);
      expect(find.text('Sem conexão no momento.'), findsOneWidget);

      final container = tester.widget<Container>(
        find.descendant(of: find.byType(InlineNotice), matching: find.byType(Container)).first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.warningBg);
    });
  });
}
