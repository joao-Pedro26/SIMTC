import 'package:flutter/material.dart';
import '../../../../design_system/ds.dart';

class ScoreSummary extends StatelessWidget {
  final double overallScore;
  final Map<String, double> categoryScores;

  const ScoreSummary({
    required this.overallScore,
    required this.categoryScores,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(SimtcSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...categoryScores.entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: SimtcSpacing.xs),
            child: ScoreBar(categoryCode: e.key, score: e.value),
          ),
        ),
      ],
    ),
  );
}
