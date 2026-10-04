import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../utils/result.dart';
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
/// - depois do login, ou quando o app abre com sessão salva — a primeira
///   leitura da fila daquele usuário, com o que já estiver nela, `pendingSync`
///   ou `error` (uma falha de uma execução anterior não fica esperando o
///   timer da retentativa, que não sobrevive ao processo morrer);
/// - entra avaliação nova na fila depois disso — o "Confirmar" da tela 1.6;
/// - a rede volta (`ConnectivityService.onReconnected`);
/// - o app volta do segundo plano, e nos botões da aba Sincronizar
///   ([syncNow]);
/// - depois de uma falha, sozinho, com espera crescente ([retryDelays]).
///
/// Um envio por vez, com a fila inteira num `POST /practical-assessments/sync`.
/// O backend responde 201 mesmo recusando itens, então o resultado é lido
/// item a item. Reenviar é seguro: o backend atualiza o registro do
/// participante em vez de criar outro.
///
/// Depois de um envio aceito, a sessão é baixada de novo, para a linha do
/// participante sair de "comigo" no cache (revisão de 30/09/2026). Se esse
/// download falhar, a sessão fica pendente em [_sessionsToRefresh], e
/// qualquer novo [syncNow] — mesmo com a fila vazia — tenta baixá-la de novo,
/// uma sessão de cada vez.
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

  /// Sessões com envio aceito que ainda esperam ser baixadas de novo — porque
  /// o download de pós-envio ainda não rodou ou a tentativa anterior falhou.
  /// Enquanto uma sessão está aqui, a linha do participante mostra "Enviada"
  /// em vez do status do servidor (revisão de 30/09/2026).
  final Set<String> _sessionsToRefresh = {};

  /// Sessões de [_sessionsToRefresh] cujo download está em voo agora — evita
  /// baixar a mesma sessão duas vezes ao mesmo tempo.
  final Set<String> _refreshingSessions = {};

  /// Sessões aceitas de novo (outro participante confirmado depois) enquanto
  /// o download delas estava em voo. Esse download pode ter sido pedido antes
  /// do segundo envio: o sucesso dele não tira a sessão de [_sessionsToRefresh],
  /// e ela é baixada de novo assim que ele termina.
  final Set<String> _reacceptedInFlight = {};

  /// Liga em [_follow], antes de assinar a fila daquele usuário; [_onQueue]
  /// desliga ao consumir a primeira emissão. Só nela o que já está em `error`
  /// também dispara envio — nas seguintes, só item `pendingSync` novo.
  bool _firstQueueEmission = false;

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
    _firstQueueEmission = false;
    _sessionsToRefresh.clear();
    _reacceptedInFlight.clear();
    notifyListeners();

    if (userId != null) unawaited(_follow(userId));
  }

  Future<void> _follow(String userId) async {
    await _assessments.claimUnowned(userId);
    if (_disposed || _userId != userId) return;

    _firstQueueEmission = true;
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

    // Primeira leitura da fila deste usuário (login, ou app abrindo com
    // sessão salva): envia o que já estiver nela, pendente ou em erro de uma
    // execução anterior — o timer da retentativa não sobrevive ao processo
    // morrer. Da segunda emissão em diante, só item pendente novo dispara
    // envio — reenviar a cada mudança da fila tentaria de novo sem esperar.
    if (_firstQueueEmission) {
      _firstQueueEmission = false;
      if (queue.isNotEmpty) unawaited(syncNow());
      return;
    }

    final hasNew = queue.any((a) =>
        a.syncStatus == LocalSyncStatus.pendingSync && !_sendingIds.contains(a.id));
    if (hasNew) unawaited(syncNow());
  }

  /// "Descartar" da aba Sincronizar (decisão de 01/10/2026): apaga do
  /// aparelho a avaliação que o servidor recusou — só se ela ainda estiver
  /// recusada; uma reenviada e aceita no meio do caminho não é apagada, e
  /// falha de rede ou de servidor nunca é descartada (tenta de novo sozinha).
  /// Com um envio no ar não apaga e devolve `false`: a linha só muda quando o
  /// resultado chega, e o reenvio pode estar levando justo essa avaliação.
  /// A fila se atualiza pelo stream do banco.
  Future<bool> discardRefused(String localAssessmentId) async {
    if (isSending) return false;
    return _assessments.discardFailed(localAssessmentId, reason: SendFailure.refused);
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

    // Antes de mais nada, tenta de novo o download de pós-envio que ficou
    // pendente de uma rodada anterior — mesmo que esta não tenha nada para
    // enviar (revisão de 30/09/2026): é o "próximo gatilho" da retentativa.
    unawaited(_refreshPendingSessions());

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

    // O backend recalcula o score e muda o status do participante: as
    // sessões aceitas entram no conjunto de quem precisa ser baixado de novo,
    // para a linha virar Aprovado/Reavaliar (chip "Enviada" até lá).
    final accepted = {
      for (final a in batch)
        if (results[a.id] == null) a.sessionId,
    };
    if (accepted.isNotEmpty) {
      _reacceptedInFlight.addAll(accepted.intersection(_refreshingSessions));
      _sessionsToRefresh.addAll(accepted);
      unawaited(_refreshPendingSessions());
    }
  }

  /// Tenta de novo, um de cada vez, o download das sessões de
  /// [_sessionsToRefresh] que não estão sendo baixadas agora. Com sucesso, a
  /// sessão sai do conjunto; com falha ou exceção, fica para a próxima
  /// chamada — nunca duas rodadas baixando a mesma sessão ao mesmo tempo. Uma
  /// sessão aceita de novo durante o download dela ([_reacceptedInFlight])
  /// não sai do conjunto por esse download e é baixada de novo, sozinha, assim
  /// que ele termina.
  Future<void> _refreshPendingSessions() async {
    final targets = _sessionsToRefresh.difference(_refreshingSessions);
    if (targets.isEmpty) return;

    _refreshingSessions.addAll(targets);
    var again = false;
    try {
      for (final sessionId in targets) {
        var succeeded = false;
        try {
          final result = await _participants.syncSession(sessionId);
          succeeded = result is Success;
        } catch (_) {
          // Fica em _sessionsToRefresh: a próxima rodada tenta de novo.
        }
        if (_reacceptedInFlight.remove(sessionId)) {
          again = true;
        } else if (succeeded) {
          _sessionsToRefresh.remove(sessionId);
        }
      }
    } finally {
      _refreshingSessions.removeAll(targets);
    }
    if (again && !_disposed) unawaited(_refreshPendingSessions());
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
