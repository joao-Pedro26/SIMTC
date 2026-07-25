import 'package:flutter/material.dart';
import '../../tokens/colors.dart';
import '../../tokens/radius.dart';
import '../../tokens/typography.dart';

enum SimtcButtonVariant { primary, secondary, danger, ghost }

class SimtcButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final SimtcButtonVariant variant;
  final bool isLoading;
  final IconData? icon;

  const SimtcButton({
    required this.label,
    required this.onPressed,
    this.variant = SimtcButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bg = switch (variant) {
      SimtcButtonVariant.primary   => SimtcColors.primary,
      SimtcButtonVariant.danger    => SimtcColors.noteM,
      SimtcButtonVariant.secondary => SimtcColors.surface,
      SimtcButtonVariant.ghost     => Colors.transparent,
    };
    final fg = switch (variant) {
      SimtcButtonVariant.primary => SimtcColors.onPrimary,
      SimtcButtonVariant.danger  => SimtcColors.onPrimary,
      _                          => SimtcColors.primary,
    };

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: variant == SimtcButtonVariant.ghost ? 0 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SimtcRadius.md),
            side: variant == SimtcButtonVariant.secondary
                ? const BorderSide(color: SimtcColors.border)
                : BorderSide.none,
          ),
        ),
        child: isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                  Text(label, style: SimtcTypography.bodyBold.copyWith(color: fg)),
                ],
              ),
      ),
    );
  }
}
