import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Item da navbar flutuante.
class PillNavItem {
  const PillNavItem({
    required this.icon,
    required this.label,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;

  /// Quantidade pendente exibida em cima do ícone; 0 esconde o badge.
  final int badgeCount;
}

/// Navbar em pastilha flutuante (Sessões / Sincronizar / Perfil).
///
/// Fundo opaco, não translúcido: o app é usado dentro do veículo, com luz
/// variável, onde contraste previsível vale mais que o efeito de vidro.
class PillNavBar extends StatelessWidget {
  const PillNavBar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final List<PillNavItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Container(
        height: 64,
        padding: const EdgeInsets.all(AppSpacing.sm - 2),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: const [
            BoxShadow(
              color: AppColors.navShadow,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(child: _buildItem(items[i], i == currentIndex, () => onSelect(i))),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(PillNavItem item, bool isSelected, VoidCallback onTap) {
    final ink = isSelected ? AppColors.accent : AppColors.textMuted;

    return Semantics(
      selected: isSelected,
      button: true,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, size: 22, color: ink),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(item.label, style: AppTypography.navLabel.copyWith(color: ink)),
                ],
              ),
              if (item.badgeCount > 0) _buildBadge(item.badgeCount),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(int count) {
    return Positioned(
      top: 4,
      child: Transform.translate(
        offset: const Offset(14, 0),
        child: Container(
          constraints: const BoxConstraints(minWidth: 18),
          height: 18,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.warningInkStrong,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.background, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            '$count',
            style: AppTypography.navLabel.copyWith(
              color: AppColors.surface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
