import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../constants.dart';
import '../services/stt/model_download_coordinator.dart';
import 'analytics_provider.dart';

enum SttModelPhase { checking, missing, downloading, ready }

/// Live state of the on-device Moonshine bundle stored in app-support storage.
class SttModelState {
  const SttModelState({
    this.phase = SttModelPhase.checking,
    this.modelName = '',
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.error,
  });

  final SttModelPhase phase;
  final String modelName;
  final int downloadedBytes;
  final int totalBytes;
  final String? error;

  bool get busy =>
      phase == SttModelPhase.checking || phase == SttModelPhase.downloading;
  int? get percent => totalBytes > 0
      ? (downloadedBytes / totalBytes * 100).round().clamp(0, 100)
      : null;

  /// Short status line for the Home chip: "Loading model…" / "Downloading 47%".
  String get label {
    final base = phase == SttModelPhase.downloading
        ? 'Downloading model'
        : 'Loading model';
    final p = percent;
    return p == null ? '$base…' : '$base $p%';
  }

  SttModelState copyWith({
    SttModelPhase? phase,
    String? modelName,
    int? downloadedBytes,
    int? totalBytes,
    String? error,
  }) {
    return SttModelState(
      phase: phase ?? this.phase,
      modelName: modelName ?? this.modelName,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      error: error ?? this.error,
    );
  }
}

final sttModelProvider = NotifierProvider<SttModelNotifier, SttModelState>(
  SttModelNotifier.new,
);

int get _bundleBytes => kOfflineBundleFiles.fold(0, (sum, f) => sum + f.bytes);

class SttModelNotifier extends Notifier<SttModelState> {
  StreamSubscription<Object?>? _progressSub;

  @override
  SttModelState build() {
    unawaited(refresh());
    return SttModelState(modelName: kOfflineBundleFileName);
  }

  Future<void> refresh() async {
    state = const SttModelState(
      phase: SttModelPhase.checking,
    ).copyWith(modelName: kOfflineBundleFileName);
    try {
      final dir = await _modelDirectory();
      if (dir != null && _bundleExists(dir)) {
        state = SttModelState(
          phase: SttModelPhase.ready,
          modelName: kOfflineBundleFileName,
          downloadedBytes: await _bundleSize(dir),
          totalBytes: _bundleBytes,
        );
      } else {
        state = const SttModelState(
          phase: SttModelPhase.missing,
        ).copyWith(modelName: kOfflineBundleFileName);
      }
    } catch (e) {
      state = SttModelState(
        phase: SttModelPhase.missing,
        modelName: kOfflineBundleFileName,
        error: '$e',
      );
    }
  }

  Future<void> download() async {
    if (state.busy) return;
    state = const SttModelState(
      phase: SttModelPhase.downloading,
      modelName: '',
    ).copyWith(modelName: kOfflineBundleFileName);

    // The coordinator is single-flight: if the engine's warm-up is already
    // downloading, [ensure] awaits that same transfer and the progress stream
    // below still tracks it live, so no second writer ever touches the bundle.
    await _progressSub?.cancel();
    _progressSub = null;
    _progressSub = ModelDownloadCoordinator.progress.listen((p) {
      state = SttModelState(
        phase: SttModelPhase.downloading,
        modelName: kOfflineBundleFileName,
        downloadedBytes: p.received,
        totalBytes: p.total > 0 ? p.total : _bundleBytes,
      );
    });
    final startedAt = DateTime.now();
    try {
      final file = await ModelDownloadCoordinator.ensure(onEvent: (_) {});
      await _progressSub?.cancel();
      _progressSub = null;
      if (file != null) {
        var bytes = 0;
        try {
          bytes = await file.length();
        } catch (e) {
          debugPrint('[tanu] could not stat downloaded bundle: $e');
        }
        ref
            .read(analyticsProvider)
            .capture(
              'stt model downloaded',
              properties: {
                'bytes': bytes,
                'duration_s': DateTime.now().difference(startedAt).inSeconds,
              },
            );
        await refresh();
      } else {
        state = SttModelState(
          phase: SttModelPhase.missing,
          modelName: kOfflineBundleFileName,
          error: 'Model download failed.',
        );
        ref
            .read(analyticsProvider)
            .capture(
              'stt model failed',
              properties: {
                'reason': 'exhausted_retries',
                'duration_s': DateTime.now().difference(startedAt).inSeconds,
              },
            );
      }
    } catch (e) {
      await _progressSub?.cancel();
      _progressSub = null;
      state = SttModelState(
        phase: SttModelPhase.missing,
        modelName: kOfflineBundleFileName,
        error: 'Download failed: $e',
      );
      ref
          .read(analyticsProvider)
          .capture(
            'stt model failed',
            properties: {
              // The error class only — the message can embed a filesystem path.
              'reason': e.runtimeType.toString(),
              'duration_s': DateTime.now().difference(startedAt).inSeconds,
            },
          );
      debugPrint('[tanu] moonshine download failed: $e');
    }
  }

  Future<void> deleteModel() async {
    if (state.busy) return;
    var deleted = false;
    try {
      final root = (await getApplicationSupportDirectory()).path;
      final stem = kOfflineBundleFileName.replaceFirst('.tar.bz2', '');
      final modelDir = Directory('$root/$stem');
      if (await modelDir.exists()) {
        await modelDir.delete(recursive: true);
        deleted = true;
      }
      final bundle = File('$root/$kOfflineBundleFileName');
      if (await bundle.exists()) {
        await bundle.delete();
        deleted = true;
      }
      for (final name in kRetiredModelBundles) {
        final path = '$root/$name';
        if (await File(path).exists()) await File(path).delete();
        final dir = Directory(path);
        if (await dir.exists()) await dir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('[tanu] model delete failed: $e');
    }
    if (deleted) {
      ref.read(analyticsProvider).capture('stt model deleted');
    }
    await refresh();
  }

  Future<bool> hasRetiredModels() async {
    try {
      final root = (await getApplicationSupportDirectory()).path;
      for (final name in kRetiredModelBundles) {
        final path = '$root/$name';
        if (await File(path).exists() || await Directory(path).exists()) {
          return true;
        }
      }
    } catch (e) {
      debugPrint('[tanu] retired model check failed: $e');
    }
    return false;
  }

  /// Mirrors the Moonshine engine's default model directory:
  /// `appSupport/<bundle-stem>`.
  Future<String?> _modelDirectory() async {
    final stem = kOfflineBundleFileName.replaceFirst('.tar.bz2', '');
    try {
      final support = await getApplicationSupportDirectory();
      return '${support.path}/$stem';
    } catch (e) {
      debugPrint('[tanu] model dir unavailable: $e');
      return null;
    }
  }

  bool _bundleExists(String dir) =>
      kOfflineBundleFiles.every((f) => File('$dir/${f.name}').existsSync());

  Future<int> _bundleSize(String dir) async {
    var total = 0;
    for (final f in kOfflineBundleFiles) {
      total += await File('$dir/${f.name}').length();
    }
    return total;
  }
}
