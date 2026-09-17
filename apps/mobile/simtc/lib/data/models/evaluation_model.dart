enum EvaluationStatus { pending, completed, synced }

class EvaluationModel {
  final String id;
  final String title;
  final String description;
  final double score;
  final DateTime createdAt;
  final EvaluationStatus status;

  const EvaluationModel({
    required this.id,
    required this.title,
    required this.description,
    required this.score,
    required this.createdAt,
    this.status = EvaluationStatus.pending,
  });

  factory EvaluationModel.fromJson(Map<String, dynamic> json) {
    return EvaluationModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      status: EvaluationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => EvaluationStatus.pending,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'score': score,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
    };
  }
}
