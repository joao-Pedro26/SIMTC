import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/services/assessment_sync_service.dart';
import 'package:simtc/data/services/connectivity_service.dart';
import 'package:simtc/data/services/device_data_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/router.dart';
import 'package:simtc/ui/core/form_factor.dart';
import 'package:simtc/ui/profile/profile_screen.dart';

import '../../support/fake_assessment_sync_service.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockDeviceData extends Mock implements DeviceDataService {}

class _MockConnectivity extends Mock implements Connectivity {}

const AuthUser carla = AuthUser(
  id: 'user-1',
  name: 'Carla Mendes',
  email: 'carla.mendes@simtreinamentos.com.br',
  role: AppUserRole.consultant,
);

/// 18,4 MB: o valor do canvas na linha "Limpar cache local".
final int canvasCacheBytes = (18.4 * 1024 * 1024).round();

/// A aba Perfil aberta pela rota real, com a Home atrás dela no go_router, e
/// os serviços de mentira: o login, a medida do cache, a fila e a conexão. O
/// banco é de verdade, em memória — o "Sair" conta os rascunhos nele.
class ProfileHarness {
  ProfileHarness() {
    PackageInfo.setMockInitialValues(
      appName: 'SIMTC',
      packageName: 'br.com.simtc.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    when(() => auth.currentUser).thenReturn(carla);
    when(() => auth.logout()).thenAnswer((_) async {});
    when(() => deviceData.downloadedBytes())
        .thenAnswer((_) async => canvasCacheBytes);
    when(() => deviceData.clearDownloaded()).thenAnswer((_) async {});
  }

  final MockAuthRepository auth = MockAuthRepository();
  final MockDeviceData deviceData = MockDeviceData();
  final AppDatabase db = AppDatabase(DatabaseConnection(
    NativeDatabase.memory(),
    closeStreamsSynchronously: true,
  ));
  ConnectivityService connectivity = ConnectivityService();
  late FakeAssessmentSyncService sync;

  final DateTime now = DateTime(2026, 10, 24, 9);

  Future<void> dispose() async {
    connectivity.dispose();
    await db.close();
  }

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

  /// Um rascunho de [owner] no banco: o "Sair" conta as avaliações iniciadas.
  Future<void> seedDraft({String owner = 'user-1', String participantId = 'tp-9'}) {
    return db.into(db.localAssessments).insert(LocalAssessmentsCompanion.insert(
          id: 'draft-$participantId',
          trainingParticipantId: participantId,
          sessionId: 'sess-1',
          date: DateTime(2026, 10, 24),
          startTime: DateTime(2026, 10, 24, 8),
          syncStatus: LocalSyncStatus.draft,
          createdAt: DateTime(2026, 10, 24, 8),
          updatedAt: DateTime(2026, 10, 24, 8),
          ownerUserId: Value(owner),
        ));
  }

  Future<void> pump(
    WidgetTester tester, {
    List<LocalAssessment> queue = const [],
    DateTime? lastSyncedAt,
    Size size = const Size(412, 915),
    FormFactor formFactor = FormFactor.phone,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    sync = FakeAssessmentSyncService(queue: queue, lastSyncedAt: lastSyncedAt);
    final router = GoRouter(
      initialLocation: AppRoutes.profile,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: AppRoutes.profile,
          builder: (context, state) => ProfileScreen(clock: () => now),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthRepository>.value(value: auth),
          Provider<AssessmentRepository>.value(
            value: AssessmentRepository(database: db),
          ),
          Provider<DeviceDataService>.value(value: deviceData),
          ChangeNotifierProvider<AssessmentSyncService>.value(value: sync),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
        ],
        child: FormFactorScope(
          formFactor: formFactor,
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Uma das quatro linhas: `role`, `sync`, `cache` ou `version`.
  static Finder row(String name) => find.byKey(Key('profile-row-$name'));
}
