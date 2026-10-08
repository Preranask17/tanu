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
    this.speaker,
  });

  final String id;
  final String text;
  final DateTime timestamp;

  /// Milliseconds since the session started (SRT-style offset for display).
  final int startMs;
  final int? endMs;

  /// Always true today — the pendant is a single-user mic.
  final bool isUser;

  /// Acoustic speaker label assigned by post-session diarization
  /// (`'You'`, `'Other 1'`, …). Null until (or when) diarization runs —
  /// never invent one from text alone.
  final String? speaker;

  TranscriptSegment copyWith({
    String? id,
    String? text,
    DateTime? timestamp,
    int? startMs,
    int? endMs,
    bool? isUser,
    String? speaker,
    bool clearSpeaker = false,
  }) {
    return TranscriptSegment(
      id: id ?? this.id,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      isUser: isUser ?? this.isUser,
      speaker: clearSpeaker ? null : (speaker ?? this.speaker),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
    'startMs': startMs,
    'endMs': endMs,
    'isUser': isUser,
    if (speaker != null) 'speaker': speaker,
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
      speaker: json['speaker'] as String?,
    );
  }
}

/// One speaker-attributed turn of a processed memory: the structured,
/// reviewable unit the RAG layer indexes and the UI renders.
///
/// Turns are produced post-session — either by acoustic diarization aligned
/// to STT segments, by the memory processor's structured output, or both —
/// so unlike raw [TranscriptSegment]s they always carry a speaker label and
/// a time span.
@immutable
class TranscriptTurn {
  const TranscriptTurn({
    required this.speaker,
    required this.text,
    this.startMs = 0,
    this.endMs,
  });

  /// `'You'` for the wearer, `'Other 1'…` for everyone else. Session-local:
  /// `Other 1` in one memory is not the same person as `Other 1` in another.
  final String speaker;
  final String text;

  /// Milliseconds since the session started.
  final int startMs;
  final int? endMs;

  TranscriptTurn copyWith({
    String? speaker,
    String? text,
    int? startMs,
    int? endMs,
  }) {
    return TranscriptTurn(
      speaker: speaker ?? this.speaker,
      text: text ?? this.text,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'speaker': speaker,
    'text': text,
    'startMs': startMs,
    'endMs': endMs,
  };

  factory TranscriptTurn.fromJson(Map<String, dynamic> json) {
    return TranscriptTurn(
      speaker: json['speaker'] as String? ?? 'Other 1',
      text: json['text'] as String? ?? '',
      startMs: json['startMs'] as int? ?? 0,
      endMs: json['endMs'] as int?,
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
    this.turns = const [],
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

  /// Structured speaker turns, filled in by post-session processing. Empty
  /// for sessions captured before the structured pipeline existed (they fall
  /// back to [segments] / [cleanedTranscript] everywhere).
  final List<TranscriptTurn> turns;
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
    List<TranscriptTurn>? turns,
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
      turns: turns ?? this.turns,
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
    if (turns.isNotEmpty) 'turns': turns.map((t) => t.toJson()).toList(),
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
    final turns = (json['turns'] as List? ?? [])
        .whereType<Map>()
        .map((t) => TranscriptTurn.fromJson(Map<String, dynamic>.from(t)))
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
      turns: turns,
      isDeleted: json['isDeleted'] as bool? ?? false,
      isPinned: json['isPinned'] as bool? ?? false,
    );
  }
}
