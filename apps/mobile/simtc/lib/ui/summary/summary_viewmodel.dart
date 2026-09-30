import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/session_participant.dart';
import '../../data/repositories/assessment_catalog_repository.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/services/local/app_database.dart';
import '../../utils/scoring.dart';
import '../checklist/checklist_sections.dart';

/// Estado da tela 1.6 "Conferir e finalizar" (Fase 5A).
///
/// Lê só do banco, então funciona sem rede. O rascunho, as marcações e o
/// catálogo são os mesmos do checklist, e as seções saem de
/// `buildChecklistSections`: a tela mostra exatamente os números que o
/// checklist mostrava. O "Confirmar" só grava — quem envia é o
/// `AssessmentSyncService`, que observa a fila.
class SummaryViewModel extends ChangeNotifier {
  SummaryViewModel({
    required this.participantId,
    required AssessmentRepository assessmentRepository,
    required ParticipantRepository participantRepository,
    required AssessmentCatalogRepository catalogRepository,
  })  : _assessmentRepository = assessmentRepository,
        _participantRepository = participantRepository,
        _catalogRepository = catalogRepository;

  final String participantId;
  final AssessmentRepository _assessmentRepository;
  final ParticipantRepository _participantRepository;
  final AssessmentCatalogRepository _catalogRepository;

  static const String _confirmFailed =
      'Não foi possível confirmar a avaliação. Tente de novo.';

  StreamSubscription<SessionParticipant?>? _participantSubscription;

  bool _disposed = false;
  bool _loading = true;
  bool _confirming = false;
  bool _confirmed = false;
  String? _errorMessage;
  LocalAssessment? _assessment;
  SessionParticipant? _participant;
  List<ChecklistCategory> _sections = const [];

  bool get isLoading => _loading;
  SessionParticipant? get participant => _participant;
  List<ChecklistCategory> get sections => _sections;
  double get overallScore => overallScoreOf(_sections);

  /// Mesmo corte do backend (`getApprovalStatus`): 70% ou mais.
  bool get isApproved => getApprovalStatus(overallScore) == 'APROVADO';

  /// Infrações marcadas na avaliação inteira.
  int get infractionCount =>
      _sections.fold(0, (total, category) => total + category.markedCount);

  bool get isConfirming => _confirming;

  /// Uma vez `true`, a tela fecha — a avaliação está na fila de envio.
  bool get isConfirmed => _confirmed;

  /// Falha ao gravar o "Confirmar" — a tela continua aberta e o rascunho,
  /// intacto.
  String? get errorMessage => _errorMessage;

  /// Sem rascunho ou sem catálogo não há o que confirmar: uma avaliação sem
  /// categoria nenhuma daria 100%, "Aprovado".
  bool get canConfirm =>
      !_loading &&
      _assessment != null &&
      _sections.isNotEmpty &&
      !_confirming &&
      !_confirmed;

  Future<void> init() async {
    _participantSubscription ??=
        _participantRepository.watchParticipant(participantId).listen((p) {
      _participant = p;
      notifyListeners();
    });

    final assessment =
        await _assessmentRepository.findByParticipant(participantId);
    if (_disposed) return;
    _assessment = assessment;

    if (assessment != null) {
      final items = await _assessmentRepository.loadItems(assessment.id);
      final catalog = await _catalogRepository.loadCatalog();
      if (_disposed) return;
      _sections = buildChecklistSections(catalog, items);
    }

    _loading = false;
    notifyListeners();
  }

  /// "Confirmar": grava o fim, o nome e o % mostrado, e põe na fila.
  Future<void> confirm() async {
    final assessment = _assessment;
    if (assessment == null || !canConfirm) return;

    _confirming = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _assessmentRepository.confirm(
        assessment.id,
        participantName: _participant?.name,
        score: overallScore,
      );
      _confirmed = true;
    } catch (_) {
      _errorMessage = _confirmFailed;
    } finally {
      _confirming = false;
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _participantSubscription?.cancel();
    super.dispose();
  }
}
