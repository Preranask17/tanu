import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../services/dev/wav_capture.dart';
import 'ble_provider.dart';

/// Dev-only capture of the pendant's decoded audio to a WAV file.
class DevCaptureState {
  const DevCaptureState({this.recording = false, this.bytes = 0, this.path});

  final bool recording;
  final int bytes;
  final String? path;

  DevCaptureState copyWith({bool? recording, int? bytes, String? path}) {
    return DevCaptureState(
      recording: recording ?? this.recording,
      bytes: bytes ?? this.bytes,
      path: path ?? this.path,
    );
  }
}

final devCaptureProvider =
    NotifierProvider<DevCaptureNotifier, DevCaptureState>(
      DevCaptureNotifier.new,
    );

class DevCaptureNotifier extends Notifier<DevCaptureState> {
  StreamSubscription<Uint8List>? _sub;
  WavCapture? _capture;
  int _bytes = 0;
  int _lastUi = 0;

  @override
  DevCaptureState build() => const DevCaptureState();

  Future<void> toggle() async {
    if (state.recording) {
      await _stop();
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    if (_sub != null) return;
    final source = ref.read(pendantProvider);
    if (!source.currentStatus.isConnected) {
      state = state.copyWith(path: 'Connect the pendant first');
      return;
    }

    final dir = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/tanu_captures',
    );
    await dir.create(recursive: true);
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final capture = await WavCapture.create(
      File('${dir.path}/capture_$stamp.wav'),
    );

    _capture = capture;
    _bytes = 0;
    _lastUi = 0;
    state = const DevCaptureState(recording: true);

    _sub = source.pcmAudio.listen(
      _onPcm,
      onError: (Object e) {
        _lastUi = 0;
        state = state.copyWith(recording: false, path: 'capture error: $e');
        unawaited(_cleanup());
      },
    );
  }

  void _onPcm(Uint8List pcm) {
    _capture?.add(pcm);
    _bytes += pcm.length;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastUi > 250) {
      _lastUi = now;
      state = state.copyWith(bytes: _bytes);
    }
  }

  Future<void> _stop() async {
    final path = await _cleanup();
    state = DevCaptureState(bytes: _bytes, path: path);
    _bytes = 0;
  }

  Future<String?> _cleanup() async {
    final sub = _sub;
    _sub = null;
    await sub?.cancel();

    final capture = _capture;
    _capture = null;
    if (capture == null) return state.path;
    try {
      return await capture.close();
    } catch (e) {
      return 'capture error: $e';
    }
  }
}
