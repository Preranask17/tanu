import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

import '../../abstractions/stt_engine.dart';
import '../../constants.dart';

/// On-device speech-to-text using the Moonshine tiny-en model, decoded by
/// sherpa_onnx.
///
/// The model bundle (~43 MB) is downloaded elsewhere into app-support storage
/// (see [kMoonshineBundleFileName]); this engine only ever reads the three
/// extracted files (`encoder_model.ort`, `decoder_model_merged.ort`,
/// `tokens.txt`) from a model directory it is handed (or resolves from
/// `path_provider` by default). It swaps the retired engine's native decode
/// call for a long-lived sherpa_onnx worker isolate: the FFI bindings and the
/// recognizer are loaded once in that isolate and reused across every
/// utterance, since spawning per utterance would re-pay the
/// 40+ MB model load each time.
class MoonshineSttEngine implements ContinuousSttEngine {
  MoonshineSttEngine({String? modelDir}) : _modelDirOverride = modelDir;

  /// Overrides the default `appSupport/<bundle-stem>` model directory.
  final String? _modelDirOverride;

  static const int _sampleRate = 16000;
  static const int _chunkSamples = 1600;

  ReceivePort? _replyPort;
  StreamSubscription<dynamic>? _replySub;
  SendPort? _workerSend;
  Future<bool>? _startFuture;
  Completer<bool>? _readyCompleter;
  Completer<void>? _shutdownCompleter;
  final Map<int, Completer<String>> _pending = {};
  int _nextRequestId = 0;
  bool _busy = false;
  String? _lastError;

  // Fast "chunked" live mode: audio is sliced at silence and each slice is
  // transcribed ONCE with the offline worker (tiny-en on a short clip is
  // quick), instead of re-decoding a growing 60 s window every ~700 ms.
  StreamSubscription<Uint8List>? _chunkSub;
  bool _continuousActive = false;
  bool _vadSpeech = false;
  int _vadSilenceMs = 0;
  int _utteranceMs = 0;
  final List<double> _pendingSamples = [];

  /// Only the trailing slice of the growing utterance is re-decoded for a live
  /// preview; the accurate final pass always gets the full clip. Bounds both
  /// the main-isolate copy and the worker work so a long turn can't stack
  /// wheat-field-size buffers every tick.
  static const _partialPreviewSeconds = 5;
  bool _transcribing = false;
  bool _partialBusy = false;
  Timer? _partialTimer;
  String _lastPartialText = '';
  final Stopwatch _lastMicEmit = Stopwatch()..start();
  
  VoiceActivityDetector? _vad;

  /// Silence-cut clips awaiting their accurate final pass, each carrying the
  /// best live hypothesis captured at flush time. If the decoder returns empty
  /// for a clip (it happens on soft/quiet turns), that fallback is emitted so
  /// the user's words are never lost to a hiccup of the decoder.
  final List<(Float32List, String)> _transcribeQueue = [];
  double _noiseFloor = 0;
  void Function(String)? _onUtteranceCb;
  void Function(String)? _onPartialCb;
  void Function(double)? _onMicLevelCb;
  void Function(String)? _onEventCb;

  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _recorderSub;

  /// True while the Moonshine bindings/model are loading in the worker isolate
  /// (the slow part the app warms up at startup). Listened to by the Home UI.
  @override
  final ValueNotifier<bool> warmingUp = ValueNotifier(false);

  /// True while speech is live in the chunker or a cut slice is being
  /// recognized. The provider uses this to avoid wiping live words when a Tanu
  /// reply completes mid-speech.
  @override
  bool get hasActiveUtterance => _vadSpeech || _transcribing;

  @override
  String get modelLabel => kMoonshineModelLabel;

  String? get lastError => _lastError;

  /// Trailing silence (per silence-sliced chunk) that ends the utterance.
  /// Long enough to not split mid-thought, short enough to feel instant.
  /// The user already saw the words live as partials, so this can be short.
  static const int _silenceFlushMs = 600;

  /// Hard cap for a single utterance; longer clips are cut and processed even
  /// while still talking, so the feed never falls behind.
  static const int _maxUtteranceMs = 12000;

  /// Cadence for the live partial preview re-decode of the trailing tail.
  static const Duration _partialCadence = Duration(milliseconds: 650);

  /// Upper bound for a single worker decode. One-shot jobs can sit behind a
  /// warm partial pass, so a stuck native call must not hang the caller.
  static const Duration _decodeTimeout = Duration(seconds: 30);

  /// Bounded mic capture window for [transcribeMic].
  static const Duration _micWindow = Duration(seconds: 8);

  /// Sentinel that tells the worker isolate to shut down. A String is safe
  /// because every real request is a `List` message.
  static const String _shutdownKey = 'moonshine::shutdown';

  /// The three files the bundle extracts and sherpa_onnx loads, mirroring
  /// [kMoonshineBundleFiles] without the expected byte counts.
  static const List<String> _bundleFiles = [
    'encoder_model.ort',
    'decoder_model_merged.ort',
    'tokens.txt',
  ];

  @override
  Future<bool> isAvailable() async {
    final dir = await _modelDirectory();
    return dir != null && _filesExist(dir);
  }

  /// Resolves the model directory: an injected override, else
  /// `appSupport/<bundle-stem>` matching how the downloader extracts the
  /// archive. Downloads are owned by a separate file; this engine never
  /// fetches anything.
  Future<String?> _modelDirectory() async {
    final override = _modelDirOverride;
    if (override != null) return override;
    try {
      final support = await getApplicationSupportDirectory();
      final stem = kMoonshineBundleFileName.replaceFirst('.tar.bz2', '');
      return '${support.path}/$stem';
    } catch (e) {
      debugPrint('[tanu] model dir unavailable: $e');
      return null;
    }
  }

  bool _filesExist(String dir) =>
      _bundleFiles.every((f) => File('$dir/$f').existsSync());

  /// Loads (spawning the worker isolate and its recognizer if needed) and
  /// caches the live worker. Safe to call concurrently: concurrent callers
  /// await the same in-flight start instead of double-spawning.
  Future<bool> _ensureWorker(void Function(String)? onEvent) async {
    if (_workerSend != null) return true;
    final inFlight = _startFuture;
    if (inFlight != null) return inFlight;
    final start = _startWorker(onEvent);
    _startFuture = start;
    try {
      return await start;
    } finally {
      if (identical(_startFuture, start)) _startFuture = null;
    }
  }

  Future<bool> _startWorker(void Function(String)? onEvent) async {
    final dir = await _modelDirectory();
    if (dir == null || !_filesExist(dir)) {
      _lastError = 'model files missing';
      onEvent?.call('model files missing');
      return false;
    }
    warmingUp.value = true;
    try {
      final replies = ReceivePort();
      _replyPort = replies;
      _readyCompleter = Completer<bool>();
      _replySub = replies.listen(
        _onWorkerReply,
        onError: (Object e, StackTrace st) {
          _lastError = '$e';
          _workerSend = null;
          final ready = _readyCompleter;
          if (ready != null && !ready.isCompleted) ready.complete(false);
          debugPrint('[tanu] moonshine worker error: $e\n$st');
        },
        onDone: () {
          _closePending();
          _workerSend = null;
          final ready = _readyCompleter;
          if (ready != null && !ready.isCompleted) ready.complete(false);
        },
      );

      await Isolate.spawn(_moonshineWorker, [
        '$dir/${_bundleFiles[0]}',
        '$dir/${_bundleFiles[1]}',
        '$dir/${_bundleFiles[2]}',
        replies.sendPort,
      ]);

      final ok = await _readyCompleter!.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () => false,
      );
      if (!ok) {
        _lastError = 'model load failed';
        onEvent?.call('model error: load failed');
        final sub = _replySub;
        _replySub = null;
        await sub?.cancel();
        _closePending();
        replies.close();
        _replyPort = null;
      }
      return ok;
    } catch (e, st) {
      _lastError = '$e';
      onEvent?.call('model error: $e');
      debugPrint('[tanu] moonshine worker start failed: $e\n$st');
      return false;
    } finally {
      warmingUp.value = false;
    }
  }

  /// Handles worker-bound replies: the `ready` handshake that hands over the
  /// command port, `[id, text]` decode results, and the `bye` shutdown ack.
  void _onWorkerReply(Object? message) {
    if (message is List && message.isNotEmpty) {
      final head = message.first;
      if (head == 'ready' && message.length == 2) {
        final send = message[1];
        if (send is SendPort) {
          _workerSend = send;
          final ready = _readyCompleter;
          if (ready != null && !ready.isCompleted) ready.complete(true);
        }
        return;
      }
      if (head == 'bye') {
        _closePending();
        _workerSend = null;
        final shutdown = _shutdownCompleter;
        if (shutdown != null && !shutdown.isCompleted) shutdown.complete();
        return;
      }
      if (head is int && message.length == 2) {
        final completer = _pending.remove(head);
        final text = message[1] is String ? message[1] as String : '';
        if (completer != null && !completer.isCompleted) completer.complete(text);
      }
    }
  }

  /// Sends [samples] to the worker and awaits its transcript. Failures and
  /// timeouts resolve to `''` so the caller's flow is never held hostage.
  Future<String> _decodeOne(Float32List samples) async {
    final send = _workerSend;
    if (send == null || samples.isEmpty) return '';
    final id = _nextRequestId++;
    final completer = Completer<String>();
    _pending[id] = completer;
    send.send([id, samples]);
    try {
      return await completer.future.timeout(_decodeTimeout, onTimeout: () => '');
    } finally {
      _pending.remove(id);
    }
  }

  void _closePending() {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.complete('');
    }
    _pending.clear();
  }

  /// Asks the worker to free its recognizer and terminate. In-flight requests
  /// are answered before the worker exits, so this also resolves any pending
  /// decodes (to `''`) rather than leaving them dangling.
  Future<void> _shutdownWorker() async {
    final send = _workerSend;
    if (send != null) {
      _shutdownCompleter = Completer<void>();
      try {
        send.send(_shutdownKey);
        await _shutdownCompleter!.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {},
        );
      } catch (_) {}
    }
    _closePending();
    _workerSend = null;
    final sub = _replySub;
    _replySub = null;
    await sub?.cancel();
    final port = _replyPort;
    _replyPort = null;
    if (port != null) port.close();
  }

  @override
  Future<String> transcribe(
    Uint8List pcmUtterance, {
    SttCallbacks? callbacks,
  }) async {
    if (_busy || _continuousActive) {
      callbacks?.onEvent?.call('recognizer busy');
      return '';
    }
    _busy = true;
    try {
      if (!await _ensureWorker(callbacks?.onEvent)) return '';

      final samples = _toFloat32(pcmUtterance);
      if (samples.isEmpty) return '';

      for (var start = 0; start < samples.length; start += _chunkSamples) {
        final end = math.min(start + _chunkSamples, samples.length);
        callbacks?.onMicLevel?.call(_level(Float32List.sublistView(samples, start, end)));
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      return await _decodeOne(samples);
    } finally {
      _busy = false;
    }
  }

  @override
  Future<String> transcribeMic({SttCallbacks? callbacks}) async {
    if (_busy || _continuousActive) {
      callbacks?.onEvent?.call('recognizer busy');
      return '';
    }
    _busy = true;
    try {
      if (!await _ensureWorker(callbacks?.onEvent)) return '';

      final recorder = AudioRecorder();
      if (!await recorder.hasPermission()) {
        callbacks?.onEvent?.call('microphone permission denied');
        _lastError = 'microphone permission denied';
        return '';
      }

      final Stream<Uint8List> audio;
      try {
        audio = await recorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: _sampleRate,
            numChannels: 1,
          ),
        );
      } catch (e) {
        _lastError = '$e';
        callbacks?.onEvent?.call('mic error: $e');
        try {
          await recorder.dispose();
        } catch (_) {}
        return '';
      }
      _recorder = recorder;

      final buffer = BytesBuilder();
      final lastEmit = Stopwatch()..start();
      try {
        _recorderSub = audio.listen((chunk) {
          buffer.add(chunk);
          if (lastEmit.elapsedMilliseconds >= 250) {
            lastEmit.reset();
            callbacks?.onMicLevel?.call(_level(_toFloat32(chunk)));
          }
        });
        await Future<void>.delayed(_micWindow);
      } finally {
        await _releaseMic();
      }

      final pcm = buffer.takeBytes();
      if (pcm.isEmpty) return '';
      return await _decodeOne(_toFloat32(pcm));
    } finally {
      _busy = false;
    }
  }

  /// Starts the live pendant session: incoming PCM16 chunks are sliced into
  /// utterances by silence, and each finished slice is transcribed exactly once
  /// (fast offline job) before [onUtterance] receives the final words. While
  /// the user is still talking, cheap partial passes fire [onPartial] so words
  /// appear live and the final result lands at the sentence break.
  ///
  /// The stream keeps running while Tanu replies, so overlapping speech is
  /// captured into the following utterances. [onMicLevel] fires per chunk,
  /// [onEvent] for status (non-empty) and idle ('').
  @override
  Future<bool> startContinuous(
    Stream<Uint8List> chunks, {
    required void Function(String utterance) onUtterance,
    void Function(String partial)? onPartial,
    void Function(double level)? onMicLevel,
    void Function(String event)? onEvent,
  }) async {
    if (_continuousActive) return true;
    if (!await _ensureWorker(onEvent)) return false;

    try {
      await initBindingsAsync();
      final support = await getApplicationSupportDirectory();
      final vadPath = '${support.path}/$kSileroVadFileName';
      _vad = VoiceActivityDetector(
        config: VadModelConfig(
          sileroVad: SileroVadModelConfig(model: vadPath),
          sampleRate: _sampleRate,
        ),
        bufferSizeInSeconds: 30,
      );
    } catch (e) {
      debugPrint('[tanu] vad init failed: $e');
      _lastError = 'vad init failed: $e';
      onEvent?.call('vad error: $e');
      return false;
    }

    _continuousActive = true;
    _onUtteranceCb = onUtterance;
    _onPartialCb = onPartial;
    _onMicLevelCb = onMicLevel;
    _onEventCb = onEvent;
    _pendingSamples.clear();
    _transcribeQueue.clear();
    _vadSpeech = false;
    _vadSilenceMs = 0;
    _utteranceMs = 0;
    _noiseFloor = 0;
    _lastPartialText = '';

    _chunkSub = chunks.listen(
      _onChunk,
      onError: (Object e, StackTrace st) {
        if (_continuousActive) onEvent?.call('audio error: $e');
      },
      onDone: () {
        _continuousActive = false;
        _chunkSub = null;
      },
    );
    debugPrint('[tanu] moonshine chunk mode subscribed');
    return true;
  }

  void _onChunk(Uint8List pcm) {
    if (!_continuousActive) return;
    final samples = _toFloat32(pcm);
    if (samples.isEmpty) return;

    final level = _level(samples);
    if (_lastMicEmit.elapsedMilliseconds >= 250) {
      _lastMicEmit.reset();
      _onMicLevelCb?.call(level);
    }

    _vad?.acceptWaveform(samples);
    final isSpeaking = _vad?.isDetected() ?? (level >= _vadThreshold);
    while (_vad != null && !_vad!.isEmpty()) {
      _vad!.pop(); // we don't need the extracted segments, just the state
    }

    final ms = samples.length * 1000 ~/ _sampleRate;
    if (!_vadSpeech) {
      if (!isSpeaking) {
        if (_vad == null) _noiseFloor = _noiseFloor * 0.94 + level * 0.06;
        return;
      }
      // Speech just started: open a fresh utterance.
      debugPrint('[tanu] vad speech onset');
      _vadSpeech = true;
      _pendingSamples.clear();
      _utteranceMs = 0;
      _vadSilenceMs = 0;
      _noiseFloor = 0;
      _startPartialTimer();
    }

    _pendingSamples.addAll(samples);
    _utteranceMs += ms;
    _vadSilenceMs =
        isSpeaking ? 0 : _vadSilenceMs + ms;

    if (_utteranceMs >= _maxUtteranceMs ||
        _vadSilenceMs >= _silenceFlushMs) {
      _finishUtterance();
      _vadSpeech = false;
      _vadSilenceMs = 0;
      _utteranceMs = 0;
      _noiseFloor = 0;
    }
  }

  double get _vadThreshold {
    final floor = _noiseFloor;
    return math.min(0.02, math.max(0.0035, floor * 1.8));
  }

  void _finishUtterance() {
    _partialTimer?.cancel();
    _partialTimer = null;
    if (_pendingSamples.isEmpty) return;
    final clip = Float32List.fromList(_pendingSamples);
    _pendingSamples.clear();
    final fallback = _lastPartialText.trim();
    _lastPartialText = '';
    debugPrint(
        '[tanu] chunk flush samples=${clip.length} '
        'ms=${(clip.length * 1000 ~/ _sampleRate)}');
    if (clip.length < _sampleRate * 3 ~/ 10) return; // <300 ms: ignore.

    if (_transcribing || _partialBusy) {
      _transcribeQueue.add((clip, fallback));
      return;
    }
    unawaited(_transcribeChunk(clip, fallback));
  }

  Future<void> _transcribeChunk(Float32List clip, String fallback) async {
    _transcribing = true;
    try {
      _onEventCb?.call('hearing…');
      final text = await _decodeOne(clip);
      if (_continuousActive) {
        final finalText = text.trim().isNotEmpty ? text.trim() : fallback;
        debugPrint(
            '[tanu] chunk result: "${text.isEmpty ? '<empty>' : text}"'
            '${finalText != text && finalText.isNotEmpty ? ' (fallback)' : ''}');
        if (finalText.isNotEmpty) {
          _onUtteranceCb?.call(finalText);
          _onEventCb?.call('');
        }
      }
    } catch (e) {
      _lastError = '$e';
      if (_continuousActive) _onEventCb?.call('stt error: $e');
      debugPrint('[tanu] chunk transcription failed: $e');
    } finally {
      _transcribing = false;
      _drainQueue();
    }
  }

  void _startPartialTimer() {
    _lastPartialText = '';
    _partialTimer?.cancel();
    _partialTimer = Timer.periodic(_partialCadence, (_) {
      unawaited(_transcribePartial());
    });
  }

  /// Best-effort live preview: re-decodes the trailing tail of the growing
  /// buffer with the worker and streams words to [onPartial] — and only when
  /// the hypothesis actually changed, so the UI isn't rebuilt with identical
  /// text. Skips while a final pass or another partial is running; the next
  /// tick retries. Partials are previews only; never surface or queue them.
  Future<void> _transcribePartial() async {
    if (!_continuousActive || !_vadSpeech) return;
    if (_transcribing || _partialBusy) return;
    if (_pendingSamples.length < _sampleRate) return; // need ≥1s of audio.

    _partialBusy = true;
    try {
      // Trailing window only: re-decoding the whole buffer on a long turn is
      // what pegged the main isolate and triggered the ANR.
      final total = _pendingSamples.length;
      final start = total - _sampleRate * _partialPreviewSeconds;
      final copy =
          Float32List.fromList(_pendingSamples.sublist(start > 0 ? start : 0));
      final text = (await _decodeOne(copy)).trim();
      if (_continuousActive && _vadSpeech) {
        // `…` marks a mid-sentence preview that only covers the tail window;
        // the final pass will replace it with the full, accurate turn.
        final shown = start > 0 && text.isNotEmpty ? '…$text' : text;
        if (shown.isNotEmpty && shown != _lastPartialText) {
          _lastPartialText = shown;
          _onPartialCb?.call(shown);
        }
      }
    } catch (e) {
      debugPrint('[tanu] partial transcription failed: $e');
    } finally {
      _partialBusy = false;
      _drainQueue();
    }
  }

  void _drainQueue() {
    if (_transcribeQueue.isEmpty || !_continuousActive) return;
    if (_transcribing || _partialBusy) return;
    final (next, fallback) = _transcribeQueue.removeAt(0);
    unawaited(_transcribeChunk(next, fallback));
  }

  /// Ends the live session; a final fragment still in flight is transcribed so
  /// the last words before the pendant dropped are not lost.
  @override
  Future<void> stopContinuous() async {
    _continuousActive = false;
    _partialTimer?.cancel();
    _partialTimer = null;
    _lastPartialText = '';
    final sub = _chunkSub;
    _chunkSub = null;
    await sub?.cancel();
    _transcribeQueue.clear();
    _transcribing = false;
    _vadSpeech = false;
    _vadSilenceMs = 0;
    _utteranceMs = 0;
    _noiseFloor = 0;
    _onUtteranceCb = null;
    _onMicLevelCb = null;
    _onEventCb = null;
    _pendingSamples.clear();
    _vad?.free();
    _vad = null;
  }

  @override
  Future<void> stop() async {
    await stopContinuous();
    await _releaseMic();
    await _shutdownWorker();
  }

  /// Tears down the worker isolate and shared resources when the engine is
  /// replaced (e.g. a new model/engine is selected in Settings).
  Future<void> dispose() async {
    _onUtteranceCb = null;
    _onPartialCb = null;
    _onMicLevelCb = null;
    _onEventCb = null;
    _partialTimer?.cancel();
    _partialTimer = null;
    _lastPartialText = '';
    await _chunkSub?.cancel();
    _chunkSub = null;
    _continuousActive = false;
    _vadSpeech = false;
    _transcribing = false;
    _transcribeQueue.clear();
    await _shutdownWorker();
    _startFuture = null;
    _vad?.free();
    _vad = null;
  }

  Future<void> _releaseMic() async {
    final sub = _recorderSub;
    final recorder = _recorder;
    _recorderSub = null;
    _recorder = null;
    await sub?.cancel();
    if (recorder != null) {
      try {
        await recorder.stop();
      } catch (_) {}
      try {
        await recorder.dispose();
      } catch (_) {}
    }
  }

  static Float32List _toFloat32(Uint8List pcm) {
    if (pcm.lengthInBytes.isOdd) {
      pcm = pcm.sublist(0, pcm.lengthInBytes - 1);
    }
    final data = ByteData.sublistView(pcm);
    final count = pcm.lengthInBytes ~/ 2;
    final out = Float32List(count);
    for (var i = 0; i < count; i++) {
      out[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }

  static double _level(Float32List samples) {
    if (samples.isEmpty) return 0;
    var sum = 0.0;
    for (final v in samples) {
      sum += v * v;
    }
    return math.min(1.0, math.sqrt(sum / samples.length) * 3);
  }
}

/// Long-lived sherpa-onnx worker isolate: binds FFI once (bindings are
/// isolate-local), builds the Moonshine recognizer once, then loops serving
/// decode requests until the shutdown key arrives. Spawning it once and keeping
/// it alive across utterances is the whole latency win over per-utterance
/// loads.
Future<void> _moonshineWorker(List<Object?> args) async {
  final encoder = args[0] as String;
  final mergedDecoder = args[1] as String;
  final tokens = args[2] as String;
  final replyPort = args[3] as SendPort;

  final commands = ReceivePort();
  replyPort.send(['ready', commands.sendPort]);

  await initBindingsAsync();

  final recognizer = OfflineRecognizer(OfflineRecognizerConfig(
    model: OfflineModelConfig(
      moonshine: OfflineMoonshineModelConfig(
        encoder: encoder,
        mergedDecoder: mergedDecoder,
      ),
      tokens: tokens,
      numThreads: 2,
      provider: 'cpu',
      debug: false,
    ),
  ));

  await for (final Object? message in commands) {
    if (message is String && message == MoonshineSttEngine._shutdownKey) break;
    if (message is List && message.length == 2 && message[0] is int) {
      final id = message[0] as int;
      final samples = message[1];
      var text = '';
      if (samples is Float32List) {
        try {
          text = _recognizeOnce(recognizer, samples);
        } catch (e) {
          debugPrint('[tanu] moonshine decode failed: $e');
        }
      }
      replyPort.send([id, text]);
    }
  }

  recognizer.free();
  replyPort.send(['bye']);
}

String _recognizeOnce(OfflineRecognizer recognizer, Float32List samples) {
  final stream = recognizer.createStream();
  try {
    stream.acceptWaveform(samples: samples, sampleRate: 16000);
    recognizer.decode(stream);
    return recognizer.getResult(stream).text.trim();
  } finally {
    stream.free();
  }
}