import 'package:flutter/material.dart';

import '../theme/tanu_colors.dart';

class MemoryCard extends StatelessWidget {
  final String title;
  final String summary;
  final String time;

  const MemoryCard({
    super.key,
    required this.title,
    required this.summary,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
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
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
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
              style: textTheme.bodySmall?.copyWith(
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
            style: textTheme.labelSmall?.copyWith(
              fontSize: 11,
              color: c.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
