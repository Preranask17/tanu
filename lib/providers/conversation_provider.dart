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
import '../services/simulator_pendant_source.dart';
import 'agent_provider.dart';
import 'analytics_provider.dart';
import 'ble_provider.dart';
import 'commitment_provider.dart';
import 'rag_provider.dart';
import 'proactive_provider.dart';

import '../services/stt/whisper_small_engine.dart';

final sttEngineProvider = Provider<ContinuousSttEngine>((ref) {
  final engine = WhisperSmallEngine();

  ref.onDispose(() => engine.dispose());
  return engine;
});

/// Drives the core loop: pendant audio -> continuous STT -> timestamped
/// transcript segments inside one in-progress "memory" session Ã¢â‚¬â€ the same
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

  /// User paused from the VoicePill — blocks auto-restart while connected.
  bool _userPaused = false;
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
      // Retry any memories whose AI processing failed previously.
      unawaited(_drainRetryQueue());
    });
    return ConversationState(
      active: loaded.active,
      conversations: loaded.completed,
    );
  }

  /// --- Session lifecycle ------------------------------------------------

  void _syncContinuous(PendantStatus? status) {
    final connected = status?.isConnected ?? false;
    if (connected && !_micTestActive && !_continuousStarted && !_userPaused) {
      unawaited(_startContinuous());
    } else if (!connected && _continuousStarted) {
      _userPaused = false;
      unawaited(_stopContinuous());
    }
  }

  Future<void> _startContinuous({bool resumeExisting = false}) async {
    if (_continuousStarted || _micTestActive) return;
    _continuousStarted = true;
    _userPaused = false;

    final engine = ref.read(sttEngineProvider);
    final source = ref.read(pendantProvider);

    // Fresh connects open a new memory. Manual resume keeps the active one.
    if (!resumeExisting || state.active == null) {
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
    } else {
      state = state.copyWith(isListening: true, sttEvent: 'listening…');
      if (!_clock.isRunning) _clock.start();
    }

    _buttonSub?.cancel();
    _buttonSub = source.buttonEvents.listen(_onButtonEvent);

    final available = await engine.isAvailable();
    if (!available) {
      state = state.copyWith(
        isListening: false,
        sttEvent: "Model missing. Download in Settings.",
      );
      _continuousStarted = false;
      return;
    }
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
      state = state.copyWith(isListening: false, sttEvent: 'stt unavailable');
      _continuousStarted = false;
    } else {
      // The "phone just received bytes from the pendant" cue: any PCM chunk
      // lights the receiving flag for a short window.
      _receivingSub?.cancel();
      _receivingSub = source.pcmAudio.listen((_) => _bumpReceiving());
      ref
          .read(analyticsProvider)
          .capture(
            'session started',
            properties: {
              'stt_model': engine.modelLabel,
              'simulated': source is SimulatorPendantSource,
            },
          );
    }
  }

  /// Pause STT while keeping the in-progress memory. Pill collapses until
  /// [resumeListening] (or a fresh connect after disconnect clears the pause).
  Future<void> pauseListening() async {
    _userPaused = true;
    if (!_continuousStarted) {
      state = state.copyWith(
        isListening: false,
        receivingAudio: false,
        micLevel: 0,
      );
      return;
    }
    _continuousStarted = false;
    _buttonSub?.cancel();
    _buttonSub = null;
    _receivingSub?.cancel();
    _receivingSub = null;
    _receivingTimer?.cancel();
    _receivingTimer = null;
    _idleTimer?.cancel();
    _idleTimer = null;
    _clock.stop();

    final engine = ref.read(sttEngineProvider);
    await engine.stopContinuous();

    state = state.copyWith(
      isListening: false,
      receivingAudio: false,
      micLevel: 0,
      liveTranscript: '',
    );
  }

  /// Resume after [pauseListening]. No-op if the pendant is disconnected.
  Future<void> resumeListening() async {
    _userPaused = false;
    final status =
        ref.read(pendantStatusProvider).value ??
        ref.read(pendantProvider).currentStatus;
    if (!status.isConnected) return;
    await _startContinuous(resumeExisting: state.active != null);
  }

  /// End the current memory and pause listening so the pill collapses.
  Future<void> stopListening([String reason = 'manual']) async {
    // Pause first so [forceEndSession] does not open a replacement session.
    await pauseListening();
    forceEndSession(reason);
  }

  /// Closes the current memory into the conversations list. Recording keeps
  /// flowing into a brand-new session, exactly like Omi after a force-process.
  ///
  /// [reason] is only used to label the `session ended` analytics event; it
  /// defaults to `manual` so existing call sites keep working.
  void forceEndSession([String reason = 'manual']) {
    final session = state.active;
    if (session != null && session.segments.isNotEmpty) {
      final finished = session.copyWith(
        status: ConversationStatus.completed,
        finishedAt: DateTime.now(),
      );
      state = state.copyWith(
        conversations: [...state.conversations, finished],
        clearActive: true,
        liveTranscript: '',
      );
      _trackSessionEnded(finished, reason);
      _processMemoryAsync(finished);
    } else {
      state = state.copyWith(clearActive: true, liveTranscript: '');
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
        clearActive: true,
        conversations: [...state.conversations, finished],
        liveTranscript: '',
        isListening: false,
        receivingAudio: false,
        micLevel: 0,
      );
      _trackSessionEnded(finished, 'disconnect');
      _processMemoryAsync(finished);
    } else {
      state = state.copyWith(
        clearActive: true,
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
      segments.add(
        TranscriptSegment(
          id: '${session.id}-${segments.length}',
          text: trimmed,
          timestamp: DateTime.now(),
          startMs: ms,
        ),
      );
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
      segments.add(
        TranscriptSegment(
          id: '${session.id}-${segments.length}',
          text: trimmed,
          timestamp: DateTime.now(),
          startMs: start,
          endMs: ms,
        ),
      );
    }

    state = state.copyWith(
      active: _withTitle(session, segments),
      liveTranscript: '',
      isListening: true,
      sttEvent: '',
    );
    _resetIdleTimer();
    _evaluateEndOfConversation(trimmed, segments.length);
  }

  // --- End-of-conversation detection -------------------------------------

  Timer? _softEndTimer;
  DateTime? _lastEndCloseAt;

  /// Strong closers — the whole utterance wraps up, close right away.
  static final RegExp _strongEndPattern = RegExp(
    r'^(?:okay|ok|alright|well|so)?\s*(?:thank you|thanks(?: a lot| so much| everyone| all)?|'
    r'got it[.,]? thanks|bye+|goodbye|see (?:you|ya)(?: later| all)?|farewell|take care|'
    r'talk (?:later|soon)|catch you later|'
    r"that's (?:all|it)(?: for (?:today|now))?|"
    r"that's enough(?: for (?:today|now))?|we'?re (?:done|finished|wrapped up)|"
    "i'?m done(?: now| here)?|(?:let'?s|we can|let us) (?:call it a day|wrap (?:it )?up|finish up|end here)|"
    r'end of (?:meeting|discussion|conversation)|meeting adjourned|'
    "let'?s end here|"
    r'perfect[.,]? (?:thanks|thank you)|great[.,]? thanks|sounds good[.,]? (?:thanks|thank you)|'
    r'agreed[.,]? (?:thanks|thank you)|'
    "i think that'?s (?:it|all|everything)|"
    r'no (?:more )?questions(?:[.,]? ?(?:\w+ \w+)?)?|any other business|'
    r"i'?ll let you go|i appreciate (?:your time|it)|have a (?:good|great) (?:day|one)|"
    r'thanks everybody|thank you everyone)\b[.!\s]*$',
    caseSensitive: false,
  );

  /// Softer closers — only close after ~20 s of no new speech.
  static final RegExp _softEndPattern = RegExp(
    r'^(?:great|okay|ok|right|well|so|alright|cool|nice|perfect|understood|sure|fine|'
    r'works for me|that works|sounds good|no problem|no worries|all right|'
    r'yeah|yes|maybe|hmm|uh|mm)[.!?…\s]*$',
    caseSensitive: false,
  );

  /// Meeting-style closers — treated as strong once a session has some meat.
  static final RegExp _businessEndPattern = RegExp(
    r"(?:minutes after|we'?ll pick up (?:this|next week|tomorrow)|"
    r"let'?s continue (?:this|next time)|follow up (?:on )?this (?:later|next week)|"
    r'circling back (?:on this )?(?:tomorrow|later)|schedule another (?:meeting|call)|'
    r'get back to (?:you|this))\b',
    caseSensitive: false,
  );

  void _evaluateEndOfConversation(String utterance, int segmentCount) {
    // Cancel any pending soft-close: new speech means the conversation goes on.
    _softEndTimer?.cancel();
    _softEndTimer = null;

    final last = _lastEndCloseAt;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 2)) {
      return;
    }

    final cleaned =
        utterance.replaceAll(RegExp(r'[.!?…,"\s]+$'), '').trim();

    if (_strongEndPattern.hasMatch(cleaned) ||
        (segmentCount >= 2 && _businessEndPattern.hasMatch(cleaned))) {
      _softEndTimer?.cancel();
      _closeFromEndPhrase('end_phrase');
      return;
    }

    if (_softEndPattern.hasMatch(cleaned)) {
      _softEndTimer = Timer(const Duration(seconds: 20), () {
        if (_continuousStarted && !_micTestActive && state.active != null) {
          _closeFromEndPhrase('end_phrase_soft');
        }
      });
    }
  }

  void _closeFromEndPhrase(String reason) {
    _lastEndCloseAt = DateTime.now();
    state = state.copyWith(sttEvent: '— conversation ended —');
    unawaited(stopListening(reason));
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
          title = t.length <= _titleCutoff
              ? t
              : '${t.substring(0, _titleCutoff)}Ã¢â‚¬Â¦';
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
      forceEndSession('idle');
    });
  }

  /// Reports how a memory ended. Deliberately aggregate-only: a duration, a
  /// segment count and why it closed. The words themselves never leave the
  /// phone — the `transcript` property key is stripped by the redaction hook
  /// even if someone adds it here later.
  void _trackSessionEnded(ConversationSession session, String reason) {
    final finishedAt = session.finishedAt;
    final startedAt = session.startedAt;
    ref
        .read(analyticsProvider)
        .capture(
          'session ended',
          properties: {
            'close_reason': reason,
            'segment_count': session.segmentCount,
            if (finishedAt != null)
              'duration_s':
                  finishedAt.difference(startedAt).inMilliseconds ~/ 1000,
          },
        );
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
      forceEndSession('button');
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
        sttEvent: 'listeningÃ¢â‚¬Â¦',
        clearError: true,
      );
      var peak = 0.0;
      final transcript = await ref
          .read(sttEngineProvider)
          .transcribeMic(
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
          sttEvent:
              'no words recognized Ã‚Â· mic peak ${(peak * 100).round()}%',
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

    // Drain any previously failed sessions first (best effort).
    unawaited(_drainRetryQueue());

    final processor = ref.read(memoryProcessorProvider);
    final result = await processor.process(text);

    if (result.error != null) {
      _enqueueForRetry(session.id);
      ref.read(analyticsProvider).capture(
        'memory retry queued',
        properties: {'error': result.error!.length > 100 ? result.error!.substring(0, 100) : result.error!},
      );
      return;
    }

    _dequeueRetry(session.id);

    // Update the session in state with the new AI summary and title
    final idx = state.conversations.indexWhere((c) => c.id == session.id);
    if (idx != -1) {
      final conversations = List<ConversationSession>.of(state.conversations);
      conversations[idx] = conversations[idx].copyWith(
        title: result.title,
        summary: result.summary,
        cleanedTranscript: result.cleanedTranscript.isEmpty
            ? null
            : result.cleanedTranscript,
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

    // Index the session chunks for RAG retrieval (best effort, non-blocking).
    if (idx != -1) {
      unawaited(_indexSession(session.copyWith(
        title: result.title,
        summary: result.summary,
        cleanedTranscript: result.cleanedTranscript.isEmpty
            ? null
            : result.cleanedTranscript,
      )));
    }

    try {
      final svc = await ref.read(proactiveServiceProvider.future);
      final updated = idx != -1 && idx < state.conversations.length
          ? state.conversations[idx]
          : session;
      final kind = await svc.maybeNotify(
        session: updated,
        result: result,
      );
      if (kind != null) {
        ref.read(analyticsProvider).capture(
          'proactive notified',
          properties: {'kind': kind.name},
        );
      }
    } catch (_) {}

    ref
        .read(analyticsProvider)
        .capture(
          'memory processed',
          properties: {
            'commitment_count': result.commitments.length,
            'has_summary': result.summary.isNotEmpty,
          },
        );
  }

  Future<void> _indexSession(ConversationSession session) async {
    try {
      final indexer = await ref.read(memoryIndexerProvider.future);
      await indexer.indexSession(session);
    } catch (_) {}
  }

  // --- AI retry queue ------------------------------------------------------

  static const int _maxRetryAttempts = 3;

  List<String> _retryQueue() {
    final box = Hive.box(Boxes.conversation);
    final raw = box.get('memoryRetryQueue');
    if (raw is List) return raw.cast<String>().toList();
    return [];
  }

  void _enqueueForRetry(String sessionId) {
    final box = Hive.box(Boxes.conversation);
    final queue = _retryQueue();
    if (!queue.contains(sessionId)) {
      queue.add(sessionId);
      box.put('memoryRetryQueue', queue);
    }
  }

  void _dequeueRetry(String sessionId, {bool keepAttemptCount = false}) {
    final box = Hive.box(Boxes.conversation);
    final queue = _retryQueue()..remove(sessionId);
    box.put('memoryRetryQueue', queue);
    if (keepAttemptCount) return;
    final raw = box.get('memoryRetryAttempts');
    final attempts = Map<String, dynamic>.from(raw is Map ? raw : {});
    attempts.remove(sessionId);
    box.put('memoryRetryAttempts', attempts);
  }

  int _retryAttemptCount(String sessionId) {
    final box = Hive.box(Boxes.conversation);
    final raw = box.get('memoryRetryAttempts');
    if (raw is Map) return (raw[sessionId] as int?) ?? 0;
    return 0;
  }

  bool _draining = false;
  static const int _maxDrainPerRun = 5;

  Future<void> _drainRetryQueue() async {
    if (_draining) return;
    _draining = true;
    try {
      // Rescue sessions left in a failed state by older builds (pre-queue).
      for (final s in state.conversations) {
        final summary = s.summary ?? '';
        final looksFailed = summary.startsWith('Could not parse') ||
            summary.startsWith('Failed to process memory');
        final looksUnprocessed = summary.isEmpty &&
            s.cleanedTranscript == null &&
            s.transcriptText.trim().isNotEmpty;
        if ((looksFailed || looksUnprocessed) &&
            _retryAttemptCount(s.id) < _maxRetryAttempts) {
          _enqueueForRetry(s.id);
        }
      }

      final queue = _retryQueue();
      if (queue.isEmpty) return;

      final processor = ref.read(memoryProcessorProvider);
      var processedThisRun = 0;
      for (final id in List<String>.of(queue)) {
        if (processedThisRun >= _maxDrainPerRun) break;
        processedThisRun++;
        final idx = state.conversations.indexWhere((c) => c.id == id);
        if (idx == -1) {
          _dequeueRetry(id);
          continue;
        }

        final session = state.conversations[idx];
        final result = await processor.process(session.transcriptText);

        if (result.error == null) {
          final conversations = List<ConversationSession>.of(state.conversations);
          conversations[idx] = session.copyWith(
            title: result.title,
            summary: result.summary,
            cleanedTranscript: result.cleanedTranscript.isEmpty
                ? null
                : result.cleanedTranscript,
          );
          state = state.copyWith(conversations: conversations);
          _persist();
          _dequeueRetry(id);
          try {
            final indexer = await ref.read(memoryIndexerProvider.future);
            unawaited(indexer.indexSession(conversations[idx]));
          } catch (_) {}
          ref.read(analyticsProvider).capture('memory retry succeeded');
        try {
          final svc = await ref.read(proactiveServiceProvider.future);
          await svc.maybeNotify(session: conversations[idx], result: result);
        } catch (_) {}
        } else {
          final attempts = _retryAttemptCount(id) + 1;
          final box = Hive.box(Boxes.conversation);
          final raw = box.get('memoryRetryAttempts');
          final map = Map<String, dynamic>.from(raw is Map ? raw : {});
          map[id] = attempts;
          box.put('memoryRetryAttempts', map);
          if (attempts >= _maxRetryAttempts) {
            _dequeueRetry(id, keepAttemptCount: true);
            ref.read(analyticsProvider).capture('memory retry gave up');
          }
        }
      }
    } finally {
      _draining = false;
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
          .map(
            (e) => ConversationSession.fromJson(Map<String, dynamic>.from(e)),
          )
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
        rebuilt.add(
          c.copyWith(
            status: ConversationStatus.completed,
            finishedAt: c.finishedAt ?? now,
          ),
        );
        finalized = true;
      } else {
        rebuilt.add(c);
      }
    }
    completed = rebuilt;

    final activeJson = box.get('activeSession');
    if (activeJson is Map) {
      final storedActive = ConversationSession.fromJson(
        Map<String, dynamic>.from(activeJson),
      );
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
        segments.add(
          TranscriptSegment(
            id: 'legacy-$i',
            text: text,
            timestamp:
                DateTime.tryParse(map['timestamp'] as String? ?? '') ??
                DateTime.now().subtract(Duration(minutes: 5 * (i + 1))),
            startMs: i * 30000,
            endMs: i * 30000 + 15000,
          ),
        );
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
    // Soft delete
    conversations[idx] = conversations[idx].copyWith(isDeleted: true);
    state = state.copyWith(conversations: conversations);
    _persist();
  }

  void togglePin(String id) {
    final conversations = List<ConversationSession>.of(state.conversations);
    final idx = conversations.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    conversations[idx] = conversations[idx].copyWith(
      isPinned: !conversations[idx].isPinned,
    );
    state = state.copyWith(conversations: conversations);
    _persist();
  }

  void restoreSession(String id) {
    final conversations = List<ConversationSession>.of(state.conversations);
    final idx = conversations.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    conversations[idx] = conversations[idx].copyWith(isDeleted: false);
    state = state.copyWith(conversations: conversations);
    _persist();
  }

  void deleteSessionPermanently(String id) {
    final conversations = List<ConversationSession>.of(state.conversations);
    final idx = conversations.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    conversations.removeAt(idx);
    state = state.copyWith(conversations: conversations);
    _persist();
  }

  void emptyTrash() {
    final conversations = List<ConversationSession>.of(
      state.conversations,
    ).where((c) => !c.isDeleted).toList();
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
    return t.length <= _titleCutoff
        ? t
        : '${t.substring(0, _titleCutoff)}Ã¢â‚¬Â¦';
  }
}
