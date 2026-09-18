import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Checkbox quadrado do DS com rótulo ao lado. A área de toque cobre rótulo e
/// caixa, e respeita o alvo mínimo de 48 dp.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      label: label,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBox(),
              const SizedBox(width: AppSpacing.sm + 2),
              Flexible(
                child: Text(label, style: AppTypography.optionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBox() {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: value ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: value ? AppColors.primary : AppColors.borderStrong,
          width: 1.5,
        ),
      ),
      child: value
          ? const Icon(AppIcons.check, size: 17, color: AppColors.surface)
          : null,
    );
  }
}
