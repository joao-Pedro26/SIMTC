import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Linha de sessão da Home: empresa, curso, metadados, chip de status e, quando
/// houver, o progresso de avaliação. O traço superior e inferior usa a cor do
/// status, como no canvas.
class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.companyName,
    required this.courseName,
    required this.meta,
    required this.statusChip,
    this.accentColor = AppColors.border,
    this.progressLabel,
    this.progressValue,
    this.onTap,
  });

  final String companyName;
  final String courseName;
  final String meta;
  final Widget statusChip;
  final Color accentColor;
  final String? progressLabel;

  /// Progresso de 0 a 1; quando nulo, a barra não aparece.
  final double? progressValue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg - 1,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.symmetric(
            horizontal: BorderSide(color: accentColor, width: 1.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: AppSpacing.md),
            _buildStatusRow(),
            if (progressValue != null) ...[
              const SizedBox(height: AppSpacing.md),
              _buildProgressBar(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(companyName, style: AppTypography.cardTitle),
              const SizedBox(height: AppSpacing.xs + 1),
              Text(courseName, style: AppTypography.body),
              const SizedBox(height: AppSpacing.xs + 1),
              Text(meta, style: AppTypography.meta),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        const Icon(AppIcons.chevronRight, size: 24, color: AppColors.text3),
      ],
    );
  }

  Widget _buildStatusRow() {
    return Row(
      children: [
        statusChip,
        if (progressLabel != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              progressLabel!,
              style: AppTypography.meta.copyWith(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: LinearProgressIndicator(
        value: progressValue,
        minHeight: 6,
        backgroundColor: AppColors.border,
        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
      ),
    );
  }
}
