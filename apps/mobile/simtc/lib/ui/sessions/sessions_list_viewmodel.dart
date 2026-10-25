import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/training_session.dart';
import '../../data/repositories/assessment_catalog_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/connectivity_service.dart';
import '../../utils/result.dart';
import '../core/list_search.dart';
import '../core/search_text.dart';
import 'session_filter.dart';

/// Estado da tela 1.3 "Minhas sessões".
///
/// A lista nunca vem da resposta HTTP: chega pelo stream do cache. O sync é um
/// efeito colateral que atualiza o cache — se falhar, a tela continua com o que
/// tem e só ganha uma mensagem.
///
/// As três seções (Hoje, Esta semana, Concluídas) estão sempre todas
/// presentes — os chips não filtram, só marcam qual seção está em foco (a
/// tela usa isso pra saber pra onde rolar e qual chip destacar).
class SessionsListViewModel extends ChangeNotifier with ListSearch {
  SessionsListViewModel({
    required SessionRepository repository,
    required AssessmentCatalogRepository catalog,
    required ConnectivityService connectivity,
    DateTime Function()? now,
  })  : _repository = repository,
        _catalog = catalog,
        _connectivity = connectivity,
        _now = now ?? DateTime.now;

  final SessionRepository _repository;
  final AssessmentCatalogRepository _catalog;
  final ConnectivityService _connectivity;
  final DateTime Function() _now;

  StreamSubscription<List<TrainingSession>>? _sessionsSubscription;
  StreamSubscription<DateTime?>? _syncedAtSubscription;
  StreamSubscription<void>? _reconnectSubscription;

  List<TrainingSession> _sessions = const [];
  SessionFilter _filter = SessionFilter.hoje;
  final Map<SessionBlockId, int> _visibleCounts = {};
  bool _hasLoadedOnce = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  DateTime? _lastSyncedAt;

  // A Home é fechada no "Sair" com o sync da abertura ainda no ar (ele é
  // `unawaited`). Sem esta guarda, o `finally` do `refresh` chamaria
  // notifyListeners depois do dispose — a mesma da `SessionDetailViewModel`.
  bool _disposed = false;

  SessionFilter get filter => _filter;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;

  /// Quando o cache foi atualizado pela última vez — a faixa de offline usa
  /// isso para dizer a idade do que está na tela.
  DateTime? get lastSyncedAt => _lastSyncedAt;

  /// Antes da primeira leitura do cache, é sempre carregamento. Depois disso,
  /// mesmo vazia, a tela já sabe o que mostrar — e skeleton por cima de dados
  /// velhos esconderia justamente o que o consultor precisa ver quando está
  /// offline. A exceção é o cache vazio que nunca foi sincronizado (primeiro
  /// login): aí o stream do Drift emite `[]` na hora, e sem esta distinção a
  /// tela afirmaria "sem sessão nenhuma" enquanto o primeiro sync ainda
  /// baixa em 4G ruim — então o carregamento continua até ele terminar.
  bool get isLoading =>
      !_hasLoadedOnce ||
      (_sessions.isEmpty && _lastSyncedAt == null && _isRefreshing);

  /// As três seções, sempre nesta ordem, sempre as três — nunca escondidas.
  /// Com a busca filtrando, só as sessões da empresa buscada, e todas elas: nada de "Ver
  /// mais" no meio de um resultado (Fase 8B).
  List<SessionSection> get sections {
    if (!isFiltering) return buildSections(_sessions, _now(), _visibleCounts);

    final found = _sessions
        .where((s) => containsSearch(s.companyName, searchQuery))
        .toList(growable: false);
    return buildSections(found, _now(), {
      for (final id in SessionBlockId.values) id: found.length,
    });
  }

  Map<SessionFilter, int> get counts => {
        for (final filter in SessionFilter.values)
          filter: chipCountFor(_sessions, filter, _now()),
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

  /// Marca qual seção está em foco — não esconde nem revela nenhuma sessão,
  /// as três seções continuam sempre visíveis. A tela usa isto pra saber
  /// qual chip destacar; quem decide rolar a lista é a tela, não o VM.
  void setFilter(SessionFilter value) {
    if (_filter == value) return;
    _filter = value;
    notifyListeners();
  }

  /// Revela mais `sessionsPageSize` sessões no bloco pedido. Os dados já
  /// estão todos em memória — isto é paginação de exibição, não busca nova.
  void revealMore(SessionBlockId id) {
    _visibleCounts[id] =
        (_visibleCounts[id] ?? sessionsPageSize) + sessionsPageSize;
    notifyListeners();
  }

  /// Puxar para atualizar, abertura da tela e volta da conexão caem todos aqui.
  Future<void> refresh() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    _errorMessage = null;
    notifyListeners();

    // O catálogo de avaliação desce junto com a agenda (decisão de
    // 23/09/2026): é o que garante que ele já está no aparelho quando o
    // consultor perde o sinal no pátio. Corre em paralelo e em silêncio — o
    // puxar para atualizar não espera por ele, e a falha dele não vira
    // mensagem na Home; o próximo refresh tenta de novo.
    unawaited(_syncCatalog());

    try {
      final result = await _repository.syncAll();
      if (result case Failure(message: final message)) {
        _errorMessage = message ?? 'Não foi possível atualizar as sessões.';
      }
    } catch (_) {
      // `syncAll` já devolve `Result` para todo erro esperado; isto é uma
      // rede de segurança contra o que escapar dele. Sem ela, `_isRefreshing`
      // travaria em `true` e todo refresh seguinte (puxar, voltar a conexão,
      // reabrir a tela) cairia no guard-clause de início deste método.
      _errorMessage = 'Não foi possível atualizar as sessões.';
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> _syncCatalog() async {
    try {
      await _catalog.sync();
    } catch (_) {
      // `sync` já devolve `Result`; isto só impede que um erro inesperado
      // escape como exceção não tratada.
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionsSubscription?.cancel();
    _syncedAtSubscription?.cancel();
    _reconnectSubscription?.cancel();
    super.dispose();
  }
}
