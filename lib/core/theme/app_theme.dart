import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light({Color accentColor = const Color(0xFF1976D2)}) {
    return baseTheme(Brightness.light, accentColor);
  }

  static ThemeData dark({Color accentColor = const Color(0xFF1976D2)}) {
    return baseTheme(Brightness.dark, accentColor).copyWith(
      scaffoldBackgroundColor: const Color(0xFF121212),
    );
  }

  static ThemeData neobrutalism() {
    final seed = const Color(0xFFFFD700);
    return baseTheme(Brightness.light, seed).copyWith(
      scaffoldBackgroundColor: const Color(0xFFF5F0E8),
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.light,
        primary: seed,
        onPrimary: const Color(0xFF1A1A00),
        surface: const Color(0xFFFFFFFF),
        onSurface: const Color(0xFF1A1A00),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF000000), width: 2),
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xFFFFD700),
        foregroundColor: Color(0xFF1A1A00),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFFD700),
          foregroundColor: const Color(0xFF1A1A00),
          side: const BorderSide(color: Color(0xFF000000), width: 2),
          elevation: 4,
          shadowColor: Colors.black38,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFFFFD700),
        foregroundColor: Color(0xFF1A1A00),
        elevation: 6,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF000000), width: 2),
        ),
      ),
    );
  }

  static ThemeData glass() {
    return baseTheme(Brightness.dark, const Color(0xFF64B4FF)).copyWith(
      scaffoldBackgroundColor: const Color(0xFF1A1A3A),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF64B4FF),
        brightness: Brightness.dark,
        primary: const Color(0xFF64B4FF),
        surface: Colors.white.withOpacity(0.10),
        onSurface: Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        color: Colors.white.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF64B4FF),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF64B4FF),
        foregroundColor: Colors.white,
        elevation: 6,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white.withOpacity(0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
      ),
    );
  }

  static ThemeData minimal() {
    return baseTheme(Brightness.light, const Color(0xFF000000)).copyWith(
      scaffoldBackgroundColor: const Color(0xFFFFFFFF),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF000000),
        onPrimary: Color(0xFFFFFFFF),
        surface: Color(0xFFFFFFFF),
        onSurface: Color(0xFF000000),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: Color(0xFFEEEEEE), width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xFFFFFFFF),
        foregroundColor: Color(0xFF000000),
        surfaceTintColor: Color(0xFFFFFFFF),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF000000),
          foregroundColor: const Color(0xFFFFFFFF),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF000000),
        foregroundColor: Color(0xFFFFFFFF),
        elevation: 2,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  static ThemeData clay() {
    return baseTheme(Brightness.light, const Color(0xFFD4A574)).copyWith(
      scaffoldBackgroundColor: const Color(0xFFF0E8D8),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFD4A574),
        brightness: Brightness.light,
        primary: const Color(0xFFD4A574),
        onPrimary: const Color(0xFF3D3028),
        surface: const Color(0xFFFAF5EE),
        onSurface: const Color(0xFF3D3028),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: const Color(0xFFFAF5EE),
        shadowColor: const Color(0xFF3D3028).withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFD4C8B8)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xFFD4A574),
        foregroundColor: Color(0xFF3D3028),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFD4A574),
          foregroundColor: const Color(0xFF3D3028),
          elevation: 3,
          shadowColor: const Color(0xFF3D3028).withOpacity(0.25),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFFD4A574),
        foregroundColor: Color(0xFF3D3028),
        elevation: 4,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFD4C8B8)),
        ),
      ),
    );
  }

  static ThemeData baseTheme(Brightness brightness, Color accent) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: accent,
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.02),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.02),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.02),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(elevation: 4),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

enum ThemeOption {
  light('☀️', 'Light'),
  dark('🌙', 'Dark'),
  neobrutalism('💥', 'Neo'),
  glass('🪟', 'Glass'),
  minimal('⚪', 'Minimal'),
  clay('🏺', 'Clay');

  final String emoji;
  final String label;
  const ThemeOption(this.emoji, this.label);
}
