import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/assessment_catalog.dart';
import '../../data/models/remote_assessment.dart';
import '../../data/models/session_participant.dart';
import '../../data/models/training_session.dart';
import '../../data/repositories/assessment_catalog_repository.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/api/api_exception.dart';
import '../../data/services/connectivity_service.dart';
import '../../data/services/local/app_database.dart';
import '../../utils/result.dart';
import '../../utils/scoring.dart';
import '../checklist/checklist_sections.dart';
import '../core/date_labels.dart';
import 'result_details.dart';

/// De onde vêm os dados do Resultado (decisão de 01/10/2026).
enum ResultSource {
  /// A avaliação feita neste aparelho — ainda não aceita pelo servidor, ou
  /// aceita e o servidor não respondeu agora.
  device,

  /// `GET /practical-assessments/by-participant/:id`.
  server,

  /// Só a nota e o status que o cache da sessão guarda, sem as infrações.
  cacheOnly,
}

/// O aviso sobre os dados que a tela mostra (Parte 3 do desenho de
/// 01/10/2026).
enum ResultDataNotice {
  /// O servidor não respondeu, e a tela mostra a avaliação deste aparelho.
  deviceFallback,

  /// Sem rede, e o aparelho não tem a avaliação: as infrações chegam com a
  /// internet — a volta da conexão busca de novo, com a tela aberta.
  offline,

  /// O servidor falhou (5xx, resposta fora do formato), ou uma leitura do
  /// aparelho lançou — "Tentar novamente".
  serverFailed,

  /// O servidor não tem avaliação deste participante.
  notOnServer,
}

/// Estado da tela 1.8 Resultado (Fase 5B).
///
/// Uma avaliação deste aparelho ainda não aceita (na fila ou com erro de
/// envio) é mostrada com os dados do aparelho: o servidor ainda não a tem.
/// Nos outros casos, os dados vêm do servidor; se ele não responde, a
/// avaliação aceita deste aparelho, ou só a nota e o status do cache. Nada
/// novo é guardado no aparelho.
class ResultViewModel extends ChangeNotifier {
  ResultViewModel({
    required this.sessionId,
    required this.participantId,
    required this.ownerUserId,
    required this.justConfirmed,
    required AssessmentRepository assessmentRepository,
    required ParticipantRepository participantRepository,
    required AssessmentCatalogRepository catalogRepository,
    required SessionRepository sessionRepository,
    required ConnectivityService connectivity,
    this.consultantId,
    DateTime Function()? now,
  })  : _assessmentRepository = assessmentRepository,
        _participantRepository = participantRepository,
        _catalogRepository = catalogRepository,
        _sessionRepository = sessionRepository,
        _connectivity = connectivity,
        _now = now ?? DateTime.now;

  final String sessionId;
  final String participantId;

  /// `AuthUser.id` do consultor logado — o dono das avaliações do aparelho.
  final String ownerUserId;

  /// Aberta logo depois do "Confirmar" da tela 1.6: o rodapé é o "Próximo
  /// participante".
  final bool justConfirmed;

  /// `AuthUser.consultantId` do consultor logado — sem perfil de consultor
  /// não há "Reavaliar".
  final String? consultantId;

  final AssessmentRepository _assessmentRepository;
  final ParticipantRepository _participantRepository;
  final AssessmentCatalogRepository _catalogRepository;
  final SessionRepository _sessionRepository;
  final ConnectivityService _connectivity;
  final DateTime Function() _now;

  StreamSubscription<SessionParticipant?>? _participantSubscription;
  StreamSubscription<List<LocalAssessment>>? _localSubscription;
  StreamSubscription<TrainingSession?>? _sessionSubscription;
  StreamSubscription<void>? _reconnectSubscription;

  bool _disposed = false;
  bool _loading = true;
  TrainingSession? _session;
  SessionParticipant? _participant;
  LocalAssessment? _local;

  /// O stream das avaliações do aparelho já emitiu: daí em diante só ele
  /// escreve em [_local].
  bool _localFromStream = false;
  ResultSource? _source;
  ResultDataNotice? _dataNotice;
  List<ResultCategory>? _categories;
  double? _score;
  DateTime? _startTime;
  DateTime? _endTime;

  bool get isLoading => _loading;
  SessionParticipant? get participant => _participant;
  ResultSource? get source => _source;
  ResultDataNotice? get dataNotice => _dataNotice;

  /// Só a falha do servidor tem "Tentar novamente"; sem rede, o aviso já diz
  /// que as infrações chegam com a internet — e a volta dela busca sozinha
  /// ([init]).
  bool get canRetry => _dataNotice == ResultDataNotice.serverFailed;

  /// Nulo quando só há a nota e o status do cache ([ResultSource.cacheOnly]).
  List<ResultCategory>? get categories => _categories;

  int get infractionCount => infractionCountOf(_categories ?? const []);

  /// A nota da avaliação mostrada; sem ela (o backend ainda não calculou, ou
  /// só há o cache), a que o cache da sessão guarda.
  double? get score => _score ?? _participant?.score;

  /// Mesmo corte do backend (`getApprovalStatus`). Sem nota, o status do
  /// cache decide; nulo se nem ele diz.
  bool? get isApproved {
    final score = this.score;
    if (score != null) return getApprovalStatus(score) == 'APROVADO';
    return switch (_participant?.status) {
      ParticipantStatus.aprovado => true,
      ParticipantStatus.necessitaReavaliacao => false,
      _ => null,
    };
  }

  DateTime? get startTime => _startTime;
  DateTime? get endTime => _endTime;

  /// "Início 08:12 · Fim 08:31" — o mesmo formato da tela 1.6.
  String? get timesLabel {
    final start = _startTime;
    if (start == null) return null;
    final now = _now();
    final end = _endTime;
    final started = 'Início ${clockLabel(start, now)}';
    return end == null ? started : '$started · Fim ${clockLabel(end, now)}';
  }

  /// A situação de envio da avaliação deste aparelho, quando é ela que a
  /// tela mostra — a tela escolhe o tom do aviso por ela. Nula nos outros
  /// casos.
  LocalSyncStatus? get sendStatus {
    final local = _local;
    if (_source != ResultSource.device || local == null) return null;
    return local.syncStatus == LocalSyncStatus.draft ? null : local.syncStatus;
  }

  /// Como está o envio da avaliação deste aparelho, quando é ela que a tela
  /// mostra. Muda sozinho com a tela aberta.
  String? get sendNotice {
    final local = _local;
    if (_source != ResultSource.device || local == null) return null;
    final at = local.lastAttemptAt;
    final now = _now();
    return switch (local.syncStatus) {
      LocalSyncStatus.pendingSync =>
        'Na fila de envio — sai sozinha quando houver conexão.',
      LocalSyncStatus.error => '${[
          'Erro no envio',
          if (at != null) 'falhou ${atLabel(at, now)}',
          if (local.lastError != null) local.lastError!,
        ].join(' · ')}.',
      LocalSyncStatus.synced => at == null ? 'Enviada.' : 'Enviada ${atLabel(at, now)}.',
      LocalSyncStatus.draft => null,
    };
  }

  /// "Reavaliar" (decisão de 01/10/2026): só fora do "Confirmar", para quem
  /// está em "Necessita reavaliação", com perfil de consultor e sem avaliação
  /// deste aparelho esperando envio — essa é mais nova que a do servidor. E só
  /// com a sessão em andamento, como o detalhe e o painel web: numa sessão
  /// concluída, o envio da reavaliação sobrescreveria a avaliação que já
  /// embasou os certificados.
  ///
  /// O botão só abre o checklist em "não iniciada": quem reserva o
  /// participante é o "Iniciar avaliação" de lá (decisão de 06/10/2026).
  bool get canReevaluate {
    final local = _local;
    final waiting = local != null &&
        (local.syncStatus == LocalSyncStatus.pendingSync ||
            local.syncStatus == LocalSyncStatus.error);
    return !justConfirmed &&
        consultantId != null &&
        !waiting &&
        _session?.status == SessionStatus.emAndamento &&
        _participant?.status == ParticipantStatus.necessitaReavaliacao;
  }

  Future<void> init() async {
    _sessionSubscription ??=
        _sessionRepository.watchSession(sessionId).listen((session) {
      _session = session;
      notifyListeners();
    });
    _participantSubscription ??=
        _participantRepository.watchParticipant(participantId).listen((p) {
      _participant = p;
      notifyListeners();
    });
    _localSubscription ??= _assessmentRepository
        .watchSessionAssessments(sessionId, ownerUserId)
        .listen((rows) {
      _localFromStream = true;
      _local = rows
          .where((r) =>
              r.trainingParticipantId == participantId &&
              r.syncStatus != LocalSyncStatus.draft)
          .firstOrNull;
      notifyListeners();
    });
    // O aviso de "sem conexão" promete as infrações quando houver internet:
    // a volta da rede busca de novo. Os outros avisos não dependem dela.
    _reconnectSubscription ??= _connectivity.onReconnected.listen((_) {
      if (_dataNotice == ResultDataNotice.offline) unawaited(_load());
    });
    await _load();
  }

  /// "Tentar novamente", depois de uma falha do servidor.
  Future<void> retry() async {
    if (_loading) return;
    await _load();
  }

  Future<void> _load() async {
    _loading = true;
    _dataNotice = null;
    notifyListeners();

    try {
      final local = await _ownLocal();
      final catalog = await _catalogRepository.loadCatalog();
      if (_disposed) return;
      // O stream é o dono de `_local` assim que emite: esta leitura pode ser
      // mais velha que a última emissão dele (o envio foi aceito no meio do
      // caminho), e o aviso de envio ficaria velho até a próxima escrita.
      if (!_localFromStream) _local = local;

      if (local != null && local.syncStatus != LocalSyncStatus.synced) {
        // Confirmada e ainda não aceita: o servidor ainda não tem esta.
        await _showDevice(local, catalog);
      } else {
        final result = await _participantRepository.fetchAssessment(participantId);
        if (_disposed) return;
        switch (result) {
          case Success(data: final remote?):
            _showServer(remote, catalog);
          case Success():
            _showCacheOnly(ResultDataNotice.notOnServer);
          case Failure(:final exception):
            if (local != null) {
              await _showDevice(local, catalog);
              _dataNotice = ResultDataNotice.deviceFallback;
            } else {
              final offline = exception is ApiException && exception.isNetworkError;
              _showCacheOnly(offline ? ResultDataNotice.offline : ResultDataNotice.serverFailed);
            }
        }
      }
    } catch (_) {
      // Uma leitura do aparelho lançou: fica o que o cache tem, com o "Tentar
      // novamente". Sem isto a exceção escaparia do `init`, a tela ficaria
      // carregando e o `retry` não faria nada.
      _showCacheOnly(ResultDataNotice.serverFailed);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// A avaliação confirmada deste aparelho, do consultor logado.
  Future<LocalAssessment?> _ownLocal() async {
    final local = await _assessmentRepository.findByParticipant(participantId);
    if (local == null || local.syncStatus == LocalSyncStatus.draft) return null;
    return local.ownerUserId == ownerUserId ? local : null;
  }

  Future<void> _showDevice(LocalAssessment local, List<CatalogCategory> catalog) async {
    final items = await _assessmentRepository.loadItems(local.id);
    _source = ResultSource.device;
    _categories = resultFromLocal(catalog, items);
    _score = local.score ?? overallScoreOf(buildChecklistSections(catalog, items));
    _startTime = local.startTime;
    _endTime = local.endTime;
  }

  void _showServer(RemoteAssessment remote, List<CatalogCategory> catalog) {
    _source = ResultSource.server;
    _categories = resultFromRemote(catalog, remote);
    _score = remote.score;
    _startTime = remote.startTime;
    _endTime = remote.endTime;
  }

  void _showCacheOnly(ResultDataNotice notice) {
    _source = ResultSource.cacheOnly;
    _categories = null;
    _score = null;
    _startTime = null;
    _endTime = null;
    _dataNotice = notice;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionSubscription?.cancel();
    _participantSubscription?.cancel();
    _localSubscription?.cancel();
    _reconnectSubscription?.cancel();
    super.dispose();
  }
}
