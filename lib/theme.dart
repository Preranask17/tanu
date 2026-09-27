import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tanu's "Storytelling AI" Aesthetic
class TanuTheme {
  static ThemeData getTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    
    // Deep contrast colors
    final primaryInk = isDark ? Colors.white : Colors.black;
    final primaryBg = isDark ? const Color(0xFF000000) : const Color(0xFFFAFAFA);
    final surfaceColor = isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF);
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5);
    final accentBlue = isDark ? const Color(0xFF4A90E2) : Colors.blueAccent;
    final mutedText = isDark ? const Color(0xFF888888) : const Color(0xFF666666);

    final textTheme = TextTheme(
      displayLarge: GoogleFonts.dmSerifDisplay(
        color: primaryInk,
        fontSize: 32,
        height: 1.2,
      ),
      displayMedium: GoogleFonts.dmSerifDisplay(
        color: primaryInk,
        fontSize: 28,
        height: 1.2,
      ),
      titleLarge: GoogleFonts.inter(
        color: primaryInk,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      ),
      bodyLarge: GoogleFonts.inter(
        color: primaryInk,
        fontSize: 16,
        letterSpacing: -0.2,
        height: 1.4,
      ),
      bodyMedium: GoogleFonts.inter(
        color: primaryInk,
        fontSize: 15,
        letterSpacing: -0.2,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.inter(
        color: mutedText,
        fontSize: 13,
        letterSpacing: 0,
      ),
    );

    return ThemeData(
      brightness: brightness,
      primaryColor: accentBlue,
      scaffoldBackgroundColor: primaryBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentBlue,
        brightness: brightness,
        surface: surfaceColor,
        onSurface: primaryInk,
        primary: accentBlue,
        onPrimary: Colors.white,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryBg,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: primaryInk),
        titleTextStyle: textTheme.titleLarge,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: primaryBg,
        selectedItemColor: accentBlue,
        unselectedItemColor: mutedText,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(
        color: primaryInk,
        size: 24,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accentBlue,
        selectionColor: accentBlue.withValues(alpha: 0.3),
        selectionHandleColor: accentBlue,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: accentBlue),
        ),
        hintStyle: TextStyle(color: mutedText),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryInk,
          foregroundColor: primaryBg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentBlue,
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
