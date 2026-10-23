import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tanu_colors.dart';
import 'floating_navigation.dart';

/// Page order supplied by the app shell:
/// 0 = Home, 1 = Library, 2 = Settings, 3 = Recall.
///
/// The visual order below puts Recall before Library while keeping the
/// existing page indices (and therefore the existing navigation state) stable.
const List<FloatingNavItem> _navItems = [
  FloatingNavItem(
    label: 'Home',
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    pageIndex: 0,
    scrollsToTopOnRepeat: true,
  ),
  FloatingNavItem(
    label: 'Recall',
    icon: Icons.auto_awesome_outlined,
    activeIcon: Icons.auto_awesome_rounded,
    pageIndex: 3,
  ),
  FloatingNavItem(
    label: 'Library',
    icon: Icons.grid_view_outlined,
    activeIcon: Icons.grid_view_rounded,
    pageIndex: 1,
    scrollsToTopOnRepeat: true,
  ),
  FloatingNavItem(
    label: 'Settings',
    icon: Icons.tune_outlined,
    activeIcon: Icons.tune_rounded,
    pageIndex: 2,
  ),
];

class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    required this.currentIndex,
    required this.onTabTapped,
    required this.pages,
    this.onAddTap,
  });

  final int currentIndex;
  final void Function(int) onTabTapped;
  final List<Widget> pages;

  /// Optional action for the docked centre button. When omitted, the button
  /// returns to Home, where a memory can be captured.
  final VoidCallback? onAddTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          // Desktop / Wide Layout (Sharp minimalist Sidebar)
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Row(
              children: [
                _Sidebar(
                  currentIndex: currentIndex,
                  onTabTapped: onTabTapped,
                  onAddTap: onAddTap,
                ),
                Container(
                  width: 1,
                  color: Theme.of(context).dividerTheme.color,
                ),
                Expanded(
                  child: IndexedStack(index: currentIndex, children: pages),
                ),
              ],
            ),
          );
        }

        // Mobile / Narrow Layout (Curved notched dock)
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Stack(
            children: [
              IndexedStack(index: currentIndex, children: pages),
              Positioned(
                bottom: MediaQuery.paddingOf(context).bottom + 12,
                left: 16,
                right: 16,
                child: FloatingNavigationBar(
                  items: _navItems,
                  selectedIndex: currentIndex,
                  onTabSelected: onTabTapped,
                  onAddTap: onAddTap,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.currentIndex,
    required this.onTabTapped,
    required this.onAddTap,
  });

  final int currentIndex;
  final void Function(int) onTabTapped;
  final VoidCallback? onAddTap;

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    return Container(
      width: 250,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Text(
                'Tanu',
                style: Theme.of(context).textTheme.displayMedium,
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _navItems.length,
                itemBuilder: (context, index) {
                  final item = _navItems[index];
                  final isSelected = item.pageIndex == currentIndex;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? c.surfaceMuted
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            if (isSelected && !item.scrollsToTopOnRepeat) {
                              return;
                            }
                            onTabTapped(item.pageIndex);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? item.activeIcon : item.icon,
                                  color: isSelected ? c.primary : c.textMuted,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isSelected ? c.primary : c.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    (onAddTap ?? () => onTabTapped(0))();
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add'),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: c.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
