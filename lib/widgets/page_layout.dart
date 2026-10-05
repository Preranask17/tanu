import 'package:flutter/material.dart';

const double kPageMaxWidth = 970;
const double kPageGutter = 24;

class TanuPageTitle extends StatelessWidget {
  const TanuPageTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.displayMedium);
  }
}

class TanuPageRail extends StatelessWidget {
  const TanuPageRail({
    super.key,
    required this.child,
    this.bottom = 60,
    this.top = 16,
  });

  final Widget child;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(kPageGutter, top, kPageGutter, bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kPageMaxWidth),
          child: child,
        ),
      ),
    );
  }
}

class TanuPageIconButton extends StatelessWidget {
  const TanuPageIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.selected = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool selected;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final button = IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : (dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7)),
        foregroundColor: selected
            ? theme.colorScheme.primary
            : (dark ? Colors.white : Colors.black),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon),
    );
    return MouseRegion(cursor: SystemMouseCursors.click, child: button);
  }
}
