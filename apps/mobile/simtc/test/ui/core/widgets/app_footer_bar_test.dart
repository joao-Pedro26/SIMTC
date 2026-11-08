import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/app_spacing.dart';
import 'package:simtc/ui/core/widgets/app_footer_bar.dart';

void main() {
  Container barContainer(WidgetTester tester) {
    return tester.widget<Container>(find.descendant(
      of: find.byType(AppFooterBar),
      matching: find.byType(Container),
    ).first);
  }

  testWidgets('padrão: fundo surface, borda só em cima e recuo padrão', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AppFooterBar(child: Text('conteúdo'))),
    ));

    final container = barContainer(tester);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, AppColors.surface);
    expect(
      decoration.border,
      const Border(top: BorderSide(color: AppColors.border)),
    );
    expect(
      container.padding,
      const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
    );
  });

  testWidgets('padding e color próprios passam adiante e o child aparece', (tester) async {
    const padding = EdgeInsets.symmetric(horizontal: 32, vertical: 16);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AppFooterBar(
          padding: padding,
          color: AppColors.background,
          child: Text('conteúdo'),
        ),
      ),
    ));

    final container = barContainer(tester);
    expect(container.padding, padding);
    expect((container.decoration as BoxDecoration).color, AppColors.background);
    expect(find.text('conteúdo'), findsOneWidget);
  });
}
