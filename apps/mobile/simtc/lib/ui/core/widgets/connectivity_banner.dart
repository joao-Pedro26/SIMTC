import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Faixa fina de "sem conexão", exibida abaixo do cabeçalho.
///
/// Fica oculta quando há conexão — o estado normal não ocupa espaço.
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({
    super.key,
    required this.isOffline,
    this.message,
  });

  final bool isOffline;
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: AppColors.warningBg,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Icon(AppIcons.offline, size: 16, color: AppColors.warningInk),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message ?? 'Sem conexão — o app continua funcionando com os dados baixados.',
              style: AppTypography.meta.copyWith(color: AppColors.warningInk),
            ),
          ),
        ],
      ),
    );
  }
}
