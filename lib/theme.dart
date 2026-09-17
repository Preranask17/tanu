import 'package:flutter/material.dart';

/// Tanu's own warm palette — cream, white cards, warm-beige chips, ink text
/// and a tan accent. The layout/shell borrows Omi's structure; the colors are
/// all Tanu.
class TanuTheme {
  /// Warm cream page background.
  static const Color bg = Color(0xFFFAF7F2);

  /// White card surface (conversation tiles, live card, settings rows).
  static const Color surface = Color(0xFFFFFFFF);

  /// Warm-beige tertiary chips (account tiles, icon squares, stat rows).
  static const Color chip = Color(0xFFEDE3D4);

  /// Warm near-black ink for all primary text.
  static const Color ink = Color(0xFF221A11);

  /// Tan accent — record button, active states, secondary icons.
  static const Color warm = Color(0xFFB07A3E);

  /// Muted sage for "ready / connected / success".
  static const Color green = Color(0xFF5E7D5A);

  /// Terracotta for errors, delete, stop.
  static const Color red = Color(0xFFA3432E);

  /// Secondary/iso text.
  static const Color muted = Color(0xFF8A7F70);

  /// Bottom edge of the nav fade.
  static const Color navEdge = Color(0xFFF0E9DE);

  /// Hairline borders/separators (ink @ 8%).
  static const Color line = Color(0x14221A11);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: warm,
      brightness: Brightness.light,
      surface: surface,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: const DividerThemeData(color: line),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: chip,
        hintStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: warm),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: warm),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: const TextStyle(color: bg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: warm,
        textColor: ink,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}

const Color kTanuBg = TanuTheme.bg;
const Color kTanuSurface = TanuTheme.surface;
const Color kTanuChip = TanuTheme.chip;
const Color kTanuInk = TanuTheme.ink;
const Color kTanuWarm = TanuTheme.warm;
const Color kTanuGreen = TanuTheme.green;
const Color kTanuRed = TanuTheme.red;
const Color kTanuMuted = TanuTheme.muted;
const Color kTanuLine = TanuTheme.line;
const Color kTanuNavEdge = TanuTheme.navEdge;