import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

import '../../abstractions/stt_engine.dart';
import '../../constants.dart';

/// Moonshine v2 base-en on-device engine (English-only).
///
/// Hallucinations ("thank you", "bye", ...) come almost entirely from
/// decoding near-silence: the model would rather emit a learned phrase than
/// nothing. This engine kills them at three levels, so the transcript stays
/// live AND honest:
/// 1. VAD gating — only Silero-confirmed speech segments are ever decoded;
///    silence is never sent to the recognizer.
/// 2. Segment guards — segments under 0.4 s or with near-zero energy are
///    dropped before decode.
/// 3. Junk-phrase filter — decoded text matching known hallucination
///    patterns is dropped (mirrors the provider filter as defense in depth).
/// UI thread converts PCM16 -> Float32 + mic level, worker isolate owns
/// `OfflineRecognizer` + `VoiceActivityDetector`.
class MoonshineSttEngine implements ContinuousSttEngine {
  MoonshineSttEngine() {
    _warmingUp.value = true;
  }

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
  String get modelLabel => kOfflineModelLabel;

  static Future<String> _bundlePath() async {
    final support = await getApplicationSupportDirectory();
    return '${support.path}/$kMoonshineDirName';
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final bundlePath = await _bundlePath();
      return File('$bundlePath/encoder_model.ort').existsSync() &&
          File('$bundlePath/decoder_model_merged.ort').existsSync() &&
          File('$bundlePath/tokens.txt').existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _ensureWorker() async {
    if (_workerPort != null) return true;
    final bundlePath = await _bundlePath();

    final p = ReceivePort();
    _isolate = await Isolate.spawn(_moonshineWorker, [bundlePath, p.sendPort]);

    final completer = Completer<SendPort?>();
    p.listen((msg) {
      if (msg is List && msg[0] == 'ready') {
        completer.complete(msg[1] as SendPort);
      } else if (msg is List && msg[0] == 'error') {
        _log('[tanu] moonshine worker error: ${msg[1]}');
        if (!completer.isCompleted) completer.complete(null);
      } else if (msg is List && msg[0] == 'partial') {
        final text = msg[1] as String;
        if (_continuousActive && text.isNotEmpty) {
          _hasActiveUtterance = true;
          _onPartialCb?.call('?$text');
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
  Future<String> transcribe(Uint8List pcmUtterance, {SttCallbacks? callbacks}) async {
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
    for (final v in samples) sum += v * v;
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
    'you',
    'yes',
    'no',
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

Future<void> _moonshineWorker(List<dynamic> args) async {
  final bundlePath = args[0] as String;
  final replyPort = args[1] as SendPort;

  final commands = ReceivePort();
  replyPort.send(['ready', commands.sendPort]);

  await initBindingsAsync();

  // Moonshine v2: encoder + merged decoder (no preprocessor file in the
  // quantized bundle, no separate cached/uncached decoders).
  final config = OfflineRecognizerConfig(
    model: OfflineModelConfig(
      moonshine: OfflineMoonshineModelConfig(
        encoder: '$bundlePath/encoder_model.ort',
        mergedDecoder: '$bundlePath/decoder_model_merged.ort',
      ),
      tokens: '$bundlePath/tokens.txt',
      numThreads: 4,
      provider: 'cpu',
      debug: false,
    ),
  );

  final vadConfig = VadModelConfig(
    sileroVad: SileroVadModelConfig(
      model: '$bundlePath/$kSileroVadFileName',
      threshold: 0.5,
      minSilenceDuration: 0.5,
      minSpeechDuration: 0.3,
      windowSize: 512,
    ),
    sampleRate: 16000,
    debug: false,
    numThreads: 1,
  );

  OfflineRecognizer? recognizer;
  VoiceActivityDetector? vad;

  try {
    recognizer = OfflineRecognizer(config);
    vad = VoiceActivityDetector(config: vadConfig, bufferSizeInSeconds: 30.0);
  } catch (e) {
    replyPort.send(['error', 'init failed: $e']);
    return;
  }

  await for (final msg in commands) {
    if (msg is List) {
      final cmd = msg[0] as String;
      if (cmd == 'shutdown') {
        vad?.free();
        recognizer.free();
        break;
      } else if (cmd == 'reset') {
        vad.clear();
      } else if (cmd == 'audio') {
        final samples = msg[1] as Float32List;
        vad.acceptWaveform(samples);

        while (!vad.isEmpty()) {
          final segment = vad.front();
          vad.pop();

          // Guard 1: ignore very short blips (door slams, mic taps).
          if (segment.samples.length < 16000 * 0.4) continue;

          final seg = Float32List.fromList(segment.samples);

          // Guard 2: ignore near-silent segments that slipped past VAD.
          var sum = 0.0;
          for (final v in seg) {
            sum += v * v;
          }
          if (seg.isEmpty || sum / seg.length < 0.0002) continue;

          final stream = recognizer.createStream();
          stream.acceptWaveform(samples: seg, sampleRate: 16000);
          recognizer.decode(stream);

          final result = recognizer.getResult(stream);
          final text = result.text.trim();
          stream.free();

          // Guard 3: drop hallucinated filler phrases.
          if (text.isEmpty || _isJunk(text)) continue;
          replyPort.send(['final', text]);
        }
      }
    }
  }
}
