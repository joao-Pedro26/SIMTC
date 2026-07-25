import 'package:flutter/material.dart';
import '../../tokens/colors.dart';
import '../../tokens/spacing.dart';
import '../../tokens/typography.dart';

class SimtcEmptyState extends StatelessWidget {
  final String message;
  final String? subtitle;
  final IconData icon;

  const SimtcEmptyState({
    required this.message,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(SimtcSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: SimtcColors.textDisabled),
          const SizedBox(height: SimtcSpacing.md),
          Text(message, style: SimtcTypography.headingSm.copyWith(color: SimtcColors.textSecondary), textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: SimtcSpacing.xs),
            Text(subtitle!, style: SimtcTypography.caption.copyWith(color: SimtcColors.textDisabled), textAlign: TextAlign.center),
          ],
        ],
      ),
    ),
  );
}
