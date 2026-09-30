import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/assessment_catalog.dart';
import '../../data/models/session_participant.dart';
import '../../data/repositories/assessment_catalog_repository.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/services/local/app_database.dart';
import 'checklist_sections.dart';

/// Estado da tela do checklist (Fase 4).
///
/// O catálogo é lido uma vez (`loadCatalog`, sem stream — não muda durante a
/// avaliação); as marcações, sim, vêm de um stream, porque `toggleNote`
/// escreve no banco e a tela precisa reagir à própria escrita. Nada aqui fala
/// com o backend: a avaliação só é gravada no aparelho, e a fila de envio é de
/// uma fase futura.
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
  String? _assessmentId;
  DateTime? _startTime;
  SessionParticipant? _participant;
  List<CatalogCategory> _catalog = const [];
  List<LocalAssessmentItem> _items = const [];
  String? _expandedCategoryId;
  bool _finished = false;

  bool get isLoading => _loading;
  SessionParticipant? get participant => _participant;
  String? get expandedCategoryId => _expandedCategoryId;

  /// Uma vez `true`, a tela navega de volta ao detalhe da sessão — regra
  /// decidida com o usuário em 26/09/2026: finalizar marca local e volta.
  bool get isFinished => _finished;

  List<ChecklistCategory> get sections =>
      buildChecklistSections(_catalog, _items);

  double get overallScore => overallScoreOf(sections);

  int get reviewedCount => sections.where((s) => s.isReviewed).length;
  int get totalCategories => sections.length;
  int get unreviewedCount => totalCategories - reviewedCount;

  /// Há categoria sem nenhuma infração marcada — só então o "Finalizar
  /// avaliação" pede confirmação (roteiro da Fase 4).
  bool get hasUnreviewedCategories => unreviewedCount > 0;

  /// O catálogo nunca chegou a este aparelho (a descida junto com a Home
  /// falhou) — ou só tem itens sem id, que as seções descartam. Sem seção
  /// não há o que avaliar, e finalizar uma avaliação sem categoria nenhuma
  /// daria 100%, "Aprovado".
  bool get hasCatalog => sections.isNotEmpty;

  /// "00:12:34" desde o início da avaliação — `00:00:00` antes de o rascunho
  /// abrir.
  String get elapsedLabel {
    final start = _startTime;
    if (start == null) return '00:00:00';
    return _formatElapsed(_now().difference(start));
  }

  Future<void> init() async {
    final assessment = await _assessmentRepository.openDraft(
      trainingParticipantId: participantId,
      sessionId: sessionId,
      ownerUserId: ownerUserId,
    );
    if (_disposed) return;

    _assessmentId = assessment.id;
    _startTime = assessment.startTime;

    _participantSubscription ??=
        _participantRepository.watchParticipant(participantId).listen((p) {
      _participant = p;
      notifyListeners();
    });

    _itemsSubscription ??=
        _assessmentRepository.watchItems(assessment.id).listen((items) {
      _items = items;
      notifyListeners();
    });

    _catalog = await _catalogRepository.loadCatalog();
    if (_disposed) return;

    // Como no canvas: a tela sempre abre com a primeira categoria aberta.
    final sections = this.sections;
    _expandedCategoryId = sections.isEmpty ? null : sections.first.id;

    _ticker ??= Timer.periodic(tickInterval, (_) => notifyListeners());

    _loading = false;
    notifyListeners();
  }

  /// Acordeão de uma seção só — abrir outra fecha a anterior, como no canvas.
  void toggleCategory(String categoryId) {
    _expandedCategoryId = _expandedCategoryId == categoryId ? null : categoryId;
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

  /// Finaliza a avaliação: grava local e sinaliza a volta para o detalhe.
  /// Sem catálogo, não finaliza — a tela nem mostra o botão, e esta guarda
  /// garante que uma avaliação vazia nunca entre na fila de envio.
  Future<void> finish() async {
    final assessmentId = _assessmentId;
    if (assessmentId == null || _finished || !hasCatalog) return;

    await _assessmentRepository.finish(assessmentId);
    _ticker?.cancel();
    _finished = true;
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

String _formatElapsed(Duration elapsed) {
  final total = elapsed.isNegative ? Duration.zero : elapsed;
  final hours = total.inHours.toString().padLeft(2, '0');
  final minutes = (total.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (total.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
