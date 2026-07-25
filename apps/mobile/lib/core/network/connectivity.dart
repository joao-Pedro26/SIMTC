import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity.g.dart';

@riverpod
Stream<bool> isOnline(IsOnlineRef ref) {
  return Connectivity().onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
}
