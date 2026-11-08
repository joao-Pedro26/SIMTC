import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Cor cheia da nota — o selo das "Infrações registradas" no Resultado.
/// As notas são "B" e "PM"; qualquer outro valor é "M".
Color noteFillColor(String noteType) => switch (noteType) {
      'B' => AppColors.noteBFill,
      'PM' => AppColors.notePmFill,
      _ => AppColors.noteMFill,
    };

/// Cores de um dos botões B/PM/M do checklist. Marcado, o botão fica na cor
/// cheia da nota; desmarcado, na versão clara. Qualquer outro valor é "M".
({Color bg, Color border, Color ink}) noteButtonColors(
  String noteType, {
  required bool selected,
}) =>
    switch (noteType) {
      'B' => selected
          ? (bg: AppColors.noteBFill, border: AppColors.noteBFill, ink: AppColors.noteBSelectedInk)
          : (bg: AppColors.noteBBg, border: AppColors.noteBBorder, ink: AppColors.noteBInk),
      'PM' => selected
          ? (bg: AppColors.notePmFill, border: AppColors.notePmFill, ink: AppColors.notePmSelectedInk)
          : (bg: AppColors.notePmBg, border: AppColors.notePmBorder, ink: AppColors.notePmInk),
      _ => selected
          ? (bg: AppColors.noteMFill, border: AppColors.noteMFill, ink: AppColors.noteMSelectedInk)
          : (bg: AppColors.noteMBg, border: AppColors.noteMBorder, ink: AppColors.noteMInk),
    };
