import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/diary_entry.dart';

class EntryDetailModal extends StatelessWidget {
  const EntryDetailModal({
    required this.entry,
    super.key,
  });

  final DiaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = const Color(0xFFF5F1E9);
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5);
    final textColor = isDark ? Colors.white : const Color(0xFF4A453F);
    final accentColor = const Color(0xFF899386);

    final durationText = _formatDuration(entry.dateTime);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(color: borderColor, width: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header
            Row(
              children: [
                Text(
                  entry.formattedDate,
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    color: const Color(0xFF888888),
                    height: 1.2,
                  ),
                ),
                const Spacer(),
                Text(
                  durationText,
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    color: const Color(0xFF888888),
                    height: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Summary Section
            Text(
              'Summary',
              style: GoogleFonts.lato(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              entry.title,
              style: GoogleFonts.lora(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),

            // Full Transcript Section
            Text(
              'Transcript',
              style: GoogleFonts.lato(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              entry.transcript,
              style: GoogleFonts.lora(
                fontSize: 14,
                color: textColor.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
            const Spacer(),

            // Action Buttons
            Column(
              children: [
                _ActionRow(
                  icon: Icons.push_pin,
                  label: 'Pin Entry',
                  onTap: () => _onAction(context, 'pin'),
                  color: accentColor,
                ),
                const Divider(height: 8, thickness: 0.5),
                _ActionRow(
                  icon: Icons.edit,
                  label: 'Edit',
                  onTap: () => _onAction(context, 'edit'),
                  color: accentColor,
                ),
                const Divider(height: 8, thickness: 0.5),
                _ActionRow(
                  icon: Icons.link,
                  label: 'Copy Link',
                  onTap: () => _onAction(context, 'copy'),
                  color: accentColor,
                ),
                const Divider(height: 8, thickness: 0.5),
                _ActionRow(
                  icon: Icons.delete,
                  label: 'Delete',
                  onTap: () => _onAction(context, 'delete'),
                  color: const Color(0xFFE74C3C),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatDuration(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    }
    if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    }
    if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    }
    return 'Just now';
  }

  void _onAction(BuildContext context, String action) {
    // Close the modal first
    Navigator.of(context).maybePop();

    // Show action confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Entry $action',
          style: GoogleFonts.lato(
            color: const Color(0xFFF5F1E9),
            fontSize: 14,
          ),
        ),
        backgroundColor: action == 'delete'
            ? const Color(0xFFE74C3C)
            : const Color(0xFF899386),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF4A453F);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.lato(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
                height: 1.3,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: textColor.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}