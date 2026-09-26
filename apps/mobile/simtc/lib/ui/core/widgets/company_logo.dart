import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// O bucket `logos` aceita PNG, JPEG e SVG (`companies.service.ts`,
/// `uploadCompanyLogo` — a extensão vem sempre em minúsculas, do
/// `contentType`, e o cache busting é pelo timestamp no caminho, nunca por
/// query string). `CachedNetworkImage` só decodifica raster: um logo SVG
/// nunca teria imagem nenhuma, e sempre cairia no `errorWidget`.
bool isSvgLogoUrl(String url) => url.toLowerCase().endsWith('.svg');

/// Logo da empresa contratante: a imagem (bucket público, sem token) ou, sem
/// logo, as iniciais da empresa. Aparece no card da Home e no cabeçalho do
/// detalhe da sessão — sem borda, como no export de 24/09/2026 do canvas.
///
/// Raster (PNG/JPEG) passa pelo `cached_network_image`; SVG passa pelo
/// `flutter_svg`, mas com o arquivo baixado pelo mesmo `flutter_cache_manager`
/// que o `cached_network_image` usa por baixo — os dois compartilham o cache
/// em disco, e o logo continua aparecendo offline depois da primeira vez,
/// venha ele em qualquer dos dois formatos. Sem rede na primeira vez, ficam
/// as iniciais.
class CompanyLogo extends StatelessWidget {
  /// 44 de lado, para o card da Home (tela 1.3).
  const CompanyLogo.card({super.key, required this.companyName, this.url})
      : _size = AppSpacing.huge - AppSpacing.xs,
        _radius = AppRadius.sm;

  /// 52 de lado, para o cabeçalho do detalhe da sessão (tela 1.4).
  const CompanyLogo.header({super.key, required this.companyName, this.url})
      : _size = AppSpacing.huge + AppSpacing.xs,
        _radius = AppRadius.md;

  final String companyName;
  final String? url;
  final double _size;
  final double _radius;

  @override
  Widget build(BuildContext context) {
    final initials = _buildInitials();
    final logoUrl = url;

    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: logoUrl == null
          ? initials
          : isSvgLogoUrl(logoUrl)
              ? _buildSvg(logoUrl, initials)
              : CachedNetworkImage(
                  imageUrl: logoUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, _) => initials,
                  errorWidget: (context, _, __) => initials,
                ),
    );
  }

  /// `SvgPicture.network` guarda o SVG só em memória (o `Cache` dele é um
  /// `Map`, sem persistir em disco) — não bastaria para o logo continuar
  /// aparecendo depois de o app fechar e reabrir offline. Por isso o arquivo
  /// é baixado pelo `DefaultCacheManager` (o cache em disco por trás do
  /// `cached_network_image`) e só então lido por `SvgPicture.file`.
  Widget _buildSvg(String logoUrl, Widget initials) {
    return FutureBuilder<File>(
      future: DefaultCacheManager().getSingleFile(logoUrl),
      builder: (context, snapshot) {
        // `snapshot.hasData` é falso tanto enquanto baixa quanto se a
        // busca falhar (sem cache e sem rede) — as iniciais cobrem os dois
        // casos, como o `placeholder`/`errorWidget` fazem no ramo raster.
        if (!snapshot.hasData) return initials;
        return SvgPicture.file(snapshot.data!, fit: BoxFit.contain);
      },
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
