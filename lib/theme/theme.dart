import 'package:flutter/material.dart';

/// imperium design tokens (source of truth: DESIGN.md).
/// Gold is scarce & semantic; ivory is reading type; one accent hue.

abstract final class AppColors {
  // Dark (home field)
  static const bg = Color(0xFF141312);
  static const surface = Color(0xFF1C1A18);
  static const surfaceRaised = Color(0xFF232120);
  static const hairline = Color(0xFF2E2A24);
  static const brass = Color(0xFFC9A25F);
  static const goldDeep = Color(0xFF8A6D1F);
  static const ivory = Color(0xFFEAE3D0);
  static const muted = Color(0xFFA79E88);
  static const doneSurface = Color(0xFF1A1710);

  // Light (parchment / capture field)
  static const lightBg = Color(0xFFF1EBDF);
  static const lightSurface = Color(0xFFFAF6EC);
  static const lightInk = Color(0xFF201B13);
  static const lightBody = Color(0xFF3A3429);
  static const lightMuted = Color(0xFF6E6652);
  static const lightHairline = Color(0xFFD8CDB4);
}

abstract final class AppType {
  static const monument = 'Cinzel'; // wordmark, quote, numerals
  static const ledger = 'Archivo'; // UI, body, data
}

ThemeData buildAppTheme({required Brightness brightness}) {
  final dark = brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: dark ? AppColors.bg : AppColors.lightBg,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: dark ? AppColors.brass : AppColors.goldDeep,
      onPrimary: dark ? AppColors.bg : AppColors.lightSurface,
      secondary: AppColors.muted,
      onSecondary: dark ? AppColors.bg : AppColors.lightInk,
      error: const Color(0xFFB3574A),
      onError: AppColors.lightSurface,
      surface: dark ? AppColors.surface : AppColors.lightSurface,
      onSurface: dark ? AppColors.ivory : AppColors.lightInk,
      outline: dark ? AppColors.hairline : AppColors.lightHairline,
    ),
    textTheme: _textTheme(dark),
    dividerColor: dark ? AppColors.hairline : AppColors.lightHairline,
    dividerTheme: DividerThemeData(
      color: dark ? AppColors.hairline : AppColors.lightHairline,
      thickness: 1,
      space: 1,
    ),
    fontFamily: AppType.ledger,
  );
}

TextTheme _textTheme(bool dark) {
  final ink = dark ? AppColors.ivory : AppColors.lightInk;
  final mut = dark ? AppColors.muted : AppColors.lightMuted;
  final brass = dark ? AppColors.brass : AppColors.goldDeep;
  final base = Typography.material2021(platform: TargetPlatform.android)
      .black
      .apply(bodyColor: ink, displayColor: ink);

  // Ledger (Archivo) scales — eyebrow, body, metric.
  return base.copyWith(
    // Engraved label: 10-11sp uppercase wide-tracked (Archivo).
    labelSmall: base.labelSmall?.copyWith(
      fontFamily: AppType.ledger,
      fontSize: 10.5,
      letterSpacing: 1.6,
      color: mut,
      fontWeight: FontWeight.w600,
    ),
    labelLarge: base.labelLarge?.copyWith(
      fontFamily: AppType.ledger,
      letterSpacing: 0.6,
      color: mut,
      fontWeight: FontWeight.w700,
    ),
    bodyMedium: base.bodyMedium?.copyWith(
      fontFamily: AppType.ledger,
      fontSize: 15,
      color: ink,
    ),
    bodySmall: base.bodySmall?.copyWith(
      fontFamily: AppType.ledger,
      fontSize: 12,
      color: mut,
    ),
    titleSmall: base.titleMedium?.copyWith(
      fontFamily: AppType.ledger,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
    // Monument (Cinzel) scales — quote, wordmark, numerals.
    headlineMedium: base.headlineMedium?.copyWith(
      fontFamily: AppType.monument,
      fontSize: 32,
      height: 1.35,
      color: ink,
    ),
    headlineSmall: base.headlineSmall?.copyWith(
      fontFamily: AppType.monument,
      fontSize: 20,
      letterSpacing: 2.4,
      color: ink,
      fontWeight: FontWeight.w600,
    ),
    displaySmall: base.displaySmall?.copyWith(
      fontFamily: AppType.monument,
      fontSize: 52,
      color: brass,
    ),
  );
}
