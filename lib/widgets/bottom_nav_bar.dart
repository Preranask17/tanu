import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/navigation_provider.dart';
import '../theme.dart';

/// Height of the bottom nav row above whatever bottom inset it reserves.
const double kBottomNavBarHeight = 92;

/// Gap between the top of the nav row and the home chat bar that floats above
/// it. The chat bar derives its offset from this pair rather than repeating a
/// literal, so changing the row height can't silently close the gap.
const double kBottomNavChatBarGap = 14;

/// Bottom inset the nav row reserves for system chrome. Anything positioned
/// against the row must add this to stay in step with it.
double bottomNavBarReservedInset(BuildContext context) =>
    MediaQuery.viewPaddingOf(context).bottom;

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key, required this.onTabTap});

  /// [index] the tapped tab; [isRepeat] true when it was already selected
  /// (use to scroll the tab content back to top).
  final void Function(int index, bool isRepeat) onTabTap;

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  late final Widget _navigation;

  @override
  void initState() {
    super.initState();
    _navigation = _NavRow(onTabTap: widget.onTabTap);
  }

  @override
  Widget build(BuildContext context) => _navigation;
}

class _NavRow extends ConsumerWidget {
  const _NavRow({required this.onTabTap});

  final void Function(int index, bool isRepeat) onTabTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(navigationTabProvider);
    final bottomInset = bottomNavBarReservedInset(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        height: kBottomNavBarHeight + bottomInset,
        padding: EdgeInsets.fromLTRB(12, 10, 12, bottomInset),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.35, 1.0],
            colors: [Colors.transparent, kTanuNavEdge, kTanuNavEdge],
          ),
        ),
        child: Row(
          children: [
            _buildTab(context, index, 0, Icons.home_outlined, Icons.home, 'Home'),
            _buildTab(context, index, 1, Icons.forum_outlined, Icons.forum, 'Conversations'),
            _buildTab(context, index, 2, Icons.settings_outlined, Icons.settings, 'Settings'),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(BuildContext context, int selectedIndex, int index,
      IconData icon, IconData selectedIcon, String label) {
    final selected = selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          onTabTap(index, selected);
          primaryFocus?.unfocus();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            HapticFeedback.selectionClick();
          });
        },
        child: SizedBox(
          height: kBottomNavBarHeight - 8,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: 24,
                  color: selected ? kTanuInk : kTanuMuted.withValues(alpha: 0.8),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? kTanuInk : kTanuMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}