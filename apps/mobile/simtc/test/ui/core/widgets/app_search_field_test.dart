import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/widgets/app_search_field.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: child))),
    );
  }

  group('AppSearchButton', () {
    testWidgets('alvo de 48 com a lupa cinza e o rótulo "Buscar"', (tester) async {
      var taps = 0;
      await pump(tester, AppSearchButton(onPressed: () => taps++));

      expect(tester.getSize(find.byType(AppSearchButton)), const Size(48, 48));
      final icon = tester.widget<Icon>(find.byIcon(AppIcons.search));
      expect(icon.size, 22);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).color,
        AppColors.text3,
      );
      expect(find.byTooltip('Buscar'), findsOneWidget);

      await tester.tap(find.byType(AppSearchButton));
      expect(taps, 1);
    });

    testWidgets('na barra dos filtros, o ícone tem 19', (tester) async {
      await pump(
        tester,
        AppSearchButton(
          onPressed: () {},
          iconSize: AppSearchButton.filtersIconSize,
        ),
      );

      expect(tester.widget<Icon>(find.byIcon(AppIcons.search)).size, 19);
    });
  });

  group('AppSearchField', () {
    testWidgets('48 de altura, abre com o foco e começa com o texto dado',
        (tester) async {
      await pump(
        tester,
        SizedBox(
          width: 360,
          child: AppSearchField(
            hintText: 'Buscar pela empresa',
            initialText: 'brac',
            onChanged: (_) {},
            onClose: () {},
          ),
        ),
      );

      expect(tester.getSize(find.byType(AppSearchField)).height, 48);
      expect(tester.getSize(find.byType(TextField)).height, 48);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofocus, isTrue);
      expect(field.controller!.text, 'brac');
      expect(field.decoration!.hintText, 'Buscar pela empresa');
      await tester.pump();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
        isTrue,
      );
    });

    testWidgets('cada letra avisa o texto; o X fecha a busca', (tester) async {
      final changes = <String>[];
      var closes = 0;
      await pump(
        tester,
        SizedBox(
          width: 360,
          child: AppSearchField(
            hintText: 'Buscar por nome ou CPF',
            onChanged: changes.add,
            onClose: () => closes++,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'ana');
      expect(changes.last, 'ana');

      await tester.tap(find.byTooltip('Fechar a busca'));
      expect(closes, 1);
    });
  });
}
