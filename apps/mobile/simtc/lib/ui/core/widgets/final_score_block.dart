import 'package:flutter/material.dart';

import '../score_labels.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// O topo da tela 1.6 e do Resultado (canvas "2e" e "2g"): "Pontuação final",
/// o % em destaque e a pílula "Aprovado"/"Necessita reavaliação", com as
/// linhas de detalhe embaixo.
class FinalScoreBlock extends StatelessWidget {
  const FinalScoreBlock({
    super.key,
    required this.score,
    required this.approved,
    this.details = const [],
  });

  /// Nulo quando não há nota a mostrar: aparece "—".
  final double? score;

  /// Nulo esconde a pílula.
  final bool? approved;

  /// Linhas abaixo do % — as vazias não aparecem.
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    final score = this.score;
    final approved = this.approved;
    final lines = details.where((line) => line.isNotEmpty).toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pontuação final', style: AppTypography.summaryScoreLabel),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      score == null ? '—' : percentLabel(score),
                      style: AppTypography.summaryScore,
                    ),
                  ],
                ),
              ),
              if (approved != null) ...[
                const SizedBox(width: AppSpacing.md),
                _ResultPill(approved: approved),
              ],
            ],
          ),
          for (var i = 0; i < lines.length; i++) ...[
            SizedBox(height: i == 0 ? AppSpacing.md + 2 : AppSpacing.xs),
            Text(lines[i], style: AppTypography.summaryDetail),
          ],
        ],
      ),
    );
  }
}

/// "Aprovado" ou "Necessita reavaliação", ao lado do % — o corte de 70% do
/// backend. As cores são as dos chips de status do detalhe da sessão.
class _ResultPill extends StatelessWidget {
  const _ResultPill({required this.approved});

  final bool approved;

  @override
  Widget build(BuildContext context) {
    final (label, icon, bg, border, ink) = approved
        ? (
            'Aprovado',
            AppIcons.approved,
            AppColors.successBg,
            AppColors.successBorder,
            AppColors.successInk,
          )
        : (
            'Necessita reavaliação',
            AppIcons.needsReview,
            AppColors.dangerBg,
            AppColors.dangerBorder,
            AppColors.dangerInk,
          );

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm + 2,
        AppSpacing.xs + 2,
        AppSpacing.md,
        AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: ink),
          const SizedBox(width: AppSpacing.xs + 1),
          Text(label, style: AppTypography.resultPill.copyWith(color: ink)),
        ],
      ),
    );
  }
}
