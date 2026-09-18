import 'package:flutter/material.dart';

/// Identidad visual compartida por toda la app móvil.
/// Mantiene la misma paleta oscura y dorada de la web.
abstract final class UrbanColors {
  static const background = Color(0xFF0A0A0A);
  static const surface = Color(0xFF0F0F0F);
  static const surfaceElevated = Color(0xFF171411);
  static const line = Color(0xFF2A2A2A);
  static const gold = Color(0xFFC9A96E);
  static const goldLight = Color(0xFFF0D28F);
  static const text = Color(0xFFF0EDE8);
  static const muted = Color(0xFF8F8A82);
  static const danger = Color(0xFFE36A70);
}

abstract final class UrbanTheme {
  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: UrbanColors.gold,
      onPrimary: UrbanColors.background,
      surface: UrbanColors.surface,
      onSurface: UrbanColors.text,
      error: UrbanColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: UrbanColors.background,
      fontFamily: 'Montserrat',
      appBarTheme: const AppBarTheme(
        backgroundColor: UrbanColors.background,
        foregroundColor: UrbanColors.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: UrbanColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: UrbanColors.line),
        ),
      ),
      dividerTheme: const DividerThemeData(color: UrbanColors.line, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        hintStyle: const TextStyle(color: UrbanColors.muted),
        labelStyle: const TextStyle(color: UrbanColors.muted),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: UrbanColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: UrbanColors.gold, width: 1.2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: UrbanColors.surfaceElevated,
        contentTextStyle: const TextStyle(color: UrbanColors.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
