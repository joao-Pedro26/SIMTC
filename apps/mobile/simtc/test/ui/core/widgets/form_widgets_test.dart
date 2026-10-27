import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/theme/app_theme.dart';
import 'package:simtc/ui/core/theme/app_typography.dart';
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

    testWidgets('mostra o texto de apoio, e o erro toma o lugar dele', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _pump(
        tester,
        AppTextField(label: 'CPF', controller: controller, helperText: 'CPF válido.'),
      );
      expect(find.text('CPF válido.'), findsOneWidget);

      await _pump(
        tester,
        AppTextField(
          label: 'CPF',
          controller: controller,
          helperText: 'CPF válido.',
          errorText: 'CPF inválido.',
        ),
      );
      expect(find.text('CPF inválido.'), findsOneWidget);
      expect(find.text('CPF válido.'), findsNothing);
    });

    testWidgets('mostra a nota ao lado do rótulo e o widget à direita do texto',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _pump(
        tester,
        AppTextField(
          label: 'E-mail',
          controller: controller,
          labelTrailing: 'opcional',
          trailing: const Icon(AppIcons.approved, key: Key('ok')),
        ),
      );

      expect(find.text('opcional'), findsOneWidget);
      expect(find.byKey(const Key('ok')), findsOneWidget);
      expect(
        tester.getCenter(find.byKey(const Key('ok'))).dx,
        greaterThan(tester.getCenter(find.byType(TextField)).dx),
      );
    });

    testWidgets('aplica os formatadores de entrada e a capitalização', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _pump(
        tester,
        AppTextField(
          label: 'UF',
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [LengthLimitingTextInputFormatter(2)],
        ),
      );

      await tester.enterText(find.byType(TextField), 'MGX');
      expect(controller.text, 'MG');
      expect(
        tester.widget<TextField>(find.byType(TextField)).textCapitalization,
        TextCapitalization.characters,
      );
    });

    testWidgets(
        'só leitura: o toque em qualquer ponto da caixa chama a ação e não '
        'abre o teclado', (tester) async {
      final controller = TextEditingController(text: '12 set 2026');
      addTearDown(controller.dispose);
      var taps = 0;

      await _pump(
        tester,
        AppTextField(
          label: 'Data',
          controller: controller,
          icon: AppIcons.event,
          readOnly: true,
          onTap: () => taps++,
        ),
      );

      // `tapAt`: o campo de dentro não recebe o ponteiro (é a caixa que
      // responde), e o `tap` num widget assim avisa que errou o alvo.
      await tester.tapAt(tester.getCenter(find.byIcon(AppIcons.event)));
      await tester.tapAt(tester.getCenter(find.text('12 set 2026')));
      await tester.pump();

      expect(taps, 2);
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('só leitura e desabilitado: o toque não chama a ação', (tester) async {
      final controller = TextEditingController(text: '12 set 2026');
      addTearDown(controller.dispose);
      var taps = 0;

      await _pump(
        tester,
        AppTextField(
          label: 'Data',
          controller: controller,
          readOnly: true,
          enabled: false,
          onTap: () => taps++,
        ),
      );

      await tester.tapAt(tester.getCenter(find.text('12 set 2026')));
      expect(taps, 0);
    });

    testWidgets('várias linhas: cresce a partir do mínimo e fica mais alto que '
        'um campo comum', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _pump(
        tester,
        AppTextField(
          label: 'Observações',
          controller: controller,
          minLines: 3,
          maxLines: null,
          keyboardType: TextInputType.multiline,
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.minLines, 3);
      expect(field.maxLines, isNull);
      expect(tester.getSize(find.byType(AppTextField)).height, greaterThan(96));
      // O texto das observações do quadro "3b": 15/1,45 (Fase 8C).
      expect(field.style!.fontSize, 15);
      expect(field.style!.height, 1.45);
    });

    testWidgets('o campo de uma linha tem 48 de toque, e tocar no ícone foca o '
        'campo; a caixa continua com 56 (Fase 8C)', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _pump(
        tester,
        AppTextField(
          label: 'E-mail',
          icon: AppIcons.email,
          controller: controller,
        ),
      );

      expect(tester.getSize(find.byType(TextField)).height,
          greaterThanOrEqualTo(48));
      final box = find.descendant(
        of: find.byType(AppTextField),
        matching: find.byWidgetPredicate((w) =>
            w is Container && w.constraints?.minHeight == 56),
      );
      expect(tester.getSize(box).height, 56);

      await tester.tap(find.byIcon(AppIcons.email));
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
          isTrue);
    });

    testWidgets('mono: o valor usa a fonte de números', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _pump(tester, AppTextField(label: 'CPF', controller: controller, mono: true));

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.style?.fontFamily, AppTypography.monoFamily);
    });
  });

  group('AppDangerOutlineButton', () {
    testWidgets('dispara a ação, com 56dp de altura e a tinta de perigo',
        (tester) async {
      var taps = 0;
      await _pump(
        tester,
        AppDangerOutlineButton(
          label: 'Cancelar sessão',
          icon: AppIcons.needsReview,
          onPressed: () => taps++,
        ),
      );

      await tester.tap(find.text('Cancelar sessão'));
      expect(taps, 1);
      expect(tester.getSize(find.byType(AppDangerOutlineButton)).height, 56);

      final context = tester.element(find.text('Cancelar sessão'));
      expect(DefaultTextStyle.of(context).style.color, AppColors.dangerInk);
      expect(find.byIcon(AppIcons.needsReview), findsOneWidget);
    });

    testWidgets('em carregamento mostra o indicador e não responde ao toque',
        (tester) async {
      var taps = 0;
      await _pump(
        tester,
        AppDangerOutlineButton(
          label: 'Cancelar sessão',
          isLoading: true,
          onPressed: () => taps++,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // O rótulo fica escondido embaixo do indicador, guardando a largura
      // (Fase 8C): não se vê nem é lido.
      expect(find.bySemanticsLabel('Cancelar sessão'), findsNothing);

      await tester.tap(find.byType(AppDangerOutlineButton));
      expect(taps, 0);
    });

    testWidgets('sem ação, fica desabilitado', (tester) async {
      await _pump(tester, const AppDangerOutlineButton(label: 'Cancelar sessão'));

      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('compacto tem 48dp, texto 14, ícone 19 e canto 10, como o '
        '"Remover da sessão" do canvas', (tester) async {
      await _pump(
        tester,
        AppDangerOutlineButton(
          label: 'Remover da sessão',
          icon: AppIcons.discard,
          compact: true,
          onPressed: () {},
        ),
      );

      expect(tester.getSize(find.byType(AppDangerOutlineButton)).height, 48);
      expect(tester.widget<Icon>(find.byIcon(AppIcons.discard)).size, 19);
      final text =
          tester.renderObject<RenderParagraph>(find.text('Remover da sessão'));
      expect(text.text.style?.fontSize, 14);
      expect(text.text.style?.color, AppColors.dangerInk);

      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(
        button.style!.shape!.resolve(const {}),
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
    });

    testWidgets('em carregamento, o compacto sem expandir guarda a largura do '
        'rótulo (Fase 8C)', (tester) async {
      Widget button({required bool loading}) => Align(
            alignment: Alignment.topLeft,
            child: AppDangerOutlineButton(
              label: 'Sair da conta',
              icon: AppIcons.logout,
              compact: true,
              expand: false,
              isLoading: loading,
              onPressed: () {},
            ),
          );

      await _pump(tester, button(loading: false));
      final width = tester.getSize(find.byType(AppDangerOutlineButton)).width;

      await _pump(tester, button(loading: true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.getSize(find.byType(AppDangerOutlineButton)).width, width);
      expect(find.bySemanticsLabel('Sair da conta'), findsNothing,
          reason: 'o rótulo escondido não é lido');
    });

    testWidgets('o tamanho padrão continua com texto 15, ícone 20 e canto 12',
        (tester) async {
      await _pump(
        tester,
        AppDangerOutlineButton(
          label: 'Cancelar sessão',
          icon: AppIcons.cancelSession,
          onPressed: () {},
        ),
      );

      expect(tester.widget<Icon>(find.byIcon(AppIcons.cancelSession)).size, 20);
      final text =
          tester.renderObject<RenderParagraph>(find.text('Cancelar sessão'));
      expect(text.text.style?.fontSize, 15);

      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(
        button.style!.shape!.resolve(const {}),
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
    });
  });

  group('AppCompactOutlineButton', () {
    // Como na tela: ao lado de um texto que ocupa o resto da linha.
    Widget inRow(Widget button) {
      return Row(
        children: [const Expanded(child: Text('Diego Barbosa')), button],
      );
    }

    testWidgets('dispara a ação, com 48dp de altura, a largura do rótulo e as '
        'medidas do "Adicionar" do canvas', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        inRow(
          AppCompactOutlineButton(
            label: 'Adicionar',
            icon: AppIcons.assign,
            onPressed: () => taps++,
          ),
        ),
      );

      await tester.tap(find.text('Adicionar'));
      expect(taps, 1);

      final box = tester.getRect(find.byType(AppCompactOutlineButton));
      final icon = tester.getRect(find.byIcon(AppIcons.assign));
      final label = tester.getRect(find.text('Adicionar'));
      expect(box.height, 48);
      // Recuo de 14, ícone de 19, vão de 6, o rótulo e mais 14.
      expect(icon.left - box.left, 14);
      expect(icon.width, 19);
      expect(label.left - icon.right, 6);
      expect(box.right - label.right, 14);

      final outlined = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(
        outlined.style!.side!.resolve(const {}),
        const BorderSide(color: AppColors.borderStrong, width: 1.5),
      );
      expect(
        outlined.style!.shape!.resolve(const {}),
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
      final text = tester.renderObject<RenderParagraph>(find.text('Adicionar'));
      expect(text.text.style?.fontSize, 14);
      expect(text.text.style?.color, AppColors.primaryDark);
    });

    testWidgets('em carregamento mostra o indicador, não responde ao toque e '
        'mantém a largura', (tester) async {
      var taps = 0;
      Widget build({required bool loading}) {
        return inRow(
          AppCompactOutlineButton(
            label: 'Adicionar',
            icon: AppIcons.assign,
            isLoading: loading,
            onPressed: () => taps++,
          ),
        );
      }

      await _pump(tester, build(loading: false));
      final idle = tester.getSize(find.byType(AppCompactOutlineButton));
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await _pump(tester, build(loading: true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // A linha não pula quando o botão troca o rótulo pelo indicador.
      expect(tester.getSize(find.byType(AppCompactOutlineButton)), idle);

      await tester.tap(find.byType(AppCompactOutlineButton));
      expect(taps, 0);
    });

    testWidgets('sem ação, continua à vista, apagado', (tester) async {
      await _pump(
        tester,
        inRow(
          const AppCompactOutlineButton(
            label: 'Adicionar',
            icon: AppIcons.assign,
          ),
        ),
      );

      final outlined = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(outlined.onPressed, isNull);
      expect(
        outlined.style!.side!.resolve(const {}),
        const BorderSide(color: AppColors.border, width: 1.5),
      );
      final text = tester.renderObject<RenderParagraph>(find.text('Adicionar'));
      expect(text.text.style?.color, AppColors.textMuted);
    });
  });

  group('AppTextButton', () {
    testWidgets('dispara a ação e tem o alvo mínimo de toque', (tester) async {
      var taps = 0;
      await _pump(tester, AppTextButton(label: 'Descartar', onPressed: () => taps++));

      await tester.tap(find.text('Descartar'));
      expect(taps, 1);
      expect(
        tester.getSize(find.byType(AppTextButton)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('o tom neutro usa a tinta de texto, não a de marca', (tester) async {
      await _pump(
        tester,
        Column(
          children: [
            AppTextButton(label: 'Salvar e adicionar outro', onPressed: () {}),
            AppTextButton(
              label: 'Descartar',
              tone: AppTextButtonTone.neutral,
              onPressed: () {},
            ),
          ],
        ),
      );

      Color? inkOf(String label) =>
          DefaultTextStyle.of(tester.element(find.text(label))).style.color;
      expect(inkOf('Salvar e adicionar outro'), AppColors.primaryDark);
      expect(inkOf('Descartar'), AppColors.text3);
    });

    testWidgets('sem ação, fica desabilitado', (tester) async {
      await _pump(tester, const AppTextButton(label: 'Descartar'));

      final button = tester.widget<TextButton>(find.byType(TextButton));
      expect(button.onPressed, isNull);
    });
  });

  group('AppIconAction', () {
    testWidgets('dispara a ação num alvo de 48dp, com a dica de acessibilidade',
        (tester) async {
      var taps = 0;
      await _pump(
        tester,
        Row(
          children: [
            AppIconAction(
              icon: AppIcons.search,
              tooltip: 'Editar dados do treinamento',
              onPressed: () => taps++,
            ),
          ],
        ),
      );

      await tester.tap(find.byTooltip('Editar dados do treinamento'));
      expect(taps, 1);
      expect(tester.getSize(find.byType(AppIconAction)), const Size(48, 48));
    });

    testWidgets('sem ação, continua visível, apagado, e não responde',
        (tester) async {
      await _pump(
        tester,
        const Row(
          children: [
            AppIconAction(icon: AppIcons.search, tooltip: 'Editar dados do treinamento'),
          ],
        ),
      );

      expect(find.byIcon(AppIcons.search), findsOneWidget);
      final button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.onPressed, isNull);
      expect(button.disabledColor, AppColors.textMuted);
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

    testWidgets('o tamanho large tem 56dp, texto 16 e ícone 22, como o '
        '"Finalizar avaliação" do canvas', (tester) async {
      await _pump(
        tester,
        const AppCtaButton(
          label: 'Finalizar avaliação',
          icon: AppIcons.check,
          size: AppCtaSize.large,
        ),
      );

      expect(tester.getSize(find.byType(AppCtaButton)).height, 56);
      expect(tester.widget<Icon>(find.byIcon(AppIcons.check)).size, 22);
      final text = tester.renderObject<RenderParagraph>(find.text('Finalizar avaliação'));
      expect(text.text.style?.fontSize, 16);
    });

    testWidgets('o tamanho padrão continua compacto: 48dp e texto 14',
        (tester) async {
      await _pump(tester, AppCtaButton(label: 'Atribuir a mim', onPressed: () {}));

      expect(tester.getSize(find.byType(AppCtaButton)).height, 48);
      final text = tester.renderObject<RenderParagraph>(find.text('Atribuir a mim'));
      expect(text.text.style?.fontSize, 14);
    });

    testWidgets('o compacto tem canto 10, como no quadro; o do cabeçalho '
        'continua com 12 (Fase 8C)', (tester) async {
      ShapeBorder? shape() => tester
          .widget<FilledButton>(find.byType(FilledButton))
          .style!
          .shape!
          .resolve(const {});

      await _pump(tester, AppCtaButton(label: 'Atribuir a mim', onPressed: () {}));
      expect(
        shape(),
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );

      await _pump(
        tester,
        AppCtaButton(
          label: 'Iniciar avaliação',
          size: AppCtaSize.header,
          fullWidth: false,
          onPressed: () {},
        ),
      );
      expect(
        shape(),
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
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
