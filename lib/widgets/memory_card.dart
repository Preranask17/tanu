import 'package:flutter/material.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(10),
          topRight: const Radius.circular(10),
          bottomLeft: Radius.circular(mirror ? 10 : 0),
          bottomRight: Radius.circular(mirror ? 0 : 10),
        ),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              color: isDark ? Colors.white : const Color(0xFF4A453F),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              summary.isNotEmpty ? summary : 'No transcript recorded.',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : const Color(0xFF777777),
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
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF888888),
            ),
          ),
        ],
      ),
    );
  }
}
