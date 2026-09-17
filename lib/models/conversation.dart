import 'transcript.dart';

/// The live memory state: one in-progress session being captured, plus the
/// completed sessions that make up the conversation history. Modeled exactly
/// like Omi — the in-progress session's transcript streams in with timestamped
/// segments and is promoted to the history list when a session closes.
class ConversationState {
  const ConversationState({
    this.active,
    this.conversations = const [],
    this.liveTranscript = '',
    this.isListening = false,
    this.receivingAudio = false,
    this.error,
    this.micLevel = 0,
    this.sttEvent = '',
  });

  /// The session currently being recorded (null when idle).
  final ConversationSession? active;

  /// Closed sessions (the Conversations tab).
  final List<ConversationSession> conversations;

  /// The live partial sentence while the user is still talking; merges into
  /// the final segment in place instead of bouncing.
  final String liveTranscript;

  /// True in the ~half second after the last PCM bytes arrived from the
  /// pendant — powers the "receiving audio" animation.
  final bool receivingAudio;

  /// Whether the recognizer session is live.
  final bool isListening;

  final String? error;

  /// Live mic level normalized to 0..1 while a recognizer is active.
  final double micLevel;

  /// Last recognizer status/error surfaced verbatim, for diagnosing on-device.
  final String sttEvent;

  ConversationState copyWith({
    ConversationSession? active,
    List<ConversationSession>? conversations,
    String? liveTranscript,
    bool? isListening,
    bool? receivingAudio,
    String? error,
    double? micLevel,
    String? sttEvent,
    bool clearError = false,
    bool clearActive = false,
  }) {
    return ConversationState(
      active: clearActive ? null : (active ?? this.active),
      conversations: conversations ?? this.conversations,
      liveTranscript: liveTranscript ?? this.liveTranscript,
      isListening: isListening ?? this.isListening,
      receivingAudio: receivingAudio ?? this.receivingAudio,
      error: clearError ? null : (error ?? this.error),
      micLevel: micLevel ?? this.micLevel,
      sttEvent: sttEvent ?? this.sttEvent,
    );
  }
}