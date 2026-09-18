import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Severidade de uma infração. Os rótulos aparecem literalmente como "B", "PM"
/// e "M" — a mesma convenção do painel web, reconhecida por consultores e
/// admins. A explicação de cada nota vem do texto da própria nota, nunca de
/// expandir a sigla.
enum Severity { b, pm, m }

class SeverityBadge extends StatelessWidget {
  const SeverityBadge({super.key, required this.severity});

  final Severity severity;

  String get _label => switch (severity) {
        Severity.b => 'B',
        Severity.pm => 'PM',
        Severity.m => 'M',
      };

  Color get _background => switch (severity) {
        Severity.b => AppColors.severityGoodBg,
        Severity.pm => AppColors.severityMediumBg,
        Severity.m => AppColors.severityHighBg,
      };

  Color get _ink => switch (severity) {
        Severity.b => AppColors.severityGoodInk,
        Severity.pm => AppColors.severityMediumInk,
        Severity.m => AppColors.severityHighInk,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 32),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(AppRadius.sm - 2),
      ),
      child: Text(
        _label,
        textAlign: TextAlign.center,
        style: AppTypography.chipLabel.copyWith(color: _ink),
      ),
    );
  }
}
