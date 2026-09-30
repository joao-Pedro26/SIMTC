import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/services/assessment_sync_service.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/theme/app_theme.dart';
import 'package:simtc/ui/core/widgets/sync_status_indicator.dart';

import '../../../support/fake_assessment_sync_service.dart';

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late ConnectivityService connectivity;

  setUp(() => connectivity = ConnectivityService());
  tearDown(() => connectivity.dispose());

  Future<void> goOffline() async {
    final plugin = _MockConnectivity();
    when(plugin.checkConnectivity)
        .thenAnswer((_) async => [ConnectivityResult.none]);
    when(() => plugin.onConnectivityChanged)
        .thenAnswer((_) => const Stream.empty());
    connectivity.dispose();
    connectivity = ConnectivityService(connectivity: plugin);
    await connectivity.initialize();
  }

  Future<void> pump(WidgetTester tester, FakeAssessmentSyncService sync) {
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AssessmentSyncService>.value(value: sync),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: SyncStatusIndicator()),
        ),
      ),
    );
  }

  testWidgets('fila vazia: a nuvem com check, sem badge', (tester) async {
    await pump(tester, FakeAssessmentSyncService());

    expect(find.byIcon(AppIcons.syncDone), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('com fila e rede: a nuvem de sincronização com a contagem',
      (tester) async {
    await pump(
      tester,
      FakeAssessmentSyncService(
        queue: [queuedAssessment('1'), queuedAssessment('2')],
      ),
    );

    expect(find.byIcon(AppIcons.sync), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('com fila e sem rede: a nuvem riscada, como no canvas',
      (tester) async {
    await goOffline();

    await pump(
      tester,
      FakeAssessmentSyncService(queue: [queuedAssessment('1')]),
    );

    expect(find.byIcon(AppIcons.offline), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('a contagem acompanha a fila', (tester) async {
    final sync = FakeAssessmentSyncService(queue: [queuedAssessment('1')]);
    await pump(tester, sync);

    sync.setQueue(const []);
    await tester.pump();

    expect(find.text('1'), findsNothing);
    expect(find.byIcon(AppIcons.syncDone), findsOneWidget);
  });
}
