import 'package:flutter/material.dart';
import '../models/diary_entry.dart';
import '../widgets/diary_entry_card.dart';

class DiaryFeedView extends StatelessWidget {
  const DiaryFeedView({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = DiaryEntry.sampleEntries;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) => DiaryEntryCard(
        entry: entries[index],
      ),
    );
  }
}