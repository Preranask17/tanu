import 'package:flutter/material.dart';

import '../theme/tanu_colors.dart';

/// Compact TANU wordmark for the primary tab headers.
///
/// Uses the theme's Outfit title face and the active heading token so the logo
/// reads clearly on both the warm beige and deep navy backgrounds. Pure UI:
/// no providers, no backend.
class TanuBrandMark extends StatelessWidget {
  const TanuBrandMark({
    super.key,
    this.size = 24,
    this.alignment = Alignment.centerLeft,
  });

  /// Font size of the wordmark; the line height is kept tight.
  final double size;

  /// Alignment within the available row width.
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.titleLarge ?? const TextStyle();
    return Align(
      alignment: alignment,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text(
          'TANU',
          maxLines: 1,
          semanticsLabel: 'TANU',
          style: base.copyWith(
            color: context.tanuColors.heading,
            fontSize: size,
            fontWeight: FontWeight.w700,
            letterSpacing: size * 0.10,
            height: 1,
          ),
        ),
      ),
    );
  }
}
