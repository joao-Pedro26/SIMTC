import 'assessment_item.dart';

/// Lógica pura de cálculo de score — sem dependências de Flutter
/// Espelha a lógica do packages/shared-types/src/scoring.ts
class ScoreCalculator {
  /// Peso máximo possível de uma nota — usado para normalizar a proporção da falta
  static const int _maxNoteWeight = 5; // M

  /// Score por categoria em porcentagem (0-100). Cada tópico começa em 100%;
  /// cada infração cadastrada (marcada ou não) vale uma fração igual de 100%
  /// (100 / totalInfractionsInCategory), e a nota (B/PM/M) modula quanto dessa
  /// fatia é descontada, preservando a proporção de severidade 1:3:5.
  static double categoryScore(List<AssessmentItem> items, int totalInfractionsInCategory) {
    if (totalInfractionsInCategory <= 0) return 100;
    final perInfractionShare = 100 / totalInfractionsInCategory;
    final totalDeduction = items.fold<double>(
      0,
      (acc, item) => acc + (item.deduction / _maxNoteWeight) * perInfractionShare,
    );
    return (100 - totalDeduction).clamp(0, 100).toDouble();
  }

  static double overallScore(List<double> categoryScores) {
    if (categoryScores.isEmpty) return 100;
    return categoryScores.reduce((a, b) => a + b) / categoryScores.length;
  }

  static String approvalLabel(double score) {
    if (score >= 70) return 'Aprovado';
    return 'Necessita Reavaliação';
  }

  static bool isApproved(double score) => score >= 70;
}
