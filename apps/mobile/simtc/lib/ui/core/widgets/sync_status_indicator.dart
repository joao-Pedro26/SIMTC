import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';

/// Indicador de avaliações esperando envio, no canto do cabeçalho da Home e
/// do detalhe da sessão. A fila local já existe (Fase 4), mas o badge com a
/// contagem vem com o envio, na Fase 5 (decisão de 27/09/2026); o indicador
/// já existe para o consultor aprender onde olhar — e para a Fase 5 mudar um
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
