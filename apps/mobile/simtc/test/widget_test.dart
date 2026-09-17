import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/app.dart';

void main() {
  testWidgets('App renders successfully smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SimtcApp());
    expect(find.byType(SimtcApp), findsOneWidget);
  });
}
