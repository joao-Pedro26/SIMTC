import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/theme/app_theme.dart';
import 'package:simtc/ui/core/widgets/app_select_field.dart';

import '../../../support/a11y.dart';

void main() {
  Future<void> pumpField(
    WidgetTester tester, {
    String? value,
    bool enabled = true,
    ValueChanged<String>? onChanged,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: AppSelectField<String>(
              label: 'Categoria da CNH',
              hintText: 'Selecione',
              value: value,
              options: const ['A', 'B', 'AB'],
              optionLabel: (option) => option,
              onChanged: onChanged ?? (_) {},
              enabled: enabled,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('sem valor mostra a dica', (tester) async {
    await pumpField(tester);

    expect(find.text('Categoria da CNH'), findsOneWidget);
    expect(find.text('Selecione'), findsOneWidget);
  });

  testWidgets('com valor mostra o rótulo da opção, e não a dica', (tester) async {
    await pumpField(tester, value: 'AB');

    // A dica continua na árvore, transparente; o que vale é o texto do campo.
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'AB');
  });

  testWidgets('tocar abre as opções, cada uma com alvo de 48', (tester) async {
    await pumpField(tester);
    expect(find.text('B'), findsNothing);

    await tester.tap(find.text('Selecione'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('AB'), findsOneWidget);
    expect(
      tester.getSize(find.widgetWithText(MenuItemButton, 'B')).height,
      greaterThanOrEqualTo(48),
    );
    await expectAccessibleTargets(tester);
  });

  testWidgets('escolher uma opção chama onChanged e fecha o menu', (tester) async {
    String? chosen;
    await pumpField(tester, onChanged: (value) => chosen = value);

    await tester.tap(find.text('Selecione'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('AB'));
    await tester.pumpAndSettle();

    expect(chosen, 'AB');
    expect(find.byType(MenuItemButton), findsNothing);
  });

  testWidgets('o valor novo que chega de fora aparece no campo', (tester) async {
    await pumpField(tester, value: 'A');
    await pumpField(tester, value: 'B');
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'B');
  });

  testWidgets('desabilitado não abre', (tester) async {
    await pumpField(tester, enabled: false);

    await tester.tap(find.text('Selecione'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(MenuItemButton), findsNothing);
  });
}
