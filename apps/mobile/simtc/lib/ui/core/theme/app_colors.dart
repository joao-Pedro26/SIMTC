import 'package:flutter/material.dart';

/// Tokens de cor do app. Nenhum widget deve declarar `Color(0xFF…)` direto.
///
/// Marca e neutros vêm de `prompt-claude-design-mobile.md` (valores reais de
/// produção, os mesmos do painel web). Os tons semânticos foram conferidos no
/// export do Claude Design (`apps/mobile/docs/design/SIMTC-Mobile.dc.html`).
abstract final class AppColors {
  // ─── Marca ────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF1D9AA4);
  static const Color primaryHover = Color(0xFF167F8A);
  static const Color primaryDark = Color(0xFF0A6E80);
  static const Color primarySoft = Color(0xFFEEF9FA);

  /// Fundo de chips e tiles de ação sobre superfície branca
  static const Color primarySurface = Color(0xFFE6F6F7);

  /// Acento de marca — usado no item ativo da navbar, como no canvas
  static const Color accent = Color(0xFF38BEC8);

  static const Color cta = Color(0xFFF5A520);
  static const Color ctaHover = Color(0xFFE09510);
  static const Color ctaSoft = Color(0xFFFEF8EE);

  /// Tinta sobre o laranja de CTA ("Atribuir a mim") — branco sobre #F5A520
  /// não passa no contraste; o canvas usa este marrom escuro.
  static const Color ctaInk = Color(0xFF3D2500);

  static const Color mauve = Color(0xFF9B80A8);
  static const Color mauveSoft = Color(0xFFF5F0F8);
  static const Color mauveBorder = Color(0xFFCFBBD8);

  static const Color charcoal = Color(0xFF1E2A34);
  static const Color charcoal2 = Color(0xFF2A3A46);

  // ─── Neutros ──────────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderStrong = Color(0xFFCBD5E1);
  static const Color text = Color(0xFF0F172A);
  static const Color text2 = Color(0xFF334155);
  static const Color text3 = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);

  // ─── Severidade B/PM/M — mesma escala do painel web ───────────────────────
  static const Color severityGoodBg = Color(0xFFDCFCE7);
  static const Color severityGoodInk = Color(0xFF16A34A);
  static const Color severityMediumBg = Color(0xFFFEF9C3);
  static const Color severityMediumInk = Color(0xFFCA8A04);
  static const Color severityHighBg = Color(0xFFFEE2E2);
  static const Color severityHighInk = Color(0xFFDC2626);

  // ─── Status (fundo / borda / tinta) ───────────────────────────────────────
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color successBorder = Color(0xFF86D9A4);
  static const Color successInk = Color(0xFF166534);

  static const Color warningBg = Color(0xFFFFF7EC);
  static const Color warningBorder = Color(0xFFF0DCB8);
  static const Color warningInk = Color(0xFF8A4100);

  /// Tinta de alerta mais forte — badges de pendência sobre fundo claro
  static const Color warningInkStrong = Color(0xFFC2670A);

  static const Color dangerBg = Color(0xFFFEE2E2);
  static const Color dangerBorder = Color(0xFFFCA5A5);
  static const Color dangerInk = Color(0xFFB91C1C);

  static const Color neutralBg = Color(0xFFF1F5F9);
  static const Color neutralBorder = Color(0xFFCBD5E1);
  static const Color neutralInk = Color(0xFF334155);

  /// Sombra da navbar flutuante
  static const Color navShadow = Color(0x4715172A);

  /// Trilho da barra de progresso da abertura
  static const Color progressTrack = Color(0x24000000);
}
