import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../constants.dart';

/// Byte-level progress of the Whisper Small bundle download.
class ModelDownloadProgress {
  ModelDownloadProgress({required this.received, required this.total});

  final int received;
  final int total;

  double? get fraction => total > 0 ? received / total : null;
}

/// Single owner of the on-device Whisper Small bundle download.
///
/// Single-flight: concurrent callers await the same in-flight download.
/// Downloads the `.tar.bz2` with range-resume, verifies the BZip2 CRC while
/// extracting into `appSupport/<kWhisperSmallDirName>/`, then fetches the
/// shared-needs Silero VAD model into the same directory.
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

  /// Ensures the Whisper Small bundle is on disk, downloading it if needed.
  /// Single-flight: a concurrent caller awaits the same in-flight download.
  /// Returns the verified `small-tokens.txt` inside the model directory,
  /// or `null` if the bundle could not be obtained.
  static Future<File?> ensure({void Function(String)? onEvent}) {
    final task = _singleton._tasks[kWhisperSmallTarFileName];
    if (task != null) {
      onEvent?.call('downloading models… (already running)');
      return task.done;
    }
    final started = _ActiveTask(onEvent);
    _singleton._tasks[kWhisperSmallTarFileName] = started;
    started.done.whenComplete(() {
      _singleton._tasks.remove(kWhisperSmallTarFileName);
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
      debugPrint('[tanu] model lookup failed: $e');
      return null;
    }

    for (var attempt = 1; attempt <= _maxDownloadAttempts; attempt++) {
      try {
        final file = await _downloadAndExtract();
        if (file != null) {
          ok = true;
          return file;
        }
      } catch (e) {
        debugPrint('[tanu] download attempt $attempt failed: $e');
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

  /// The model directory sherpa_onnx reads from:
  /// `appSupport/<kWhisperSmallDirName>`.
  Future<String?> _modelDir() async {
    try {
      final support = await getApplicationSupportDirectory();
      return '${support.path}/$kWhisperSmallDirName';
    } catch (e) {
      debugPrint('[tanu] model dir unavailable: $e');
      return null;
    }
  }

  Future<File?> _find() async {
    final dir = await _modelDir();
    if (dir == null) return null;
    if (_verified(dir)) return File('$dir/small-tokens.txt');
    // A half-written extraction can't be trusted: drop it so the fresh
    // download lands in a clean directory.
    try {
      final stale = Directory(dir);
      if (stale.existsSync()) await stale.delete(recursive: true);
    } catch (e) {
      debugPrint('[tanu] could not purge stale model dir: $e');
    }
    return null;
  }

  /// True when every expected bundle member is present on disk and non-empty.
  /// The authoritative integrity guard is BZip2's own `verify: true` stream
  /// CRC (any truncated/corrupt archive fails in the decoder before a single
  /// file lands). Existence + non-empty is the stable contract the
  /// recognizer needs (all files must be loadable).
  bool _verified(String dir) {
    for (final f in kWhisperSmallBundleFiles) {
      final file = File('$dir/${f.name}');
      if (!file.existsSync() || file.lengthSync() == 0) return false;
    }
    final vad = File('$dir/$kSileroVadFileName');
    if (!vad.existsSync() || vad.lengthSync() == 0) return false;
    return true;
  }

  Future<File?> _downloadAndExtract() async {
    final dir = await _modelDir();
    if (dir == null) return null;
    final support = Directory(dir).parent;
    final archiveFile = File('${support.path}/$kWhisperSmallTarFileName');
    final part = File('${support.path}/$kWhisperSmallTarFileName.part');
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
    await _ensureVad(dir);
    if (!_verified(dir)) {
      await _cleanupDownload(archiveFile, part, dir);
      throw const FormatException('downloaded bundle failed verification');
    }
    await _retireRetiredBundles(support);
    return File('$dir/small-tokens.txt');
  }

  Future<void> _ensureVad(String dir) async {
    final file = File('$dir/$kSileroVadFileName');
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

  /// Range-resumes into [part] from its existing length, emitting byte-level
  /// progress. Throws so the caller can retry; an interrupted transfer leaves
  /// a valid prefix behind resuming later.
  Future<void> _transfer(File part) async {
    final client = http.Client();
    try {
      final start = part.existsSync() ? part.lengthSync() : 0;
      final request = http.Request('GET', Uri.parse(kWhisperSmallTarUrl));
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

  /// Expands the archive into [dir]. `BZip2Decoder(verify: true)` checks the
  /// stream CRC, so truncated bytes can never silently unpack into broken
  /// model files. Runs inside `Isolate.run`: BZip2/TAR decode of ~100 MB is
  /// CPU-bound work that would stall the UI isolate for seconds otherwise.
  /// Only allowlisted members are written, taken from the archive's own
  /// entries.
  Future<void> _extract(File archiveFile, String dir) {
    return Isolate.run(() => _extractSync(archiveFile.path, dir));
  }

  static Future<void> _extractSync(String archivePath, String dir) async {
    final bytes = await File(archivePath).readAsBytes();
    final tarBytes = Uint8List.fromList(
      BZip2Decoder().decodeBytes(bytes, verify: true),
    );
    final archive = TarDecoder().decodeBytes(tarBytes);
    final out = Directory(dir);
    if (out.existsSync()) await out.delete(recursive: true);
    await out.create(recursive: true);
    final expected = kWhisperSmallBundleFiles.map((f) => f.name).toSet();
    for (final f in archive.files) {
      final name = f.name.split('/').last;
      if (name.isEmpty || !expected.contains(name)) continue;
      final content = f.content as List<int>;
      await File('${out.path}/$name').writeAsBytes(content);
    }
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

  /// Deletes retired bundles (files, directories, stale `.part`s) plus any
  /// leftover per-language `stt-*` directories from the multilingual
  /// experiment.
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
      try {
        final dir = Directory('${support.path}/$name');
        if (dir.existsSync()) {
          await dir.delete(recursive: true);
          debugPrint('[tanu] removed retired bundle dir $name');
        }
      } catch (e) {
        debugPrint('[tanu] could not remove retired bundle dir $name: $e');
      }
      try {
        final part = File('${support.path}/$name.part');
        if (part.existsSync()) {
          await part.delete();
          debugPrint('[tanu] removed retired part $name.part');
        }
      } catch (_) {}
    }
    for (final prefix in kRetiredModelPrefixes) {
      try {
        await for (final e in support.list()) {
          if (e is Directory &&
              e.path.split(Platform.pathSeparator).last.startsWith(prefix)) {
            await e.delete(recursive: true);
            debugPrint('[tanu] removed retired prefixed dir ${e.path}');
          }
        }
      } catch (e) {
        debugPrint('[tanu] could not sweep retired prefix $prefix: $e');
      }
    }
  }
}
