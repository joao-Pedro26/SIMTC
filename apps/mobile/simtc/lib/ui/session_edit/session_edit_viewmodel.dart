import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/auth_user.dart';
import '../../data/models/session_participant.dart';
import '../../data/models/training_session.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/api/api_exception.dart';
import '../../utils/result.dart';

/// Siglas das 27 unidades da federação. A UF digitada é conferida contra esta
/// lista — o backend aceita qualquer texto.
const Set<String> brazilianStates = {
  'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS', 'MG',
  'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE',
  'TO',
};

/// Estado da tela 1.12 "Dados do treinamento" (Fase 6A), só para ADMIN.
///
/// Os valores iniciais vêm do cache e são lidos uma vez: o que o admin digita
/// não é desfeito por uma atualização do cache que chegue com a tela aberta.
/// O status da sessão, esse sim, é acompanhado — se alguém a concluir ou
/// cancelar no meio, os campos travam. Só o campo que mudou vai ao servidor
/// (decisão de 06/10/2026): uma edição feita no painel web em outro campo
/// não é desfeita, e um valor antigo fora do padrão não trava o salvar.
class SessionEditViewModel extends ChangeNotifier {
  SessionEditViewModel({
    required this.sessionId,
    required SessionRepository sessionRepository,
    required ParticipantRepository participantRepository,
    required AuthUser? currentUser,
  })  : _sessionRepository = sessionRepository,
        _participantRepository = participantRepository,
        _currentUser = currentUser;

  final String sessionId;
  final SessionRepository _sessionRepository;
  final ParticipantRepository _participantRepository;
  final AuthUser? _currentUser;

  static const String _saveFailed =
      'Não foi possível salvar as alterações. Tente de novo.';
  static const String _cancelFailed =
      'Não foi possível cancelar a sessão. Tente de novo.';

  StreamSubscription<TrainingSession?>? _sessionSubscription;
  StreamSubscription<List<SessionParticipant>>? _participantsSubscription;

  bool _disposed = false;
  bool _loaded = false;
  TrainingSession? _session;

  /// A sessão como estava quando a tela abriu: a base do "o que mudou".
  TrainingSession? _initial;
  DateTime? _date;
  String _city = '';
  String _state = '';
  String _notes = '';
  int _inEvaluation = 0;
  bool _saving = false;
  bool _cancelling = false;
  String? _error;

  /// Antes da primeira leitura do cache.
  bool get isLoading => !_loaded;

  /// A sessão no cache agora. Nula depois de carregada quer dizer que ela não
  /// está mais no aparelho.
  TrainingSession? get session => _session;

  DateTime? get date => _date;
  String get city => _city;
  String get state => _state;
  String get notes => _notes;

  bool get isSaving => _saving;
  bool get isCancelling => _cancelling;

  /// Salvar e cancelar não correm juntos, nem duas vezes.
  bool get isBusy => _saving || _cancelling;

  /// Falha do último salvar ou cancelar, mostrada na própria tela; some
  /// quando o admin mexe num campo.
  String? get errorMessage => _error;

  /// Quantos participantes estão em avaliação agora, pelo cache — o aviso do
  /// diálogo de "Cancelar sessão".
  int get inEvaluationCount => _inEvaluation;

  /// Por que os campos estão travados; nulo quando dá para editar. O motivo
  /// fica escrito na tela — os campos nunca somem (canvas "3b").
  String? get lockedReason {
    if (_currentUser?.isAdmin != true) {
      return 'Só administradores podem alterar os dados do treinamento.';
    }
    final session = _session;
    if (session == null) {
      return 'Esta sessão não está mais disponível neste aparelho.';
    }
    if (session.status.acceptsChanges) return null;
    return session.status == SessionStatus.cancelado
        ? 'Sessão cancelada: os dados não podem mais ser alterados.'
        : 'Sessão concluída: os dados não podem mais ser alterados.';
  }

  bool get canEdit => _loaded && lockedReason == null;

  bool get _dateChanged {
    final before = _initial?.date;
    final now = _date;
    if (before == null || now == null) return before != now;
    return before.year != now.year ||
        before.month != now.month ||
        before.day != now.day;
  }

  // Aparados dos dois lados: espaço sobrando não é mudança, nem um valor
  // antigo que já veio com espaço do painel web.
  bool get _cityChanged => _city.trim() != (_initial?.city ?? '').trim();
  bool get _stateChanged => _state.trim() != (_initial?.state ?? '').trim();
  bool get _notesChanged => _notes.trim() != (_initial?.notes ?? '').trim();

  bool get isDirty =>
      _initial != null &&
      (_dateChanged || _cityChanged || _stateChanged || _notesChanged);

  /// Só o campo que mudou é conferido — o que veio do servidor fica como
  /// está, mesmo fora do padrão.
  String? get cityError =>
      _cityChanged && _city.trim().isEmpty ? 'Informe a cidade.' : null;

  String? get stateError =>
      _stateChanged && !brazilianStates.contains(_state.trim().toUpperCase())
          ? 'UF inválida.'
          : null;

  bool get canSave =>
      canEdit && isDirty && cityError == null && stateError == null && !isBusy;

  /// Assina o cache. Chamado uma vez pela tela.
  void init() {
    _sessionSubscription ??=
        _sessionRepository.watchSession(sessionId).listen((session) {
      _session = session;
      _loaded = true;
      if (_initial == null && session != null) {
        _initial = session;
        _date = session.date;
        _city = session.city;
        _state = session.state;
        _notes = session.notes ?? '';
      }
      notifyListeners();
    });

    _participantsSubscription ??= _participantRepository
        .watchBySession(sessionId)
        .listen((participants) {
      _inEvaluation = participants
          .where((p) => p.status == ParticipantStatus.emAvaliacao)
          .length;
      notifyListeners();
    });
  }

  /// A data é de calendário: a hora que o seletor trouxer é descartada.
  void setDate(DateTime value) {
    _date = DateTime(value.year, value.month, value.day);
    _edited();
  }

  void setCity(String value) {
    _city = value;
    _edited();
  }

  void setState(String value) {
    _state = value;
    _edited();
  }

  void setNotes(String value) {
    _notes = value;
    _edited();
  }

  void _edited() {
    _error = null;
    notifyListeners();
  }

  /// "Salvar alterações". Devolve `true` quando o servidor aceitou: a tela
  /// fecha. Na falha, o motivo fica em [errorMessage] e nada do que foi
  /// digitado se perde.
  Future<bool> save() async {
    if (!canSave) return false;

    _saving = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _sessionRepository.update(
        sessionId,
        date: _dateChanged ? _date : null,
        city: _cityChanged ? _city.trim() : null,
        state: _stateChanged ? _state.trim().toUpperCase() : null,
        notes: _notesChanged ? _notes.trim() : null,
      );
      switch (result) {
        case Success():
          return true;
        case Failure(:final exception, :final message):
          _error = message ?? _saveFailed;
          _resyncIfRefused(exception);
          return false;
      }
    } catch (_) {
      _error = _saveFailed;
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// "Cancelar sessão" — a tela pede confirmação antes. Devolve `true`
  /// quando o servidor cancelou: a tela leva o admin de volta à lista.
  Future<bool> cancelSession() async {
    if (!canEdit || isBusy) return false;

    _cancelling = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _sessionRepository.cancel(sessionId);
      switch (result) {
        case Success():
          return true;
        case Failure(:final exception, :final message):
          _error = message ?? _cancelFailed;
          _resyncIfRefused(exception);
          return false;
      }
    } catch (_) {
      _error = _cancelFailed;
      return false;
    } finally {
      _cancelling = false;
      notifyListeners();
    }
  }

  /// O servidor recusou (403) ou não achou a sessão (404): alguém a concluiu,
  /// cancelou ou apagou. Baixar de novo põe o cache — e o status desta tela —
  /// em dia.
  void _resyncIfRefused(Exception exception) {
    if (exception is! ApiException) return;
    if (exception.statusCode == 403 || exception.statusCode == 404) {
      unawaited(_participantRepository.syncSession(sessionId));
    }
  }

  // Uma resposta pode chegar depois de a tela fechar; sem esta guarda, o
  // `finally` de salvar/cancelar chamaria notifyListeners num ChangeNotifier
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
    super.dispose();
  }
}
