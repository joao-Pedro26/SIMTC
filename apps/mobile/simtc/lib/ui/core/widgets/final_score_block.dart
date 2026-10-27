import 'package:flutter/material.dart';

import '../score_labels.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// O topo da tela 1.6 e do Resultado (canvas "2e" e "2g"): "Pontuação final",
/// o % em destaque e a pílula "Aprovado"/"Não recomendado", com as
/// linhas de detalhe embaixo.
class FinalScoreBlock extends StatelessWidget {
  const FinalScoreBlock({
    super.key,
    required this.score,
    required this.approved,
    this.details = const [],
    this.scale = FinalScoreScale.phone,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
  });

  /// Os tamanhos do bloco: o do celular ou o da conferência no tablet.
  final FinalScoreScale scale;
  final EdgeInsetsGeometry padding;

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
    final tablet = scale == FinalScoreScale.summaryTablet;
    final result = scale == FinalScoreScale.resultTablet;

    return Container(
      padding: padding,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A pílula fica à direita do %; quando não cabe ao lado dele
          // (tela estreita ou fonte do sistema grande), desce para baixo,
          // sem quebrar o texto (Fase 8C).
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pontuação final',
                    style: tablet
                        ? AppTypography.summaryScoreLabelTablet
                        : AppTypography.summaryScoreLabel,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    score == null ? '—' : percentLabel(score),
                    style: tablet
                        ? AppTypography.summaryScoreTablet
                        : result
                            ? AppTypography.resultScoreTablet
                            : AppTypography.summaryScore,
                  ),
                ],
              ),
              if (approved != null) _ResultPill(approved: approved, large: tablet),
            ],
          ),
          for (var i = 0; i < lines.length; i++) ...[
            SizedBox(height: i == 0 ? AppSpacing.md + 2 : AppSpacing.xs),
            Text(
              lines[i],
              style: tablet
                  ? AppTypography.summaryDetailTablet
                  : result
                      ? AppTypography.resultDetailTablet
                      : AppTypography.summaryDetail,
            ),
          ],
        ],
      ),
    );
  }
}

/// Os tamanhos do [FinalScoreBlock].
enum FinalScoreScale {
  /// Celular (quadros "2e" e "2g").
  phone,

  /// Conferir e finalizar no tablet (quadros "4g" e "4r"): % de 48.
  summaryTablet,

  /// Resultado no tablet (quadros "4i" e "4t"): % de 44 e a pílula do
  /// celular.
  resultTablet,
}

/// "Aprovado" ou "Não recomendado", ao lado do % — o corte de 70% do
/// backend. As cores são as dos chips de status do detalhe da sessão.
class _ResultPill extends StatelessWidget {
  const _ResultPill({required this.approved, this.large = false});

  final bool approved;

  /// A pílula da conferência no tablet (quadro "4g"): 8/15/8/12 de recuo,
  /// ícone de 18 e texto de 14.
  final bool large;

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
            'Não recomendado',
            AppIcons.needsReview,
            AppColors.dangerBg,
            AppColors.dangerBorder,
            AppColors.dangerInk,
          );

    return Container(
      padding: large
          ? const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md + 3,
              AppSpacing.sm,
            )
          : const EdgeInsets.fromLTRB(
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
          Icon(icon, size: large ? 18 : 16, color: ink),
          SizedBox(width: large ? AppSpacing.xs + 2 : AppSpacing.xs + 1),
          Text(
            label,
            style: (large ? AppTypography.resultPillTablet : AppTypography.resultPill)
                .copyWith(color: ink),
          ),
        ],
      ),
    );
  }
}
