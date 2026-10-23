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

/// Flat, edge-to-edge bottom navigation bar with four labeled tabs.
///
/// Pure presentation: destinations and callbacks come from the scaffold.
class FloatingNavigationBar extends StatelessWidget {
  const FloatingNavigationBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final List<FloatingNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  static const _barHeight = 78.0;

  @override
  Widget build(BuildContext context) {
    assert(items.length == 4, 'The bottom bar expects four destinations.');
    final c = context.tanuColors;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      height: _barHeight + bottomInset,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: _NavItem(
                item: item,
                selected: selectedIndex == item.pageIndex,
                onTap: () => onTabSelected(item.pageIndex),
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
    final color = selected ? c.heading : c.textMuted;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: color,
      fontSize: 11.5,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.1,
    );

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? item.activeIcon : item.icon,
                  size: 24,
                  color: color,
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
