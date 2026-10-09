class DiaryEntry {
  final String id;
  final String title;
  final String transcript;
  final DateTime dateTime;
  final List<String> tags;
  bool isPinned;

  DiaryEntry({
    required this.id,
    required this.title,
    required this.transcript,
    required this.dateTime,
    this.tags = const [],
    this.isPinned = false,
  });

  String get formattedDate =>
      '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';

  static final List<DiaryEntry> sampleEntries = [
    DiaryEntry(
      id: '1',
      dateTime: DateTime(2024, 3, 15, 9, 30),
      title: 'Meeting Note',
      transcript: 'Discussed Q3 project milestones. Reviewed roadmap and upcoming deadlines.',
      tags: ['work', 'meeting'],
    ),
    DiaryEntry(
      id: '2',
      dateTime: DateTime(2024, 3, 15, 7, 15),
      title: 'Workout Reminder',
      transcript: 'Morning run 5km. Focus on breathing.',
      tags: ['fitness'],
    ),
    DiaryEntry(
      id: '3',
      dateTime: DateTime(2024, 3, 14, 20, 45),
      title: 'Daily Recap',
      transcript: 'Spent the day on app development. Fixed UI bugs.',
      tags: ['development'],
    ),
  ];
}
