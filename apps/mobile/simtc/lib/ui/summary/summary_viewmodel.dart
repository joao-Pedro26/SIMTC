import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/session_participant.dart';
import '../../data/repositories/assessment_catalog_repository.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/participant_repository.dart';
import '../../data/services/local/app_database.dart';
import '../../utils/scoring.dart';
import '../checklist/checklist_sections.dart';
import '../core/date_labels.dart';

/// Estado da tela 1.6 "Conferir e finalizar" (Fase 5A).
///
/// Lê só do banco, então funciona sem rede. O rascunho, as marcações e o
/// catálogo são os mesmos do checklist, e as seções saem de
/// `buildChecklistSections`: a tela mostra exatamente os números que o
/// checklist mostrava. O consultor pode ajustar início e fim aqui antes de
/// confirmar (decisão de 28/11/2026: ele às vezes esquece de finalizar na
/// hora, e o fim tardio iria para o relatório). Nada é gravado antes do
/// "Confirmar" — o `startTime` do rascunho segue valendo para a regra de uma
/// avaliação por vez. O "Confirmar" só grava — quem envia é o
/// `AssessmentSyncService`, que observa a fila.
class SummaryViewModel extends ChangeNotifier {
  SummaryViewModel({
    required this.participantId,
    required AssessmentRepository assessmentRepository,
    required ParticipantRepository participantRepository,
    required AssessmentCatalogRepository catalogRepository,
    DateTime Function()? now,
  })  : _now = now ?? DateTime.now,
        _assessmentRepository = assessmentRepository,
        _participantRepository = participantRepository,
        _catalogRepository = catalogRepository;

  final String participantId;
  final AssessmentRepository _assessmentRepository;
  final ParticipantRepository _participantRepository;
  final AssessmentCatalogRepository _catalogRepository;
  final DateTime Function() _now;

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
  DateTime? _startTime;
  DateTime? _endTime;

  bool get isLoading => _loading;
  SessionParticipant? get participant => _participant;
  List<ChecklistCategory> get sections => _sections;
  double get overallScore => overallScoreOf(_sections);

  /// Início e fim que o "Confirmar" vai gravar. Começam no início do rascunho
  /// e na hora em que a tela abriu; o consultor pode trocar a hora e o minuto
  /// de cada um (ver [setStartClock] e [setEndClock]). Nulos sem rascunho.
  DateTime? get startTime => _startTime;
  DateTime? get endTime => _endTime;

  /// Erro de horário, se o par início/fim não faz sentido. Nulo quando está
  /// certo. "Agora" é lido a cada chamada, para o fim não ficar à frente do
  /// relógio.
  String? get timesError {
    final start = _startTime;
    final end = _endTime;
    if (start == null || end == null) return null;
    if (!end.isAfter(start)) {
      return 'A hora de término precisa ser depois da hora de início.';
    }
    if (end.isAfter(_now())) {
      return 'A hora de término não pode ser depois de agora.';
    }
    return null;
  }

  /// "Início 08:12 · Fim 08:31", com os horários que o "Confirmar" vai gravar
  /// (já ajustados, se o consultor mexeu). Nulo sem rascunho.
  String? get timesLabel {
    final start = _startTime;
    final end = _endTime;
    if (start == null || end == null) return null;
    final now = _now();
    return 'Início ${clockLabel(start, now)} · Fim ${clockLabel(end, now)}';
  }

  /// Troca a hora e o minuto do início, mantendo o dia que ele já tinha e
  /// zerando segundos e milissegundos. Não grava nada: vale só ao confirmar.
  void setStartClock(int hour, int minute) {
    final current = _startTime;
    if (current == null) return;
    _startTime = _withClock(current, hour, minute);
    _errorMessage = null;
    notifyListeners();
  }

  /// Igual a [setStartClock], para o fim.
  void setEndClock(int hour, int minute) {
    final current = _endTime;
    if (current == null) return;
    _endTime = _withClock(current, hour, minute);
    _errorMessage = null;
    notifyListeners();
  }

  /// Mantém o dia local de [moment] — o rascunho pode ter começado ontem, e
  /// ajustar o fim à meia-noite não pode jogá-lo para outro dia.
  static DateTime _withClock(DateTime moment, int hour, int minute) =>
      DateTime(moment.year, moment.month, moment.day, hour, minute);

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
  /// categoria nenhuma daria 100%, "Aprovado". Horário errado também barra
  /// ([timesError]).
  bool get canConfirm =>
      !_loading &&
      _assessment != null &&
      _sections.isNotEmpty &&
      timesError == null &&
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
      _startTime = assessment.startTime;
      _endTime = _now();
      final items = await _assessmentRepository.loadItems(assessment.id);
      // As mesmas categorias do checklist: só as do curso da sessão.
      final catalog = await _catalogRepository.loadCatalog(
        sessionId: assessment.sessionId,
      );
      if (_disposed) return;
      _sections = buildChecklistSections(catalog, items);
    }

    _loading = false;
    notifyListeners();
  }

  /// "Confirmar": grava o início e o fim que a tela mostra, o nome e o % mostrado,
  /// e põe na fila.
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
        startTime: _startTime,
        endTime: _endTime,
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
