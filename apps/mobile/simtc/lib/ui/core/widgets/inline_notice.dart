import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Tom de um aviso em bloco.
enum NoticeTone { neutral, warning, danger, success }

/// Aviso em bloco: ícone à esquerda e texto explicativo.
///
/// Usado para mensagens que precisam ficar visíveis na tela (sem conexão, ação
/// indisponível, resultado de uma operação), em vez de um toast que some.
class InlineNotice extends StatelessWidget {
  const InlineNotice({
    super.key,
    required this.icon,
    required this.message,
    this.tone = NoticeTone.neutral,
  });

  final IconData icon;
  final String message;
  final NoticeTone tone;

  Color get _background => switch (tone) {
        NoticeTone.neutral => AppColors.background,
        NoticeTone.warning => AppColors.warningBg,
        NoticeTone.danger => AppColors.dangerBg,
        NoticeTone.success => AppColors.successBg,
      };

  Color get _border => switch (tone) {
        NoticeTone.neutral => AppColors.border,
        NoticeTone.warning => AppColors.warningBorder,
        NoticeTone.danger => AppColors.dangerBorder,
        NoticeTone.success => AppColors.successBorder,
      };

  Color get _ink => switch (tone) {
        NoticeTone.neutral => AppColors.text2,
        NoticeTone.warning => AppColors.warningInk,
        NoticeTone.danger => AppColors.dangerInk,
        NoticeTone.success => AppColors.successInk,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _background,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _ink),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(color: _ink),
            ),
          ),
        ],
      ),
    );
  }
}
