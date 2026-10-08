import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../constants.dart';
import '../services/speakers/speaker_diarizer.dart';
import '../services/speakers/speaker_model_coordinator.dart';
import 'analytics_provider.dart';

enum SpeakerModelPhase { checking, missing, downloading, ready }

/// Live state of the on-device speaker-embedding model
/// (`appSupport/speaker-id/`). Mirrors the STT model provider's shape so
/// the Settings row can share its visual language.
class SpeakerModelState {
  const SpeakerModelState({
    this.phase = SpeakerModelPhase.checking,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.error,
  });

  final SpeakerModelPhase phase;
  final int downloadedBytes;
  final int totalBytes;
  final String? error;

  bool get busy =>
      phase == SpeakerModelPhase.checking ||
      phase == SpeakerModelPhase.downloading;
  int? get percent => totalBytes > 0
      ? (downloadedBytes / totalBytes * 100).round().clamp(0, 100)
      : null;

  /// Short status line for Settings: "Checking…", "Downloading 47%",
  /// "Ready · 25 MB", "Not downloaded".
  String get label {
    switch (phase) {
      case SpeakerModelPhase.checking:
        return 'Checking…';
      case SpeakerModelPhase.downloading:
        final p = percent;
        return p == null ? 'Downloading…' : 'Downloading $p%';
      case SpeakerModelPhase.ready:
        return 'Ready · on-device';
      case SpeakerModelPhase.missing:
        return 'Not downloaded';
    }
  }

  SpeakerModelState copyWith({
    SpeakerModelPhase? phase,
    int? downloadedBytes,
    int? totalBytes,
    String? error,
  }) {
    return SpeakerModelState(
      phase: phase ?? this.phase,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      error: error ?? this.error,
    );
  }
}

final speakerModelProvider =
    NotifierProvider<SpeakerModelNotifier, SpeakerModelState>(
      SpeakerModelNotifier.new,
    );

/// The diarizer itself: stateless, created on demand for session-close work.
final speakerDiarizerProvider = Provider<SpeakerDiarizer>((ref) {
  return SpeakerDiarizer();
});

class SpeakerModelNotifier extends Notifier<SpeakerModelState> {
  @override
  SpeakerModelState build() {
    unawaited(refresh());
    return const SpeakerModelState();
  }

  Future<void> refresh() async {
    state = const SpeakerModelState(phase: SpeakerModelPhase.checking);
    try {
      if (await SpeakerModelCoordinator.isReady()) {
        state = const SpeakerModelState(phase: SpeakerModelPhase.ready);
      } else {
        state = const SpeakerModelState(phase: SpeakerModelPhase.missing);
      }
    } catch (e) {
      state = SpeakerModelState(
        phase: SpeakerModelPhase.missing,
        error: '$e',
      );
    }
  }

  /// Downloads the embedding model (or awaits the in-flight transfer).
  /// Unlike the STT bundle this never auto-starts: diarization degrades
  /// gracefully to text-only turns, so the 25 MB stays opt-in from Settings.
  Future<void> download() async {
    if (state.busy) return;
    state = const SpeakerModelState(phase: SpeakerModelPhase.downloading);
    final startedAt = DateTime.now();
    try {
      final file = await SpeakerModelCoordinator.ensure(
        onProgress: (received, total) {
          state = SpeakerModelState(
            phase: SpeakerModelPhase.downloading,
            downloadedBytes: received,
            totalBytes: total ?? 0,
          );
        },
        onEvent: (_) {},
      );
      if (file != null) {
        var bytes = 0;
        try {
          bytes = await file.length();
        } catch (e) {
          debugPrint('[tanu] could not stat speaker model: $e');
        }
        ref.read(analyticsProvider).capture(
          'speaker model downloaded',
          properties: {
            'bytes': bytes,
            'duration_s': DateTime.now().difference(startedAt).inSeconds,
          },
        );
        await refresh();
      } else {
        state = const SpeakerModelState(
          phase: SpeakerModelPhase.missing,
          error: 'Speaker model download failed.',
        );
        ref.read(analyticsProvider).capture(
          'speaker model failed',
          properties: {
            'reason': 'exhausted_retries',
            'duration_s': DateTime.now().difference(startedAt).inSeconds,
          },
        );
      }
    } catch (e) {
      state = SpeakerModelState(
        phase: SpeakerModelPhase.missing,
        error: 'Download failed: $e',
      );
      ref.read(analyticsProvider).capture(
        'speaker model failed',
        properties: {
          // The error class only — the message can embed a filesystem path.
          'reason': e.runtimeType.toString(),
          'duration_s': DateTime.now().difference(startedAt).inSeconds,
        },
      );
      debugPrint('[tanu] speaker model download failed: $e');
    }
  }

  Future<void> deleteModel() async {
    if (state.busy) return;
    try {
      final root = (await getApplicationSupportDirectory()).path;
      final dir = Directory('$root/$kSpeakerModelDirName');
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('[tanu] speaker model delete failed: $e');
    }
    await refresh();
  }
}
