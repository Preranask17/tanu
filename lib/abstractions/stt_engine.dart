import 'package:flutter/foundation.dart';

/// Live diagnostics callbacks fired while a recognizer session is running.
class SttCallbacks {
  const SttCallbacks({this.onPartial, this.onMicLevel, this.onEvent});

  /// Live partial words as the user keeps talking.
  final void Function(String partial)? onPartial;

  /// Live mic input level normalized to roughly 0..1.
  final void Function(double level)? onMicLevel;

  /// Recognizer status/error strings verbatim.
  final void Function(String event)? onEvent;
}

/// Speech-to-text. This interface is the ONE deliberate swap point: today we
/// have Moonshine v2 base-en on-device (sherpa-onnx) with VAD-gated
/// continuous decoding, reached through [ContinuousSttEngine]. The interface
/// stays tight: PCM in, transcript out.
abstract class SttEngine {
  /// Transcribe a single mono PCM16 utterance at 16000 Hz.
  Future<String> transcribe(Uint8List pcmUtterance, {SttCallbacks? callbacks});

  /// Phone-microphone enabled session ("Test mic" on Home) for validating the
  /// caption pipeline without the pendant. Returns the final transcript after
  /// a bounded listening window.
  Future<String> transcribeMic({SttCallbacks? callbacks});

  /// Any permission / availability check the engine needs before use.
  /// Returns false if the engine could not become ready (e.g. model missing).
  Future<bool> isAvailable();

  /// Abort any in-flight recognition.
  Future<void> stop();
}

/// A recognizer that keeps a live ambient session running off the pendant's
/// PCM16 stream rather than clamping at a single fixed utterance. This is the
/// shape `conversation_provider` talks to, and today it is implemented by
/// [MoonshineSttEngine]: on-device Moonshine + Silero VAD segmentation with
/// hallucination guards.
abstract class ContinuousSttEngine extends SttEngine {
  /// Begin a continuous, pendant-fed session. The engine consumes PCM16 mono
  /// chunks at 16000 Hz from [chunks], delivering finished utterances through
  /// [onUtterance] and live partials through [onPartial]. Returns false if the
  /// engine was warming up or could not start.
  Future<bool> startContinuous(
    Stream<Uint8List> chunks, {
    required void Function(String utterance) onUtterance,
    void Function(String partial)? onPartial,
    void Function(double level)? onMicLevel,
    void Function(String event)? onEvent,
  });

  /// End the session, flushing any trailing utterance.
  Future<void> stopContinuous();

  /// True while the engine is loading its model / opening its websocket;
  /// the UI shows a warming chip instead of listening.
  ValueListenable<bool> get warmingUp;

  /// True while an utterance is live in the recognizer (so the provider can
  /// avoid clobbering it when a memory reply arrives mid-speech).
  bool get hasActiveUtterance;

  /// Short human label for the caption engine shown in Settings / inventory.
  String get modelLabel;
}
