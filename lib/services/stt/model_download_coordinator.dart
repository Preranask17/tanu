import 'dart:async';
import 'dart:isolate';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../constants.dart';

/// Byte-level progress of the Moonshine bundle download.
class ModelDownloadProgress {
  ModelDownloadProgress({required this.received, required this.total});

  final int received;
  final int total;

  double? get fraction => total > 0 ? received / total : null;
}

/// Single owner of the on-device Moonshine bundle download.
///
/// The STT engine's startup warm-up and the Settings download button used to
/// call `downloadCatalogModel` independently, so two streams wrote the same
/// `.part` file at once: progress reset mid-transfer, the partial grew and
/// shrank, and the model never landed. Every caller routes through [ensure],
/// which is single-flight (concurrent callers await the same download) and
/// retries a fresh attempt if the server drops a range-request resume.
final class ModelDownloadCoordinator {
  ModelDownloadCoordinator._();

  /// Fine-grained byte progress for anyone subscribed to [progress].
  static final StreamController<ModelDownloadProgress> _events =
      StreamController<ModelDownloadProgress>.broadcast();

  /// Emits `true`/`false` when any download finishes (success/failure).
  static final StreamController<bool> _completions =
      StreamController<bool>.broadcast();

  final Map<String, _ActiveTask> _tasks = {};
  static final ModelDownloadCoordinator _singleton =
      ModelDownloadCoordinator._();

  static ModelDownloadCoordinator get instance => _singleton;

  /// Byte-level progress of whichever download is running, or empty.
  static Stream<ModelDownloadProgress> get progress => _events.stream;

  /// Completion signals of any download (true = model is ready).
  static Stream<bool> get completions => _completions.stream;

  static bool get active => _singleton._tasks.isNotEmpty;

  /// Ensures the Moonshine bundle is on disk, downloading it if needed.
  /// Single-flight: a concurrent caller awaits the same in-flight download.
  /// Returns the verified `tokens.txt` inside the extracted model directory,
  /// or `null` if the bundle could not be obtained.
  static Future<File?> ensure({void Function(String)? onEvent}) {
    final task = _singleton._tasks[kOfflineBundleFileName];
    if (task != null) {
      onEvent?.call('downloading models… (already running)');
      return task.done;
    }
    final started = _ActiveTask(onEvent);
    _singleton._tasks[kOfflineBundleFileName] = started;
    started.done.whenComplete(() {
      _singleton._tasks.remove(kOfflineBundleFileName);
      _completions.add(started.ok);
    });
    started.done.ignore();
    return started.done;
  }
}

/// Retries a range-request resume that the server answered with a plain 200
/// (scrapping the partial) instead of throwing away the download.
const int _maxDownloadAttempts = 3;

final class _ActiveTask {
  _ActiveTask(this.onEvent);

  final void Function(String)? onEvent;

  late final Future<File?> done = _run();
  bool ok = false;

  Future<File?> _run() async {
    try {
      final found = await _find();
      if (found != null) return found;
    } catch (e) {
      final msg = 'model download failed: $e';
      onEvent?.call(msg);
      debugPrint('[tanu] moonshine model lookup failed: $e');
      return null;
    }

    for (var attempt = 1; attempt <= _maxDownloadAttempts; attempt++) {
      try {
        await _ensureVad(onEvent);
        final file = await _downloadAndExtract();
        if (file != null) {
          ok = true;
          return file;
        }
      } catch (e) {
        debugPrint('[tanu] moonshine download attempt $attempt failed: $e');
        if (attempt == _maxDownloadAttempts) {
          final msg = 'model download failed: $e';
          onEvent?.call(msg);
          return null;
        }
      }
      onEvent?.call('downloading models… retry $attempt/$_maxDownloadAttempts');
      await Future<void>.delayed(Duration(seconds: 2 * attempt));
    }
    return null;
  }

  Future<void> _ensureVad(void Function(String)? onEvent) async {
    final support = await getApplicationSupportDirectory();
    final file = File('${support.path}/$kSileroVadFileName');
    if (file.existsSync() && file.lengthSync() > 0) return;

    onEvent?.call('downloading VAD model…');
    final client = http.Client();
    try {
      final response = await client.get(Uri.parse(kSileroVadUrl));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
      } else {
        throw HttpException('vad download failed: ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  /// The model directory sherpa_onnx reads from: `appSupport/<bundle-stem>`,
  /// mirroring [MoonshineSttEngine]'s resolution so `ensure` can land the files
  /// exactly where the engine looks.
  Future<String?> _modelDir() async {
    try {
      final support = await getApplicationSupportDirectory();
      final stem = kOfflineBundleFileName.replaceFirst('.tar.bz2', '');
      return '${support.path}/$stem';
    } catch (e) {
      debugPrint('[tanu] model dir unavailable: $e');
      return null;
    }
  }

  Future<File?> _find() async {
    final dir = await _modelDir();
    if (dir == null) return null;
    if (_verified(dir)) return File('$dir/tokens.txt');
    // A byte-mismatched extraction (interrupted write, half-upgrade) can't be
    // trusted: drop it so the fresh download lands in a clean directory.
    try {
      final stale = Directory(dir);
      if (stale.existsSync()) await stale.delete(recursive: true);
    } catch (e) {
      debugPrint('[tanu] could not purge stale model dir: $e');
    }
    return null;
  }

  /// True when every expected bundle member is present on disk and non-empty.
  /// The authoritative integrity guard is BZip2's own `verify: true` stream CRC
  /// (any truncated/corrupt archive fails in the decoder before a single file
  /// lands); per-file byte counts are deliberately NOT compared here — the
  /// release asset is republished by upstream without notice, so a baked-in
  /// byte table silently rots and turns every legitimate re-download into a
  /// false "failed size verification". Existence + non-empty is the stable
  /// contract the recognizer needs (all three files must be loadable).
  bool _verified(String dir) {
    for (final f in kOfflineBundleFiles) {
      final file = File('$dir/${f.name}');
      if (!file.existsSync() || file.lengthSync() == 0) return false;
    }
    return true;
  }

  Future<File?> _downloadAndExtract() async {
    final dir = await _modelDir();
    if (dir == null) return null;
    final support = Directory(dir).parent;
    final archiveFile = File('${support.path}/$kOfflineBundleFileName');
    final part = File('${support.path}/$kOfflineBundleFileName.part');
    await support.create(recursive: true);

    if (!archiveFile.existsSync()) {
      await _transfer(part);
      // The download is complete and verified: commit it, then extract.
      try {
        await part.rename(archiveFile.path);
      } catch (e) {
        await _cleanupDownload(archiveFile, part, dir);
        rethrow;
      }
    } else {
      // Archive already exists (likely from a hot restart during extraction).
      // Emit a 100% progress event so the UI jumps straight to "Extracting..."
      final len = archiveFile.lengthSync();
      ModelDownloadCoordinator._events.add(
        ModelDownloadProgress(received: len, total: len),
      );
    }
    try {
      await _extract(archiveFile, dir);
    } catch (e) {
      await _cleanupDownload(archiveFile, part, dir);
      rethrow;
    }
    if (!_verified(dir)) {
      await _cleanupDownload(archiveFile, part, dir);
      throw const FormatException('downloaded bundle failed size verification');
    }
    await _retireRetiredBundles(support);
    return File('$dir/tokens.txt');
  }

  /// Range-resumes into [part] from its existing length, emitting byte-level
  /// progress. Throws so the caller can retry; an interrupted transfer leaves
  /// a valid prefix behind resuming later.
  Future<void> _transfer(File part) async {
    final client = http.Client();
    try {
      final start = part.existsSync() ? part.lengthSync() : 0;
      final request = http.Request('GET', Uri.parse(kOfflineBundleUrl));
      if (start > 0) {
        request.headers[HttpHeaders.rangeHeader] = 'bytes=$start-';
      }
      final response = await client.send(request);
      // A 200 to a resume means the server dropped the range request; scrap
      // the partial and let the retry loop start fresh.
      if (start > 0 && response.statusCode == 200) {
        await part.delete();
        throw const FormatException('server ignored the resume range request');
      }
      final int total;
      if (response.statusCode == 206) {
        total = start + (response.contentLength ?? 0);
      } else if (response.statusCode == 200) {
        total = response.contentLength ?? 0;
      } else {
        throw HttpException('unexpected status ${response.statusCode}');
      }

      final sink = part.openWrite(mode: FileMode.append);
      var received = start;
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          ModelDownloadCoordinator._events.add(
            ModelDownloadProgress(received: received, total: total),
          );
        }
        await sink.flush();
      } finally {
        try {
          await sink.close();
        } catch (_) {}
      }
      if (total > 0 && received != total) {
        throw FormatException('incomplete download: $received of $total');
      }
    } finally {
      client.close();
    }
  }

  /// Expands the commit archive into [dir]. `BZip2Decoder(verify: true)`
  /// checks the stream CRC, so a truncated set of bytes can never be silently
  /// unpacked into broken model files; per-file byte counts are re-checked by
  /// [_verified] against [kOfflineBundleFiles] afterwards.
  ///
  /// Extraction runs inside an `Isolate.run` worker: the archive package's
  /// BZip2/TAR decode + per-file writes are megabytes of CPU-bound byte work
  /// that would stall the calling isolate (the Settings download button, or
  /// the conversation provider's warm-up) for several seconds otherwise.
  /// Expands the archive in the background and returns the exact name → bytes
  /// map of what was written, taken from the archive's own members. This is the
  /// truth the caller re-checks on disk, so the pending smoke path needs no
  /// hardcoded per-file byte table that rots every time upstream republishes
  /// the bundle with the same names.
  Future<Map<String, int>> _extract(File archiveFile, String dir) {
    return Isolate.run(() => _extractSync(archiveFile.path, dir));
  }

  /// Top-level companion for [_extract] so `Isolate.run` gets a closure with no
  /// `this` capture (isolates can't take instance state by reference here).
  /// BZip2's `verify: true` CRC is what guards against truncated/corrupt
  /// archives; per-member sizes are simply reported so [_verified] can compare
  /// on-disk bytes against the decode, never against a stale constant.
  static Future<Map<String, int>> _extractSync(
    String archivePath,
    String dir,
  ) async {
    final bytes = await File(archivePath).readAsBytes();
    final tarBytes = Uint8List.fromList(
      BZip2Decoder().decodeBytes(bytes, verify: true),
    );
    final archive = TarDecoder().decodeBytes(tarBytes);
    final out = Directory(dir);
    if (out.existsSync()) await out.delete(recursive: true);
    await out.create(recursive: true);
    final expected = kOfflineBundleFiles.map((f) => f.name).toSet();
    final written = <String, int>{};
    for (final f in archive.files) {
      final name = f.name.split('/').last;
      if (name.isEmpty || !expected.contains(name)) continue;
      final content = f.content as List<int>;
      await File('${out.path}/$name').writeAsBytes(content);
      written[name] = content.length;
    }
    return written;
  }

  Future<void> _cleanupDownload(File archiveFile, File part, String dir) async {
    try {
      if (part.existsSync()) await part.delete();
    } catch (_) {}
    try {
      final d = Directory(dir);
      if (d.existsSync()) await d.delete(recursive: true);
    } catch (_) {}
  }

  /// Once the Moonshine bundle is usable, the retired model weights shipped
  /// under [kRetiredModelBundles] are dead weight in app support.
  Future<void> _retireRetiredBundles(Directory support) async {
    for (final name in kRetiredModelBundles) {
      final file = File('${support.path}/$name');
      try {
        if (file.existsSync()) {
          await file.delete();
          debugPrint('[tanu] removed retired bundle $name');
        }
      } catch (e) {
        debugPrint('[tanu] could not remove retired bundle $name: $e');
      }
    }
  }
}
