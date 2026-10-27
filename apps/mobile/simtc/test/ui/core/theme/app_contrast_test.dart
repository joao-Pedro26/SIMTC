import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/app_typography.dart';

/// Contraste entre duas cores opacas, pela fórmula do WCAG 2.
double contrast(Color a, Color b) {
  double channel(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  double luminance(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  final la = luminance(a);
  final lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('cores do canvas (Fase 8C)', () {
    test('o contorno vermelho é o #E9A2A2 do canvas', () {
      expect(AppColors.dangerBorder, const Color(0xFFE9A2A2));
    });

    test('"Somente teórica" escreve em #6B4A7A; o mauve continua o da marca',
        () {
      expect(AppColors.mauveInk, const Color(0xFF6B4A7A));
      expect(AppColors.mauve, const Color(0xFF9B80A8));
    });
  });

  group('contraste do texto (Fase 8C)', () {
    test('o cinza do texto informativo pequeno passa de 4,5:1', () {
      expect(AppColors.textSubtle, const Color(0xFF64748B));
      expect(contrast(AppColors.textSubtle, AppColors.surface),
          greaterThanOrEqualTo(4.5));
      expect(contrast(AppColors.textSubtle, AppColors.background),
          greaterThanOrEqualTo(4.5));
    });

    test('o texto informativo pequeno usa esse cinza', () {
      expect(AppTypography.fieldOptional.color, AppColors.textSubtle);
      expect(AppTypography.categoryCount.color, AppColors.textSubtle);
      expect(AppTypography.infractionNumber.color, AppColors.textSubtle);
      expect(AppTypography.resultGroupCountTablet.color, AppColors.textSubtle);
    });

    test('o link é o verde da marca mais escuro, que passa de 4,5:1', () {
      expect(AppTypography.link.color, AppColors.primaryHover);
      expect(contrast(AppColors.primaryHover, AppColors.surface),
          greaterThanOrEqualTo(4.5));
    });

    test('"Somente teórica" passa de 4,5:1 sobre o fundo do chip', () {
      expect(contrast(AppColors.mauveInk, AppColors.mauveSoft),
          greaterThanOrEqualTo(4.5));
    });

    test('a navbar do celular passa de 4,5:1 no ativo e no inativo', () {
      expect(contrast(AppColors.primaryDark, AppColors.primarySurface),
          greaterThanOrEqualTo(4.5));
      expect(contrast(AppColors.text3, AppColors.background),
          greaterThanOrEqualTo(4.5));
    });
  });
}
