import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/app.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/splash/splash_screen.dart';

void main() {
  testWidgets('o app abre na tela de abertura', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(SimtcApp(database: database));
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
  });
}
