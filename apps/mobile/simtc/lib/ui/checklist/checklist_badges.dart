import 'package:flutter/material.dart';

import '../core/score_labels.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import 'checklist_sections.dart';

/// Chip do código da categoria ("CV") — no checklist e na tela 1.6.
class CategoryCodeChip extends StatelessWidget {
  const CategoryCodeChip({
    super.key,
    required this.code,
    this.background = AppColors.categoryChipBg,
    this.ink = AppColors.primaryDark,
  });

  final String code;
  final Color background;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm - 1,
        vertical: AppSpacing.xs - 1,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.sm - 2),
      ),
      child: Text(code, style: AppTypography.categoryCode.copyWith(color: ink)),
    );
  }
}

/// Selo de score da categoria ("86,7%", spec "5a") — no checklist e na tela
/// 1.6, com as cores por faixa de [scoreBadgeColorsFor].
class ScoreBadge extends StatelessWidget {
  const ScoreBadge({super.key, required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final colors = scoreBadgeColorsFor(score);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm - 1,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(AppRadius.sm - 2),
      ),
      child: Text(
        percentLabel(score),
        style: AppTypography.scoreBadge.copyWith(color: colors.ink),
      ),
    );
  }
}
