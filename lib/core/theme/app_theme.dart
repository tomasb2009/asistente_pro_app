import 'package:flutter/material.dart';

/// Tema oscuro minimalista, azules (#0B1020–#162036, acentos cian).
class AppTheme {
  AppTheme._();

  static const Color background = Color(0xFF0B1020);
  static const Color backgroundAlt = Color(0xFF121A2F);
  static const Color surface = Color(0xFF162036);
  static const Color border = Color(0xFF2A3F6B);
  static const Color primaryBlue = Color(0xFF3D7CFF);
  static const Color primaryBlueSoft = Color(0xFF5B8DEF);
  static const Color accentCyan = Color(0xFF00D4FF);
  static const Color textPrimary = Color(0xFFE8EEF8);
  static const Color textSecondary = Color(0xFF8FA4C7);

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        surface: surface,
        primary: primaryBlue,
        onPrimary: textPrimary,
        secondary: accentCyan,
        onSecondary: background,
        surfaceContainerHighest: surface.withValues(alpha: 0.85),
        outline: border.withValues(alpha: 0.5),
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
      ),
      scaffoldBackgroundColor: background,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border.withValues(alpha: 0.35)),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: backgroundAlt,
        selectedIconTheme: const IconThemeData(color: accentCyan),
        selectedLabelTextStyle: const TextStyle(
          color: accentCyan,
          fontWeight: FontWeight.w600,
        ),
        unselectedIconTheme: IconThemeData(color: textSecondary.withValues(alpha: 0.9)),
        unselectedLabelTextStyle: TextStyle(color: textSecondary.withValues(alpha: 0.9)),
        indicatorColor: primaryBlue.withValues(alpha: 0.25),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentCyan,
          side: BorderSide(color: border.withValues(alpha: 0.6)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border.withValues(alpha: 0.45)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlueSoft, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.7)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        side: BorderSide(color: border.withValues(alpha: 0.4)),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: DividerThemeData(color: border.withValues(alpha: 0.35)),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.5,
        ),
        headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textPrimary),
        bodyLarge: TextStyle(color: textPrimary, height: 1.45),
        bodyMedium: TextStyle(color: textSecondary, height: 1.4),
        labelLarge: TextStyle(color: accentCyan, fontWeight: FontWeight.w600),
      ),
    );
    return base;
  }
}
