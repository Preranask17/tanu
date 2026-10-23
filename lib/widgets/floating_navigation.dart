import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// Grounded, edge-to-edge bottom navigation bar with a raised Ask TANU action.
///
/// Pure presentation: destinations and callbacks come from the scaffold.
class FloatingNavigationBar extends StatelessWidget {
  const FloatingNavigationBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.onAskTap,
  });

  final List<FloatingNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onAskTap;

  static const _barHeight = 62.0;
  static const _fabClearance = 84.0;
  static const _fabSize = 52.0;
  static const _totalHeight = 78.0;

  @override
  Widget build(BuildContext context) {
    assert(items.length == 4, 'The bottom bar expects four destinations.');
    final c = context.tanuColors;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SizedBox(
      height: _totalHeight + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: _totalHeight - _barHeight,
            bottom: 0,
            child: CustomPaint(
              painter: _BottomBarPainter(
                fillColor: c.surface,
                borderColor: c.border,
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, bottomInset),
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
                    const SizedBox(width: _fabClearance),
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
              child: _AskButton(size: _fabSize, onTap: onAskTap),
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
    final activeColor = c.isDark ? c.primary : c.heading;
    final iconColor = selected ? activeColor : c.textMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            if (selected && !item.scrollsToTopOnRepeat) return;
            onTap();
          },
          child: Center(
            child: AnimatedScale(
              scale: selected ? 1.06 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                width: 42,
                height: 42,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: selected
                      ? activeColor.withValues(alpha: c.isDark ? 0.16 : 0.09)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: activeColor.withValues(
                              alpha: c.isDark ? 0.22 : 0.12,
                            ),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ]
                      : const [],
                ),
                child: Center(
                  child: Icon(
                    selected ? item.activeIcon : item.icon,
                    size: 26,
                    color: iconColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AskButton extends StatelessWidget {
  const _AskButton({required this.size, required this.onTap});

  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    return Semantics(
      button: true,
      label: 'Ask TANU',
      child: Material(
        color: TanuPalette.midnightBlue,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: c.isDark ? 0.5 : 0.22),
        shape: CircleBorder(
          side: BorderSide(
            color: c.primary.withValues(alpha: c.isDark ? 0.55 : 0.28),
            width: 1.5,
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          splashColor: Colors.white.withValues(alpha: 0.16),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: SizedBox(
            width: size,
            height: size,
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 28,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBarPainter extends CustomPainter {
  const _BottomBarPainter({required this.fillColor, required this.borderColor});

  final Color fillColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..isAntiAlias = true
        ..color = fillColor,
    );
    canvas.drawLine(
      const Offset(0, 0.5),
      Offset(size.width, 0.5),
      Paint()
        ..isAntiAlias = true
        ..strokeWidth = 1
        ..color = borderColor,
    );
  }

  @override
  bool shouldRepaint(covariant _BottomBarPainter old) =>
      old.fillColor != fillColor || old.borderColor != borderColor;
}
