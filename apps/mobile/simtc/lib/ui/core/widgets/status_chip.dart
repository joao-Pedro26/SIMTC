import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Tom semântico de um chip de status.
enum StatusTone { neutral, info, warning, success, danger, mauve }

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

  Color get _background => switch (tone) {
        StatusTone.neutral => AppColors.neutralBg,
        StatusTone.info => AppColors.primarySurface,
        StatusTone.warning => AppColors.warningBg,
        StatusTone.success => AppColors.successBg,
        StatusTone.danger => AppColors.dangerBg,
        StatusTone.mauve => AppColors.mauveSoft,
      };

  Color get _border => switch (tone) {
        StatusTone.neutral => AppColors.neutralBorder,
        StatusTone.info => AppColors.primary,
        StatusTone.warning => AppColors.warningBorder,
        StatusTone.success => AppColors.successBorder,
        StatusTone.danger => AppColors.dangerBorder,
        StatusTone.mauve => AppColors.mauveBorder,
      };

  Color get _ink => switch (tone) {
        StatusTone.neutral => AppColors.neutralInk,
        StatusTone.info => AppColors.primaryDark,
        StatusTone.warning => AppColors.warningInk,
        StatusTone.success => AppColors.successInk,
        StatusTone.danger => AppColors.dangerInk,
        StatusTone.mauve => AppColors.mauve,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: dashedBorder ? _border.withValues(alpha: 0.5) : _border,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _ink),
          const SizedBox(width: AppSpacing.xs + 1),
          Text(label, style: AppTypography.chipLabel.copyWith(color: _ink)),
        ],
      ),
    );
  }
}
