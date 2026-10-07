import 'package:flutter/foundation.dart';

/// Lifecycle of a memory session, mirroring Omi's conversation states.
enum ConversationStatus { inProgress, completed }

/// One locked (or lazily live-merged) line of transcript. Partials write into
/// the same [id] and the finalized text replaces it in place — Omi's curate
/// behavior — so words lock into the transcript instead of racing.
@immutable
class TranscriptSegment {
  const TranscriptSegment({
    required this.id,
    required this.text,
    required this.timestamp,
    this.startMs = 0,
    this.endMs,
    this.isUser = true,
  });

  final String id;
  final String text;
  final DateTime timestamp;

  /// Milliseconds since the session started (SRT-style offset for display).
  final int startMs;
  final int? endMs;

  /// Always true today — the pendant is a single-user mic.
  final bool isUser;

  TranscriptSegment copyWith({
    String? id,
    String? text,
    DateTime? timestamp,
    int? startMs,
    int? endMs,
    bool? isUser,
  }) {
    return TranscriptSegment(
      id: id ?? this.id,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      isUser: isUser ?? this.isUser,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
    'startMs': startMs,
    'endMs': endMs,
    'isUser': isUser,
  };

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) {
    return TranscriptSegment(
      id: json['id'] as String,
      text: json['text'] as String? ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      startMs: json['startMs'] as int? ?? 0,
      endMs: json['endMs'] as int?,
      isUser: json['isUser'] as bool? ?? true,
    );
  }
}

/// A recording session: the in-progress memory fills [segments] while [status]
/// is [ConversationStatus.inProgress] and is moved into the conversations list
/// as [ConversationStatus.completed] once it closes.
@immutable
class ConversationSession {
  const ConversationSession({
    required this.id,
    required this.title,
    required this.startedAt,
    this.finishedAt,
    this.status = ConversationStatus.inProgress,
    this.segments = const [],
    this.summary,
    this.cleanedTranscript,
    this.isDeleted = false,
    this.isPinned = false,
  });

  final String id;
  final String title;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final ConversationStatus status;
  final List<TranscriptSegment> segments;
  final String? summary;
  final String? cleanedTranscript;
  final bool isDeleted;
  final bool isPinned;

  String get transcriptText => segments.map((s) => s.text).join(' ').trim();

  int get segmentCount => segments.length;

  ConversationSession copyWith({
    String? title,
    DateTime? finishedAt,
    ConversationStatus? status,
    List<TranscriptSegment>? segments,
    String? summary,
    String? cleanedTranscript,
    bool? isDeleted,
    bool? isPinned,
  }) {
    return ConversationSession(
      id: id,
      title: title ?? this.title,
      startedAt: startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      status: status ?? this.status,
      segments: segments ?? this.segments,
      summary: summary ?? this.summary,
      cleanedTranscript: cleanedTranscript ?? this.cleanedTranscript,
      isDeleted: isDeleted ?? this.isDeleted,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'finishedAt': finishedAt?.toIso8601String(),
    'status': status.name,
    'segments': segments.map((s) => s.toJson()).toList(),
    'summary': summary,
    'cleanedTranscript': cleanedTranscript,
    'isDeleted': isDeleted,
    'isPinned': isPinned,
  };

  factory ConversationSession.fromJson(Map<String, dynamic> json) {
    final started = DateTime.tryParse(json['startedAt'] as String? ?? '');
    final status = ConversationStatus.values
        .asNameMap()[json['status'] as String];
    final segments = (json['segments'] as List? ?? [])
        .whereType<Map>()
        .map((s) => TranscriptSegment.fromJson(Map<String, dynamic>.from(s)))
        .toList();
    return ConversationSession(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      startedAt: started ?? DateTime.now(),
      finishedAt: json['finishedAt'] == null
          ? null
          : DateTime.tryParse(json['finishedAt'] as String),
      status: status ?? ConversationStatus.completed,
      segments: segments,
      summary: json['summary'] as String?,
      cleanedTranscript: json['cleanedTranscript'] as String?,
      isDeleted: json['isDeleted'] as bool? ?? false,
      isPinned: json['isPinned'] as bool? ?? false,
    );
  }
}
