import 'package:flutter/material.dart';
import '../../tokens/colors.dart';
import '../../tokens/spacing.dart';
import '../../tokens/typography.dart';

class ScoreBar extends StatelessWidget {
  final String categoryCode;
  final double score;

  const ScoreBar({required this.categoryCode, required this.score, super.key});

  @override
  Widget build(BuildContext context) {
    final color = score >= 85
        ? SimtcColors.noteB
        : score >= 70
            ? SimtcColors.inProgress
            : SimtcColors.noteM;

    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(categoryCode, style: SimtcTypography.label),
        ),
        const SizedBox(width: SimtcSpacing.sm),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: SimtcColors.border,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: SimtcSpacing.sm),
        Text('${score.toStringAsFixed(0)}', style: SimtcTypography.bodyBold),
      ],
    );
  }
}
