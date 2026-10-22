import 'package:flutter/material.dart';

/// Raw Blue & Beige brand values.
///
/// This is the only place where brand hex values should live. Widgets should
/// consume the semantic [TanuColors] extension instead of referencing these
/// constants (or raw hex literals) directly.
abstract final class TanuPalette {
  // ---- Blue ---------------------------------------------------------------
  static const Color blue950 = Color(0xFF0B2233);
  static const Color blue900 = Color(0xFF14344F);
  static const Color blue800 = Color(0xFF1A4263);
  static const Color blue700 = Color(0xFF1F4E79);
  static const Color blue500 = Color(0xFF2F6690);
  static const Color blue300 = Color(0xFF6FA8C9);
  static const Color blue100 = Color(0xFFD7E6F0);
  static const Color blue050 = Color(0xFFEDF4F8);

  // ---- Beige / sand -------------------------------------------------------
  static const Color beige025 = Color(0xFFFFFDF9);
  static const Color beige050 = Color(0xFFFBF8F2);
  static const Color beige100 = Color(0xFFF5F1E9);
  static const Color beige200 = Color(0xFFEDE6D8);
  static const Color beige300 = Color(0xFFE3DCCB);
  static const Color beige400 = Color(0xFFD8CBB4);

  // ---- Slate / charcoal neutrals -----------------------------------------
  static const Color ink900 = Color(0xFF33302B);
  static const Color ink500 = Color(0xFF736B60);

  // ---- Deep navy (dark-mode surfaces) ------------------------------------
  static const Color navy950 = Color(0xFF0E1A24);
  static const Color navy900 = Color(0xFF1C2328);
  static const Color navy800 = Color(0xFF232B31);
  static const Color navy700 = Color(0xFF283137);
  static const Color navy600 = Color(0xFF2C363F);

  // ---- Warm light text for dark mode -------------------------------------
  static const Color sand100 = Color(0xFFF2EDE4);
  static const Color sand300 = Color(0xFFC9C2B6);
  static const Color sand400 = Color(0xFFA6A095);

  // ---- Semantic state only (never brand accents) --------------------------
  static const Color green700 = Color(0xFF2E7D32);
  static const Color green300 = Color(0xFF66BB6A);
  static const Color amber700 = Color(0xFFB26A00);
  static const Color amber300 = Color(0xFFFFB74D);
  static const Color red700 = Color(0xFFC62828);
  static const Color red300 = Color(0xFFEF5350);
  static const Color red100 = Color(0xFFFFDAD6);
  static const Color red050 = Color(0xFFFBEAEA);
  static const Color red900 = Color(0xFF3A1B1B);
}

/// Semantic colour tokens shared by every widget.
///
/// Registered as a [ThemeExtension] by `TanuTheme.getTheme`, so screens can
/// read roles via `context.tanuColors` and get light/dark values for free.
/// This keeps the Blue & Beige palette out of individual widgets and avoids
/// per-widget `isDark ? … : …` colour ternaries.
@immutable
class TanuColors extends ThemeExtension<TanuColors> {
  const TanuColors({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.scaffold,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceElevated,
    required this.border,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.heading,
    required this.success,
    required this.warning,
    required this.danger,
    required this.onDanger,
    required this.dangerContainer,
    required this.onDangerContainer,
  });

  final Brightness brightness;

  /// Primary action / brand blue.
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;

  /// Warm sand surface accent for tags and quiet emphasis. Primary selection
  /// and action states use [primary] instead.
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;

  /// Page background (beige in light mode, deep navy in dark mode).
  final Color scaffold;

  /// Cards, sheets, inputs and other raised surfaces.
  final Color surface;

  /// Recessed surfaces: chips, tracks, inactive pills.
  final Color surfaceMuted;

  /// Higher-contrast surface for menus and overlays.
  final Color surfaceElevated;

  /// Standard hairline border.
  final Color border;

  /// Lower-contrast divider / separator.
  final Color borderSubtle;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// Headlines, page titles and card titles. This is the midnight-blue accent
  /// used for primary typography, separate from body copy.
  final Color heading;

  final Color success;
  final Color warning;
  final Color danger;
  final Color onDanger;
  final Color dangerContainer;
  final Color onDangerContainer;

  bool get isDark => brightness == Brightness.dark;

  /// Light mode: beige canvas, espresso ink, deep blue actions.
  static const TanuColors light = TanuColors(
    brightness: Brightness.light,
    primary: TanuPalette.blue700,
    onPrimary: Colors.white,
    primaryContainer: TanuPalette.blue050,
    onPrimaryContainer: TanuPalette.blue900,
    secondary: TanuPalette.beige400,
    onSecondary: TanuPalette.ink900,
    secondaryContainer: TanuPalette.beige200,
    onSecondaryContainer: TanuPalette.ink900,
    scaffold: TanuPalette.beige100,
    surface: TanuPalette.beige050,
    surfaceMuted: TanuPalette.beige200,
    surfaceElevated: TanuPalette.beige025,
    border: TanuPalette.beige300,
    borderSubtle: TanuPalette.beige200,
    textPrimary: TanuPalette.ink900,
    textSecondary: TanuPalette.ink900,
    textMuted: TanuPalette.ink500,
    heading: TanuPalette.blue700,
    success: TanuPalette.green700,
    warning: TanuPalette.amber700,
    danger: TanuPalette.red700,
    onDanger: Colors.white,
    dangerContainer: TanuPalette.red050,
    onDangerContainer: TanuPalette.red900,
  );

  /// Dark mode: deep navy canvas, warm sand text, lighter blue actions.
  static const TanuColors dark = TanuColors(
    brightness: Brightness.dark,
    primary: TanuPalette.blue300,
    onPrimary: TanuPalette.navy950,
    primaryContainer: TanuPalette.blue900,
    onPrimaryContainer: TanuPalette.blue100,
    secondary: TanuPalette.beige400,
    onSecondary: TanuPalette.ink900,
    secondaryContainer: TanuPalette.ink900,
    onSecondaryContainer: TanuPalette.sand100,
    scaffold: TanuPalette.navy950,
    surface: TanuPalette.navy900,
    surfaceMuted: TanuPalette.navy800,
    surfaceElevated: TanuPalette.navy700,
    border: TanuPalette.navy600,
    borderSubtle: TanuPalette.navy800,
    textPrimary: TanuPalette.sand100,
    textSecondary: TanuPalette.sand300,
    textMuted: TanuPalette.sand400,
    heading: TanuPalette.blue300,
    success: TanuPalette.green300,
    warning: TanuPalette.amber300,
    danger: TanuPalette.red300,
    onDanger: TanuPalette.navy950,
    dangerContainer: TanuPalette.red900,
    onDangerContainer: TanuPalette.red100,
  );

  /// Resolves the active tokens, falling back to light mode if a widget is
  /// rendered outside the Tanu theme (e.g. a bare MaterialApp in a test).
  static TanuColors of(BuildContext context) =>
      Theme.of(context).extension<TanuColors>() ?? light;

  @override
  TanuColors copyWith({
    Brightness? brightness,
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? secondary,
    Color? onSecondary,
    Color? secondaryContainer,
    Color? onSecondaryContainer,
    Color? scaffold,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceElevated,
    Color? border,
    Color? borderSubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? heading,
    Color? success,
    Color? warning,
    Color? danger,
    Color? onDanger,
    Color? dangerContainer,
    Color? onDangerContainer,
  }) {
    return TanuColors(
      brightness: brightness ?? this.brightness,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      secondary: secondary ?? this.secondary,
      onSecondary: onSecondary ?? this.onSecondary,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      onSecondaryContainer: onSecondaryContainer ?? this.onSecondaryContainer,
      scaffold: scaffold ?? this.scaffold,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      heading: heading ?? this.heading,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      onDangerContainer: onDangerContainer ?? this.onDangerContainer,
    );
  }

  @override
  TanuColors lerp(TanuColors? other, double t) {
    if (other == null) return this;
    return TanuColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primaryContainer: Color.lerp(
        primaryContainer,
        other.primaryContainer,
        t,
      )!,
      onPrimaryContainer: Color.lerp(
        onPrimaryContainer,
        other.onPrimaryContainer,
        t,
      )!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      onSecondary: Color.lerp(onSecondary, other.onSecondary, t)!,
      secondaryContainer: Color.lerp(
        secondaryContainer,
        other.secondaryContainer,
        t,
      )!,
      onSecondaryContainer: Color.lerp(
        onSecondaryContainer,
        other.onSecondaryContainer,
        t,
      )!,
      scaffold: Color.lerp(scaffold, other.scaffold, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      heading: Color.lerp(heading, other.heading, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      onDangerContainer: Color.lerp(
        onDangerContainer,
        other.onDangerContainer,
        t,
      )!,
    );
  }
}

/// Shorthand for `TanuColors.of(context)`.
extension TanuColorsContext on BuildContext {
  TanuColors get tanuColors => TanuColors.of(this);
}
