import 'assessment_item.dart';

/// Lógica pura de cálculo de score — sem dependências de Flutter
/// Espelha a lógica do packages/shared-types/src/scoring.ts
class ScoreCalculator {
  static double categoryScore(List<AssessmentItem> items) {
    final total = items.fold(0, (acc, item) => acc + item.deduction);
    return (100 - total).clamp(0, 100).toDouble();
  }

  static double overallScore(List<double> categoryScores) {
    if (categoryScores.isEmpty) return 100;
    return categoryScores.reduce((a, b) => a + b) / categoryScores.length;
  }

  static String approvalLabel(double score) {
    if (score >= 85) return 'Aprovado com Excelência';
    if (score >= 70) return 'Aprovado';
    return 'Necessita Reavaliação';
  }

  static bool isApproved(double score) => score >= 70;
}
