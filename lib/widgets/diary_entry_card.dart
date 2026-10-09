import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/diary_entry.dart';
import 'entry_detail_modal.dart';

class DiaryEntryCard extends StatelessWidget {
  final DiaryEntry entry;
  const DiaryEntryCard({required this.entry, super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        builder: (context) => EntryDetailModal(entry: entry),
      ),
      child: Card(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.formattedDate,
                style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF888888)),
              ),
              const SizedBox(height: 8),
              Text(
                entry.title,
                style: GoogleFonts.ebGaramond(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                entry.transcript,
                style: GoogleFonts.ebGaramond(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: entry.tags.map((tag) => Chip(
                  label: Text(tag, style: GoogleFonts.lato(fontSize: 11, color: Colors.white)),
                  backgroundColor: const Color(0xFF899386),
                )).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
