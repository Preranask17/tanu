import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

import '../../abstractions/stt_engine.dart';

class SenseVoiceSttEngine implements ContinuousSttEngine {
  SenseVoiceSttEngine() {
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
  String get modelLabel => 'SenseVoice Â· 163 MB';

  @override
  Future<bool> isAvailable() async {
    final support = await getApplicationSupportDirectory();
    final bundle = Directory('${support.path}/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17');
    return bundle.existsSync();
  }

  Future<bool> _ensureWorker() async {
    if (_workerPort != null) return true;
    final support = await getApplicationSupportDirectory();
    final bundlePath = '${support.path}/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17';
    
    final p = ReceivePort();
    _isolate = await Isolate.spawn(_senseVoiceWorker, [bundlePath, p.sendPort]);
    
    final completer = Completer<SendPort?>();
    p.listen((msg) {
      if (msg is List && msg[0] == 'ready') {
        completer.complete(msg[1] as SendPort);
      } else if (msg is List && msg[0] == 'error') {
        _log('[tanu] worker error: ${msg[1]}');
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
    void Function(String)? onPartial,
    void Function(double)? onMicLevel,
    void Function(String)? onEvent,
  }) async {
    _onUtteranceCb = onUtterance;
    _onPartialCb = onPartial;
    _onMicLevelCb = onMicLevel;
    _onEventCb = onEvent;

    _continuousActive = true;
    _hasActiveUtterance = false;

    _onEventCb?.call('Starting SenseVoice...');
    final ready = await _ensureWorker();
    if (!ready || !_continuousActive) {
      _warmingUp.value = false;
      return false;
    }

    _warmingUp.value = false;
    _onEventCb?.call('SenseVoice Listening');

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

  @override
  Future<void> flushUtterance() async {
    // No worker-side audio held: nothing to salvage.
  }

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

Future<void> _senseVoiceWorker(List<dynamic> args) async {
  final bundlePath = args[0] as String;
  final replyPort = args[1] as SendPort;

  final commands = ReceivePort();
  replyPort.send(['ready', commands.sendPort]);

  await initBindingsAsync();

  final config = OfflineRecognizerConfig(
    model: OfflineModelConfig(
      senseVoice: OfflineSenseVoiceModelConfig(
        model: '$bundlePath/model.int8.onnx',
        language: 'en',
        useInverseTextNormalization: true,
      ),
      tokens: '$bundlePath/tokens.txt',
      numThreads: 4,
      provider: 'cpu',
      debug: false,
    )
  );

  final vadConfig = VadModelConfig(
    sileroVad: SileroVadModelConfig(
      model: '$bundlePath/silero_vad.onnx',
      threshold: 0.5,
      minSilenceDuration: 0.5,
      minSpeechDuration: 0.25,
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
        vad.free();
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
          
          final stream = recognizer.createStream();
          stream.acceptWaveform(samples: Float32List.fromList(segment.samples), sampleRate: 16000);
          recognizer.decode(stream);
          
          final result = recognizer.getResult(stream);
          final text = result.text.trim();
          stream.free();
          
          if (text.isNotEmpty) {
            replyPort.send(['final', text]);
          }
        }
      }
    }
  }
}
