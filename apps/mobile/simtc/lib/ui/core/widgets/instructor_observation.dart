import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A observação do instrutor sobre uma falta: rótulo "Observação do
/// instrutor" e o texto livre. Visual da cor da marca (fundo `primarySoft`),
/// distinto da caixa amarela do comentário do catálogo.
///
/// Com [onTap], a caixa abre a edição; sem ele (avaliação confirmada ou
/// liberada, e o Resultado) é só leitura.
class InstructorObservation extends StatelessWidget {
  const InstructorObservation({super.key, required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(AppIcons.edit, size: 16, color: AppColors.primaryDark),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Observação do instrutor',
                    style: AppTypography.instructorObservationLabel),
                const SizedBox(height: AppSpacing.xxs),
                Text(text, style: AppTypography.instructorObservation),
              ],
            ),
          ),
        ],
      ),
    );
    // O fundo é do próprio Material para a tinta do toque aparecer.
    return Material(
      color: AppColors.primarySoft,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.primarySurface),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? box : InkWell(onTap: onTap, child: box),
    );
  }
}
