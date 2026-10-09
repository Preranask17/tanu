import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'stt_worker_utils.dart';

import '../../abstractions/stt_engine.dart';
import '../../config/stt_config.dart';
import '../../constants.dart';

/// Whisper Small (multilingual) on-device engine.
///
/// Decodes English plus South Indian languages (Kannada, Tamil, Telugu,
/// Malayalam) entirely offline via sherpa-onnx. Hallucinations ("thank you",
/// "bye", "um", ...) come almost entirely from decoding near-silence, so the
/// transcript stays live AND honest through three guards:
/// 1. VAD gating — only Silero-confirmed speech segments are ever decoded;
///    silence is never sent to the recognizer.
/// 2. Segment guards — segments under 0.4 s or with near-zero energy are
///    dropped before decode.
/// 3. Junk-phrase filter — decoded text matching known hallucination
///    patterns is dropped (mirrors the provider filter as defense in depth).
/// Main isolate converts PCM16 -> Float32 + mic level and forwards audio;
/// the worker isolate owns `OfflineRecognizer` + `VoiceActivityDetector` so
/// a Whisper decode never blocks audio capture.
class WhisperSmallEngine implements ContinuousSttEngine {
  WhisperSmallEngine() {
    _warmingUp.value = true;
  }

  final ValueNotifier<bool> _warmingUp = ValueNotifier(true);
  bool _continuousActive = false;
  bool _hasActiveUtterance = false;

  SendPort? _workerPort;
  Isolate? _isolate;
  Completer<void>? _flushAck;

  StreamSubscription<Uint8List>? _micSub;

  void Function(String)? _onUtteranceCb;
  void Function(String)? _onPartialCb;
  void Function(double)? _onMicLevelCb;
  void Function(String)? _onEventCb;

  @override
  ValueListenable<bool> get warmingUp => _warmingUp;

  @override
  bool get hasActiveUtterance => _hasActiveUtterance;

  @override
  String get modelLabel => kOfflineModelLabel;

  static Future<String> _bundlePath() async {
    final support = await getApplicationSupportDirectory();
    return '${support.path}/$kWhisperSmallDirName';
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final bundlePath = await _bundlePath();
      return File('$bundlePath/small-encoder.int8.onnx').existsSync() &&
          File('$bundlePath/small-decoder.int8.onnx').existsSync() &&
          File('$bundlePath/small-tokens.txt').existsSync();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> flushUtterance() async {
    final port = _workerPort;
    if (port == null) return;
    final ack = Completer<void>();
    _flushAck = ack;
    port.send(['flush']);
    try {
      await ack.future.timeout(const Duration(seconds: 5));
    } catch (_) {
      // Worker never acked (shutting down / model missing): whatever finals
      // already arrived are merged by the provider; nothing more to salvage.
    } finally {
      if (identical(_flushAck, ack)) _flushAck = null;
    }
  }

  Future<bool> _ensureWorker() async {
    if (_workerPort != null) return true;
    final bundlePath = await _bundlePath();

    final p = ReceivePort();
    _isolate = await Isolate.spawn(_whisperWorker, [bundlePath, p.sendPort]);

    final completer = Completer<SendPort?>();
    p.listen((msg) {
      if (msg is List && msg[0] == 'ready') {
        completer.complete(msg[1] as SendPort);
      } else if (msg is List && msg[0] == 'error') {
        _log('[tanu] whisper worker error: ${msg[1]}');
        if (!completer.isCompleted) completer.complete(null);
      } else if (msg is List && msg[0] == 'flushed') {
        _flushAck?.complete();
      } else if (msg is List && msg[0] == 'timing') {
        _log('[tanu] decode ${(msg[1] as num).toStringAsFixed(1)}s audio in ${msg[2]}ms');
      } else if (msg is List && msg[0] == 'partial') {
        final text = msg[1] as String;
        if (_continuousActive && text.isNotEmpty) {
          _hasActiveUtterance = true;
          _onPartialCb?.call(text);
        }
      } else if (msg is List && msg[0] == 'final') {
        final text = msg[1] as String;
        if (_continuousActive && text.isNotEmpty) {
          _hasActiveUtterance = false;
          _onUtteranceCb?.call(text);
        }
      }
    });

    _workerPort = await completer.future;
    return _workerPort != null;
  }

  @override
  Future<bool> startContinuous(
    Stream<Uint8List> chunks, {
    required void Function(String) onUtterance,
    void Function(String partial)? onPartial,
    void Function(double level)? onMicLevel,
    void Function(String event)? onEvent,
  }) async {
    _onUtteranceCb = onUtterance;
    _onPartialCb = onPartial;
    _onMicLevelCb = onMicLevel;
    _onEventCb = onEvent;

    _continuousActive = true;
    _hasActiveUtterance = false;

    _onEventCb?.call('Starting Offline Model...');
    final ready = await _ensureWorker();
    if (!ready || !_continuousActive) {
      _warmingUp.value = false;
      return false;
    }

    _warmingUp.value = false;
    _onEventCb?.call('Offline Model Listening');

    _workerPort?.send(['reset']);

    _micSub = chunks.listen((pcm) {
      if (!_continuousActive) return;
      final samples = _toFloat32(pcm);
      final level = _level(samples);
      _onMicLevelCb?.call(level);

      _workerPort?.send(['audio', samples]);
    });

    return true;
  }

  @override
  Future<void> stopContinuous() async {
    _continuousActive = false;
    _hasActiveUtterance = false;
    await _micSub?.cancel();
    _micSub = null;
    _workerPort?.send(['reset']);
  }

  @override
  Future<String> transcribe(
    Uint8List pcmUtterance, {
    SttCallbacks? callbacks,
  }) async {
    return '';
  }

  @override
  Future<String> transcribeMic({SttCallbacks? callbacks}) async {
    return '';
  }

  @override
  Future<void> stop() async {
    await stopContinuous();
  }

  void dispose() {
    stopContinuous();
    _workerPort?.send(['shutdown']);
    _isolate?.kill();
    _workerPort = null;
    _isolate = null;
  }

  Float32List _toFloat32(Uint8List pcm16) {
    final bd = ByteData.sublistView(pcm16);
    final count = pcm16.length ~/ 2;
    final out = Float32List(count);
    for (int i = 0; i < count; i++) {
      out[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }

  double _level(Float32List samples) {
    if (samples.isEmpty) return 0;
    var sum = 0.0;
    for (final v in samples) {
      sum += v * v;
    }
    return math.min(1.0, math.sqrt(sum / samples.length) * 3);
  }

  void _log(String m) => debugPrint(m);
}

/// Known model hallucinations: fluent phrases emitted for noise/silence
/// instead of empty output. Dropped here AND in the conversation provider.
bool _isJunk(String text) {
  final t = text.trim().toLowerCase().replaceAll(RegExp(r'[.!?,]+$'), '');
  if (t.isEmpty || t.length < 2) return true;
  const junk = {
    'thank you',
    'thanks',
    'thank you very much',
    'thanks for watching',
    'bye',
    'goodbye',
    'oh',
    'ah',
    'um',
    'uh',
    'subtitles by amara.org',
    'amara.org',
    'captioned by',
    'transcribed by',
  };
  return junk.contains(t);
}

Future<void> _whisperWorker(List<dynamic> args) async {
  final bundlePath = args[0] as String;
  final replyPort = args[1] as SendPort;

  final commands = ReceivePort();
  replyPort.send(['ready', commands.sendPort]);

  await initBindingsAsync();

  final config = OfflineRecognizerConfig(
    model: OfflineModelConfig(
      whisper: OfflineWhisperModelConfig(
        encoder: '$bundlePath/small-encoder.int8.onnx',
        decoder: '$bundlePath/small-decoder.int8.onnx',
        language: SttConfig.language,
        task: SttConfig.task,
      ),
      tokens: '$bundlePath/small-tokens.txt',
      numThreads: SttConfig.numThreads,
      provider: 'cpu',
      debug: false,
    ),
  );

  final vadConfig = VadModelConfig(
    sileroVad: SileroVadModelConfig(
      model: '$bundlePath/$kSileroVadFileName',
      // A higher confidence boundary prevents room noise and pendant taps
      // from being sent to Whisper as speech.
      threshold: SttConfig.vadThreshold,
      // Keep a short but meaningful trailing pause so final words are not
      // clipped when someone speaks naturally.
      minSilenceDuration: SttConfig.vadMinSilence,
      minSpeechDuration: SttConfig.vadMinSpeech,
      maxSpeechDuration: SttConfig.vadMaxSpeech,
      windowSize: SttConfig.vadWindowSize,
    ),
    sampleRate: SttConfig.sampleRate,
    debug: false,
    numThreads: 1,
  );

  OfflineRecognizer? recognizer;
  VoiceActivityDetector? vad;

  try {
    recognizer = OfflineRecognizer(config);
    vad = VoiceActivityDetector(
      config: vadConfig,
      bufferSizeInSeconds: SttConfig.vadMaxSpeech,
    );
  } catch (e) {
    replyPort.send(['error', 'init failed: $e']);
    return;
  }

  // Incoming BLE chunks are not sample-aligned to the Silero window, so
  // audio is coalesced here and handed to the VAD in exact window-size
  // chunks.
  final window = SttConfig.vadWindowSize;
  final pending = <double>[];
  final sampleRate = SttConfig.sampleRate;

  // Drains full VAD windows, then decodes every popped segment in bounded
  // ~10 s pieces (synchronous decodes would otherwise stall live partials
  // for seconds on long monologues). When [flushTrailing] is set, pending
  // audio is first padded with silence so the open VAD segment endpoint-closes
  // instead of evaporating.
  void drainWindows({bool flushTrailing = false}) {
    final v = vad;
    final r = recognizer;
    if (v == null || r == null) return;
    if (flushTrailing) {
      final remainder = pending.length % window;
      if (remainder != 0) {
        pending.addAll(List.filled(window - remainder, 0.0));
      }
      // Trailing silence forces the open segment to endpoint-close.
      pending.addAll(List.filled((sampleRate * 0.6).round(), 0.0));
    }
    while (pending.length >= window) {
      final chunk = Float32List(window);
      for (var i = 0; i < window; i++) {
        chunk[i] = pending[i];
      }
      pending.removeRange(0, window);
      v.acceptWaveform(chunk);

      while (!v.isEmpty()) {
        final segment = v.front();
        v.pop();

        // Guard 1: ignore very short blips (door slams, mic taps).
        if (segment.samples.length < sampleRate * 0.4) continue;

        for (final seg in splitDecodeWindows(segment.samples, sampleRate * 10)) {
          // Guard 2: ignore near-silent pieces that slipped past VAD.
          var sum = 0.0;
          for (final sample in seg) {
            sum += sample * sample;
          }
          if (seg.isEmpty || sum / seg.length < 0.0002) continue;

          final stream = r.createStream();
          stream.acceptWaveform(samples: seg, sampleRate: sampleRate);
          final decodeWatch = Stopwatch()..start();
          r.decode(stream);
          decodeWatch.stop();
          replyPort.send([
            'timing',
            seg.length / sampleRate,
            decodeWatch.elapsedMilliseconds,
          ]);

          final result = r.getResult(stream);
          final text = result.text.trim();
          stream.free();

          // Guard 3: drop hallucinated filler phrases.
          if (text.isEmpty || _isJunk(text)) continue;
          replyPort.send(['partial', text]);
          replyPort.send(['final', text]);
        }
      }
    }
  }

  await for (final msg in commands) {
    if (msg is List) {
      final cmd = msg[0] as String;
      if (cmd == 'shutdown') {
        vad.free();
        recognizer.free();
        break;
      } else if (cmd == 'reset') {
        vad.clear();
        pending.clear();
      } else if (cmd == 'flush') {
        drainWindows(flushTrailing: true);
        replyPort.send(['flushed']);
      } else if (cmd == 'audio') {
        final samples = msg[1] as Float32List;
        pending.addAll(samples);
        drainWindows();
      }
    }
  }
}
