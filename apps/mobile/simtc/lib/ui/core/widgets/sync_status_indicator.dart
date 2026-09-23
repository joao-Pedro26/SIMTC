import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';

/// Indicador de avaliações esperando envio, no canto do cabeçalho da Home e
/// do detalhe da sessão. Fica sem badge até a Fase 4 criar a fila local; já
/// existe para o consultor aprender onde olhar — e para a Fase 4 mudar um
/// lugar só.
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: AppSpacing.touchTarget,
      height: AppSpacing.touchTarget,
      child: Icon(AppIcons.syncDone, color: AppColors.text3),
    );
  }
}
