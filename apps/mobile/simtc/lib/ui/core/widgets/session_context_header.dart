import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'company_logo.dart';

/// Faixa de contexto no topo dos formulários de ADMIN (canvas "3a" e "3b"):
/// o logo da empresa e duas linhas dizendo em que sessão o admin está
/// mexendo — ele cadastra em sequência e precisa saber onde está.
class SessionContextHeader extends StatelessWidget {
  const SessionContextHeader({
    super.key,
    required this.companyName,
    required this.subtitle,
    this.logoUrl,
    this.muted = false,
  });

  final String companyName;
  final String? logoUrl;

  /// A segunda linha: o curso e, quando ajuda, a data ("… · 12 set").
  final String subtitle;

  /// Fundo da tela em vez do da superfície (canvas "3a").
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: muted ? AppColors.background : AppColors.surface,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          CompanyLogo.card(companyName: companyName, url: logoUrl),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  companyName,
                  style: AppTypography.contextTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs + 1),
                Text(
                  subtitle,
                  style: AppTypography.meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
