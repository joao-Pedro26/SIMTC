import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Tom semântico de um chip de status.
enum StatusTone { neutral, info, warning, success, danger, mauve }

/// Fundo, contorno e tinta de cada tom — os mesmos no [StatusChip] e na
/// [LabelPill].
extension on StatusTone {
  Color get background => switch (this) {
        StatusTone.neutral => AppColors.neutralBg,
        StatusTone.info => AppColors.primarySurface,
        StatusTone.warning => AppColors.warningBg,
        StatusTone.success => AppColors.successBg,
        StatusTone.danger => AppColors.dangerBg,
        StatusTone.mauve => AppColors.mauveSoft,
      };

  Color get border => switch (this) {
        StatusTone.neutral => AppColors.neutralBorder,
        StatusTone.info => AppColors.primary,
        StatusTone.warning => AppColors.warningBorder,
        StatusTone.success => AppColors.successBorder,
        StatusTone.danger => AppColors.dangerBorder,
        StatusTone.mauve => AppColors.mauveBorder,
      };

  Color get ink => switch (this) {
        StatusTone.neutral => AppColors.neutralInk,
        StatusTone.info => AppColors.primaryDark,
        StatusTone.warning => AppColors.warningInk,
        StatusTone.success => AppColors.successInk,
        StatusTone.danger => AppColors.dangerInk,
        StatusTone.mauve => AppColors.mauveInk,
      };
}

/// Chip de status: sempre ícone + texto, nunca só cor (daltonismo e leitura
/// rápida com atenção dividida).
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.icon,
    required this.tone,
    this.dashedBorder = false,
  });

  final String label;
  final IconData icon;
  final StatusTone tone;

  /// Usado para status que não pertencem a este consultor (ex.: participante em
  /// avaliação com outra pessoa): mesma cor, contorno mais fraco.
  final bool dashedBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: dashedBorder ? tone.border.withValues(alpha: 0.5) : tone.border,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tone.ink),
          const SizedBox(width: AppSpacing.xs + 1),
          Text(label, style: AppTypography.chipLabel.copyWith(color: tone.ink)),
        ],
      ),
    );
  }
}

/// Pastilha só de texto, nas cores de um [StatusTone]: um rótulo que não é a
/// situação de nada e por isso dispensa o ícone — o papel do consultor
/// ("Responsável", "Consultor") na tela "Consultores" (canvas "3c").
class LabelPill extends StatelessWidget {
  const LabelPill({super.key, required this.label, required this.tone});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: tone.border, width: 1.5),
      ),
      child: Text(label, style: AppTypography.chipLabel.copyWith(color: tone.ink)),
    );
  }
}
