import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/widgets/app_spinner.dart';

void main() {
  Future<void> pumpSpinner(WidgetTester tester, Widget spinner) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: spinner)),
    ));
  }

  testWidgets('sem argumentos: 20×20, espessura 2,5 e cor do tema', (tester) async {
    await pumpSpinner(tester, const AppSpinner());

    expect(tester.getSize(find.byType(AppSpinner)), const Size(20, 20));
    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(indicator.strokeWidth, 2.5);
    expect(indicator.valueColor, isNull);
  });

  testWidgets('size, strokeWidth e color passam adiante', (tester) async {
    await pumpSpinner(
      tester,
      const AppSpinner(size: 22, strokeWidth: 2, color: AppColors.surface),
    );

    expect(tester.getSize(find.byType(AppSpinner)), const Size(22, 22));
    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(indicator.strokeWidth, 2);
    final color = indicator.valueColor as AlwaysStoppedAnimation<Color?>;
    expect(color.value, AppColors.surface);
  });
}
