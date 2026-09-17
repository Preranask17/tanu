import 'package:flutter/cupertino.dart';
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
      color: CupertinoColors.black.withValues(alpha: 0.04),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static const Color primary = ink;

  static CupertinoThemeData getTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primaryInk = isDark ? CupertinoColors.white : CupertinoColors.black;
    final primaryBg = isDark ? CupertinoColors.black : bg;

    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: CupertinoColors.activeBlue,
      primaryContrastingColor: primaryBg,
      barBackgroundColor: primaryBg.withValues(alpha: 0.8), // Translucent for frosted glass
      scaffoldBackgroundColor: primaryBg,
      textTheme: CupertinoTextThemeData(
        primaryColor: primaryInk,
        textStyle: GoogleFonts.inter(
          color: primaryInk,
          fontSize: 17,
          letterSpacing: -0.41,
        ),
        actionTextStyle: GoogleFonts.inter(
          color: CupertinoColors.activeBlue,
          fontSize: 17,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.41,
        ),
        tabLabelTextStyle: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.24,
        ),
        navTitleTextStyle: GoogleFonts.inter(
          color: primaryInk,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.41,
        ),
        navLargeTitleTextStyle: GoogleFonts.inter(
          color: primaryInk,
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
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