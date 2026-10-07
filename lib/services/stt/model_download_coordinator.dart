import 'dart:async';
import 'dart:io';

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
/// The three int8 files (and the VAD model) stream concurrently and
/// directly into `appSupport/<kWhisperSmallDirName>/` — with range-resume
/// across launches — then the bundle is verified file-by-file.
///
/// There is deliberately no archive step: the GitHub `.tar.bz2` is 610 MB
/// and unpacks to ~1.3 GB, so decoding it in-process exceeded the Android
/// app heap and the phones sat there forever. Streaming keeps memory flat
/// at a few socket buffers and moves the exact 375 MB the model needs.
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
    final task = _singleton._tasks[kWhisperSmallDirName];
    if (task != null) {
      onEvent?.call('downloading models… (already running)');
      return task.done;
    }
    final started = _ActiveTask(onEvent);
    _singleton._tasks[kWhisperSmallDirName] = started;
    started.done.whenComplete(() {
      _singleton._tasks.remove(kWhisperSmallDirName);
      _completions.add(started.ok);
    });
    started.done.ignore();
    return started.done;
  }
}

const int _maxDownloadAttempts = 3;

/// Progress is only pushed to the UI every half-megabyte so a 375 MB
/// transfer does not schedule thousands of no-op rebuilds.
const int _progressGranularity = 512 * 1024;

final class _ActiveTask {
  _ActiveTask(this.onEvent);

  final void Function(String)? onEvent;

  late final Future<File?> done = _run();
  bool ok = false;

  int _lastEmitted = 0;

  /// Shared byte counter across every concurrent stream; only mutated on
  /// this isolate's event loop, then emitted as one progress number.
  int _received = 0;
  int _total = 0;

  Future<File?> _run() async {
    try {
      final found = await _find();
      if (found != null) {
        ok = true;
        return found;
      }
    } catch (e) {
      final msg = 'model download failed: $e';
      onEvent?.call(msg);
      debugPrint('[tanu] model lookup failed: $e');
      return null;
    }

    for (var attempt = 1; attempt <= _maxDownloadAttempts; attempt++) {
      try {
        final file = await _downloadFiles();
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
    await _purgeLegacyArchive(Directory(dir).parent);

    if (!_modelFilesPresent(dir)) {
      // A half-written extraction from an older build can't be trusted:
      // drop it so the fresh download lands in a clean directory. Partial
      // `.part` files live outside the model dir and survive this purge.
      try {
        final stale = Directory(dir);
        if (stale.existsSync()) await stale.delete(recursive: true);
      } catch (e) {
        debugPrint('[tanu] could not purge stale model dir: $e');
      }
      return null;
    }

    // The weights are good; only the VAD may be missing from an earlier
    // partial run. Fetch it without forcing a 375 MB re-download.
    try {
      await _ensureVad(dir);
    } catch (e) {
      debugPrint('[tanu] vad fetch after find failed: $e');
    }
    if (_verified(dir)) return File('$dir/small-tokens.txt');
    return null;
  }

  bool _sizeOk(int actual, int expected) =>
      expected > 0 ? actual >= expected : actual > 0;

  /// True when every weight file is present at (at least) its expected
  /// size. Anything smaller is a truncated leftover and gets purged.
  bool _modelFilesPresent(String dir) {
    for (final f in kWhisperSmallBundleFiles) {
      final file = File('$dir/${f.name}');
      if (!file.existsSync() || !_sizeOk(file.lengthSync(), f.bytes)) {
        return false;
      }
    }
    return true;
  }

  /// True when every expected bundle member is present on disk and the
  /// right size, including the VAD model. Files only ever reach their final
  /// name after a byte-exact transfer (or after a known-good extraction),
  /// so "present + sized" is the stable contract the recognizer needs.
  bool _verified(String dir) {
    if (!_modelFilesPresent(dir)) return false;
    final vad = File('$dir/$kSileroVadFileName');
    if (!vad.existsSync() || vad.lengthSync() == 0) return false;
    return true;
  }

  String _fileUrl(String name) => '$kWhisperSmallFilesBaseUrl/$name';

  Future<File?> _downloadFiles() async {
    final dir = await _modelDir();
    if (dir == null) return null;
    final support = Directory(dir).parent;
    await support.create(recursive: true);
    await _purgeLegacyArchive(support);
    final out = Directory(dir);
    if (!out.existsSync()) await out.create(recursive: true);

    // Seed progress from whatever is already on disk (finished files and
    // resumable prefixes) so the bar starts where the last session left off.
    _total = kWhisperSmallBundleFiles.fold<int>(
      0,
      (sum, f) => sum + f.bytes,
    );
    _received = 0;
    _lastEmitted = 0;
    for (final f in kWhisperSmallBundleFiles) {
      _received += _settledBytes(dir, support, f);
    }
    _emit(force: true);

    // The three weight files and the VAD model transfer concurrently, so
    // wall time tracks the largest file (the 262 MB decoder) instead of
    // the 375 MB sum. Errors are collected first and rethrown after every
    // stream settles — finished files stay on disk and the retry loop
    // resumes only the survivors.
    Object? firstError;
    StackTrace? firstStack;
    Future<void> guard(Future<void> Function() run) async {
      try {
        await run();
      } catch (e, s) {
        firstError ??= e;
        firstStack ??= s;
      }
    }

    await Future.wait([
      for (final f in kWhisperSmallBundleFiles)
        guard(() => _downloadOne(f, dir, support)),
      guard(() => _ensureVad(dir)),
    ]);
    final error = firstError;
    if (error != null) Error.throwWithStackTrace(error, firstStack!);

    if (!_verified(dir)) {
      await _cleanupModelDir(dir);
      throw const FormatException('downloaded bundle failed verification');
    }
    await _retireRetiredBundles(support);
    return File('$dir/small-tokens.txt');
  }

  /// Skips files that are already complete, clears truncated ones, then
  /// streams whatever is missing. Every file lands via [_transfer].
  Future<void> _downloadOne(
    ({String name, int bytes}) f,
    String dir,
    Directory support,
  ) async {
    final dest = File('$dir/${f.name}');
    if (dest.existsSync() && _sizeOk(dest.lengthSync(), f.bytes)) return;
    if (dest.existsSync()) {
      try {
        await dest.delete();
      } catch (_) {}
    }

    onEvent?.call('downloading ${f.name}…');
    final part = File('${support.path}/${f.name}.part');
    await _transfer(_fileUrl(f.name), dest, part, expected: f.bytes);
  }

  /// Bytes already counted as progress for one bundle member: a finished
  /// file in full, otherwise its resumable `.part` prefix (clamped).
  int _settledBytes(
    String dir,
    Directory support,
    ({String name, int bytes}) f,
  ) {
    final dest = File('$dir/${f.name}');
    if (dest.existsSync()) {
      final len = dest.lengthSync();
      if (_sizeOk(len, f.bytes)) return len;
    }
    final part = File('${support.path}/${f.name}.part');
    if (part.existsSync()) {
      final len = part.lengthSync();
      return len < f.bytes ? len : f.bytes;
    }
    return 0;
  }

  /// Streams one model file into [dest] with range-resume, folding each
  /// chunk into the shared byte counter. An interrupted transfer leaves a
  /// valid prefix in [part] (kept outside the model dir so purges never
  /// touch it) that the next attempt resumes from. Throws if the transfer
  /// stops short, so the retry loop never installs a truncated model.
  Future<void> _transfer(
    String url,
    File dest,
    File part, {
    required int expected,
  }) async {
    var start = part.existsSync() ? part.lengthSync() : 0;
    if (start > expected) {
      // Stale/overshot partial (e.g. a different mirror): start over.
      await part.delete();
      start = 0;
    } else if (start == expected) {
      // A previous attempt finished the bytes but died before the rename.
      await part.rename(dest.path);
      _emit(force: true);
      return;
    }

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      if (start > 0) {
        request.headers[HttpHeaders.rangeHeader] = 'bytes=$start-';
      }
      final response = await client.send(request);

      final bool append;
      if (response.statusCode == 206) {
        append = true;
      } else if (response.statusCode == 200) {
        // The server dropped the range request: restart this file in
        // place instead of discarding the transfer.
        append = false;
        start = 0;
      } else if (response.statusCode == 416) {
        await part.delete();
        throw HttpException('resume range rejected for $url');
      } else {
        throw HttpException('unexpected status ${response.statusCode} for $url');
      }

      final remaining = response.contentLength;
      final sink = part.openWrite(
        mode: append ? FileMode.append : FileMode.write,
      );
      var received = start;
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          _received += chunk.length;
          _emit();
        }
        await sink.flush();
      } finally {
        try {
          await sink.close();
        } catch (_) {}
      }

      if (remaining != null) {
        final fileTotal = append ? start + remaining : remaining;
        if (received != fileTotal) {
          throw FormatException('incomplete download: $received of $fileTotal');
        }
      }
      if (received == 0) throw FormatException('empty download: $url');

      await part.rename(dest.path);
      _emit(force: true);
    } finally {
      client.close();
    }
  }

  void _emit({bool force = false}) {
    if (!force &&
        _received < _total &&
        _received - _lastEmitted < _progressGranularity) {
      return;
    }
    _lastEmitted = _received;
    ModelDownloadCoordinator._events.add(
      ModelDownloadProgress(received: _received, total: _total),
    );
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

  /// Removes the 610 MB GitHub archive (and its `.part`) left behind by
  /// builds that tried to download-and-extract the bundle.
  Future<void> _purgeLegacyArchive(Directory support) async {
    for (final name in [
      kWhisperSmallTarFileName,
      '$kWhisperSmallTarFileName.part',
    ]) {
      try {
        final file = File('${support.path}/$name');
        if (file.existsSync()) {
          await file.delete();
          debugPrint('[tanu] removed legacy archive $name');
        }
      } catch (e) {
        debugPrint('[tanu] could not remove legacy archive $name: $e');
      }
    }
  }

  /// Drops a bad model directory but keeps the resumable `.part` files in
  /// app support, so a failed verification never throws away 375 MB.
  Future<void> _cleanupModelDir(String dir) async {
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
