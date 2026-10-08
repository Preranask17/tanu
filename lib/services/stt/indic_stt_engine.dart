import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

import '../../abstractions/stt_engine.dart';
import '../../config/stt_config.dart';
import '../../constants.dart';

/// Indic-language on-device engine ("core" STT for Indian languages).
///
/// Decodes one explicit Indic language (Hindi, Kannada, Tamil, Telugu,
/// Malayalam, Bengali, Marathi, Gujarati — see [SttConfig.indicLanguages])
/// entirely offline via the SAME shared sherpa-onnx stack as Whisper Small:
/// the same 375 MB multilingual bundle already on disk, the same shared
/// Silero VAD download, the same VAD tuning. No extra model download, no
/// extra storage, no new native dependency.
///
/// The only deliberate difference from [WhisperSmallEngine] is the explicit
/// `language` hint passed to the recognizer instead of auto-detect: with a
/// fixed language the model skips detection (faster first-final) and stops
/// mis-decoding one language as another. The three anti-hallucination
/// guards are identical: VAD-gated decode, 0.4 s + energy segment guards,
/// junk-phrase filter.
///
/// Main isolate converts PCM16 -> Float32 + mic level and forwards audio;
/// the worker isolate owns `OfflineRecognizer` + `VoiceActivityDetector`.
class IndicSttEngine implements ContinuousSttEngine {
  IndicSttEngine({required this.languageCode, required this.languageLabel}) {
    _warmingUp.value = true;
  }

  /// Whisper language id, e.g. `hi`. Must be in [SttConfig.indicLanguages].
  final String languageCode;

  /// Human name shown in Settings / chips, e.g. `Hindi`.
  final String languageLabel;

  final ValueNotifier<bool> _warmingUp = ValueNotifier(true);
  bool _continuousActive = false;
  bool _hasActiveUtterance = false;

  SendPort? _workerPort;
  Isolate? _isolate;

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
  String get modelLabel => 'Whisper Small · $languageLabel';

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

  Future<bool> _ensureWorker() async {
    if (_workerPort != null) return true;
    final bundlePath = await _bundlePath();

    final p = ReceivePort();
    _isolate = await Isolate.spawn(_indicWorker, [
      bundlePath,
      languageCode,
      p.sendPort,
    ]);

    final completer = Completer<SendPort?>();
    p.listen((msg) {
      if (msg is List && msg[0] == 'ready') {
        completer.complete(msg[1] as SendPort);
      } else if (msg is List && msg[0] == 'error') {
        _log('[tanu] indic worker error: ${msg[1]}');
        if (!completer.isCompleted) completer.complete(null);
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

    _onEventCb?.call('Starting $languageLabel model...');
    final ready = await _ensureWorker();
    if (!ready || !_continuousActive) {
      _warmingUp.value = false;
      return false;
    }

    _warmingUp.value = false;
    _onEventCb?.call('$languageLabel Listening');

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
    for (var i = 0; i < count; i++) {
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

/// Same hallucination contract as the Whisper engine: fluent phrases emitted
/// for noise/silence instead of empty output. Dropped here AND in the
/// conversation provider. Shared verbatim so both engines stay honest the
/// same way regardless of language.
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

Future<void> _indicWorker(List<dynamic> args) async {
  final bundlePath = args[0] as String;
  final language = args[1] as String;
  final replyPort = args[2] as SendPort;

  final commands = ReceivePort();
  replyPort.send(['ready', commands.sendPort]);

  await initBindingsAsync();

  final config = OfflineRecognizerConfig(
    model: OfflineModelConfig(
      whisper: OfflineWhisperModelConfig(
        encoder: '$bundlePath/small-encoder.int8.onnx',
        decoder: '$bundlePath/small-decoder.int8.onnx',
        // Explicit language (never auto-detect): the Indic core contract.
        language: language,
        task: SttConfig.task,
      ),
      tokens: '$bundlePath/small-tokens.txt',
      numThreads: SttConfig.numThreads,
      provider: 'cpu',
      debug: false,
    ),
  );

  // Shared Silero VAD with the same tuning as every other engine.
  final vadConfig = VadModelConfig(
    sileroVad: SileroVadModelConfig(
      model: '$bundlePath/$kSileroVadFileName',
      threshold: SttConfig.vadThreshold,
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
      } else if (cmd == 'audio') {
        final samples = msg[1] as Float32List;
        pending.addAll(samples);

        while (pending.length >= window) {
          final chunk = Float32List(window);
          for (var i = 0; i < window; i++) {
            chunk[i] = pending[i];
          }
          pending.removeRange(0, window);
          vad.acceptWaveform(chunk);

          while (!vad.isEmpty()) {
            final segment = vad.front();
            vad.pop();

            // Guard 1: ignore very short blips (door slams, mic taps).
            if (segment.samples.length < sampleRate * 0.4) continue;

            // Long segments decode synchronously and would stall live
            // partials for seconds, so split anything over ~10 s into
            // back-to-back decode windows. Same guards apply per window;
            // the provider still groups the pieces into one memory.
            final all = segment.samples;
            var offset = 0;
            while (offset < all.length) {
              final end = (offset + sampleRate * 10 < all.length)
                  ? offset + sampleRate * 10
                  : all.length;
              final seg = Float32List.fromList(all.sublist(offset, end));
              offset = end;

              // Guard 2: ignore near-silent pieces that slipped past VAD.
              var sum = 0.0;
              for (final v in seg) {
                sum += v * v;
              }
              if (seg.isEmpty || sum / seg.length < 0.0002) continue;

              final stream = recognizer.createStream();
              stream.acceptWaveform(samples: seg, sampleRate: sampleRate);
              recognizer.decode(stream);

              final result = recognizer.getResult(stream);
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
    }
  }
}
