import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/services/connectivity_service.dart';

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late _MockConnectivity connectivity;
  late StreamController<List<ConnectivityResult>> changes;
  late ConnectivityService service;

  setUp(() {
    connectivity = _MockConnectivity();
    changes = StreamController<List<ConnectivityResult>>.broadcast();
    when(() => connectivity.onConnectivityChanged).thenAnswer((_) => changes.stream);
    service = ConnectivityService(connectivity: connectivity);
  });

  tearDown(() async {
    service.dispose();
    await changes.close();
  });

  test('começa com o estado real do aparelho', () async {
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.none]);

    await service.initialize();

    expect(service.isOnline, isFalse);
    expect(service.isOffline, isTrue);
  });

  test('avisa os ouvintes quando a conexão cai', () async {
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.wifi]);
    await service.initialize();

    var notifications = 0;
    service.addListener(() => notifications++);

    changes.add([ConnectivityResult.none]);
    await Future<void>.delayed(Duration.zero);

    expect(service.isOnline, isFalse);
    expect(notifications, 1);
  });

  test('emite onReconnected só na volta da conexão', () async {
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.none]);
    await service.initialize();

    final reconnections = <void>[];
    service.onReconnected.listen(reconnections.add);

    changes.add([ConnectivityResult.mobile]);
    await Future<void>.delayed(Duration.zero);
    changes.add([ConnectivityResult.wifi]); // continua online: não emite de novo
    await Future<void>.delayed(Duration.zero);

    expect(reconnections, hasLength(1));
    expect(service.isOnline, isTrue);
  });
}
