import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/assessment_catalog.dart';
import '../../data/models/session_participant.dart';
import '../../data/repositories/assessment_catalog_repository.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/services/local/app_database.dart';
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
    this.tickInterval = const Duration(seconds: 1),
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

  /// Intervalo real do `Timer` do cronômetro — os testes passam um intervalo
  /// bem curto e avançam um relógio próprio (`now`) entre os ticks, em vez de
  /// usar `fake_async`: o `Timer` roda de verdade, só que rápido.
  final Duration tickInterval;

  StreamSubscription<SessionParticipant?>? _participantSubscription;
  StreamSubscription<List<LocalAssessmentItem>>? _itemsSubscription;
  Timer? _ticker;

  bool _disposed = false;
  bool _loading = true;
  bool _starting = false;
  String? _assessmentId;
  DateTime? _startTime;
  SessionParticipant? _participant;
  List<CatalogCategory> _catalog = const [];
  List<LocalAssessmentItem> _items = const [];
  String? _expandedCategoryId;

  bool get isLoading => _loading;
  SessionParticipant? get participant => _participant;
  String? get expandedCategoryId => _expandedCategoryId;

  /// A avaliação começou: há rascunho, cronômetro e marcações. Antes disso,
  /// a tela mostra só o "Iniciar avaliação" — abrir um participante sem
  /// querer não grava nada (decisão de 29/09/2026).
  bool get isStarted => _assessmentId != null;

  /// O "Iniciar avaliação" está gravando.
  bool get isStarting => _starting;

  List<ChecklistCategory> get sections =>
      buildChecklistSections(_catalog, _items);

  double get overallScore => overallScoreOf(sections);

  int get reviewedCount => sections.where((s) => s.isReviewed).length;
  int get totalCategories => sections.length;

  /// O catálogo nunca chegou a este aparelho (a descida junto com a Home
  /// falhou) — ou só tem itens sem id, que as seções descartam. Sem seção
  /// não há o que avaliar, e confirmar uma avaliação sem categoria nenhuma
  /// daria 100%, "Aprovado": a tela nem oferece o "Finalizar avaliação".
  bool get hasCatalog => sections.isNotEmpty;

  /// "00:12:34" desde o "Iniciar avaliação" — `00:00:00` antes dele.
  String get elapsedLabel {
    final start = _startTime;
    if (start == null) return '00:00:00';
    return stopwatchLabel(_now().difference(start));
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
    if (current != null) _attach(current);

    _catalog = await _catalogRepository.loadCatalog();
    if (_disposed) return;
    if (current != null) _openFirstCategory();

    _loading = false;
    notifyListeners();
  }

  /// "Iniciar avaliação": grava o início agora e mostra o checklist. Sem
  /// catálogo não inicia — não há o que avaliar, e a tela nem mostra o botão.
  Future<void> start() async {
    if (isStarted || _starting || !hasCatalog) return;

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
    } finally {
      _starting = false;
      notifyListeners();
    }
  }

  /// Liga a tela à avaliação em andamento: as marcações e o cronômetro.
  void _attach(LocalAssessment assessment) {
    _assessmentId = assessment.id;
    _startTime = assessment.startTime;

    _itemsSubscription ??=
        _assessmentRepository.watchItems(assessment.id).listen((items) {
      _items = items;
      notifyListeners();
    });

    _ticker ??= Timer.periodic(tickInterval, (_) => notifyListeners());
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
    if (assessmentId == null) return;

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
    _ticker?.cancel();
    _participantSubscription?.cancel();
    _itemsSubscription?.cancel();
    super.dispose();
  }
}
