import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/auth_user.dart';
import '../../data/models/session_consultant.dart';
import '../../data/models/session_participant.dart';
import '../../data/models/training_session.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/repositories/session_consultant_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/api/api_exception.dart';
import '../../data/services/connectivity_service.dart';
import '../../utils/result.dart';
import '../core/date_labels.dart';
import '../core/name_sort.dart';

/// A segunda linha de quem está na sessão, pelos participantes deste
/// aparelho: "2 participantes · 1 em andamento", "2 participantes concluídos"
/// ou "Sem participantes" (canvas "3c").
String consultantMetaLabel({required int total, required int inProgress}) {
  if (total == 0) return 'Sem participantes';
  if (inProgress == 0) {
    return total == 1
        ? '1 participante concluído'
        : '$total participantes concluídos';
  }
  final people = total == 1 ? '1 participante' : '$total participantes';
  return '$people · $inProgress em andamento';
}

/// Uma linha de "Na sessão".
class SessionConsultantItem {
  const SessionConsultantItem({
    required this.id,
    required this.name,
    required this.displayName,
    required this.isResponsible,
    required this.meta,
    required this.inProgressCount,
    this.note,
  });

  /// `Consultant.id`.
  final String id;

  /// O nome puro, para os avisos ("Rafael Lima saiu da sessão.").
  final String name;

  /// O nome como a linha mostra: o do usuário logado leva "(você)".
  final String displayName;

  /// O responsável pela sessão não sai por aqui: trocar o responsável é do
  /// painel web.
  final bool isResponsible;
  final String meta;

  /// Quantos participantes estão em avaliação com ele agora.
  final int inProgressCount;

  /// O que acontece com essas avaliações se ele sair. Só quem pode sair tem.
  final String? note;

  bool get removable => !isResponsible;
}

/// Por que a equipe não está na tela.
enum _TeamFailure { none, unreachable, failed }

/// Estado da tela 1.13 "Consultores" (Fase 6B, canvas "3c"), só para ADMIN.
///
/// Quem está na sessão e os participantes vêm do cache, pelos streams; a
/// equipe vem do servidor a cada abertura e não fica guardada. Entrar e sair
/// valem na hora: um consultor por toque, e um toque de cada vez.
class SessionConsultantsViewModel extends ChangeNotifier {
  SessionConsultantsViewModel({
    required this.sessionId,
    required SessionRepository sessionRepository,
    required ParticipantRepository participantRepository,
    required SessionConsultantRepository consultantRepository,
    required ConnectivityService connectivity,
    required AuthUser? currentUser,
  })  : _sessionRepository = sessionRepository,
        _participantRepository = participantRepository,
        _consultantRepository = consultantRepository,
        _connectivity = connectivity,
        _currentUser = currentUser;

  final String sessionId;
  final SessionRepository _sessionRepository;
  final ParticipantRepository _participantRepository;
  final SessionConsultantRepository _consultantRepository;
  final ConnectivityService _connectivity;
  final AuthUser? _currentUser;

  static const String _addFailed =
      'Não foi possível adicionar o consultor. Tente de novo.';
  static const String _removeFailed =
      'Não foi possível remover o consultor. Tente de novo.';

  StreamSubscription<TrainingSession?>? _sessionSubscription;
  StreamSubscription<List<SessionParticipant>>? _participantsSubscription;
  StreamSubscription<List<SessionConsultant>>? _consultantsSubscription;
  StreamSubscription<void>? _reconnectSubscription;

  bool _disposed = false;
  bool _sessionLoaded = false;
  bool _participantsLoaded = false;
  bool _consultantsLoaded = false;
  TrainingSession? _session;
  List<SessionParticipant> _participants = const [];
  List<SessionConsultant> _consultants = const [];

  /// Os consultores ativos da equipe. Nulo enquanto não chegaram.
  List<SessionConsultant>? _team;
  bool _teamLoading = false;
  _TeamFailure _teamFailure = _TeamFailure.none;

  /// Um download da sessão está no ar; e se, enquanto isso, chegou outro
  /// pedido, ele espera. Quantos chegaram no meio não importa: baixa uma vez.
  bool _isResyncing = false;
  bool _resyncQueued = false;

  String? _busyConsultantId;
  String? _error;
  String? _message;

  /// Antes da primeira leitura do cache.
  bool get isLoading =>
      !_sessionLoaded || !_participantsLoaded || !_consultantsLoaded;

  /// Nula depois de carregada quer dizer que a sessão não está mais no
  /// aparelho.
  TrainingSession? get session => _session;

  /// "Bracell · 12 set", a primeira linha da faixa de contexto.
  String get contextTitle {
    final session = _session;
    if (session == null) return '';
    final date = session.date;
    return date == null
        ? session.companyName
        : '${session.companyName} · ${dayMonthLabel(date)}';
  }

  /// "5 participantes · 3 consultores". Sem os consultores no aparelho, só
  /// os participantes.
  String get contextSubtitle {
    final total = _session?.totalParticipants ?? 0;
    final people = total == 1 ? '1 participante' : '$total participantes';
    if (_consultants.isEmpty) return people;
    final count = _consultants.length;
    return '$people · ${count == 1 ? '1 consultor' : '$count consultores'}';
  }

  /// Os consultores desta sessão ainda não foram baixados neste aparelho —
  /// uma sessão que foi para o cache antes de o app guardar os consultores, e
  /// que ainda não foi aberta com conexão.
  bool get notDownloaded => !isLoading && _consultants.isEmpty;

  /// "Na sessão": o responsável primeiro, e os outros por nome.
  List<SessionConsultantItem> get inSession {
    final responsibleId = _session?.responsibleConsultantId;
    final sorted = [..._consultants]..sort((a, b) {
        final aFirst = a.id == responsibleId ? 0 : 1;
        final bFirst = b.id == responsibleId ? 0 : 1;
        if (aFirst != bFirst) return aFirst.compareTo(bFirst);
        return nameSortKey(a.name).compareTo(nameSortKey(b.name));
      });
    return [for (final consultant in sorted) _itemFor(consultant, responsibleId)];
  }

  SessionConsultantItem _itemFor(
    SessionConsultant consultant,
    String? responsibleId,
  ) {
    final inProgress = _participants
        .where((p) =>
            p.status == ParticipantStatus.emAvaliacao &&
            p.assignedConsultantId == consultant.id)
        .toList(growable: false);
    final concluded = _participants
        .where((p) => p.isAssessed && p.assessedByConsultantId == consultant.id)
        .length;
    final isResponsible = consultant.id == responsibleId;
    final isMe = consultant.id == _currentUser?.consultantId;

    return SessionConsultantItem(
      id: consultant.id,
      name: consultant.name,
      displayName: isMe ? '${consultant.name} (você)' : consultant.name,
      isResponsible: isResponsible,
      meta: consultantMetaLabel(
        total: inProgress.length + concluded,
        inProgress: inProgress.length,
      ),
      inProgressCount: inProgress.length,
      note: isResponsible ? null : _removalNote(inProgress),
    );
  }

  /// A mesma regra do backend ao liberar: quem nunca foi avaliado volta para
  /// "Pendente"; numa reavaliação, para o status da nota anterior ("Não
  /// recomendado" — aprovado não é reavaliado).
  String? _removalNote(List<SessionParticipant> inProgress) {
    if (inProgress.isEmpty) return null;
    if (inProgress.length > 1) {
      return 'Tem ${inProgress.length} avaliações em andamento. Remover '
          'libera esses participantes para outro consultor.';
    }
    final participant = inProgress.single;
    final status =
        participant.hasPreviousAssessment ? 'Não recomendado' : 'Pendente';
    return 'Tem 1 avaliação em andamento. Remover devolve '
        '${participant.name} para $status.';
  }

  /// "Disponíveis na equipe": os ativos que ainda não estão na sessão, por
  /// nome.
  List<SessionConsultant> get available {
    final team = _team;
    if (team == null) return const [];
    final inSession = {for (final consultant in _consultants) consultant.id};
    return team.where((c) => !inSession.contains(c.id)).toList(growable: false)
      ..sort((a, b) => nameSortKey(a.name).compareTo(nameSortKey(b.name)));
  }

  /// A primeira busca da equipe ainda não respondeu.
  bool get isTeamLoading => _teamLoading && _team == null;

  /// O que a tela escreve no lugar da equipe; nulo quando há lista (ou
  /// enquanto ela carrega).
  String? get teamNotice {
    if (_team != null) {
      return available.isEmpty
          ? 'Todos os consultores ativos da equipe já estão nesta sessão.'
          : null;
    }
    return switch (_teamFailure) {
      _TeamFailure.none => null,
      _TeamFailure.unreachable => 'A equipe aparece quando houver conexão.',
      _TeamFailure.failed =>
        'Não foi possível carregar a equipe. Puxe para atualizar.',
    };
  }

  /// Por que nada pode mudar; nulo quando pode. O motivo fica escrito na
  /// tela — os botões nunca somem, só apagam.
  String? get lockedReason {
    if (_currentUser?.isAdmin != true) {
      return 'Só administradores podem mudar os consultores da sessão.';
    }
    final session = _session;
    if (session == null) {
      return 'Esta sessão não está mais disponível neste aparelho.';
    }
    if (session.status.acceptsChanges) return null;
    return session.status == SessionStatus.cancelado
        ? 'Sessão cancelada: os consultores não podem mais ser alterados.'
        : 'Sessão concluída: os consultores não podem mais ser alterados.';
  }

  /// O backend só aceita mexer nos consultores de uma sessão planejada ou em
  /// andamento, e só de um ADMIN. A tela ainda exige conexão. Sem os
  /// consultores da sessão baixados ([notDownloaded]) a equipe inteira
  /// pareceria disponível, inclusive quem já está na sessão: nada muda.
  bool get canChange => !isLoading && !notDownloaded && lockedReason == null;

  /// O consultor que está entrando ou saindo agora — um de cada vez.
  String? get busyConsultantId => _busyConsultantId;

  /// Falha do último adicionar ou remover, mostrada na própria tela; some no
  /// próximo toque.
  String? get errorMessage => _error;

  /// Aviso passageiro (SnackBar): quem entrou ou saiu.
  String? get message => _message;

  /// Assina o cache, busca a equipe e baixa a sessão de novo. Chamado uma
  /// vez pela tela.
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

    _consultantsSubscription ??= _consultantRepository
        .watchBySession(sessionId)
        .listen((consultants) {
      _consultants = consultants;
      _consultantsLoaded = true;
      notifyListeners();
    });

    _reconnectSubscription ??=
        _connectivity.onReconnected.listen((_) => refresh());

    unawaited(refresh());
  }

  /// Abertura da tela, puxar para atualizar e volta da conexão caem aqui: a
  /// equipe vem de novo do servidor, e a sessão é baixada de novo — é dos
  /// participantes dela que saem a linha de apoio e o aviso de cada consultor.
  Future<void> refresh() async {
    await Future.wait([_loadTeam(), _resyncSession()]);
  }

  Future<void> _loadTeam() async {
    if (_teamLoading || _disposed) return;

    _teamLoading = true;
    notifyListeners();
    try {
      final result = await _consultantRepository.fetchTeam();
      switch (result) {
        case Success(:final data):
          _team = data;
          _teamFailure = _TeamFailure.none;
        case Failure(:final exception):
          // A equipe que já estava na tela fica: `teamNotice` só olha a
          // falha enquanto não há lista.
          _teamFailure = exception is ApiException && exception.isNetworkError
              ? _TeamFailure.unreachable
              : _TeamFailure.failed;
      }
    } catch (_) {
      _teamFailure = _TeamFailure.failed;
    } finally {
      _teamLoading = false;
      notifyListeners();
    }
  }

  /// Sem aviso na falha: a tela segue com o que o cache tem, e sem conexão a
  /// faixa do topo já diz por quê. Não passa pelo estado desta ViewModel — é
  /// só o cache que muda —, e por isso roda mesmo depois de a tela fechar: o
  /// detalhe, que fica embaixo, lê do mesmo cache.
  ///
  /// Um download por vez: `syncSession` troca consultores e participantes
  /// inteiros pelo que o GET trouxe, e um GET pedido antes de uma mudança
  /// aceita, se respondido depois dela, a desfaria no cache. O pedido que
  /// chega com outro no ar é enfileirado, não descartado — vários viram um
  /// só — e roda quando o do ar termina; assim a última gravação é a de
  /// depois da última mudança.
  Future<void> _resyncSession() async {
    if (_isResyncing) {
      _resyncQueued = true;
      return;
    }

    _isResyncing = true;
    try {
      await _participantRepository.syncSession(sessionId);
    } catch (_) {
      // `syncSession` já devolve `Result` para todo erro esperado.
    } finally {
      _isResyncing = false;
      // Sem olhar `_disposed`, de propósito: o pedido enfileirado depois de
      // uma mudança aceita tem de rodar mesmo com a tela já fechada.
      if (_resyncQueued) {
        _resyncQueued = false;
        unawaited(_resyncSession());
      }
    }
  }

  /// "Adicionar": põe na sessão um consultor da equipe.
  Future<void> add(String consultantId) async {
    final consultant =
        available.where((c) => c.id == consultantId).firstOrNull;
    if (consultant == null) return;

    await _change(
      consultantId,
      send: () => _consultantRepository.add(sessionId, consultantId),
      done: '${consultant.name} entrou na sessão.',
      fallback: _addFailed,
    );
  }

  /// "Remover da sessão". Quem estava em avaliação com o consultor é liberado
  /// pelo servidor na mesma operação; a tela pede confirmação antes, quando
  /// há alguém.
  Future<void> remove(String consultantId) async {
    final consultant = inSession
        .where((c) => c.id == consultantId && c.removable)
        .firstOrNull;
    if (consultant == null) return;

    await _change(
      consultantId,
      send: () => _consultantRepository.remove(sessionId, consultantId),
      done: '${consultant.name} saiu da sessão.',
      fallback: _removeFailed,
    );
  }

  Future<void> _change(
    String consultantId, {
    required Future<Result<void>> Function() send,
    required String done,
    required String fallback,
  }) async {
    if (!canChange || _busyConsultantId != null) return;

    _busyConsultantId = consultantId;
    _error = null;
    notifyListeners();

    var resync = false;
    var refused = false;
    try {
      final result = await send();
      switch (result) {
        case Success():
          _message = done;
          // O estado oficial: os consultores e, ao remover, quem foi liberado.
          resync = true;
        case Failure(:final exception, :final message):
          _error = message ?? fallback;
          refused = _isRefusal(exception);
          resync = refused;
      }
    } catch (_) {
      _error = fallback;
    } finally {
      _busyConsultantId = null;
      notifyListeners();
    }

    if (resync) unawaited(_resyncSession());
    // O consultor ficou inativo ou foi apagado: a equipe da tela está velha.
    if (refused) unawaited(_loadTeam());
  }

  /// O servidor respondeu que não: o que o aparelho tem está velho (a sessão
  /// foi concluída, o consultor ficou inativo, alguém já mexeu na lista).
  /// Sem rede e erro do servidor não dizem nada sobre o cache.
  bool _isRefusal(Exception exception) {
    if (exception is! ApiException) return false;
    return switch (exception.statusCode) {
      400 || 403 || 404 || 409 => true,
      _ => false,
    };
  }

  void clearMessage() {
    if (_message == null) return;
    _message = null;
    notifyListeners();
  }

  // Uma resposta pode chegar depois de a tela fechar; sem esta guarda, o
  // `finally` de adicionar/remover chamaria notifyListeners num ChangeNotifier
  // morto.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionSubscription?.cancel();
    _participantsSubscription?.cancel();
    _consultantsSubscription?.cancel();
    _reconnectSubscription?.cancel();
    super.dispose();
  }
}
