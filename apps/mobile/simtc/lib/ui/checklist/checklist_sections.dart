import 'package:flutter/widgets.dart';

import '../../data/models/assessment_catalog.dart';
import '../../data/services/local/app_database.dart';
import '../../utils/scoring.dart';
import '../core/theme/app_colors.dart';

/// Uma nota (B/PM/M) disponível para uma infração, na ordem fixa do canvas —
/// não a ordem em que o backend devolveu (o admin pode ter cadastrado M antes
/// de B).
const List<String> noteTypeOrder = ['B', 'PM', 'M'];

class ChecklistNoteOption {
  const ChecklistNoteOption({
    required this.id,
    required this.noteType,
    required this.comment,
    required this.deduction,
  });

  final String id;

  /// `B`, `PM` ou `M`.
  final String noteType;
  final String? comment;
  final int deduction;
}

class ChecklistInfraction {
  const ChecklistInfraction({
    required this.id,
    required this.description,
    required this.order,
    required this.notes,
    required this.selectedNoteId,
  });

  final String id;
  final String description;
  final int order;

  /// Sempre 3, na ordem B/PM/M — os 3 botões do seletor.
  final List<ChecklistNoteOption> notes;

  /// Nulo quando nenhum botão está pressionado.
  final String? selectedNoteId;

  bool get isMarked => selectedNoteId != null;

  ChecklistNoteOption? get selectedNote => selectedNoteId == null
      ? null
      : notes.where((n) => n.id == selectedNoteId).firstOrNull;

  /// Observação da nota escolhida, mostrada sob o seletor — nula se não há
  /// nota escolhida ou se ela não tem observação cadastrada.
  String? get selectedComment => selectedNote?.comment;
}

class ChecklistCategory {
  const ChecklistCategory({
    required this.id,
    required this.code,
    required this.name,
    required this.infractions,
    required this.score,
  });

  final String id;
  final String code;
  final String name;
  final List<ChecklistInfraction> infractions;

  /// 0–100, por `calculateCategoryScore` — 100 quando nada foi marcado.
  final double score;

  /// Regra decidida com o usuário em 26/09/2026: uma categoria conta como
  /// "revisada" (não pendente, para o aviso do "Finalizar avaliação") quando
  /// tem pelo menos uma infração marcada — não precisa marcar as demais como
  /// "sem infração" para contar.
  bool get isReviewed => infractions.any((i) => i.isMarked);
}

/// Monta as seções do acordeão a partir do catálogo e das marcações
/// salvas — é a junção que a `AssessmentCatalogRepository` (catálogo) e a
/// `AssessmentRepository` (marcações) não fazem sozinhas, porque cada uma só
/// conhece a própria tabela.
///
/// Marcação órfã (o admin mudou o catálogo no painel web depois da marcação):
/// se a infração sumiu, a marcação nunca é lida — o laço percorre o catálogo,
/// não as marcações; se só a nota sumiu, a infração aparece como "sem
/// infração". Nos dois casos a linha antiga fica no banco, sem quebrar nada.
///
/// Itens do catálogo sem `id` são descartados: `CatalogCategory.fromJson` (e
/// os das infrações e notas) aceitam o id ausente como `''`, e um id vazio
/// não serve para marcar nada.
List<ChecklistCategory> buildChecklistSections(
  List<CatalogCategory> catalog,
  List<LocalAssessmentItem> items,
) {
  final itemByInfraction = {for (final item in items) item.infractionId: item};

  return [
    for (final category in catalog)
      if (category.id.isNotEmpty) _buildCategory(category, itemByInfraction),
  ];
}

ChecklistCategory _buildCategory(
  CatalogCategory category,
  Map<String, LocalAssessmentItem> itemByInfraction,
) {
  final infractions = [
    for (final infraction in category.infractions)
      if (infraction.id.isNotEmpty)
        _buildInfraction(infraction, itemByInfraction[infraction.id]),
  ];

  final noteWeights = [
    for (final infraction in infractions)
      if (infraction.selectedNote != null) infraction.selectedNote!.deduction,
  ];

  return ChecklistCategory(
    id: category.id,
    code: category.code,
    name: category.name,
    infractions: infractions,
    score: calculateCategoryScore(noteWeights, infractions.length),
  );
}

ChecklistInfraction _buildInfraction(
  CatalogInfraction infraction,
  LocalAssessmentItem? item,
) {
  final notes = [
    for (final note in infraction.notes)
      if (note.id.isNotEmpty) note,
  ]..sort(
      (a, b) => noteTypeOrder
          .indexOf(a.noteType)
          .compareTo(noteTypeOrder.indexOf(b.noteType)),
    );
  final selectedNoteId = item?.infractionNoteId;

  return ChecklistInfraction(
    id: infraction.id,
    description: infraction.description,
    order: infraction.order,
    notes: [
      for (final note in notes)
        ChecklistNoteOption(
          id: note.id,
          noteType: note.noteType,
          comment: note.comment,
          deduction: note.deduction,
        ),
    ],
    selectedNoteId:
        notes.any((n) => n.id == selectedNoteId) ? selectedNoteId : null,
  );
}

/// Score geral do checklist — a média simples das categorias
/// (`calculateOverallScore`), incluindo as ainda não abertas (valem 100).
double overallScoreOf(List<ChecklistCategory> sections) {
  return calculateOverallScore([for (final s in sections) s.score]);
}

/// Cor do selo de score (spec "5a"): as mesmas faixas de severidade PM/M
/// reaproveitadas para as faixas média/baixa — não há tokens próprios de
/// "faixa de score".
({Color bg, Color ink}) scoreBadgeColorsFor(double score) {
  if (score >= 85) return (bg: AppColors.successBg, ink: AppColors.successInk);
  if (score >= 70) return (bg: AppColors.notePmBg, ink: AppColors.notePmInk);
  return (bg: AppColors.noteMBg, ink: AppColors.noteMInk);
}
