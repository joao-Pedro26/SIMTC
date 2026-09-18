import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Tema Material 3 único do app, montado sobre os tokens do DS.
abstract final class AppTheme {
  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.surface,
      primaryContainer: AppColors.primarySurface,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.cta,
      onSecondary: AppColors.surface,
      tertiary: AppColors.mauve,
      onTertiary: AppColors.surface,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.background,
      surfaceContainer: AppColors.surfaceMuted,
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.border,
      error: AppColors.dangerInk,
      onError: AppColors.surface,
      errorContainer: AppColors.dangerBg,
      onErrorContainer: AppColors.dangerInk,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surface,
      fontFamily: AppTypography.interFamily,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.appBarTitle,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.charcoal,
        contentTextStyle: AppTypography.bodySmall.copyWith(color: AppColors.surface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      textTheme: TextTheme(
        headlineSmall: AppTypography.screenTitle,
        titleMedium: AppTypography.cardTitle,
        titleSmall: AppTypography.appBarTitle,
        bodyMedium: AppTypography.body,
        bodySmall: AppTypography.meta,
        labelLarge: AppTypography.button,
        labelMedium: AppTypography.fieldLabel,
        labelSmall: AppTypography.navLabel,
      ),
    );
  }
}
