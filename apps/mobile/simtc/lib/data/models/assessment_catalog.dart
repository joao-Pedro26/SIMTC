/// Catálogo da avaliação prática: categorias, infrações de cada categoria e as
/// notas (B, PM, M) de cada infração. Vem de `GET /assessment-categories`, que
/// devolve tudo aninhado numa chamada só.
class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.code,
    required this.name,
    required this.order,
    required this.infractions,
    this.description,
  });

  final String id;

  /// Sigla da categoria na ficha oficial ("CV", "TP"...).
  final String code;
  final String name;
  final String? description;
  final int order;
  final List<CatalogInfraction> infractions;

  factory CatalogCategory.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final infractions = json['infractions'];
    return CatalogCategory(
      id: id,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      order: (json['order'] as num?)?.toInt() ?? 0,
      infractions: infractions is List
          ? infractions
              .whereType<Map<String, dynamic>>()
              .map((item) => CatalogInfraction.fromJson(item, categoryId: id))
              .toList(growable: false)
          : const [],
    );
  }
}

class CatalogInfraction {
  const CatalogInfraction({
    required this.id,
    required this.categoryId,
    required this.description,
    required this.order,
    required this.notes,
  });

  final String id;
  final String categoryId;
  final String description;

  /// Número do item na ficha oficial — é por ele que a infração é localizada
  /// numa contestação.
  final int order;
  final List<CatalogNote> notes;

  factory CatalogInfraction.fromJson(
    Map<String, dynamic> json, {
    required String categoryId,
  }) {
    final id = json['id'] as String? ?? '';
    final notes = json['notes'];
    return CatalogInfraction(
      id: id,
      categoryId: categoryId,
      description: json['description'] as String? ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      notes: notes is List
          ? notes
              .whereType<Map<String, dynamic>>()
              .map((item) => CatalogNote.fromJson(item, infractionId: id))
              .toList(growable: false)
          : const [],
    );
  }
}

class CatalogNote {
  const CatalogNote({
    required this.id,
    required this.infractionId,
    required this.noteType,
    required this.deduction,
    this.comment,
  });

  final String id;
  final String infractionId;

  /// `B`, `PM` ou `M`, como vem do backend.
  final String noteType;
  final String? comment;

  /// Peso usado no score — o cálculo lê este valor, nunca uma constante.
  final int deduction;

  factory CatalogNote.fromJson(
    Map<String, dynamic> json, {
    required String infractionId,
  }) {
    return CatalogNote(
      id: json['id'] as String? ?? '',
      infractionId: infractionId,
      noteType: json['noteType'] as String? ?? '',
      comment: json['comment'] as String?,
      deduction: (json['deduction'] as num?)?.toInt() ?? 0,
    );
  }
}
