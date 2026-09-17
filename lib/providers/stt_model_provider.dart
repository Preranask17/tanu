import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../constants.dart';
import '../services/stt/model_download_coordinator.dart';

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
    final base =
        phase == SttModelPhase.downloading ? 'Downloading model' : 'Loading model';
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

final sttModelProvider =
    NotifierProvider<SttModelNotifier, SttModelState>(SttModelNotifier.new);

int get _bundleBytes =>
    kMoonshineBundleFiles.fold(0, (sum, f) => sum + f.bytes);

class SttModelNotifier extends Notifier<SttModelState> {
  StreamSubscription<Object?>? _progressSub;

  @override
  SttModelState build() {
    unawaited(refresh());
    return SttModelState(modelName: kMoonshineBundleFileName);
  }

  Future<void> refresh() async {
    state = const SttModelState(phase: SttModelPhase.checking)
        .copyWith(modelName: kMoonshineBundleFileName);
    try {
      final dir = await _modelDirectory();
      if (dir != null && _bundleExists(dir)) {
        state = SttModelState(
          phase: SttModelPhase.ready,
          modelName: kMoonshineBundleFileName,
          downloadedBytes: await _bundleSize(dir),
          totalBytes: _bundleBytes,
        );
      } else {
        state = const SttModelState(phase: SttModelPhase.missing)
            .copyWith(modelName: kMoonshineBundleFileName);
      }
    } catch (e) {
      state = SttModelState(
        phase: SttModelPhase.missing,
        modelName: kMoonshineBundleFileName,
        error: '$e',
      );
    }
  }

  Future<void> download() async {
    if (state.busy) return;
    state = const SttModelState(
      phase: SttModelPhase.downloading,
      modelName: '',
    ).copyWith(modelName: kMoonshineBundleFileName);

    // The coordinator is single-flight: if the engine's warm-up is already
    // downloading, [ensure] awaits that same transfer and the progress stream
    // below still tracks it live, so no second writer ever touches the bundle.
    await _progressSub?.cancel();
    _progressSub = null;
    _progressSub = ModelDownloadCoordinator.progress.listen((p) {
      state = SttModelState(
        phase: SttModelPhase.downloading,
        modelName: kMoonshineBundleFileName,
        downloadedBytes: p.received,
        totalBytes: p.total > 0 ? p.total : _bundleBytes,
      );
    });
    try {
      final file = await ModelDownloadCoordinator.ensure(onEvent: (_) {});
      await _progressSub?.cancel();
      _progressSub = null;
      if (file != null) {
        await refresh();
      } else {
        state = SttModelState(
          phase: SttModelPhase.missing,
          modelName: kMoonshineBundleFileName,
          error: 'Model download failed.',
        );
      }
    } catch (e) {
      await _progressSub?.cancel();
      _progressSub = null;
      state = SttModelState(
        phase: SttModelPhase.missing,
        modelName: kMoonshineBundleFileName,
        error: 'Download failed: $e',
      );
      debugPrint('[tanu] moonshine download failed: $e');
    }
  }

  Future<void> deleteModel() async {
    if (state.busy) return;
    try {
      final root = (await getApplicationSupportDirectory()).path;
      final stem = kMoonshineBundleFileName.replaceFirst('.tar.bz2', '');
      final modelDir = Directory('$root/$stem');
      if (await modelDir.exists()) await modelDir.delete(recursive: true);
      final bundle = File('$root/$kMoonshineBundleFileName');
      if (await bundle.exists()) await bundle.delete();
      for (final name in kRetiredModelBundles) {
        final path = '$root/$name';
        if (await File(path).exists()) await File(path).delete();
        final dir = Directory(path);
        if (await dir.exists()) await dir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('[tanu] model delete failed: $e');
    }
    await refresh();
  }

  /// Mirrors the Moonshine engine's default model directory:
  /// `appSupport/<bundle-stem>`.
  Future<String?> _modelDirectory() async {
    final stem = kMoonshineBundleFileName.replaceFirst('.tar.bz2', '');
    try {
      final support = await getApplicationSupportDirectory();
      return '${support.path}/$stem';
    } catch (e) {
      debugPrint('[tanu] model dir unavailable: $e');
      return null;
    }
  }

  bool _bundleExists(String dir) =>
      kMoonshineBundleFiles.every((f) => File('$dir/${f.name}').existsSync());

  Future<int> _bundleSize(String dir) async {
    var total = 0;
    for (final f in kMoonshineBundleFiles) {
      total += await File('$dir/${f.name}').length();
    }
    return total;
  }
}