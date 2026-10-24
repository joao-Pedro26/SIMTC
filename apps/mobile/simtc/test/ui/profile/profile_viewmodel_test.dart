import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/repositories/assessment_repository.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/services/device_data_service.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/profile/profile_viewmodel.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockDeviceData extends Mock implements DeviceDataService {}

void main() {
  const carla = AuthUser(
    id: 'user-1',
    name: 'Carla Mendes',
    email: 'carla.mendes@simtreinamentos.com.br',
    role: AppUserRole.consultant,
  );

  late _MockAuthRepository auth;
  late _MockDeviceData deviceData;
  late AppDatabase db;
  late AssessmentRepository assessments;

  setUp(() {
    auth = _MockAuthRepository();
    deviceData = _MockDeviceData();
    db = AppDatabase(NativeDatabase.memory());
    assessments = AssessmentRepository(database: db);
    when(() => auth.currentUser).thenReturn(carla);
    when(() => deviceData.downloadedBytes()).thenAnswer((_) async => 2048);
    when(() => deviceData.clearDownloaded()).thenAnswer((_) async {});
    when(() => auth.logout()).thenAnswer((_) async {});
  });

  tearDown(() => db.close());

  ProfileViewModel build({Future<String> Function()? loadVersion}) {
    final vm = ProfileViewModel(
      auth: auth,
      assessments: assessments,
      deviceData: deviceData,
      loadVersion: loadVersion ?? () async => '1.0.0 (1)',
    );
    addTearDown(vm.dispose);
    return vm;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('mostra quem entrou, a versão e o espaço do cache', () async {
    final vm = build()..init();
    expect(vm.user, carla);
    expect(vm.version, isNull);
    expect(vm.cacheBytes, isNull);

    await settle();

    expect(vm.version, '1.0.0 (1)');
    expect(vm.cacheBytes, 2048);
  });

  test('uma falha ao ler a versão ou medir o cache deixa o valor vazio',
      () async {
    when(() => deviceData.downloadedBytes()).thenThrow(Exception('disco'));
    final vm = build(loadVersion: () async => throw Exception('plugin'))..init();

    await settle();

    expect(vm.version, isNull);
    expect(vm.cacheBytes, isNull);
  });

  test('limpar o cache apaga, mede de novo e devolve que limpou', () async {
    final gate = Completer<void>();
    when(() => deviceData.clearDownloaded()).thenAnswer((_) => gate.future);
    final vm = build()..init();
    await settle();

    final clearing = vm.clearCache();
    expect(vm.isClearing, isTrue);
    when(() => deviceData.downloadedBytes()).thenAnswer((_) async => 512);
    gate.complete();

    expect(await clearing, isTrue);
    expect(vm.isClearing, isFalse);
    expect(vm.cacheBytes, 512);
  });

  test('uma falha ao limpar devolve que não limpou', () async {
    when(() => deviceData.clearDownloaded()).thenThrow(Exception('disco'));
    final vm = build();

    expect(await vm.clearCache(), isFalse);
    expect(vm.isClearing, isFalse);
  });

  test('conta as avaliações iniciadas de quem entrou', () async {
    Future<void> draft(String participantId, String owner, LocalSyncStatus status) {
      return db.into(db.localAssessments).insert(LocalAssessmentsCompanion.insert(
            id: 'a-$participantId',
            trainingParticipantId: participantId,
            sessionId: 'sess-1',
            date: DateTime(2026, 10, 24),
            startTime: DateTime(2026, 10, 24, 8),
            syncStatus: status,
            createdAt: DateTime(2026, 10, 24, 8),
            updatedAt: DateTime(2026, 10, 24, 8),
            ownerUserId: Value(owner),
          ));
    }

    await draft('tp-1', 'user-1', LocalSyncStatus.draft);
    await draft('tp-2', 'user-1', LocalSyncStatus.pendingSync);
    await draft('tp-3', 'user-2', LocalSyncStatus.draft);

    expect(await build().countStartedDrafts(), 1);
  });

  test('sem ninguém logado, nenhuma avaliação iniciada', () async {
    when(() => auth.currentUser).thenReturn(null);

    expect(await build().countStartedDrafts(), 0);
  });

  test('sair chama o logout e devolve que saiu', () async {
    final gate = Completer<void>();
    when(() => auth.logout()).thenAnswer((_) => gate.future);
    final vm = build();

    final leaving = vm.logout();
    expect(vm.isLoggingOut, isTrue);
    gate.complete();

    expect(await leaving, isTrue);
    expect(vm.isLoggingOut, isFalse);
    verify(() => auth.logout()).called(1);
  });

  test('uma falha ao sair devolve que não saiu', () async {
    when(() => auth.logout()).thenThrow(Exception('keystore'));
    final vm = build();

    expect(await vm.logout(), isFalse);
    expect(vm.isLoggingOut, isFalse);
  });

  test('dois toques no "Sair" chamam o logout uma vez só', () async {
    final gate = Completer<void>();
    when(() => auth.logout()).thenAnswer((_) => gate.future);
    final vm = build();

    final first = vm.logout();
    expect(await vm.logout(), isFalse);
    gate.complete();
    await first;

    verify(() => auth.logout()).called(1);
  });

  test('a tela fechada com a medida no ar não recebe aviso depois', () async {
    final gate = Completer<int>();
    when(() => deviceData.downloadedBytes()).thenAnswer((_) => gate.future);
    final vm = ProfileViewModel(
      auth: auth,
      assessments: assessments,
      deviceData: deviceData,
      loadVersion: () async => '1.0.0 (1)',
    )..init();
    await settle();

    vm.dispose();
    gate.complete(10);
    await settle();

    expect(vm.cacheBytes, 10);
  });
}
