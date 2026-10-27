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

    test('saudação e título da Home têm os tamanhos ajustados no aparelho', () {
      // 14 e 24, escolhidos pelo usuário em 24/09/2026 (o canvas usa 13 e
      // 22). São estilos próprios da Home: `bodySmall` e `screenTitle`
      // continuam como estão nos avisos, nos SnackBars e no tema.
      expect(AppTypography.homeGreeting.fontSize, 14);
      expect(AppTypography.homeGreeting.color, AppTypography.bodySmall.color);
      expect(AppTypography.homeTitle.fontSize, 24);
      expect(AppTypography.homeTitle.fontWeight, FontWeight.w700);
      expect(AppTypography.bodySmall.fontSize, 13);
      expect(AppTypography.screenTitle.fontSize, 22);
    });

    test('os pesos médios do "meta" são estilos próprios, com o eixo wght '
        '(Fase 8C)', () {
      // Um `copyWith(fontWeight:)` não mexe no `fontVariations`: o peso
      // pedido não aparecia.
      expect(AppTypography.progressLabel.fontSize, AppTypography.meta.fontSize);
      expect(AppTypography.progressLabel.color, AppTypography.meta.color);
      expect(AppTypography.progressLabel.fontVariations,
          contains(const FontVariation('wght', 500)));
      expect(AppTypography.blockTitle.fontSize, AppTypography.meta.fontSize);
      expect(AppTypography.blockTitle.fontVariations,
          contains(const FontVariation('wght', 600)));
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
