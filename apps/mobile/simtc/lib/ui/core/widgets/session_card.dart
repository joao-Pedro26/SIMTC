import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Linha de sessão da Home: logo da empresa, empresa, curso, metadados, chip de
/// status e, quando houver, o progresso de avaliação. O traço superior usa a
/// cor do status.
class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.companyName,
    required this.courseName,
    required this.meta,
    required this.statusChip,
    this.leading,
    this.accentColor = AppColors.border,
    this.progressLabel,
    this.progressValue,
    this.onTap,
    this.selected = false,
  });

  /// Logo da empresa, à esquerda do nome (`CompanyLogo.card`).
  final Widget? leading;
  final String companyName;
  final String courseName;
  final String meta;
  final Widget statusChip;
  final Color accentColor;
  final String? progressLabel;

  /// Progresso de 0 a 1; quando nulo, a barra não aparece.
  final double? progressValue;
  final VoidCallback? onTap;

  /// A sessão aberta ao lado da lista (tablet em paisagem, quadro "4c"):
  /// fundo claro, borda de 1,5 em cima e embaixo e um traço de 3 à esquerda,
  /// no lugar do traço de status.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Container(
          // As bordas somam ao recuo (`Container` conta a borda da
          // decoração): o recuo do card destacado desconta a diferença, e
          // nem o texto nem a altura do card mudam ao tocar.
          padding: selected
              ? const EdgeInsets.fromLTRB(
                  AppSpacing.xl - _selectedStripe,
                  AppSpacing.lg - 1 + _accentWidth - _selectedEdge,
                  AppSpacing.xl,
                  AppSpacing.lg - 1 - _selectedEdge,
                )
              : const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.lg - 1,
                ),
          decoration: selected ? _selectedDecoration : _decoration,
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
      ),
    );
  }

  /// Traço de status em cima do card comum.
  static const double _accentWidth = 0.8;

  /// Bordas do card destacado (quadro "4c").
  static const double _selectedEdge = 1.5;
  static const double _selectedStripe = 3;

  BoxDecoration get _decoration => BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: accentColor, width: _accentWidth)),
      );

  static const BoxDecoration _selectedDecoration = BoxDecoration(
    color: AppColors.categoryExpandedBg,
    border: Border(
      top: BorderSide(color: AppColors.selectedCardBorder, width: _selectedEdge),
      bottom: BorderSide(color: AppColors.selectedCardBorder, width: _selectedEdge),
      left: BorderSide(color: AppColors.primary, width: _selectedStripe),
    ),
  );

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: AppSpacing.md),
        ],
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
              style: AppTypography.progressLabel,
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
