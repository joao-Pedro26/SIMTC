import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/typography.dart';

class SimtcTheme {
  SimtcTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: SimtcTypography.fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: SimtcColors.primary,
        brightness: Brightness.light,
        surface: SimtcColors.surface,
      ),
      scaffoldBackgroundColor: SimtcColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: SimtcColors.surface,
        foregroundColor: SimtcColors.textPrimary,
        elevation: 0,
        titleTextStyle: SimtcTypography.headingMd,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SimtcColors.primary,
          foregroundColor: SimtcColors.onPrimary,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      dividerTheme: const DividerThemeData(color: SimtcColors.border, space: 1),
    );
  }
}
