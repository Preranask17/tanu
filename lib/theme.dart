import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme/tanu_colors.dart';

/// Tanu's "Storytelling AI" aesthetic, expressed in Blue & Beige.
///
/// Colour values live in [TanuPalette]; this class maps them onto Material
/// component themes and exposes the semantic [TanuColors] extension so widgets
/// never need to branch on brightness themselves.
class TanuTheme {
  static ThemeData getTheme(Brightness brightness) {
    final colors = brightness == Brightness.dark
        ? TanuColors.dark
        : TanuColors.light;

    final textTheme = TextTheme(
      displayLarge: GoogleFonts.outfit(
        color: colors.heading,
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.15,
        letterSpacing: -0.6,
      ),
      displayMedium: GoogleFonts.outfit(
        color: colors.heading,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.15,
        letterSpacing: -0.5,
      ),
      displaySmall: GoogleFonts.outfit(
        color: colors.heading,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.4,
      ),
      headlineLarge: GoogleFonts.outfit(
        color: colors.heading,
        fontSize: 26,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.4,
      ),
      headlineMedium: GoogleFonts.outfit(
        color: colors.heading,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.3,
      ),
      headlineSmall: GoogleFonts.outfit(
        color: colors.heading,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.2,
      ),
      titleLarge: GoogleFonts.outfit(
        color: colors.heading,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: -0.3,
      ),
      titleMedium: GoogleFonts.outfit(
        color: colors.heading,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: -0.2,
      ),
      titleSmall: GoogleFonts.outfit(
        color: colors.heading,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: -0.1,
      ),
      bodyLarge: GoogleFonts.inter(
        color: colors.textPrimary,
        fontSize: 16,
        letterSpacing: -0.2,
        height: 1.4,
      ),
      bodyMedium: GoogleFonts.inter(
        color: colors.textPrimary,
        fontSize: 15,
        letterSpacing: -0.2,
        height: 1.4,
      ),
      bodySmall: GoogleFonts.inter(
        color: colors.textMuted,
        fontSize: 13,
        letterSpacing: -0.1,
        height: 1.35,
      ),
      labelLarge: GoogleFonts.inter(
        color: colors.textMuted,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      labelMedium: GoogleFonts.inter(
        color: colors.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelSmall: GoogleFonts.inter(
        color: colors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );

    final scheme =
        ColorScheme.fromSeed(
          seedColor: TanuPalette.blue700,
          brightness: brightness,
        ).copyWith(
          primary: colors.primary,
          onPrimary: colors.onPrimary,
          primaryContainer: colors.primaryContainer,
          onPrimaryContainer: colors.onPrimaryContainer,
          secondary: colors.secondary,
          onSecondary: colors.onSecondary,
          secondaryContainer: colors.secondaryContainer,
          onSecondaryContainer: colors.onSecondaryContainer,
          surface: colors.surface,
          onSurface: colors.textPrimary,
          onSurfaceVariant: colors.textSecondary,
          surfaceDim: colors.surfaceMuted,
          surfaceBright: colors.surfaceElevated,
          surfaceContainerLowest: colors.isDark
              ? colors.scaffold
              : colors.surfaceElevated,
          surfaceContainerLow: colors.surface,
          surfaceContainer: colors.surface,
          surfaceContainerHigh: colors.surfaceMuted,
          surfaceContainerHighest: colors.isDark
              ? colors.surfaceElevated
              : colors.surfaceMuted,
          outline: colors.border,
          outlineVariant: colors.borderSubtle,
          error: colors.danger,
          onError: colors.onDanger,
          errorContainer: colors.dangerContainer,
          onErrorContainer: colors.onDangerContainer,
          inverseSurface: colors.textPrimary,
          onInverseSurface: colors.scaffold,
          inversePrimary: colors.primary,
          shadow: Colors.black,
          scrim: Colors.black,
        );

    OutlineInputBorder outline(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(color: color),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: colors.primary,
      scaffoldBackgroundColor: colors.scaffold,
      canvasColor: colors.scaffold,
      cardColor: colors.surface,
      dividerColor: colors.border,
      colorScheme: scheme,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.scaffold,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colors.textPrimary),
        titleTextStyle: textTheme.titleLarge,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.scaffold,
        selectedItemColor: colors.primary,
        unselectedItemColor: colors.textMuted,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.scaffold,
        indicatorColor: colors.primary.withValues(alpha: 0.14),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? colors.heading : colors.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colors.primary : colors.textMuted,
            size: 24,
          );
        }),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: colors.textPrimary, size: 24),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.primary,
        selectionColor: colors.primary.withValues(alpha: 0.25),
        selectionHandleColor: colors.primary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: outline(colors.border),
        enabledBorder: outline(colors.border),
        focusedBorder: outline(colors.primary),
        errorBorder: outline(colors.danger),
        focusedErrorBorder: outline(colors.danger),
        hintStyle: TextStyle(color: colors.textMuted),
        labelStyle: TextStyle(color: colors.textSecondary),
        prefixIconColor: colors.textMuted,
        suffixIconColor: colors.textMuted,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          disabledBackgroundColor: colors.border,
          disabledForegroundColor: colors.textMuted,
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
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
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
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          side: BorderSide(color: colors.border),
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
          foregroundColor: colors.primary,
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.textPrimary,
          disabledForegroundColor: colors.textMuted,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: colors.isDark ? 0.4 : 0.04),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colors.surface,
        modalBarrierColor: Colors.black.withValues(
          alpha: colors.isDark ? 0.6 : 0.35,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceMuted,
        selectedColor: colors.primaryContainer,
        disabledColor: colors.surfaceMuted,
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colors.textSecondary,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.onPrimaryContainer,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textSecondary,
        textColor: colors.heading,
        subtitleTextStyle: TextStyle(color: colors.textMuted),
        selectedTileColor: colors.primary.withValues(alpha: 0.10),
        selectedColor: colors.primary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.isDark
            ? colors.surfaceElevated
            : colors.textPrimary,
        contentTextStyle: TextStyle(
          color: colors.isDark ? colors.textPrimary : colors.surface,
        ),
        actionTextColor: colors.isDark ? colors.primary : TanuPalette.blue300,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          return states.contains(WidgetState.selected)
              ? colors.onPrimary
              : colors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          return states.contains(WidgetState.selected)
              ? colors.primary
              : colors.surfaceMuted;
        }),
        trackOutlineColor: WidgetStatePropertyAll(colors.border),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceMuted,
        circularTrackColor: colors.surfaceMuted,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.surfaceMuted,
        thumbColor: colors.primary,
        overlayColor: colors.primary.withValues(alpha: 0.12),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.isDark ? colors.surfaceElevated : colors.textPrimary,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          color: colors.isDark ? colors.textPrimary : colors.surface,
          fontSize: 12,
        ),
      ),
    );
  }
}
