import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/app_localization.dart';

void main() {
  testWidgets('o calendário do Material abre em português', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: AppLocalization.locale,
        supportedLocales: AppLocalization.supportedLocales,
        localizationsDelegates: AppLocalization.delegates,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDatePicker(
              context: context,
              initialDate: DateTime(2026, 9, 12),
              firstDate: DateTime(2026),
              lastDate: DateTime(2027),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('setembro de 2026'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('September 2026'), findsNothing);
  });
}
