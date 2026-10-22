import 'package:flutter/material.dart';

import '../theme/tanu_colors.dart';

/// One destination rendered by [FloatingNavigationBar].
@immutable
class FloatingNavItem {
  const FloatingNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.pageIndex,
    this.scrollsToTopOnRepeat = false,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;

  /// Index into the scaffold's page list.
  final int pageIndex;

  /// Whether tapping the already-selected tab should be forwarded (the shell
  /// uses it to scroll that page back to the top).
  final bool scrollsToTopOnRepeat;
}

/// Curved dock navigation bar with a notched centre action.
///
/// Pure presentation: destinations and callbacks come from the scaffold.
class FloatingNavigationBar extends StatelessWidget {
  const FloatingNavigationBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTabSelected,
    this.onAddTap,
  });

  final List<FloatingNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback? onAddTap;

  static const _barHeight = 62.0;
  static const _notchHalfWidth = 42.0;
  static const _fabSize = 52.0;
  static const _totalHeight = 78.0;

  @override
  Widget build(BuildContext context) {
    assert(items.length == 4, 'The dock expects four destinations.');
    final c = context.tanuColors;

    return SizedBox(
      height: _totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _barHeight,
            child: CustomPaint(
              painter: _DockPainter(
                fillColor: c.surface,
                borderColor: c.border,
                shadowColor: Colors.black.withValues(
                  alpha: c.isDark ? 0.45 : 0.16,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: _NavItem(
                        item: items[0],
                        selected: selectedIndex == items[0].pageIndex,
                        onTap: () => onTabSelected(items[0].pageIndex),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        item: items[1],
                        selected: selectedIndex == items[1].pageIndex,
                        onTap: () => onTabSelected(items[1].pageIndex),
                      ),
                    ),
                    const SizedBox(width: _notchHalfWidth * 2),
                    Expanded(
                      child: _NavItem(
                        item: items[2],
                        selected: selectedIndex == items[2].pageIndex,
                        onTap: () => onTabSelected(items[2].pageIndex),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        item: items[3],
                        selected: selectedIndex == items[3].pageIndex,
                        onTap: () => onTabSelected(items[3].pageIndex),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: _AddButton(
                size: _fabSize,
                onTap: onAddTap ?? () => onTabSelected(0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final FloatingNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    final iconColor = selected ? c.primary : c.textMuted;
    final labelColor = selected ? c.primary : c.textMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (selected && !item.scrollsToTopOnRepeat) return;
          onTap();
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? item.activeIcon : item.icon,
                size: 21,
                color: iconColor,
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.1,
                  color: labelColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.size, required this.onTap});

  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    return Semantics(
      button: true,
      label: 'Add',
      child: Material(
        color: c.primary,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: c.isDark ? 0.55 : 0.3),
        shape: CircleBorder(
          side: BorderSide(
            color: c.border.withValues(alpha: c.isDark ? 0.8 : 0.5),
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(Icons.add_rounded, size: 28, color: c.onPrimary),
          ),
        ),
      ),
    );
  }
}

class _DockPainter extends CustomPainter {
  const _DockPainter({
    required this.fillColor,
    required this.borderColor,
    required this.shadowColor,
  });

  final Color fillColor;
  final Color borderColor;
  final Color shadowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _dockPath(size);
    canvas.drawShadow(path, shadowColor, 12, false);
    canvas.drawPath(
      path,
      Paint()
        ..isAntiAlias = true
        ..color = fillColor,
    );
    canvas.drawPath(
      path,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = borderColor,
    );
  }

  Path _dockPath(Size size) {
    final width = size.width;
    final height = size.height;
    final centre = width / 2;
    const radius = 28.0;
    const notchDepth = 38.0;

    return Path()
      ..moveTo(radius, 0)
      ..lineTo(centre - FloatingNavigationBar._notchHalfWidth, 0)
      ..cubicTo(centre - 24, 0, centre - 30, notchDepth, centre, notchDepth)
      ..cubicTo(
        centre + 30,
        notchDepth,
        centre + 24,
        0,
        centre + FloatingNavigationBar._notchHalfWidth,
        0,
      )
      ..lineTo(width - radius, 0)
      ..quadraticBezierTo(width, 0, width, radius)
      ..lineTo(width, height - radius)
      ..quadraticBezierTo(width, height, width - radius, height)
      ..lineTo(radius, height)
      ..quadraticBezierTo(0, height, 0, height - radius)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _DockPainter old) =>
      old.fillColor != fillColor ||
      old.borderColor != borderColor ||
      old.shadowColor != shadowColor;
}
