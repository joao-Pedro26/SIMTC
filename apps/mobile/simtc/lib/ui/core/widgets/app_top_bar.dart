import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Barra superior das telas empilhadas (detalhe da sessão, resumo e
/// resultado): voltar à esquerda, título centralizado e, opcionalmente, um
/// atalho à direita.
///
/// O lado direito sempre reserva o espaço de um alvo de toque, com ou sem
/// atalho — é o que mantém o título no centro da tela. Com [actions], o
/// título fica centrado no espaço que sobra, como no canvas "1f".
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.trailing,
    this.leadingIcon = AppIcons.back,
    this.leadingIconSize = 30,
    this.leadingTooltip = 'Voltar',
    this.onBack,
  });

  final String title;

  /// Atalhos antes do [trailing] — o lápis do ADMIN no detalhe da sessão.
  /// Cada um traz o próprio alvo de toque (`AppIconAction`).
  final List<Widget> actions;
  final Widget? trailing;

  /// O botão da esquerda: o voltar, ou o fechar do Resultado (canvas "2g").
  final IconData leadingIcon;
  final double leadingIconSize;
  final String leadingTooltip;

  /// O que o botão da esquerda faz. Sem ele, desempilha a tela — o detalhe
  /// do tablet em retrato não está empilhado sobre a lista e volta para ela
  /// pela rota.
  final VoidCallback? onBack;

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
              tooltip: leadingTooltip,
              icon: Icon(leadingIcon, size: leadingIconSize, color: AppColors.text),
              // `maybePop` funciona igual sob o go_router e num
              // `MaterialApp` simples de teste.
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
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
          ...actions,
          SizedBox.square(dimension: AppSpacing.touchTarget, child: trailing),
        ],
      ),
    );
  }
}
