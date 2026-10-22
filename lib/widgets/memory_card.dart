import 'package:flutter/material.dart';

import '../theme/tanu_colors.dart';

class MemoryCard extends StatelessWidget {
  final String title;
  final String summary;
  final String time;

  /// When true, the single sharp corner mirrors to the other side so
  /// neighbouring cards in the grid alternate and stay visually balanced.
  final bool mirror;

  const MemoryCard({
    super.key,
    required this.title,
    required this.summary,
    required this.time,
    this.mirror = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(10),
          topRight: const Radius.circular(10),
          bottomLeft: Radius.circular(mirror ? 10 : 0),
          bottomRight: Radius.circular(mirror ? 0 : 10),
        ),
        border: Border.all(color: c.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: c.isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.isNotEmpty ? title : 'Untitled Memory',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: c.heading,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              summary.isNotEmpty ? summary : 'No transcript recorded.',
              style: TextStyle(
                color: c.textMuted,
                fontSize: 13,
                height: 1.3,
              ),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              color: c.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
