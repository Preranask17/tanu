import 'package:flutter/material.dart';

import '../theme/tanu_colors.dart';

class FloatingNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabSelected;

  const FloatingNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: c.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCircleButton(
            context,
            icon: Icons.mic,
            index: 0,
            isSelected: selectedIndex == 0,
          ),
          const SizedBox(width: 8),
          _buildCircleButton(
            context,
            icon: Icons.settings,
            index: 1,
            isSelected: selectedIndex == 1,
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton(
    BuildContext context, {
    required IconData icon,
    required int index,
    required bool isSelected,
  }) {
    final c = context.tanuColors;
    return GestureDetector(
      onTap: () => onTabSelected(index),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? c.primary : Colors.transparent,
        ),
        child: Icon(
          icon,
          color: isSelected ? c.onPrimary : c.textMuted,
          size: 22,
        ),
      ),
    );
  }
}
