import '../../data/models/assessment_catalog.dart';
import '../../data/models/remote_assessment.dart';
import '../../data/services/local/app_database.dart';
import '../../utils/scoring.dart';
import '../checklist/checklist_sections.dart';

/// Uma infração registrada, como o Resultado lista (canvas "2g"): o número do
/// item na ficha oficial, a descrição, a nota e o comentário dela.
class ResultInfraction {
  const ResultInfraction({
    required this.number,
    required this.description,
    required this.noteType,
    this.comment,
  });

  final int number;
  final String description;

  /// `B`, `PM` ou `M`.
  final String noteType;
  final String? comment;
}

/// Uma categoria do Resultado: o % dela e as infrações marcadas, na ordem do
/// item. O % é nulo quando o catálogo do aparelho não conhece a categoria —
/// sem o total de itens dela, não há como calcular.
class ResultCategory {
  const ResultCategory({
    required this.id,
    required this.code,
    required this.name,
    required this.score,
    required this.infractions,
  });

  final String id;
  final String code;
  final String name;
  final double? score;
  final List<ResultInfraction> infractions;
}

/// As categorias de uma avaliação feita neste aparelho: as marcações e o
/// catálogo, pela mesma junção do checklist e da tela 1.6
/// (`buildChecklistSections`) — os mesmos números que o consultor confirmou.
List<ResultCategory> resultFromLocal(
  List<CatalogCategory> catalog,
  List<LocalAssessmentItem> items,
) {
  return [
    for (final section in buildChecklistSections(catalog, items))
      ResultCategory(
        id: section.id,
        code: section.code,
        name: section.name,
        score: section.score,
        infractions: _sorted([
          for (final infraction in section.infractions)
            if (infraction.selectedNote case final note?)
              ResultInfraction(
                number: infraction.order,
                description: infraction.description,
                noteType: note.noteType,
                comment: note.comment,
              ),
        ]),
      ),
  ];
}

/// As categorias de uma avaliação vinda do servidor: as infrações saem da
/// resposta (descrição, número e comentário, como o backend guardou), e o %
/// de cada categoria é calculado com o catálogo do aparelho, pela regra do
/// checklist (`calculateCategoryScore`). Uma categoria que o catálogo do
/// aparelho não conhece entra no fim, sem %.
List<ResultCategory> resultFromRemote(
  List<CatalogCategory> catalog,
  RemoteAssessment remote,
) {
  final itemsByCategory = <String, List<RemoteAssessmentItem>>{};
  for (final item in remote.items) {
    itemsByCategory.putIfAbsent(item.categoryId, () => []).add(item);
  }

  final categories = <ResultCategory>[];
  for (final category in catalog) {
    if (category.id.isEmpty) continue;
    final items = itemsByCategory.remove(category.id) ?? const <RemoteAssessmentItem>[];
    final total = category.infractions.where((i) => i.id.isNotEmpty).length;
    categories.add(ResultCategory(
      id: category.id,
      code: category.code,
      name: category.name,
      score: calculateCategoryScore([for (final item in items) item.deduction], total),
      infractions: _remoteInfractions(items),
    ));
  }

  final unknown = itemsByCategory.values.toList()
    ..sort((a, b) => a.first.categoryOrder.compareTo(b.first.categoryOrder));
  for (final items in unknown) {
    final first = items.first;
    categories.add(ResultCategory(
      id: first.categoryId,
      code: first.categoryCode,
      name: first.categoryName,
      score: null,
      infractions: _remoteInfractions(items),
    ));
  }
  return categories;
}

/// Quantas infrações a avaliação registrou — o "N infrações" do Resultado.
int infractionCountOf(List<ResultCategory> categories) =>
    categories.fold(0, (total, category) => total + category.infractions.length);

List<ResultInfraction> _remoteInfractions(List<RemoteAssessmentItem> items) {
  return _sorted([
    for (final item in items)
      ResultInfraction(
        number: item.infractionOrder,
        description: item.infractionDescription,
        noteType: item.noteType,
        comment: item.comment,
      ),
  ]);
}

List<ResultInfraction> _sorted(List<ResultInfraction> infractions) =>
    infractions..sort((a, b) => a.number.compareTo(b.number));
