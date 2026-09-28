import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_top_bar.dart';
import '../core/widgets/inline_notice.dart';

/// Qual tela a provisória está ocupando.
enum EvaluationPlaceholderKind { result }

/// Tela provisória atrás da rota de resultado do participante. A Fase 4 já
/// trocou a do checklist (`ChecklistScreen`); a Fase 5 troca esta, e aí este
/// arquivo sai.
class EvaluationPlaceholderScreen extends StatelessWidget {
  const EvaluationPlaceholderScreen({
    super.key,
    required this.kind,
    this.participantName,
  });

  final EvaluationPlaceholderKind kind;

  /// Chega pelo `extra` da navegação — só para o consultor confirmar que
  /// tocou na pessoa certa.
  final String? participantName;

  @override
  Widget build(BuildContext context) {
    final (title, message) = switch (kind) {
      EvaluationPlaceholderKind.result => (
          'Resultado',
          'O resultado da avaliação chega numa próxima versão do app.',
        ),
    };

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTopBar(title: title),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (participantName != null) ...[
                    Text(participantName!, style: AppTypography.detailTitle),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  InlineNotice(icon: AppIcons.pending, message: message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
