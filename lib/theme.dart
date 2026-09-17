import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tanu's Minimalist Monolith palette — ultra-clean, high-contrast, professional.
class TanuTheme {
  /// Clean, stark off-white background.
  static const Color bg = Color(0xFFFAFAFA);

  /// Pure white surfaces.
  static const Color surface = Color(0xFFFFFFFF);

  /// Subtle light-grey chips and inactive elements.
  static const Color chip = Color(0xFFF2F2F2);

  /// Deep, rich black ink for primary text and accents.
  static const Color ink = Color(0xFF111111);

  /// Monochromatic accent (same as ink) for a sophisticated look.
  static const Color warm = Color(0xFF111111);

  /// Muted tone for secondary text.
  static const Color muted = Color(0xFF888888);

  /// Ultra-subtle hairline borders (Black @ 5%).
  static const Color line = Color(0x0D000000);

  /// Deep red for destructive actions.
  static const Color red = Color(0xFFC93A3A);

  /// Professional green for success.
  static const Color green = Color(0xFF2C7A2C);

  /// Nav edge fade
  static const Color navEdge = Color(0xFFF5F5F5);

  /// Standard soft shadow for floating elements.
  static final List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: ink,
      brightness: Brightness.light,
      surface: surface,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      textTheme: GoogleFonts.interTextTheme(),
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: ink,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
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
        fillColor: surface,
        hintStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ink, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: ink),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: GoogleFonts.inter(color: bg, fontWeight: FontWeight.w500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: ink,
        textColor: ink,
        contentPadding: EdgeInsets.symmetric(horizontal: 20),
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