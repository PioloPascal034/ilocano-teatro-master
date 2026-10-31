import 'package:flutter/material.dart';

abstract final class TeatroColors {
  static const ink = Color(0xFF253028);
  static const muted = Color(0xFF71776E);
  static const cream = Color(0xFFF8F6F0);
  static const paper = Color(0xFFFFFDF9);
  static const line = Color(0xFFE9E4D9);
  static const rust = Color(0xFFBF552E);
  static const gold = Color(0xFFD7A52E);
  static const blue = Color(0xFF658C9B);
  static const moss = Color(0xFF74865B);
  static const plum = Color(0xFF8C6682);
  static const dark = Color(0xFF27372D);
  static const success = Color(0xFF567541);
  static const error = Color(0xFFB34D2A);
}

abstract final class TeatroTypography {
  static const displayFamily = 'Fraunces';
  static const bodyFamily = 'Manrope';
  static const labelFamily = 'DM Mono';
}

abstract final class AppTheme {
  static ThemeData get light {
    const body = TextStyle(
      fontFamily: TeatroTypography.bodyFamily,
      color: TeatroColors.ink,
    );
    const display = TextStyle(
      fontFamily: TeatroTypography.displayFamily,
      color: TeatroColors.ink,
      fontWeight: FontWeight.w600,
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: TeatroColors.cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: TeatroColors.rust,
        primary: TeatroColors.rust,
        secondary: TeatroColors.gold,
        surface: TeatroColors.paper,
        error: TeatroColors.error,
      ),
      fontFamily: TeatroTypography.bodyFamily,
      textTheme: Typography.material2021().black.copyWith(
        displayLarge: display.copyWith(fontSize: 42, height: 1.08),
        displayMedium: display.copyWith(fontSize: 34, height: 1.12),
        headlineLarge: display.copyWith(fontSize: 30, height: 1.15),
        headlineMedium: display.copyWith(fontSize: 24, height: 1.2),
        titleLarge: display.copyWith(fontSize: 20, height: 1.25),
        titleMedium: body.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
        bodyLarge: body.copyWith(fontSize: 15, height: 1.6),
        bodyMedium: body.copyWith(fontSize: 13, height: 1.55),
        bodySmall: body.copyWith(fontSize: 11, height: 1.5),
        labelLarge: body.copyWith(fontSize: 13, fontWeight: FontWeight.w800),
        labelMedium: body.copyWith(fontSize: 10, fontWeight: FontWeight.w700),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: TeatroColors.paper,
        foregroundColor: TeatroColors.ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TeatroColors.paper,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 14,
        ),
        hintStyle: body.copyWith(color: TeatroColors.muted, fontSize: 13),
        labelStyle: body.copyWith(color: TeatroColors.muted, fontSize: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: TeatroColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: TeatroColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: TeatroColors.rust, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: TeatroColors.error),
        ),
      ),
      dividerColor: TeatroColors.line,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: TeatroColors.dark,
        contentTextStyle: body.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
