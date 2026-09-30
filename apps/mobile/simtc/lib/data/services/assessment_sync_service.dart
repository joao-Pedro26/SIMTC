import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../repositories/assessment_repository.dart';
import '../repositories/participant_repository.dart';
import 'api/api_client.dart';
import 'api/api_exception.dart';
import 'connectivity_service.dart';
import 'local/app_database.dart';

/// Motivo de uma falha de envio, do jeito que a aba Sincronizar e a linha do
/// participante mostram ("Falhou às 07:58 · sem conexão").
abstract final class SendFailure {
  static const String noConnection = 'sem conexão';
  static const String timeout = 'tempo esgotado';
  static const String serverDown = 'servidor indisponível';
  static const String refused = 'recusada pelo servidor';
}

/// Envia ao backend a fila de avaliações confirmadas (Fase 5A).
///
/// Um só para o app inteiro, criado no `AppDependencies`: o envio acontece de
/// qualquer tela. Quando envia (decisão de 29/09/2026):
/// - entra avaliação nova na fila — o "Confirmar" da tela 1.6, ou as que já
///   estavam no aparelho quando o consultor entra;
/// - a rede volta (`ConnectivityService.onReconnected`);
/// - o app volta do segundo plano, e nos botões da aba Sincronizar
///   ([syncNow]);
/// - depois de uma falha, sozinho, com espera crescente ([retryDelays]).
///
/// Um envio por vez, com a fila inteira num `POST /practical-assessments/sync`.
/// O backend responde 201 mesmo recusando itens, então o resultado é lido
/// item a item. Reenviar é seguro: o backend atualiza o registro do
/// participante em vez de criar outro.
class AssessmentSyncService extends ChangeNotifier {
  AssessmentSyncService({
    required ApiClient apiClient,
    required AssessmentRepository assessments,
    required ParticipantRepository participants,
    required ConnectivityService connectivity,
    required Listenable authChanges,
    required String? Function() currentUserId,
    DateTime Function()? now,
    this.retryDelays = defaultRetryDelays,
  })  : _api = apiClient,
        _assessments = assessments,
        _participants = participants,
        _connectivity = connectivity,
        _authChanges = authChanges,
        _currentUserId = currentUserId,
        _now = now ?? DateTime.now;

  final ApiClient _api;
  final AssessmentRepository _assessments;
  final ParticipantRepository _participants;
  final ConnectivityService _connectivity;

  /// Avisa quando o usuário logado muda (o `AuthRepository`) — a fila é de
  /// quem está logado.
  final Listenable _authChanges;

  /// `AuthUser.id` de quem está logado agora, ou nulo.
  final String? Function() _currentUserId;
  final DateTime Function() _now;

  /// Espera entre uma falha e a próxima tentativa; a última se repete.
  final List<Duration> retryDelays;

  static const List<Duration> defaultRetryDelays = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 10),
  ];

  static const String syncPath = '/practical-assessments/sync';

  StreamSubscription<List<LocalAssessment>>? _queueSubscription;
  StreamSubscription<DateTime?>? _lastSyncedSubscription;
  StreamSubscription<void>? _reconnectSubscription;
  Timer? _retryTimer;

  bool _started = false;
  bool _disposed = false;
  String? _userId;
  int _failures = 0;
  Future<void>? _running;
  bool _again = false;

  List<LocalAssessment> _queue = const [];
  Set<String> _sendingIds = const {};
  DateTime? _lastSyncedAt;

  /// A fila de quem está logado: confirmadas e ainda não aceitas, na ordem
  /// do "Confirmar".
  List<LocalAssessment> get queue => _queue;

  /// Um envio está no ar.
  bool get isSending => _running != null;

  /// A avaliação faz parte do envio no ar ("Enviando" na aba Sincronizar).
  bool isSendingItem(String localAssessmentId) =>
      _sendingIds.contains(localAssessmentId);

  /// Quando o último envio foi aceito — nulo se nada foi aceito ainda.
  DateTime? get lastSyncedAt => _lastSyncedAt;

  /// Começa a seguir o usuário logado, a fila dele e a conexão. Chamado uma
  /// vez, pelo `AppDependencies`.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    _authChanges.addListener(_onAuthChanged);
    _reconnectSubscription =
        _connectivity.onReconnected.listen((_) => unawaited(syncNow()));
    _onAuthChanged();
  }

  void _onAuthChanged() {
    final userId = _currentUserId();
    if (userId == _userId) return;

    _userId = userId;
    _failures = 0;
    _retryTimer?.cancel();
    _queueSubscription?.cancel();
    _lastSyncedSubscription?.cancel();
    _queue = const [];
    _lastSyncedAt = null;
    notifyListeners();

    if (userId != null) unawaited(_follow(userId));
  }

  Future<void> _follow(String userId) async {
    await _assessments.claimUnowned(userId);
    if (_disposed || _userId != userId) return;

    _queueSubscription = _assessments.watchQueue(userId).listen(_onQueue);
    _lastSyncedSubscription =
        _assessments.watchLastSyncedAt(userId).listen((at) {
      _lastSyncedAt = at;
      notifyListeners();
    });
  }

  void _onQueue(List<LocalAssessment> queue) {
    _queue = queue;
    notifyListeners();

    // Entrou avaliação nova (o "Confirmar", ou já estava no aparelho quando o
    // consultor entrou): envia. As que falharam esperam a próxima tentativa —
    // reenviar a cada mudança da fila seria tentar de novo sem espera nenhuma.
    final hasNew = queue.any((a) =>
        a.syncStatus == LocalSyncStatus.pendingSync && !_sendingIds.contains(a.id));
    if (hasNew) unawaited(syncNow());
  }

  /// Envia a fila agora, sem esperar a próxima tentativa. Sem rede, não tenta:
  /// a volta da rede chama de novo. Com um envio já no ar, repete no fim
  /// dele, para levar o que entrou na fila no meio do caminho.
  Future<void> syncNow() async {
    if (_disposed) return;

    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }

    final sending = _sendQueue();
    _running = sending;
    notifyListeners();
    try {
      await sending;
    } catch (error) {
      // Rede de segurança: os erros esperados já viram motivo na fila. Um
      // erro inesperado (do banco, por exemplo) não pode travar o envio.
      debugPrint('Envio da fila falhou: $error');
      _scheduleRetry();
    } finally {
      _running = null;
      _sendingIds = const {};
      notifyListeners();
    }

    if (_again && !_disposed) {
      _again = false;
      await syncNow();
    }
  }

  Future<void> _sendQueue() async {
    final userId = _userId;
    if (userId == null || _connectivity.isOffline) return;

    _retryTimer?.cancel();
    final batch = await _assessments.loadQueue(userId);
    if (batch.isEmpty) {
      _failures = 0;
      return;
    }

    _sendingIds = {for (final a in batch) a.id};
    notifyListeners();

    final results = <String, String?>{};
    try {
      final payload = await _assessments.syncPayload(batch);
      final response = await _api.post<List<dynamic>>(syncPath, data: payload);
      final outcome = _outcomeByParticipant(response.data);
      for (final assessment in batch) {
        final id = assessment.trainingParticipantId;
        results[assessment.id] =
            outcome.containsKey(id) ? outcome[id] : SendFailure.refused;
      }
    } on ApiException catch (error) {
      // Sessão encerrada no meio do envio: nada falhou por culpa da
      // avaliação. A fila espera o dono entrar de novo.
      if (error.statusCode == 401) return;
      final reason = _reasonFor(error);
      for (final assessment in batch) {
        results[assessment.id] = reason;
      }
    }

    await _assessments.saveSendResults(results, at: _now());

    if (results.values.any((failure) => failure != null)) {
      _scheduleRetry();
    } else {
      _failures = 0;
    }

    // O backend recalcula o score e muda o status do participante: baixa de
    // novo as sessões afetadas, para a linha virar Aprovado/Reavaliar.
    final sessions = {
      for (final a in batch)
        if (results[a.id] == null) a.sessionId,
    };
    for (final sessionId in sessions) {
      unawaited(_participants.syncSession(sessionId));
    }
  }

  /// `{trainingParticipantId: nulo se aceita, ou o motivo}`, da resposta do
  /// backend: `[{ trainingParticipantId, status: 'fulfilled' | 'rejected',
  /// error }]`. A mensagem crua da recusa vai só para o log.
  static Map<String, String?> _outcomeByParticipant(Object? body) {
    if (body is! List) return const {};
    final outcome = <String, String?>{};
    for (final item in body.whereType<Map<dynamic, dynamic>>()) {
      final id = item['trainingParticipantId'];
      if (id is! String) continue;
      if (item['status'] == 'fulfilled') {
        outcome[id] = null;
      } else {
        debugPrint('Avaliação de $id recusada: ${item['error']}');
        outcome[id] = SendFailure.refused;
      }
    }
    return outcome;
  }

  static String _reasonFor(ApiException error) {
    if (error.isTimeout) return SendFailure.timeout;
    if (error.isNetworkError) return SendFailure.noConnection;
    final status = error.statusCode;
    if (status != null && status >= 500) return SendFailure.serverDown;
    return SendFailure.refused;
  }

  void _scheduleRetry() {
    if (_disposed) return;
    final delay = retryDelays[math.min(_failures, retryDelays.length - 1)];
    _failures++;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => unawaited(syncNow()));
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_started) _authChanges.removeListener(_onAuthChanged);
    _retryTimer?.cancel();
    _queueSubscription?.cancel();
    _lastSyncedSubscription?.cancel();
    _reconnectSubscription?.cancel();
    super.dispose();
  }
}
