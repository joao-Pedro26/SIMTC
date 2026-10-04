/// Uma avaliação prática como o backend a guarda — a resposta de
/// `GET /practical-assessments/by-participant/:id` (Fase 5B). É o que a tela
/// de Resultado mostra de quem foi avaliado em outro aparelho, no painel web,
/// ou já foi aceito pelo servidor. Nada disto é guardado no aparelho
/// (decisão de 01/10/2026).
class RemoteAssessment {
  const RemoteAssessment({
    required this.startTime,
    required this.items,
    this.endTime,
    this.score,
  });

  final DateTime startTime;
  final DateTime? endTime;

  /// Calculado pelo backend no envio; nulo enquanto ele não calculou.
  final double? score;
  final List<RemoteAssessmentItem> items;

  /// Nulo se [json] não tem o formato esperado — sem `startTime` não há
  /// avaliação que se possa mostrar. Item sem a nota, a infração ou a
  /// categoria aninhadas fica de fora.
  static RemoteAssessment? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final start = DateTime.tryParse(json['startTime'] as String? ?? '');
    if (start == null) return null;

    final items = json['items'];
    return RemoteAssessment(
      startTime: start,
      endTime: DateTime.tryParse(json['endTime'] as String? ?? ''),
      score: (json['score'] as num?)?.toDouble(),
      items: items is List
          ? items
              .whereType<Map<String, dynamic>>()
              .map(RemoteAssessmentItem.tryParse)
              .whereType<RemoteAssessmentItem>()
              .toList(growable: false)
          : const [],
    );
  }
}

/// Uma infração marcada, achatada: a nota escolhida, a infração e a
/// categoria dela — o backend devolve os três aninhados em cada item.
class RemoteAssessmentItem {
  const RemoteAssessmentItem({
    required this.infractionNoteId,
    required this.noteType,
    required this.deduction,
    required this.infractionId,
    required this.infractionDescription,
    required this.infractionOrder,
    required this.categoryId,
    required this.categoryCode,
    required this.categoryName,
    required this.categoryOrder,
    this.comment,
  });

  final String infractionNoteId;

  /// `B`, `PM` ou `M`.
  final String noteType;
  final String? comment;
  final int deduction;
  final String infractionId;
  final String infractionDescription;

  /// Número do item na ficha oficial.
  final int infractionOrder;
  final String categoryId;
  final String categoryCode;
  final String categoryName;
  final int categoryOrder;

  static RemoteAssessmentItem? tryParse(Map<String, dynamic> json) {
    final note = json['infractionNote'];
    if (note is! Map<String, dynamic>) return null;
    final infraction = note['infraction'];
    if (infraction is! Map<String, dynamic>) return null;
    final category = infraction['category'];
    if (category is! Map<String, dynamic>) return null;

    return RemoteAssessmentItem(
      infractionNoteId: note['id'] as String? ?? '',
      noteType: note['noteType'] as String? ?? '',
      comment: note['comment'] as String?,
      deduction: (note['deduction'] as num?)?.toInt() ?? 0,
      infractionId: infraction['id'] as String? ?? '',
      infractionDescription: infraction['description'] as String? ?? '',
      infractionOrder: (infraction['order'] as num?)?.toInt() ?? 0,
      categoryId: category['id'] as String? ?? '',
      categoryCode: category['code'] as String? ?? '',
      categoryName: category['name'] as String? ?? '',
      categoryOrder: (category['order'] as num?)?.toInt() ?? 0,
    );
  }
}
