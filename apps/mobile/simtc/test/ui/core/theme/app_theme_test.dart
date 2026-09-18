import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/app_theme.dart';
import 'package:simtc/ui/core/theme/app_typography.dart';

void main() {
  group('AppTheme', () {
    testWidgets('mapeia os tokens de marca para o ColorScheme', (tester) async {
      late ThemeData theme;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) {
              theme = Theme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.onPrimary, AppColors.surface);
      expect(theme.colorScheme.secondary, AppColors.cta);
      expect(theme.colorScheme.error, AppColors.dangerInk);
      expect(theme.useMaterial3, isTrue);
    });

    test('usa a tipografia embutida, não uma fonte do sistema', () {
      expect(AppTheme.light.textTheme.headlineSmall!.fontFamily, AppTypography.interFamily);
      expect(AppTypography.counter.fontFamily, AppTypography.monoFamily);
    });

    test('estilos variáveis carregam o eixo wght correspondente ao peso', () {
      final style = AppTypography.button;
      expect(style.fontWeight, FontWeight.w700);
      expect(
        style.fontVariations,
        contains(const FontVariation('wght', 700)),
      );
    });
  });
}
