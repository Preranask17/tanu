import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/diary_entry.dart';
import '../theme/tanu_colors.dart';
import 'entry_detail_modal.dart';

class DiaryEntryCard extends StatelessWidget {
  final DiaryEntry entry;
  const DiaryEntryCard({required this.entry, super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        builder: (context) => EntryDetailModal(entry: entry),
      ),
      child: Card(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: c.border, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.formattedDate,
                style: GoogleFonts.lato(
                  fontSize: 13,
                  color: c.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                entry.title,
                style: GoogleFonts.ebGaramond(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                entry.transcript,
                style: GoogleFonts.ebGaramond(
                  fontSize: 14,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: entry.tags.map((tag) => Chip(
                  label: Text(
                    tag,
                    style: GoogleFonts.lato(
                      fontSize: 11,
                      color: c.onSecondary,
                    ),
                  ),
                  backgroundColor: c.secondary,
                )).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
