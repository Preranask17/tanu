import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../abstractions/stt_engine.dart';
import '../../providers/settings_provider.dart';
import 'deepgram_stt_engine.dart';
import 'moonshine_stt_engine.dart';

/// Dispatches continuous STT to Deepgram (cloud) or the on-device Moonshine
/// model depending on the user's [SttBackend] preference, transparently to the
/// consumer. Mid-session Deepgram socket failures hand off to Moonshine
/// without tearing down the conversation.
class RoutingSttEngine implements ContinuousSttEngine {
  RoutingSttEngine({
    ContinuousSttEngine? deepgram,
    ContinuousSttEngine? moonshine,
    this.backend = SttBackend.cloud,
  })  : _deepgram = deepgram ?? DeepgramSttEngine(),
        _moonshine = moonshine ?? MoonshineSttEngine();

  final ContinuousSttEngine _deepgram;
  final ContinuousSttEngine _moonshine;

  /// Which recognizer the user wants. Call [switchBackend] to change it live.
  SttBackend backend;

  static const String _onDeviceMarker =
      'cloud STT unavailable — using on-device model';

  final ValueNotifier<bool> _standbyWarm = ValueNotifier<bool>(false);

  ContinuousSttEngine? _active;
  Stream<Uint8List>? _sessionChunks;
  Stream<Uint8List>? _handoffChunks;
  void Function(String)? _sessionOnUtterance;
  void Function(String)? _sessionOnPartial;
  void Function(double)? _sessionOnMicLevel;
  void Function(String)? _sessionOnEvent;
  Future<void>? _fallbackInFlight;
  bool _fellBack = false;
  bool _fallbackStarted = false;
  bool _disposed = false;

  @override
  Future<bool> isAvailable() async =>
      await _deepgram.isAvailable() || await _moonshine.isAvailable();

  @override
  ValueListenable<bool> get warmingUp => _active?.warmingUp ?? _standbyWarm;

  @override
  bool get hasActiveUtterance => _active?.hasActiveUtterance ?? false;

  @override
  String get modelLabel => backend == SttBackend.cloud
      ? _deepgram.modelLabel
      : _moonshine.modelLabel;

  @override
  Future<bool> startContinuous(
    Stream<Uint8List> chunks, {
    required void Function(String) onUtterance,
    void Function(String partial)? onPartial,
    void Function(double level)? onMicLevel,
    void Function(String event)? onEvent,
  }) async {
    final useCloud = backend == SttBackend.cloud && await _deepgram.isAvailable();
    final active = useCloud ? _deepgram : _moonshine;
    _fellBack = false;
    _fallbackInFlight = null;
    _fallbackStarted = false;
    _sessionChunks = chunks;
    _handoffChunks = chunks;
    _sessionOnUtterance = onUtterance;
    _sessionOnPartial = onPartial;
    _sessionOnMicLevel = onMicLevel;
    _sessionOnEvent = onEvent;
    _active = active;

    final ok = await active.startContinuous(
      chunks,
      onUtterance: onUtterance,
      onPartial: onPartial,
      onMicLevel: onMicLevel,
      onEvent: _forwardChildEvent,
    );
    if (ok) return true;
    if (_fellBack) {
      await _fallbackInFlight;
      if (!_fallbackStarted) _active = null;
      return _fallbackStarted;
    }
    _active = null;
    return false;
  }

  // Deepgram's failure markers are 'stt:error:...' (connect/stream errors) and
  // 'stt:ws-closed' (socket died); both mean the cloud arm is gone.
  void _forwardChildEvent(String event) {
    if (identical(_active, _deepgram) && _isCloudFailure(event)) {
      unawaited(_fallbackToOnDevice());
    }
    _sessionOnEvent?.call(event);
  }

  bool _isCloudFailure(String event) =>
      event.startsWith('stt:error') || event.contains('stt:ws');

  Future<void> _fallbackToOnDevice() {
    final inFlight = _fallbackInFlight;
    if (inFlight != null) return inFlight;
    if (_fellBack) return Future<void>.value();
    final run = _runFallback();
    _fallbackInFlight = run;
    return run;
  }

  Future<void> _runFallback() async {
    _fellBack = true;
    final chunks = _handoffChunks;
    if (chunks == null) return;
    _handoffChunks = null;
    await _deepgram.stopContinuous();
    if (!_fellBack || _disposed) return;
    _active = _moonshine;
    final started = await _moonshine.startContinuous(
      chunks,
      onUtterance: _sessionOnUtterance ?? (_) {},
      onPartial: _sessionOnPartial,
      onMicLevel: _sessionOnMicLevel,
      onEvent: (event) => _sessionOnEvent?.call(event),
    );
    _fallbackStarted = started;
    if (!_fellBack || _disposed) {
      await _moonshine.stopContinuous();
      _active = null;
      return;
    }
    if (started) {
      _sessionOnEvent?.call(_onDeviceMarker);
    } else {
      _active = null;
    }
  }

  @override
  Future<void> stopContinuous() async {
    final active = _active;
    _fellBack = false;
    _sessionChunks = null;
    _handoffChunks = null;
    _sessionOnUtterance = null;
    _sessionOnPartial = null;
    _sessionOnMicLevel = null;
    _sessionOnEvent = null;
    _active = null;
    if (active != null) await active.stopContinuous();
    final inFlight = _fallbackInFlight;
    if (inFlight != null) await inFlight;
    _fallbackInFlight = null;
    _fallbackStarted = false;
  }

  @override
  Future<String> transcribe(
    Uint8List pcmUtterance, {
    SttCallbacks? callbacks,
  }) async {
    final active = _active;
    if (active != null) {
      return active.transcribe(pcmUtterance, callbacks: callbacks);
    }
    final engine = await _pickRoute();
    if (engine == null) return '';
    return engine.transcribe(pcmUtterance, callbacks: callbacks);
  }

  @override
  Future<String> transcribeMic({SttCallbacks? callbacks}) async {
    final active = _active;
    if (active != null) {
      return active.transcribeMic(callbacks: callbacks);
    }
    final engine = await _pickRoute();
    if (engine == null) return '';
    return engine.transcribeMic(callbacks: callbacks);
  }

  Future<ContinuousSttEngine?> _pickRoute() async {
    if (backend == SttBackend.cloud && await _deepgram.isAvailable()) {
      return _deepgram;
    }
    if (await _moonshine.isAvailable()) return _moonshine;
    return null;
  }

  /// Swaps the recognizer mid-session without interrupting the conversation:
  /// the active engine is stopped and the other is started on the same chunk
  /// stream with the same callbacks. A no-op when the preference is unchanged
  /// or nothing is actively running.
  Future<void> switchBackend(SttBackend next) async {
    if (next == backend || _disposed) return;
    final prev = backend;
    backend = next;
    final chunks = _sessionChunks;
    if (chunks == null || _sessionOnUtterance == null) return;
    final target = next == SttBackend.cloud ? _deepgram : _moonshine;
    if (identical(_active, target)) return;

    // Stop the outgoing engine but keep the shared session state local so the
    // handoff below can restart on the same stream.
    final active = _active;
    _active = null;
    if (active != null) {
      await active.stopContinuous();
      if (_disposed) return;
    }

    _fellBack = false;
    _fallbackInFlight = null;
    _fallbackStarted = false;
    final started = await target.startContinuous(
      chunks,
      onUtterance: _sessionOnUtterance ?? (_) {},
      onPartial: _sessionOnPartial,
      onMicLevel: _sessionOnMicLevel,
      onEvent: (event) => _sessionOnEvent?.call(event),
    );
    if (!_disposed) {
      _active = started ? target : null;
    }
    if (started && next == SttBackend.onDevice) {
      _sessionOnEvent?.call(_onDeviceMarker);
    }
    if (started) {
      final label = next == SttBackend.cloud
          ? _deepgram.modelLabel
          : _moonshine.modelLabel;
      _sessionOnEvent?.call('STT: $label');
    } else if (prev == backend) {
      // Target failed to start and the preference is unchanged — reopen via
      // the other auth-free path if available.
      final fallback = prev == SttBackend.cloud ? _moonshine : _deepgram;
      final ok = await fallback.startContinuous(
        chunks,
        onUtterance: _sessionOnUtterance ?? (_) {},
        onPartial: _sessionOnPartial,
        onMicLevel: _sessionOnMicLevel,
        onEvent: (event) => _sessionOnEvent?.call(event),
      );
      if (!_disposed) {
        _active = ok ? fallback : null;
        if (ok && prev == SttBackend.cloud) {
          _sessionOnEvent?.call(_onDeviceMarker);
        }
      }
    }
  }

  @override
  Future<void> stop() async {
    _fellBack = false;
    _fallbackInFlight = null;
    _fallbackStarted = false;
    _sessionChunks = null;
    _handoffChunks = null;
    _sessionOnUtterance = null;
    _sessionOnPartial = null;
    _sessionOnMicLevel = null;
    _sessionOnEvent = null;
    _active = null;
    await _deepgram.stop();
    await _moonshine.stop();
  }

  Future<void> dispose() async {
    _disposed = true;
    _fellBack = false;
    _fallbackInFlight = null;
    _fallbackStarted = false;
    _sessionChunks = null;
    _handoffChunks = null;
    _sessionOnUtterance = null;
    _sessionOnPartial = null;
    _sessionOnMicLevel = null;
    _sessionOnEvent = null;
    _active = null;
    _standbyWarm.dispose();
    await _disposeChild(_deepgram);
    await _disposeChild(_moonshine);
  }

  Future<void> _disposeChild(ContinuousSttEngine engine) async {
    await engine.stop();
    // Only Moonshine exposes a real dispose hook (worker-isolate teardown);
    // Deepgram's stop() is its full teardown.
    if (engine is MoonshineSttEngine) await engine.dispose();
  }
}