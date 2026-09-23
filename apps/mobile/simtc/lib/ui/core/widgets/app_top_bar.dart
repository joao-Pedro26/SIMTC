import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Barra superior das telas empilhadas (detalhe da sessão e, nas próximas
/// fases, checklist, resumo e resultado): voltar à esquerda, título
/// centralizado e, opcionalmente, um atalho à direita.
///
/// O lado direito sempre reserva o espaço de um alvo de toque, com ou sem
/// atalho — é o que mantém o título no centro da tela.
class AppTopBar extends StatelessWidget {
  const AppTopBar({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          SizedBox.square(
            dimension: AppSpacing.touchTarget,
            child: IconButton(
              tooltip: 'Voltar',
              icon: const Icon(AppIcons.back, size: 30, color: AppColors.text),
              // `maybePop` funciona igual sob o go_router e num
              // `MaterialApp` simples de teste.
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Expanded(
            child: Text(
              title,
              style: AppTypography.appBarTitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox.square(dimension: AppSpacing.touchTarget, child: trailing),
        ],
      ),
    );
  }
}
