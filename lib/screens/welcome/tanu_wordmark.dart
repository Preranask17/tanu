import 'package:flutter/material.dart';

/// White TANU wordmark logo.
///
/// Loads `assets/images/tanu_wordmark.png` (white type on transparency,
/// aspect preserved, high filter quality for crisp high-DPI rendering).
/// If the file is ever missing, renders nothing — never a red error box.
/// Non-interactive and pointer-transparent by default (plain [Image]).
///
/// Pure UI: no providers, no backend.
class TanuWordmark extends StatelessWidget {
  const TanuWordmark({
    super.key,
    this.height = 32,
    this.alignment = Alignment.centerLeft,
  });

  /// Logical render height; width follows the asset aspect ratio.
  final double height;

  /// Alignment within the available row width.
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Image.asset(
        'assets/images/tanu_wordmark.png',
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stackTrace) =>
            const SizedBox.shrink(),
      ),
    );
  }
}
