import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/services/assessment_sync_service.dart';
import '../../../data/services/connectivity_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Indicador da fila de envio, no canto do cabeçalho da Home e do detalhe da
/// sessão — um lugar só para as duas telas (decisão de 27/09/2026):
/// - fila vazia: a nuvem com check, cinza;
/// - com avaliações na fila: o badge laranja com a contagem, sobre a nuvem
///   riscada sem rede (canvas "2c" e "1e") ou a de sincronização com rede.
///
/// Lê o `AssessmentSyncService` e o `ConnectivityService` do app. Sem eles
/// (a galeria do DS, testes de outros widgets), mostra a fila vazia.
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key, this.onTap});

  /// A tela decide para onde o toque leva — hoje, a aba Sincronizar.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final count = context.watch<AssessmentSyncService?>()?.queue.length ?? 0;
    final isOffline = context.watch<ConnectivityService?>()?.isOffline ?? false;

    final Widget content = count == 0
        ? const Icon(AppIcons.syncDone, color: AppColors.text3)
        : Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                isOffline ? AppIcons.offline : AppIcons.sync,
                color: AppColors.warningInk,
              ),
              Positioned(
                top: AppSpacing.xs + 2,
                right: AppSpacing.xs + 1,
                child: _CountBadge(count),
              ),
            ],
          );

    return Semantics(
      button: onTap != null,
      label: count == 0
          ? 'Nenhuma avaliação na fila'
          : count == 1
              ? '1 avaliação na fila'
              : '$count avaliações na fila',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: AppSpacing.touchTarget,
          height: AppSpacing.touchTarget,
          child: content,
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs + 1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.warningInkStrong,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.surface, width: 2),
      ),
      child: Text('$count', style: AppTypography.headerBadge),
    );
  }
}
