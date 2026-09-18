import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Um filtro da barra: rótulo e, opcionalmente, um contador.
class FilterChipData {
  const FilterChipData({required this.label, this.count});

  final String label;
  final int? count;
}

/// Barra horizontal de filtros em pastilha (Todos / Pendentes / Meus / ...).
class FilterChipBar extends StatelessWidget {
  const FilterChipBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<FilterChipData> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm + 2,
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs + 2),
            _buildChip(items[i], i == selectedIndex, () => onSelect(i)),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(FilterChipData item, bool isSelected, VoidCallback onTap) {
    final ink = isSelected ? AppColors.surface : AppColors.text2;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : AppColors.borderStrong,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.label,
              style: AppTypography.chipLabel.copyWith(color: ink, fontSize: 12.5),
            ),
            if (item.count != null) ...[
              const SizedBox(width: AppSpacing.xs + 1),
              Text(
                '${item.count}',
                style: AppTypography.counter.copyWith(
                  color: ink.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
