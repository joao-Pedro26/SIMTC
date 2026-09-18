import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Estado de conectividade do aparelho, compartilhado por todo o app.
///
/// Criado uma única vez no `MultiProvider` (nunca dentro de uma tela), porque a
/// volta da conexão precisa ser percebida em qualquer lugar do app — é o gatilho
/// da sincronização automática a partir da Fase 5.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  final StreamController<void> _reconnectedController =
      StreamController<void>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;

  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  /// Emite quando o aparelho volta a ter rede (só na transição offline→online).
  Stream<void> get onReconnected => _reconnectedController.stream;

  Future<void> initialize() async {
    _apply(await _connectivity.checkConnectivity(), notify: false);
    _subscription = _connectivity.onConnectivityChanged.listen(_apply);
  }

  void _apply(List<ConnectivityResult> results, {bool notify = true}) {
    final isOnline = results.any((result) => result != ConnectivityResult.none);
    if (isOnline == _isOnline) return;

    final wasOffline = !_isOnline;
    _isOnline = isOnline;
    if (notify) notifyListeners();
    if (isOnline && wasOffline && !_reconnectedController.isClosed) {
      _reconnectedController.add(null);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _reconnectedController.close();
    super.dispose();
  }
}
