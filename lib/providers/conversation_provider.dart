import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../constants.dart';
import '../abstractions/audio_source.dart';
import '../abstractions/stt_engine.dart';
import '../models/conversation.dart';
import '../models/transcript.dart';
import '../services/storage_service.dart';
import '../services/stt/routing_stt_engine.dart';
import 'agent_provider.dart';
import 'ble_provider.dart';
import 'commitment_provider.dart';
import 'settings_provider.dart';

/// The typed routing engine backing [sttEngineProvider]. Settings toggles read
/// this to flip the cloud/on-device preference live via [RoutingSttEngine.switchBackend].
final routingSttEngineProvider = Provider<RoutingSttEngine>((ref) {
  final settings = ref.read(settingsProvider);
  final engine = RoutingSttEngine(backend: settings.sttBackend);
  ref.onDispose(() => unawaited(engine.dispose()));
  return engine;
});

/// [RoutingSttEngine] dispatches continuous speech to Deepgram streaming when
/// the user's STT preference is cloud and to the on-device Moonshine model
/// otherwise, so the conversation loop talks to one engine regardless of the
/// active recognizer.
final sttEngineProvider = Provider<ContinuousSttEngine>((ref) {
  final engine = ref.watch(routingSttEngineProvider);
  ref.onDispose(() => unawaited(engine.dispose()));
  return engine;
});

/// Drives the core loop: pendant audio -> continuous STT -> timestamped
/// transcript segments inside one in-progress "memory" session — the same
/// session model Omi uses. Sessions close on pendant disconnect, a double-tap
/// of the pendant button, or an idle timeout, and land in the conversations
/// list as completed memories.
final conversationProvider =
    NotifierProvider<ConversationNotifier, ConversationState>(
  ConversationNotifier.new,
);

/// How long a completed memory can stay quiet in a session before it is
/// closed automatically (Omi's server-side `conversation_timeout` equivalent).
/// Generous so a quiet stretch between thoughts doesn't split a memory.
const Duration kSessionIdleTimeout = Duration(minutes: 20);

class ConversationNotifier extends Notifier<ConversationState> {
  static const Duration _doubleTapWindow = Duration(milliseconds: 800);
  static const int _titleCutoff = 48;

  bool _continuousStarted = false;
  bool _micTestActive = false;
  bool _resumeAfterMicTest = false;
  StreamSubscription<Uint8List>? _receivingSub;
  StreamSubscription<int>? _buttonSub;
  Timer? _receivingTimer;
  Timer? _idleTimer;
  Timer? _doubleTapTimer;
  DateTime? _lastShortPressAt;
  Stopwatch _clock = Stopwatch();

  @override
  ConversationState build() {
    final loaded = _loadState();
    ref.listen(pendantStatusProvider, (prev, next) {
      _syncContinuous(next.value);
    });
    scheduleMicrotask(() {
      _syncContinuous(
        ref.read(pendantStatusProvider).value ??
            ref.read(pendantProvider).currentStatus,
      );
    });
    return ConversationState(
      active: loaded.active,
      conversations: loaded.completed,
    );
  }

  /// --- Session lifecycle ------------------------------------------------

  void _syncContinuous(PendantStatus? status) {
    final connected = status?.isConnected ?? false;
    if (connected && !_micTestActive && !_continuousStarted) {
      unawaited(_startContinuous());
    } else if (!connected && _continuousStarted) {
      unawaited(_stopContinuous());
    }
  }

  Future<void> _startContinuous() async {
    if (_continuousStarted || _micTestActive) return;
    _continuousStarted = true;

    final engine = ref.read(sttEngineProvider);
    final source = ref.read(pendantProvider);

    // Every connect opens a brand-new memory (Omi: a new session starts each
    // time streaming begins). Stored sessions are never resumed.
    final now = DateTime.now();
    state = state.copyWith(
      active: ConversationSession(
        id: 's${now.microsecondsSinceEpoch}',
        title: '',
        startedAt: now,
        status: ConversationStatus.inProgress,
      ),
      isListening: true,
      sttEvent: 'listening…',
    );
    _clock = Stopwatch()..start();

    _buttonSub?.cancel();
    _buttonSub = source.buttonEvents.listen(_onButtonEvent);

    final ok = await engine.startContinuous(
      source.pcmAudio,
      onUtterance: _onUtterance,
      onPartial: _onPartial,
      onMicLevel: (level) {
        state = state.copyWith(micLevel: level, isListening: true);
      },
      onEvent: (event) {
        if (event.isNotEmpty) {
          state = state.copyWith(sttEvent: event, isListening: true);
        }
      },
    );
    if (!ok) {
      state = state.copyWith(
        isListening: false,
        sttEvent: 'stt unavailable',
      );
      _continuousStarted = false;
    } else {
      // The "phone just received bytes from the pendant" cue: any PCM chunk
      // lights the receiving flag for a short window.
      _receivingSub?.cancel();
      _receivingSub = source.pcmAudio.listen((_) => _bumpReceiving());
    }
  }

  /// Closes the current memory into the conversations list. Recording keeps
  /// flowing into a brand-new session, exactly like Omi after a force-process.
  void forceEndSession() {
    final session = state.active;
    if (session != null && session.segments.isNotEmpty) {
      final finished = session.copyWith(
        status: ConversationStatus.completed,
        finishedAt: DateTime.now(),
      );
      state = state.copyWith(
        conversations: [...state.conversations, finished],
        active: null,
        liveTranscript: '',
      );
      _processMemoryAsync(finished);
    } else {
      state = state.copyWith(active: null, liveTranscript: '');
    }
    _idleTimer?.cancel();
    _idleTimer = null;
    _clock = Stopwatch();
    if (_continuousStarted) {
      // Keep listening: open the next memory so speech continues seamlessly.
      final now = DateTime.now();
      state = state.copyWith(
        active: ConversationSession(
          id: 's${now.microsecondsSinceEpoch}',
          title: '',
          startedAt: now,
          status: ConversationStatus.inProgress,
        ),
      );
      _clock = Stopwatch()..start();
    }
    _persist();
  }

  Future<void> _stopContinuous() async {
    if (!_continuousStarted) return;
    _continuousStarted = false;
    _buttonSub?.cancel();
    _buttonSub = null;
    _receivingSub?.cancel();
    _receivingSub = null;
    _receivingTimer?.cancel();
    _receivingTimer = null;
    _idleTimer?.cancel();
    _idleTimer = null;

    final engine = ref.read(sttEngineProvider);
    await engine.stopContinuous();

    final session = state.active;
    if (session != null && session.segments.isNotEmpty) {
      final finished = session.copyWith(
        status: ConversationStatus.completed,
        finishedAt: DateTime.now(),
      );
      state = state.copyWith(
        active: null,
        conversations: [...state.conversations, finished],
        liveTranscript: '',
        isListening: false,
        receivingAudio: false,
        micLevel: 0,
      );
      _processMemoryAsync(finished);
    } else {
      state = state.copyWith(
        active: null,
        liveTranscript: '',
        isListening: false,
        receivingAudio: false,
        micLevel: 0,
      );
    }
    _persist();
  }

  void _bumpReceiving() {
    if (!state.receivingAudio) {
      state = state.copyWith(receivingAudio: true);
    }
    _receivingTimer?.cancel();
    _receivingTimer = Timer(const Duration(milliseconds: 450), () {
      state = state.copyWith(receivingAudio: false);
    });
  }

  /// --- Transcript stream (Omi-style in-place merge) ----------------------

  static final _hallucinations = {
    'thank you.',
    'thank you',
    'thank you!',
    'bye.',
    'bye',
    'thanks for watching.',
    'thanks for watching!',
    'subtitles by amara.org',
    'you',
    'you.',
  };

  bool _isHallucination(String text) {
    return _hallucinations.contains(text.toLowerCase());
  }

  /// Live partial sentence: writes into the last (open) segment in place and
  /// only opens a new segment id when the previous one was locked.
  void _onPartial(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isHallucination(trimmed) || _micTestActive) return;
    if (!_continuousStarted) return;
    final session = state.active;
    if (session == null) return;

    final segments = List<TranscriptSegment>.of(session.segments);
    final last = segments.isEmpty ? null : segments.last;
    if (last != null && last.endMs == null) {
      segments[segments.length - 1] = last.copyWith(text: trimmed);
    } else {
      final ms = _clock.elapsedMilliseconds;
      segments.add(TranscriptSegment(
        id: '${session.id}-${segments.length}',
        text: trimmed,
        timestamp: DateTime.now(),
        startMs: ms,
        endMs: ms,
      ));
    }
    state = state.copyWith(
      active: _withTitle(session, segments),
      liveTranscript: trimmed,
      isListening: true,
      sttEvent: '',
    );
  }

  /// Finalized sentence: locks the open segment (same id, merge/curate) or
  /// appends one if no partial previewed it. Resets the idle timer.
  void _onUtterance(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isHallucination(trimmed) || _micTestActive) return;
    if (!_continuousStarted) return;
    final session = state.active;
    if (session == null) return;

    final ms = _clock.elapsedMilliseconds;
    final segments = List<TranscriptSegment>.of(session.segments);
    final last = segments.isEmpty ? null : segments.last;
    if (last != null && last.endMs == null) {
      segments[segments.length - 1] = last.copyWith(
        text: trimmed,
        timestamp: DateTime.now(),
        endMs: ms,
      );
    } else {
      final start = segments.isEmpty ? 0 : (ms - 800).clamp(0, ms);
      segments.add(TranscriptSegment(
        id: '${session.id}-${segments.length}',
        text: trimmed,
        timestamp: DateTime.now(),
        startMs: start,
        endMs: ms,
      ));
    }

    state = state.copyWith(
      active: _withTitle(session, segments),
      liveTranscript: '',
      isListening: true,
      sttEvent: '',
    );
    _resetIdleTimer();
  }

  ConversationSession _withTitle(
    ConversationSession session,
    List<TranscriptSegment> segments,
  ) {
    var title = session.title;
    if (title.isEmpty) {
      for (final s in segments) {
        final t = s.text.trim();
        if (t.isNotEmpty) {
          title = t.length <= _titleCutoff ? t : '${t.substring(0, _titleCutoff)}…';
          break;
        }
      }
    }
    return session.copyWith(segments: segments, title: title);
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(kSessionIdleTimeout, () {
      if (!_continuousStarted || _micTestActive) return;
      forceEndSession();
    });
  }

  /// --- Pendant button (double-tap = end memory, like Omi) ----------------

  void _onButtonEvent(int event) {
    if (event != kButtonShortPress) return;
    final now = DateTime.now();
    final last = _lastShortPressAt;
    _lastShortPressAt = now;
    if (last != null && now.difference(last) <= _doubleTapWindow) {
      _lastShortPressAt = null;
      _doubleTapTimer?.cancel();
      _doubleTapTimer = null;
      forceEndSession();
      return;
    }
    _doubleTapTimer?.cancel();
    _doubleTapTimer = Timer(_doubleTapWindow, () {
      _lastShortPressAt = null;
    });
  }

  /// --- Phone-mic dev test -------------------------------------------------

  /// Manual check: transcribe from the phone mic and land the words as a
  /// locked segment of the current memory. Pauses the continuous pendant
  /// session for the test, then resumes it.
  Future<void> microphoneTest() async {
    if (_micTestActive) return;
    _micTestActive = true;
    _resumeAfterMicTest = _continuousStarted;
    if (_continuousStarted) {
      _continuousStarted = false;
      final engine = ref.read(sttEngineProvider);
      await engine.stopContinuous();
    }
    _idleTimer?.cancel();
    _idleTimer = null;
    try {
      final ok = await ref.read(sttEngineProvider).isAvailable();
      if (!ok) {
        state = state.copyWith(error: 'Speech recognition not available.');
        return;
      }
      state = state.copyWith(
        isListening: true,
        liveTranscript: '',
        micLevel: 0,
        sttEvent: 'listening…',
        clearError: true,
      );
      var peak = 0.0;
      final transcript = await ref.read(sttEngineProvider).transcribeMic(
            callbacks: SttCallbacks(
              onPartial: (partial) {
                if (!_micTestActive) return;
                state = state.copyWith(
                  liveTranscript: partial,
                  isListening: true,
                  clearError: true,
                );
              },
              onMicLevel: (level) {
                if (!_micTestActive) return;
                if (level > peak) peak = level;
                state = state.copyWith(micLevel: level);
              },
              onEvent: (event) {
                if (_micTestActive && event.isNotEmpty) {
                  state = state.copyWith(sttEvent: event);
                }
              },
            ),
          );
      final failed = transcript.trim().isEmpty;
      if (!failed) {
        // Land the test words as a locked segment so the memory keeps the
        // transcript as its single source of truth.
        final session = state.active ?? _newSession(DateTime.now());
        final ms = _clock.elapsedMilliseconds;
        final segments = [
          ...session.segments,
          TranscriptSegment(
            id: '${session.id}-${session.segments.length}',
            text: transcript.trim(),
            timestamp: DateTime.now(),
            startMs: ms,
            endMs: ms + 1,
          ),
        ];
        state = state.copyWith(
          active: _withTitle(session, segments),
          liveTranscript: transcript.trim(),
          isListening: false,
          micLevel: 0,
        );
      } else {
        state = state.copyWith(
          liveTranscript: '',
          isListening: false,
          sttEvent: 'no words recognized · mic peak ${(peak * 100).round()}%',
          micLevel: 0,
        );
      }
    } finally {
      _micTestActive = false;
      if (_resumeAfterMicTest) {
        _resumeAfterMicTest = false;
        _syncContinuous(ref.read(pendantProvider).currentStatus);
      }
    }
  }

  ConversationSession _newSession(DateTime now) {
    _clock = Stopwatch()..start();
    return ConversationSession(
      id: 's${now.microsecondsSinceEpoch}',
      title: '',
      startedAt: now,
      status: ConversationStatus.inProgress,
    );
  }

  Future<void> _processMemoryAsync(ConversationSession session) async {
    final text = session.transcriptText;
    if (text.isEmpty) return;

    final processor = ref.read(memoryProcessorProvider);
    final result = await processor.process(text);

    // Update the session in state with the new AI summary and title
    final idx = state.conversations.indexWhere((c) => c.id == session.id);
    if (idx != -1) {
      final conversations = List<ConversationSession>.of(state.conversations);
      conversations[idx] = conversations[idx].copyWith(
        title: result.title,
        summary: result.summary,
      );
      state = state.copyWith(conversations: conversations);
      _persist();
    }

    // Push any extracted commitments to the commitments provider
    if (result.commitments.isNotEmpty) {
      final cNotifier = ref.read(commitmentsProvider.notifier);
      for (final c in result.commitments) {
        if (c.isCommitment && c.action != null && c.action!.isNotEmpty) {
          cNotifier.addManual(
            action: c.action!,
            person: c.person?.trim().isEmpty == true ? null : c.person?.trim(),
            due: c.due != null ? DateTime.tryParse(c.due!) : null,
          );
        }
      }
    }
  }

  /// --- Persistence -------------------------------------------------------

  void _persist() {
    final box = Hive.box(Boxes.conversation);
    box.put('sessions', state.conversations.map((c) => c.toJson()).toList());
    if (state.active != null) {
      box.put('activeSession', state.active!.toJson());
    } else {
      box.delete('activeSession');
    }
  }

  ({List<ConversationSession> completed, ConversationSession? active})
      _loadState() {
    final box = Hive.box(Boxes.conversation);
    var completed = <ConversationSession>[];
    final stored = box.get('sessions');
    if (stored is List) {
      completed = stored
          .whereType<Map>()
          .map((e) => ConversationSession.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    // A session that was mid-flight when the app last closed is finalized on
    // load and never reactivated: the app always starts fresh, exactly like
    // Omi after a restart. Anything still marked in-progress is promoted to
    // completed; the stored active session (if any) is merged into history.
    final now = DateTime.now();
    final rebuilt = <ConversationSession>[];
    var finalized = false;
    for (final c in completed) {
      if (c.status == ConversationStatus.inProgress) {
        rebuilt.add(c.copyWith(
          status: ConversationStatus.completed,
          finishedAt: c.finishedAt ?? now,
        ));
        finalized = true;
      } else {
        rebuilt.add(c);
      }
    }
    completed = rebuilt;

    final activeJson = box.get('activeSession');
    if (activeJson is Map) {
      final storedActive =
          ConversationSession.fromJson(Map<String, dynamic>.from(activeJson));
      if (storedActive.segments.isNotEmpty) {
        completed = [
          ...completed,
          storedActive.copyWith(
            status: ConversationStatus.completed,
            finishedAt: storedActive.finishedAt ?? now,
          ),
        ];
      }
      finalized = true;
    }
    if (finalized) {
      box.put('sessions', completed.map((c) => c.toJson()).toList());
      box.delete('activeSession');
    }

    // One-time migration from the pre-session flat "turns" list (reply-era).
    // Sessions are never reactivated on load, so this only runs when storage
    // holds no history other than the legacy list.
    final legacy = box.get('turns');
    if (legacy is List && legacy.isNotEmpty && completed.isEmpty) {
      final segments = <TranscriptSegment>[];
      var i = 0;
      for (final e in legacy) {
        if (e is! Map) continue;
        final map = Map<String, dynamic>.from(e);
        final text = (map['transcript'] as String? ?? '').trim();
        if (text.isEmpty) continue;
        segments.add(TranscriptSegment(
          id: 'legacy-$i',
          text: text,
          timestamp:
              DateTime.tryParse(map['timestamp'] as String? ?? '') ??
                  DateTime.now().subtract(Duration(minutes: 5 * (i + 1))),
          startMs: i * 30000,
          endMs: i * 30000 + 15000,
        ));
        i++;
      }
      if (segments.isNotEmpty) {
        final earliest = segments.first.timestamp;
        completed = [
          ConversationSession(
            id: 'legacy',
            title: _clip(segments.first.text),
            startedAt: earliest,
            finishedAt: segments.last.timestamp,
            status: ConversationStatus.completed,
            segments: segments,
          ),
        ];
      }
      box.delete('turns');
    }

    // Nothing is ever reactivated from storage: active is always null on load.
    return (completed: completed, active: null);
  }

  void reloadFromStorage() {
    final loaded = _loadState();
    state = state.copyWith(
      active: state.active ?? loaded.active,
      conversations: loaded.completed,
    );
  }

  void removeSession(String id) {
    final conversations = List<ConversationSession>.of(state.conversations);
    final idx = conversations.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    conversations.removeAt(idx);
    state = state.copyWith(conversations: conversations);
    _persist();
  }

  void clear() {
    state = const ConversationState();
    final box = Hive.box(Boxes.conversation);
    box.clear();
  }

  String _clip(String text) {
    final t = text.trim();
    return t.length <= _titleCutoff ? t : '${t.substring(0, _titleCutoff)}…';
  }
}