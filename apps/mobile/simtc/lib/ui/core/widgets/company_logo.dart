import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Logo da empresa contratante: a imagem (bucket público, sem token) ou, sem
/// logo, as iniciais da empresa. Aparece no card da Home e no cabeçalho do
/// detalhe da sessão — sem borda, como no export de 24/09/2026 do canvas.
///
/// O `cached_network_image` guarda o arquivo no aparelho, então o logo
/// continua aparecendo offline depois da primeira vez; sem rede na primeira
/// vez, ficam as iniciais.
class CompanyLogo extends StatelessWidget {
  /// 44 de lado, para o card da Home (tela 1.3).
  const CompanyLogo.card({super.key, required this.companyName, this.url})
      : _size = AppSpacing.huge - AppSpacing.xs,
        _radius = AppRadius.sm,
        _padding = AppSpacing.xs + 1;

  /// 52 de lado, para o cabeçalho do detalhe da sessão (tela 1.4).
  const CompanyLogo.header({super.key, required this.companyName, this.url})
      : _size = AppSpacing.huge + AppSpacing.xs,
        _radius = AppRadius.md,
        _padding = AppSpacing.xs + 2;

  final String companyName;
  final String? url;
  final double _size;
  final double _radius;
  final double _padding;

  @override
  Widget build(BuildContext context) {
    final initials = _buildInitials();
    final logoUrl = url;

    return Container(
      width: _size,
      height: _size,
      padding: EdgeInsets.all(_padding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: logoUrl == null
          ? initials
          : CachedNetworkImage(
              imageUrl: logoUrl,
              fit: BoxFit.contain,
              placeholder: (context, _) => initials,
              errorWidget: (context, _, __) => initials,
            ),
    );
  }

  Widget _buildInitials() {
    return Center(
      child: Text(_initialsOf(companyName), style: AppTypography.logoInitials),
    );
  }

  /// "Bracell Celulose" → "BC"; uma palavra só, "Bracell" → "BR".
  static String _initialsOf(String name) {
    final words =
        name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '';
    if (words.length == 1) {
      final word = words.single;
      return word.substring(0, word.length < 2 ? word.length : 2).toUpperCase();
    }
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }
}
