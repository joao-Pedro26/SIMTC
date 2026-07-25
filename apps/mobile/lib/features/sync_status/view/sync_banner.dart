import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/ds.dart';
import '../model/sync_status.dart';
import '../viewmodel/sync_viewmodel.dart';

/// Banner global exibido no topo do app para indicar status de sincronização
class SyncBanner extends ConsumerWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncViewModelProvider);

    return switch (status) {
      SyncStatusType.online  => const SizedBox.shrink(),
      SyncStatusType.offline => _Banner(
          color: SimtcColors.notePM,
          icon: Icons.wifi_off,
          message: 'Sem conexão — avaliações serão salvas localmente',
        ),
      SyncStatusType.syncing => _Banner(
          color: SimtcColors.inProgress,
          icon: Icons.sync,
          message: 'Sincronizando avaliações...',
        ),
      SyncStatusType.error => _Banner(
          color: SimtcColors.noteM,
          icon: Icons.error_outline,
          message: 'Erro ao sincronizar — tente novamente',
        ),
    };
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String message;
  const _Banner({required this.color, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: color.withOpacity(0.12),
    padding: const EdgeInsets.symmetric(
      horizontal: SimtcSpacing.md,
      vertical: SimtcSpacing.xs,
    ),
    child: Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: SimtcSpacing.xs),
        Expanded(
          child: Text(message, style: SimtcTypography.caption.copyWith(color: color)),
        ),
      ],
    ),
  );
}
