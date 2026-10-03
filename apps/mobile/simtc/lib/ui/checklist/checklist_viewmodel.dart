import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/assessment_catalog.dart';
import '../../data/models/session_participant.dart';
import '../../data/repositories/assessment_catalog_repository.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/services/local/app_database.dart';
import '../../utils/scoring.dart';
import '../core/date_labels.dart';
import 'checklist_sections.dart';

/// Estado da tela do checklist (Fase 4).
///
/// O catálogo é lido uma vez (`loadCatalog`, sem stream — não muda durante a
/// avaliação); as marcações, sim, vêm de um stream, porque `toggleNote`
/// escreve no banco e a tela precisa reagir à própria escrita. Nada aqui fala
/// com o backend: a avaliação só é gravada no aparelho. Quem a põe na fila de
/// envio é o "Confirmar" da tela 1.6 (Fase 5A).
class ChecklistViewModel extends ChangeNotifier {
  ChecklistViewModel({
    required this.sessionId,
    required this.participantId,
    required this.ownerUserId,
    required AssessmentRepository assessmentRepository,
    required ParticipantRepository participantRepository,
    required AssessmentCatalogRepository catalogRepository,
    DateTime Function()? now,
  })  : _assessmentRepository = assessmentRepository,
        _participantRepository = participantRepository,
        _catalogRepository = catalogRepository,
        _now = now ?? DateTime.now;

  final String sessionId;
  final String participantId;

  /// `AuthUser.id` do consultor logado — o dono do rascunho.
  final String ownerUserId;
  final AssessmentRepository _assessmentRepository;
  final ParticipantRepository _participantRepository;
  final AssessmentCatalogRepository _catalogRepository;
  final DateTime Function() _now;

  static const String _discardFailed = 'Não foi possível descartar. Tente de novo.';

  StreamSubscription<SessionParticipant?>? _participantSubscription;
  StreamSubscription<List<LocalAssessmentItem>>? _itemsSubscription;

  bool _disposed = false;
  bool _loading = true;
  bool _starting = false;
  bool _discarding = false;
  String? _assessmentId;
  DateTime? _startTime;
  LocalSyncStatus? _status;
  String? _message;
  SessionParticipant? _participant;
  List<CatalogCategory> _catalog = const [];
  List<LocalAssessmentItem> _items = const [];
  String? _expandedCategoryId;
  String? _blockingParticipantId;
  String? _blockingName;

  bool get isLoading => _loading;
  SessionParticipant? get participant => _participant;
  String? get expandedCategoryId => _expandedCategoryId;

  /// A avaliação começou: há rascunho, hora de início e marcações. Antes disso,
  /// a tela mostra só o "Iniciar avaliação" — abrir um participante sem
  /// querer não grava nada (decisão de 29/09/2026).
  bool get isStarted => _assessmentId != null;

  /// O "Iniciar avaliação" está gravando.
  bool get isStarting => _starting;

  /// A avaliação já foi confirmada (na fila ou com erro de envio): o checklist
  /// mostra as marcações sem deixar mudar nada (decisão de 01/10/2026). O
  /// detalhe da sessão abre o Resultado nesses casos; aqui só se chega por
  /// outro caminho.
  bool get isConfirmed => _status != null && _status != LocalSyncStatus.draft;

  /// "Descartar avaliação" do menu ⋮: só com a avaliação iniciada e ainda em
  /// rascunho.
  bool get canDiscard => isStarted && !isConfirmed;

  /// O "Descartar avaliação" está apagando.
  bool get isDiscarding => _discarding;

  /// Aviso passageiro para a tela (SnackBar); limpo por [clearMessage].
  String? get message => _message;

  /// Outro participante deste consultor está em andamento: só uma avaliação
  /// por vez (decisão de 01/10/2026). A tela mostra o aviso e desabilita o
  /// "Iniciar avaliação".
  bool get isBlocked => !isStarted && _blockingParticipantId != null;

  /// Nome de quem está em andamento, para o aviso; nulo se o participante
  /// não está mais no aparelho.
  String? get blockingParticipantName => isBlocked ? _blockingName : null;

  List<ChecklistCategory> get sections =>
      buildChecklistSections(_catalog, _items);

  double get overallScore => overallScoreOf(sections);

  /// Mesmo corte do backend (`getApprovalStatus`): 70% ou mais. A barra do
  /// topo muda de cor quando a nota cai abaixo dele.
  bool get isApproved => getApprovalStatus(overallScore) == 'APROVADO';

  /// O catálogo nunca chegou a este aparelho (a descida junto com a Home
  /// falhou) — ou só tem itens sem id, que as seções descartam. Sem seção
  /// não há o que avaliar, e confirmar uma avaliação sem categoria nenhuma
  /// daria 100%, "Aprovado": a tela nem oferece o "Finalizar avaliação".
  bool get hasCatalog => sections.isNotEmpty;

  /// "Iniciada às 08:12" — a hora do "Iniciar avaliação"; nula antes dele.
  /// Não há cronômetro: o app só registra quando começou (30/09/2026).
  String? get startedText {
    final start = _startTime;
    return start == null ? null : startedLabel(start, _now());
  }

  /// Só lê: a avaliação em andamento, se houver, e o catálogo. Nada é gravado
  /// até o "Iniciar avaliação" ([start]).
  Future<void> init() async {
    _participantSubscription ??=
        _participantRepository.watchParticipant(participantId).listen((p) {
      _participant = p;
      notifyListeners();
    });

    final current = await _assessmentRepository.findCurrent(
      trainingParticipantId: participantId,
      ownerUserId: ownerUserId,
    );
    if (_disposed) return;
    // As marcações primeiro: o stream as entrega enquanto o catálogo carrega,
    // e a tela já abre com elas.
    if (current != null) {
      _attach(current);
    } else {
      await _checkBlock();
      if (_disposed) return;
    }

    _catalog = await _catalogRepository.loadCatalog();
    if (_disposed) return;
    if (current != null) _openFirstCategory();

    _loading = false;
    notifyListeners();
  }

  /// "Iniciar avaliação": grava o início agora e mostra o checklist. Sem
  /// catálogo não inicia — não há o que avaliar, e a tela nem mostra o botão.
  Future<void> start() async {
    if (isStarted || _starting || isBlocked || !hasCatalog) return;

    _starting = true;
    notifyListeners();
    try {
      final assessment = await _assessmentRepository.openDraft(
        trainingParticipantId: participantId,
        sessionId: sessionId,
        ownerUserId: ownerUserId,
      );
      if (_disposed) return;
      _attach(assessment);
      _openFirstCategory();
    } on EvaluationInProgressException catch (e) {
      // Outro participante começou depois de a tela abrir.
      await _block(e.trainingParticipantId);
    } finally {
      _starting = false;
      notifyListeners();
    }
  }

  /// "Descartar avaliação" (decisão de 01/10/2026): apaga o rascunho e as
  /// marcações, e a tela volta a "não iniciada" — o participante continua com
  /// o consultor. A tela pede confirmação antes.
  Future<void> discard() async {
    final assessmentId = _assessmentId;
    if (assessmentId == null || !canDiscard || _discarding) return;

    _discarding = true;
    notifyListeners();
    try {
      final discarded = await _assessmentRepository.discardDraft(assessmentId);
      if (_disposed) return;
      if (!discarded) {
        _message = _discardFailed;
        return;
      }
      _detach();
      await _checkBlock();
    } catch (_) {
      _message = _discardFailed;
    } finally {
      _discarding = false;
      notifyListeners();
    }
  }

  void clearMessage() {
    if (_message == null) return;
    _message = null;
    notifyListeners();
  }

  /// Só uma avaliação por vez: confere se outro participante do consultor
  /// está em andamento, para o aviso e o "Iniciar" desabilitado.
  Future<void> _checkBlock() async {
    _blockingParticipantId = null;
    _blockingName = null;
    final inProgress = await _assessmentRepository.findInProgressOther(
      ownerUserId: ownerUserId,
      exceptTrainingParticipantId: participantId,
    );
    if (inProgress != null) await _block(inProgress.trainingParticipantId);
  }

  /// Guarda quem está em andamento e o nome dele, para o aviso.
  Future<void> _block(String blockingParticipantId) async {
    _blockingParticipantId = blockingParticipantId;
    final other = await _participantRepository.findParticipant(blockingParticipantId);
    _blockingName = other?.name;
  }

  /// Liga a tela à avaliação em andamento: as marcações e a hora de início.
  void _attach(LocalAssessment assessment) {
    _assessmentId = assessment.id;
    _startTime = assessment.startTime;
    _status = assessment.syncStatus;

    _itemsSubscription ??=
        _assessmentRepository.watchItems(assessment.id).listen((items) {
      _items = items;
      notifyListeners();
    });
  }

  /// Desliga a tela da avaliação descartada: volta a "não iniciada".
  void _detach() {
    _itemsSubscription?.cancel();
    _itemsSubscription = null;
    _assessmentId = null;
    _startTime = null;
    _status = null;
    _items = const [];
    _expandedCategoryId = null;
  }

  /// Como no canvas: o checklist começa com a primeira categoria aberta.
  void _openFirstCategory() {
    final sections = this.sections;
    _expandedCategoryId = sections.isEmpty ? null : sections.first.id;
  }

  /// Acordeão de uma seção só — abrir outra fecha a anterior, como no canvas.
  void toggleCategory(String categoryId) {
    _expandedCategoryId = _expandedCategoryId == categoryId ? null : categoryId;
    notifyListeners();
  }

  /// Abre a categoria (fechando a que estava aberta) sem alternar: é a volta
  /// da tela 1.6, que abre o checklist na categoria que o consultor tocou.
  void expandCategory(String categoryId) {
    if (_expandedCategoryId == categoryId) return;
    _expandedCategoryId = categoryId;
    notifyListeners();
  }

  /// Aperta um dos 3 botões de nota. O mesmo botão já selecionado desmarca a
  /// infração (nenhuma nota); um botão diferente troca a nota.
  ///
  /// Usa a lista que `mark`/`unmark` devolvem, em vez de esperar o
  /// `_itemsSubscription` reagir — o stream de uma assinatura já aberta pode
  /// notificar um turno de evento depois da escrita, e a tela precisa
  /// mostrar o botão pressionado na hora.
  Future<void> toggleNote(String infractionId, String noteId) async {
    final assessmentId = _assessmentId;
    if (assessmentId == null || isConfirmed) return;

    final current = _items
        .where((i) => i.infractionId == infractionId)
        .map((i) => i.infractionNoteId)
        .firstOrNull;

    _items = current == noteId
        ? await _assessmentRepository.unmark(
            localAssessmentId: assessmentId,
            infractionId: infractionId,
          )
        : await _assessmentRepository.mark(
            localAssessmentId: assessmentId,
            infractionId: infractionId,
            infractionNoteId: noteId,
          );
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _participantSubscription?.cancel();
    _itemsSubscription?.cancel();
    super.dispose();
  }
}
