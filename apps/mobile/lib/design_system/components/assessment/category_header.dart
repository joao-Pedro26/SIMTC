import 'package:flutter/material.dart';
import '../../tokens/colors.dart';
import '../../tokens/spacing.dart';
import '../../tokens/typography.dart';

class CategoryHeader extends StatelessWidget {
  final String code;
  final String name;
  final double score;
  final bool isExpanded;
  final VoidCallback onTap;

  const CategoryHeader({
    required this.code,
    required this.name,
    required this.score,
    required this.isExpanded,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SimtcSpacing.md,
          vertical: SimtcSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: SimtcColors.textSecondary,
            ),
            const SizedBox(width: SimtcSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$code — $name', style: SimtcTypography.headingSm),
                ],
              ),
            ),
            Text(
              'Score: ${score.toStringAsFixed(0)}/100',
              style: SimtcTypography.bodyBold.copyWith(color: SimtcColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
