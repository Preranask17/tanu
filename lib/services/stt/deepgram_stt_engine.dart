import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../abstractions/stt_engine.dart';
import '../../constants.dart';

/// Cloud speech-to-text using the Deepgram streaming websocket (primary
/// recognizer). Raw linear16 PCM16 mono audio at 16000 Hz from the pendant is
/// pushed straight over the socket; Deepgram returns live partials while the
/// user speaks and a final result after [kDeepgramEndpointing] ms of silence.
///
/// The on-device Moonshine fallback ([RoutingSttEngine]'s other arm) is a
/// separate engine; this class only chases `wss://api.deepgram.com`.
class DeepgramSttEngine implements ContinuousSttEngine {
  static const String _modelLabel = 'Deepgram (nova-3 · cloud)';
  static const Duration _keepAliveEvery = Duration(seconds: 10);
  static const Duration _connectTimeout = Duration(seconds: 10);
  static const Duration _micWindow = Duration(seconds: 8);

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _wsSub;
  Timer? _keepAliveTimer;
  StreamSubscription<Uint8List>? _chunkSub;
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _recorderSub;

  bool _continuousActive = false;
  bool _closed = true;
  bool _utteranceInFlight = false;
  String _lastPartial = '';
  final Stopwatch _lastMicEmit = Stopwatch()..start();

  // Client-side silence gate. Deepgram's own endpointing tolerates field
  // noise, so unless ambient chunks are filtered here the pendant's quiet
  // moments turn into phantom words. Mirrors the adaptive gate the on-device
  // Moonshine engine already runs: an EMA noise floor, speech only above
  // floor*1.8, and a guard band that keeps the socket fed while below it.
  double _noiseFloor = 0;
  bool _vadSpeech = false;
  int _vadSilenceMs = 0;
  static const int _vadSilenceFlushMs = 900;
  static const double _vadLevelFloor = 0.0035;
  static const double _vadLevelCeil = 0.02;

  double get _vadThreshold {
    final floor = _noiseFloor;
    return math.min(_vadLevelCeil, math.max(_vadLevelFloor, floor * 1.8));
  }

  void Function(String)? _onUtteranceCb;
  void Function(String)? _onPartialCb;
  void Function(double)? _onMicLevelCb;
  void Function(String)? _onEventCb;

  /// True from session start until the websocket is open and ready.
  @override
  final ValueNotifier<bool> warmingUp = ValueNotifier(false);

  /// True while audio has been sent and a final result for it has not yet
  /// landed, so the provider never clobbers live words with a memory reply.
  @override
  bool get hasActiveUtterance => _utteranceInFlight;

  @override
  String get modelLabel => _modelLabel;

  /// The routing engine passes the empty-key case to Moonshine; no key here
  /// simply means this engine can never come up.
  @override
  Future<bool> isAvailable() async => kDeepgramApiKey.isNotEmpty;

  String get _endpoint {
    final query = {
      'model': kDeepgramModel,
      'language': kDeepgramLanguage,
      'encoding': kDeepgramEncoding,
      'sample_rate': '$kDeepgramSampleRate',
      'interim_results': '$kDeepgramInterimResults',
      'endpointing': '$kDeepgramEndpointing',
      'smart_format': '$kDeepgramSmartFormat',
      'punctuate': 'true',
      'numerals': 'true',
      'utterance_end_ms': '1000',
      'vad_events': 'true',
    };
    final params =
        query.entries.map((e) => '${e.key}=${e.value}').join('&');
    return '$kDeepgramEndpoint?$params';
  }

  Future<WebSocketChannel?> _connect({void Function(String)? onEvent}) async {
    try {
      final ws = IOWebSocketChannel.connect(
        _endpoint,
        headers: {'Authorization': 'Token $kDeepgramApiKey'},
        connectTimeout: _connectTimeout,
      );
      await ws.ready;
      return ws;
    } catch (e) {
      debugPrint('[tanu] deepgram connect failed: $e');
      onEvent?.call('stt:error:connect $e');
      return null;
    }
  }

  @override
  Future<bool> startContinuous(
    Stream<Uint8List> chunks, {
    required void Function(String utterance) onUtterance,
    void Function(String partial)? onPartial,
    void Function(double level)? onMicLevel,
    void Function(String event)? onEvent,
  }) async {
    if (_continuousActive) return true;
    if (kDeepgramApiKey.isEmpty) return false;

    _continuousActive = true;
    _closed = false;
    _utteranceInFlight = false;
    _lastPartial = '';
    _noiseFloor = 0;
    _vadSpeech = false;
    _vadSilenceMs = 0;
    _onUtteranceCb = onUtterance;
    _onPartialCb = onPartial;
    _onMicLevelCb = onMicLevel;
    _onEventCb = onEvent;
    warmingUp.value = true;

    final ws = await _connect(onEvent: onEvent);
    if (ws == null || _closed) {
      _continuousActive = false;
      warmingUp.value = false;
      return false;
    }

    _channel = ws;
    _wsSub = ws.stream.listen(
      _onMessage,
      onError: _onSocketError,
      onDone: _onSocketDone,
    );
    warmingUp.value = false;
    _onEventCb?.call('stt:connected');
    _startKeepAlive();

    _chunkSub = chunks.listen(
      _onChunk,
      onError: (Object e, StackTrace st) {
        if (_continuousActive) _onEventCb?.call('audio error: $e');
      },
      onDone: () {
        if (_continuousActive) unawaited(stopContinuous());
      },
    );
    debugPrint('[tanu] deepgram streaming subscribed');
    return true;
  }

  void _onChunk(Uint8List pcm) {
    if (!_continuousActive || _closed) return;
    final samples = ByteData.sublistView(pcm);
    double peak = 0;
    for (var i = 0; i < samples.lengthInBytes; i += 2) {
      final s = samples.getInt16(i, Endian.little);
      final amp = s.abs() / 32768.0;
      if (amp > peak) peak = amp;
    }
    final level = peak;
    if (_lastMicEmit.elapsedMilliseconds >= 250) {
      _lastMicEmit.reset();
      _onMicLevelCb?.call(level);
    }

    // Silence gate: drop ambient chunks so quiet moments can't become words.
    if (!_vadSpeech) {
      if (level < _vadThreshold) {
        _noiseFloor = _noiseFloor * 0.94 + level * 0.06;
        return;
      }
      _vadSpeech = true;
      _vadSilenceMs = 0;
      _noiseFloor = 0;
    } else if (level < _vadThreshold) {
      _vadSilenceMs += pcm.length * 1000 ~/ (kDeepgramSampleRate * 2);
      if (_vadSilenceMs >= _vadSilenceFlushMs) {
        _vadSpeech = false;
        _vadSilenceMs = 0;
        _noiseFloor = 0;
        return;
      }
    } else {
      _vadSilenceMs = 0;
    }

    _utteranceInFlight = true;
    _channel?.sink.add(pcm);
  }

  void _onMessage(dynamic message) {
    if (_closed) return;
    final (text, isFinal) = _decodeResults(message);
    if (text.isEmpty && !isFinal) return;
    if (isFinal) {
      _utteranceInFlight = false;
      if (text.isNotEmpty) {
        _lastPartial = '';
        _onUtteranceCb?.call(text);
        _onEventCb?.call('');
      }
    } else if (text.isNotEmpty && text != _lastPartial) {
      _lastPartial = text;
      _onPartialCb?.call(text);
    }
  }

  void _onSocketError(Object e, StackTrace st) {
    if (_closed) return;
    debugPrint('[tanu] deepgram socket error: $e\n$st');
    _onEventCb?.call('stt:error:$e');
  }

  void _onSocketDone() {
    if (_closed) return;
    _utteranceInFlight = false;
    _stopKeepAlive();
    _onEventCb?.call('stt:ws-closed');
    final sub = _chunkSub;
    _chunkSub = null;
    unawaited(sub?.cancel());
    _continuousActive = false;
    _channel = null;
    _wsSub = null;
    warmingUp.value = false;
  }

  /// Pulls `(transcript, is_final)` out of a Deepgram `Results` frame;
  /// everything else (Metadata, UtteranceEnd, KeepAlive echoes) is inert.
  static (String, bool) _decodeResults(dynamic message) {
    if (message is! String) return ('', false);
    final Object decoded;
    try {
      decoded = jsonDecode(message);
    } catch (_) {
      return ('', false);
    }
    if (decoded is! Map<String, dynamic>) return ('', false);
    if (decoded['type'] == 'Close') {
      return ('', false);
    }
    if (decoded['type'] != 'Results') return ('', false);
    final channel = decoded['channel'];
    if (channel is! Map<String, dynamic>) return ('', false);
    final alternatives = channel['alternatives'];
    if (alternatives is! List || alternatives.isEmpty) return ('', false);
    final first = alternatives.first;
    if (first is! Map<String, dynamic>) return ('', false);
    final raw = first['transcript'];
    return (raw is String ? raw.trim() : '', decoded['is_final'] == true);
  }

  void _startKeepAlive() {
    _stopKeepAlive();
    _keepAliveTimer = Timer.periodic(_keepAliveEvery, (_) {
      final ws = _channel;
      if (ws != null && !_closed && _continuousActive) {
        ws.sink.add(jsonEncode({'type': 'KeepAlive'}));
      }
    });
  }

  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  @override
  Future<void> stopContinuous() async {
    _continuousActive = false;
    _closed = true;
    _utteranceInFlight = false;
    _stopKeepAlive();

    final sub = _chunkSub;
    _chunkSub = null;
    await sub?.cancel();

    _onUtteranceCb = null;
    _onPartialCb = null;
    _onMicLevelCb = null;
    _onEventCb = null;
    _lastPartial = '';

    final ws = _channel;
    final wsSub = _wsSub;
    _channel = null;
    _wsSub = null;
    if (ws != null) {
      try {
        ws.sink.add(jsonEncode({'type': 'CloseStream'}));
      } catch (_) {}
      await ws.sink.close().catchError((_) {});
    }
    await wsSub?.cancel();
    warmingUp.value = false;
    debugPrint('[tanu] deepgram session closed');
  }

  @override
  Future<String> transcribe(
    Uint8List pcmUtterance, {
    SttCallbacks? callbacks,
  }) async {
    if (_continuousActive) {
      callbacks?.onEvent?.call('recognizer busy');
      return '';
    }
    if (kDeepgramApiKey.isEmpty || pcmUtterance.isEmpty) return '';
    return _transcribeOverSocket(pcmUtterance, callbacks: callbacks);
  }

  @override
  Future<String> transcribeMic({SttCallbacks? callbacks}) async {
    if (_continuousActive) {
      callbacks?.onEvent?.call('recognizer busy');
      return '';
    }
    if (kDeepgramApiKey.isEmpty) return '';

    final recorder = AudioRecorder();
    if (!await recorder.hasPermission()) {
      callbacks?.onEvent?.call('microphone permission denied');
      return '';
    }

    final Stream<Uint8List> audio;
    try {
      audio = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: kDeepgramSampleRate,
          numChannels: 1,
        ),
      );
    } catch (e) {
      callbacks?.onEvent?.call('mic error: $e');
      await recorder.dispose();
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
          callbacks?.onMicLevel?.call(_pcmLevel(chunk));
        }
      });
      await Future<void>.delayed(_micWindow);
    } catch (e) {
      callbacks?.onEvent?.call('mic error: $e');
      return '';
    } finally {
      await _releaseMic();
    }

    final pcm = buffer.takeBytes();
    if (pcm.isEmpty) return '';
    return _transcribeOverSocket(pcm, callbacks: callbacks);
  }

  /// Single-utterance path shared by [transcribe] and [transcribeMic]: send
  /// the whole PCM clip, surface any final result Deepgram emits for it, then
  /// close. Bounded by [_connectTimeout] + a generous read timeout so a dead
  /// socket cannot hang the caller forever.
  Future<String> _transcribeOverSocket(
    Uint8List pcm, {
    SttCallbacks? callbacks,
  }) async {
    final ws = await _connect(onEvent: callbacks?.onEvent);
    if (ws == null) return '';

    final segments = StringBuffer();
    final completer = Completer<String>();
    StreamSubscription<dynamic>? sub;
    var sawFinal = false;
    try {
      sub = ws.stream.listen(
        (message) {
          final (text, isFinal) = _decodeResults(message);
          if (text.isEmpty) {
            if (isFinal && !completer.isCompleted) {
              completer.complete(segments.toString().trim());
            }
            return;
          }
          if (isFinal && !sawFinal) {
            sawFinal = true;
            if (segments.isNotEmpty) segments.write(' ');
            segments.write(text);
            callbacks?.onPartial?.call(text);
          }
          if (isFinal && !completer.isCompleted) {
            completer.complete(segments.toString().trim());
          }
        },
        onError: (Object e, StackTrace st) {
          if (!completer.isCompleted) completer.completeError(e, st);
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(segments.toString().trim());
          }
        },
      );
      ws.sink.add(pcm);
      final transcript = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => segments.toString().trim(),
      );
      callbacks?.onEvent?.call('');
      return transcript;
    } catch (e) {
      debugPrint('[tanu] deepgram one-shot failed: $e');
      callbacks?.onEvent?.call('stt:error:$e');
      return '';
    } finally {
      await sub?.cancel();
      try {
        await ws.sink.close();
      } catch (_) {}
    }
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

  @override
  Future<void> stop() async {
    await stopContinuous();
  }

  static double _pcmLevel(Uint8List pcm) {
    final len = pcm.lengthInBytes - (pcm.lengthInBytes.isOdd ? 1 : 0);
    if (len == 0) return 0;
    final data = ByteData.sublistView(pcm);
    final count = len ~/ 2;
    var sum = 0.0;
    for (var i = 0; i < count; i++) {
      final v = data.getInt16(i * 2, Endian.little) / 32768.0;
      sum += v * v;
    }
    return math.min(1.0, math.sqrt(sum / count) * 3);
  }
}