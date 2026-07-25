import 'package:flutter/material.dart';

class SimtcColors {
  SimtcColors._();

  // Brand
  static const primary      = Color(0xFF1A56DB);
  static const onPrimary    = Color(0xFFFFFFFF);
  static const primaryLight = Color(0xFFEBF5FF);

  // Notas de avaliação
  static const noteB  = Color(0xFF16A34A); // verde  — Bom
  static const notePM = Color(0xFFD97706); // âmbar  — Pode Melhorar
  static const noteM  = Color(0xFFDC2626); // vermelho — Melhorar

  // Status do participante
  static const approved       = Color(0xFF16A34A);
  static const needsReview    = Color(0xFFDC2626);
  static const pending        = Color(0xFF6B7280);
  static const inProgress     = Color(0xFF2563EB);

  // Superfícies e neutros
  static const surface        = Color(0xFFFFFFFF);
  static const background     = Color(0xFFF9FAFB);
  static const border         = Color(0xFFE5E7EB);
  static const textPrimary    = Color(0xFF111827);
  static const textSecondary  = Color(0xFF6B7280);
  static const textDisabled   = Color(0xFFD1D5DB);
}
