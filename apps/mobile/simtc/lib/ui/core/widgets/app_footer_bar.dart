import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Rodapé fixo do DS: fundo sólido, borda de 1 só em cima e o recuo do
/// canvas (12 em cima, 16 nos lados e embaixo) por padrão.
class AppFooterBar extends StatelessWidget {
  const AppFooterBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
    this.color = AppColors.surface,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: padding,
      child: child,
    );
  }
}
