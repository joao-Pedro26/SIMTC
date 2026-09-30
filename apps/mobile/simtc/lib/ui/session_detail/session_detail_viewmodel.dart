import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/auth_user.dart';
import '../../data/models/session_participant.dart';
import '../../data/models/training_session.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/api/api_exception.dart';
import '../../data/services/connectivity_service.dart';
import '../../data/services/local/app_database.dart';
import '../../utils/result.dart';
import 'participant_filter.dart';

/// Estado da tela 1.4 "Detalhe da sessão".
///
/// Como na Home, nada vem da resposta HTTP: a sessão e os participantes
/// chegam pelos streams do cache, e o sync é um efeito colateral que o
/// atualiza. As regras de quem pode fazer o quê espelham o `getAction` do
/// painel web (`session-management-drawer.tsx`): atribuir e abrir o checklist
/// só com a sessão em andamento; o resultado abre sempre.
///
/// As avaliações deste aparelho (Fase 5A) vêm de outro stream: o rascunho
/// põe o cronômetro na linha, e a avaliação confirmada troca o chip por
/// "Na fila"/"Erro no envio" até o servidor responder — e por "Enviada" até a
/// sessão ser baixada de novo (revisão de 30/09/2026).
class SessionDetailViewModel extends ChangeNotifier {
  SessionDetailViewModel({
    required this.sessionId,
    required SessionRepository sessionRepository,
    required ParticipantRepository participantRepository,
    required AssessmentRepository assessmentRepository,
    required ConnectivityService connectivity,
    required AuthUser? currentUser,
    DateTime Function()? now,
  })  : _sessionRepository = sessionRepository,
        _participantRepository = participantRepository,
        _assessmentRepository = assessmentRepository,
        _connectivity = connectivity,
        _currentUser = currentUser,
        _now = now ?? DateTime.now;

  final String sessionId;
  final SessionRepository _sessionRepository;
  final ParticipantRepository _participantRepository;
  final AssessmentRepository _assessmentRepository;
  final ConnectivityService _connectivity;
  final AuthUser? _currentUser;
  final DateTime Function() _now;

  static const String _refreshFailed =
      'Não foi possível atualizar os participantes.';
  static const String _assignFailed =
      'Não foi possível atribuir o participante. Tente de novo.';
  static const String _startFailed =
      'Não foi possível iniciar a sessão. Tente de novo.';

  StreamSubscription<TrainingSession?>? _sessionSubscription;
  StreamSubscription<List<SessionParticipant>>? _participantsSubscription;
  StreamSubscription<List<LocalAssessment>>? _localSubscription;
  StreamSubscription<void>? _reconnectSubscription;

  TrainingSession? _session;
  List<SessionParticipant> _participants = const [];
  Map<String, LocalAssessment> _local = const {};
  bool _sessionLoaded = false;
  bool _participantsLoaded = false;
  bool _isRefreshing = false;
  bool _isStarting = false;
  String? _assigningParticipantId;
  ParticipantFilter _filter = ParticipantFilter.todos;
  String? _message;

  // A tela pode ser fechada enquanto um sync/assign/start ainda está em voo
  // (são todos `unawaited`). Sem esta guarda, o `finally` desses métodos
  // chama notifyListeners depois do dispose, o que derruba o app em debug.
  bool _disposed = false;

  // Se um refresh chega enquanto outro já está em andamento, ele hoje é
  // simplesmente descartado. Isso perde o resync de pós-ação (assign/start),
  // que existe justamente para sobrescrever o palpite otimista local com o
  // estado oficial do servidor — sem ele, uma resposta atrasada do refresh
  // anterior pode chegar depois e desfazer a atribuição na tela.
  bool _refreshQueued = false;

  /// Nula depois de carregada quer dizer que a sessão não está mais no
  /// aparelho (a Home podou, por exemplo).
  TrainingSession? get session => _session;
  ParticipantFilter get filter => _filter;
  bool get isRefreshing => _isRefreshing;
  bool get isStarting => _isStarting;

  /// Participante com atribuição em andamento — só um de cada vez.
  String? get assigningParticipantId => _assigningParticipantId;

  /// Aviso passageiro (SnackBar) — sucesso ou falha de uma ação.
  String? get message => _message;

  /// Relógio da tela — injetável para os testes de "hoje 08:12".
  DateTime get now => _now();

  String? get myConsultantId => _currentUser?.consultantId;

  /// Um ADMIN sem perfil de consultor acompanha a sessão, mas não avalia — o
  /// backend recusa a atribuição, e o web também esconde a ação.
  bool get hasConsultantProfile => myConsultantId != null;

  /// Os participantes desta sessão nunca foram baixados neste aparelho — que
  /// é diferente de "baixados, e a sessão não tem ninguém".
  bool get neverDownloaded => _session?.participantsSyncedAt == null;

  /// Antes da primeira leitura do cache é sempre carregamento. Depois, só
  /// enquanto a primeira descida dos participantes ainda está em andamento —
  /// sem isso, a tela diria "nenhum participante" enquanto baixa em 4G ruim.
  bool get isLoading =>
      !_sessionLoaded ||
      !_participantsLoaded ||
      (neverDownloaded && _participants.isEmpty && _isRefreshing);

  bool get hasParticipants => _participants.isNotEmpty;

  /// Atribuir e abrir o checklist só valem com a sessão em andamento.
  bool get evaluationOpen => _session?.status == SessionStatus.emAndamento;

  /// Iniciar é do ADMIN e do consultor responsável — a mesma checagem do
  /// backend em `POST /training-sessions/:id/start`.
  bool get canStartSession {
    final session = _session;
    if (session == null || session.status != SessionStatus.planejado) {
      return false;
    }
    if (_currentUser?.isAdmin == true) return true;
    return myConsultantId != null &&
        session.responsibleConsultantId == myConsultantId;
  }

  /// Há alguém que eu poderia atribuir agora — é quando o aviso de "atribuir
  /// precisa de internet" faz sentido.
  bool get hasPendingToAssign => _participants.any(canAssign);

  ParticipantProgress get progress => progressOf(_participants);

  Map<ParticipantFilter, int> get counts => {
        for (final filter in ParticipantFilter.values)
          filter: _participants
              .where((p) => matchesFilter(p, filter, myConsultantId))
              .length,
      };

  /// A lista do chip escolhido, na ordem do canvas.
  List<SessionParticipant> get visibleParticipants => sortForDisplay(
        _participants
            .where((p) => matchesFilter(p, _filter, myConsultantId))
            .toList(growable: false),
        myConsultantId,
      );

  ParticipantSituation situationFor(SessionParticipant participant) =>
      situationOf(participant, myConsultantId);

  bool canAssign(SessionParticipant participant) =>
      evaluationOpen &&
      hasConsultantProfile &&
      situationFor(participant) == ParticipantSituation.pending;

  /// A avaliação deste aparelho para o participante — só as do consultor
  /// logado.
  LocalAssessment? localAssessmentFor(String participantId) =>
      _local[participantId];

  /// Rascunho, na fila, com erro de envio ou já enviada (aguardando o
  /// próximo download) — só nas linhas "comigo".
  LocalProgress? localProgressFor(SessionParticipant participant) =>
      localProgressOf(
        situationFor(participant),
        _local[participant.id],
        _session?.participantsSyncedAt,
      );

  /// Uma avaliação confirmada espera o envio e não é mais editada (decisão
  /// de 29/09/2026): na fila, com erro ou já enviada, a linha não abre o
  /// checklist.
  bool opensChecklist(SessionParticipant participant) {
    if (!evaluationOpen) return false;
    if (situationFor(participant) != ParticipantSituation.mine) return false;
    final progress = localProgressFor(participant);
    return progress != LocalProgress.queued &&
        progress != LocalProgress.failed &&
        progress != LocalProgress.sent;
  }

  bool opensResult(SessionParticipant participant) {
    final situation = situationFor(participant);
    return situation == ParticipantSituation.approved ||
        situation == ParticipantSituation.needsReview;
  }

  /// Assina o cache e dispara o primeiro sync. Chamado uma vez pela tela.
  void init() {
    _sessionSubscription ??=
        _sessionRepository.watchSession(sessionId).listen((session) {
      _session = session;
      _sessionLoaded = true;
      notifyListeners();
    });

    _participantsSubscription ??= _participantRepository
        .watchBySession(sessionId)
        .listen((participants) {
      _participants = participants;
      _participantsLoaded = true;
      notifyListeners();
    });

    final ownerUserId = _currentUser?.id;
    if (ownerUserId != null) {
      _localSubscription ??= _assessmentRepository
          .watchSessionAssessments(sessionId, ownerUserId)
          .listen((rows) {
        _local = {for (final row in rows) row.trainingParticipantId: row};
        notifyListeners();
      });
    }

    _reconnectSubscription ??=
        _connectivity.onReconnected.listen((_) => refresh());

    unawaited(refresh());
  }

  void setFilter(ParticipantFilter value) {
    if (_filter == value) return;
    _filter = value;
    notifyListeners();
  }

  /// Abertura da tela, puxar para atualizar e volta da conexão caem aqui.
  Future<void> refresh() async {
    if (_disposed) return;

    if (_isRefreshing) {
      // Não perde o pedido: um refresh que chega no meio de outro (o resync
      // de pós-ação, por exemplo) é enfileirado, não descartado.
      _refreshQueued = true;
      return;
    }

    _isRefreshing = true;
    notifyListeners();

    try {
      final result = await _participantRepository.syncSession(sessionId);
      if (result case Failure(:final message)) {
        _message = message ?? _refreshFailed;
      }
    } catch (_) {
      // Rede de segurança: `syncSession` já devolve `Result` para todo erro
      // esperado. Sem ela, `_isRefreshing` travaria em `true`.
      _message = _refreshFailed;
    } finally {
      _isRefreshing = false;
      notifyListeners();
      // Roda o refresh que ficou pendente — mas não depois do dispose, senão
      // reinicia um sync que ninguém mais vai observar.
      if (_refreshQueued && !_disposed) {
        _refreshQueued = false;
        unawaited(refresh());
      }
    }
  }

  /// "Atribuir a mim". Depois da resposta, baixa o detalhe de novo: no
  /// sucesso, para ficar com o estado oficial; no conflito, para a linha
  /// mostrar com quem o participante está.
  Future<void> assign(String participantId) async {
    final user = _currentUser;
    final consultantId = user?.consultantId;
    if (_assigningParticipantId != null || user == null || consultantId == null) {
      return;
    }

    _assigningParticipantId = participantId;
    notifyListeners();

    var resync = false;
    try {
      final result = await _participantRepository.assign(
        participantId,
        consultantId: consultantId,
        consultantName: user.name,
      );
      switch (result) {
        case Success():
          _message = 'Participante atribuído a você.';
          resync = true;
        case Failure(:final exception, :final message):
          _message = message ?? _assignFailed;
          // Sem rede, o re-sync falharia do mesmo jeito e só empilharia um
          // segundo aviso em cima deste.
          resync = exception is! ApiException || !exception.isNetworkError;
      }
    } catch (_) {
      _message = _assignFailed;
    } finally {
      _assigningParticipantId = null;
      notifyListeners();
    }

    // A tela pode ter sido fechada enquanto a resposta ainda viajava.
    if (resync && !_disposed) unawaited(refresh());
  }

  /// "Iniciar sessão" — só o responsável ou um ADMIN chegam a ver o botão.
  Future<void> startSession() async {
    if (_isStarting || !canStartSession) return;

    _isStarting = true;
    notifyListeners();

    var resync = false;
    try {
      final result = await _sessionRepository.start(sessionId);
      switch (result) {
        case Success():
          _message = 'Sessão iniciada. Já dá para atribuir participantes.';
          resync = true;
        case Failure(:final message):
          _message = message ?? _startFailed;
      }
    } catch (_) {
      _message = _startFailed;
    } finally {
      _isStarting = false;
      notifyListeners();
    }

    // A tela pode ter sido fechada enquanto a resposta ainda viajava.
    if (resync && !_disposed) unawaited(refresh());
  }

  void clearMessage() {
    if (_message == null) return;
    _message = null;
    notifyListeners();
  }

  // Chamadas `unawaited` (sync, assign, start) podem terminar depois que a
  // tela já foi fechada; sem esta guarda, o `finally` delas chamaria
  // notifyListeners num ChangeNotifier morto.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionSubscription?.cancel();
    _participantsSubscription?.cancel();
    _localSubscription?.cancel();
    _reconnectSubscription?.cancel();
    super.dispose();
  }
}
