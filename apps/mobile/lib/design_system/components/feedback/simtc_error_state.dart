import 'package:flutter/material.dart';
import '../../tokens/colors.dart';
import '../../tokens/spacing.dart';
import '../../tokens/typography.dart';
import '../buttons/simtc_button.dart';

class SimtcErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const SimtcErrorState({required this.message, this.onRetry, super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(SimtcSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 56, color: SimtcColors.noteM),
          const SizedBox(height: SimtcSpacing.md),
          Text(message, style: SimtcTypography.headingSm, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: SimtcSpacing.lg),
            SimtcButton(label: 'Tentar novamente', onPressed: onRetry!),
          ],
        ],
      ),
    ),
  );
}
