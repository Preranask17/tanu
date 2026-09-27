import 'package:flutter/material.dart';

class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    required this.currentIndex,
    required this.onTabTapped,
    required this.pages,
    required this.items,
  });

  final int currentIndex;
  final void Function(int) onTabTapped;
  final List<Widget> pages;
  final List<BottomNavigationBarItem> items;

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
                  items: items,
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
        } else {
          // Mobile / Narrow Layout (Floating Pill Dock)
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Stack(
              children: [
                IndexedStack(index: currentIndex, children: pages),
                Positioned(
                  bottom: MediaQuery.paddingOf(context).bottom + 16,
                  left: 32,
                  right: 32,
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(items.length, (index) {
                        final item = items[index];
                        final isSelected = index == currentIndex;
                        final activeIconData = (item.activeIcon as Icon?)?.icon;
                        final iconData = (item.icon as Icon?)?.icon;
                        
                        return GestureDetector(
                          onTap: () => onTabTapped(index),
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? (isDark ? const Color(0xFF222222) : const Color(0xFFF0F0F0))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              isSelected ? (activeIconData ?? iconData) : iconData,
                              color: isSelected 
                                  ? (isDark ? Colors.white : Colors.black)
                                  : const Color(0xFF888888),
                              size: 24,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.currentIndex,
    required this.onTabTapped,
    required this.items,
  });

  final int currentIndex;
  final void Function(int) onTabTapped;
  final List<BottomNavigationBarItem> items;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final isSelected = index == currentIndex;
                  final item = items[index];
                  final activeIconData = (item.activeIcon as Icon?)?.icon;
                  final iconData = (item.icon as Icon?)?.icon;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onTabTapped(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? const Color(0xFF222222) : const Color(0xFFF0F0F0))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? (activeIconData ?? iconData) : iconData,
                              color: isSelected
                                  ? (isDark ? Colors.white : Colors.black)
                                  : const Color(0xFF888888),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              item.label ?? '',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected
                                    ? (isDark ? Colors.white : Colors.black)
                                    : const Color(0xFF888888),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
