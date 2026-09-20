import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/training_session.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/connectivity_service.dart';
import '../../utils/result.dart';
import 'session_filter.dart';

/// Estado da tela 1.3 "Minhas sessões".
///
/// A lista nunca vem da resposta HTTP: chega pelo stream do cache. O sync é um
/// efeito colateral que atualiza o cache — se falhar, a tela continua com o que
/// tem e só ganha uma mensagem.
class SessionsListViewModel extends ChangeNotifier {
  SessionsListViewModel({
    required SessionRepository repository,
    required ConnectivityService connectivity,
    DateTime Function()? now,
  })  : _repository = repository,
        _connectivity = connectivity,
        _now = now ?? DateTime.now;

  final SessionRepository _repository;
  final ConnectivityService _connectivity;
  final DateTime Function() _now;

  StreamSubscription<List<TrainingSession>>? _sessionsSubscription;
  StreamSubscription<DateTime?>? _syncedAtSubscription;
  StreamSubscription<void>? _reconnectSubscription;

  List<TrainingSession> _sessions = const [];
  SessionFilter _filter = SessionFilter.hoje;
  bool _hasLoadedOnce = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  DateTime? _lastSyncedAt;

  SessionFilter get filter => _filter;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;

  /// Quando o cache foi atualizado pela última vez — a faixa de offline usa
  /// isso para dizer a idade do que está na tela.
  DateTime? get lastSyncedAt => _lastSyncedAt;

  /// Só é carregamento antes da primeira leitura do cache. Depois disso, mesmo
  /// vazia, a tela já sabe o que mostrar — e skeleton por cima de dados velhos
  /// esconderia justamente o que o consultor precisa ver quando está offline.
  bool get isLoading => !_hasLoadedOnce;

  List<SessionGroup> get groups => groupSessions(_sessions, _filter, _now());

  Map<SessionFilter, int> get counts => {
        for (final filter in SessionFilter.values)
          filter: countFor(_sessions, filter, _now()),
      };

  /// Assina o cache e dispara o primeiro sync. Chamado uma vez pela tela.
  void init() {
    _sessionsSubscription ??= _repository.watchSessions().listen((sessions) {
      _sessions = sessions;
      _hasLoadedOnce = true;
      notifyListeners();
    });

    _syncedAtSubscription ??= _repository.watchLastSyncedAt().listen((value) {
      _lastSyncedAt = value;
      notifyListeners();
    });

    // A volta da conexão atualiza a agenda sem o consultor pedir: ele costuma
    // sair da área sem sinal já dentro do pátio, com o celular no bolso.
    _reconnectSubscription ??=
        _connectivity.onReconnected.listen((_) => refresh());

    unawaited(refresh());
  }

  void setFilter(SessionFilter value) {
    if (_filter == value) return;
    _filter = value;
    notifyListeners();
  }

  /// Puxar para atualizar, abertura da tela e volta da conexão caem todos aqui.
  Future<void> refresh() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.syncAll();

    _isRefreshing = false;
    if (result case Failure(message: final message)) {
      _errorMessage = message ?? 'Não foi possível atualizar as sessões.';
    }
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionsSubscription?.cancel();
    _syncedAtSubscription?.cancel();
    _reconnectSubscription?.cancel();
    super.dispose();
  }
}
