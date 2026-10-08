import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../constants.dart';

/// Single owner of the on-device speaker-embedding model download.
///
/// One 25 MB `.onnx` streamed straight to disk into
/// `appSupport/<kSpeakerModelDirName>/` with range-resume across launches —
/// deliberately separate from [ModelDownloadCoordinator] (which is
/// Whisper-bundle-shaped) but following the same transfer contract: partial
/// bytes live in a `.part` file outside the model dir, and a file only
/// reaches its final name after a complete transfer.
final class SpeakerModelCoordinator {
  SpeakerModelCoordinator._();

  static const String _taskKey = kSpeakerModelDirName;

  static final Map<String, _SpeakerDownloadTask> _tasks = {};
  static SpeakerModelCoordinator get instance => SpeakerModelCoordinator._();

  /// Model directory: `appSupport/<kSpeakerModelDirName>`.
  static Future<String?> modelDir() async {
    try {
      final support = await getApplicationSupportDirectory();
      return '${support.path}/$kSpeakerModelDirName';
    } catch (e) {
      debugPrint('[tanu] speaker model dir unavailable: $e');
      return null;
    }
  }

  static String get fileName => kSpeakerEmbeddingFileName;

  /// True when the embedding model is on disk and plausibly complete.
  /// [minBytes] guards against error pages saved as model files.
  static Future<bool> isReady({int minBytes = 1024 * 1024}) async {
    try {
      final dir = await modelDir();
      if (dir == null) return false;
      final file = File('$dir/$fileName');
      return file.existsSync() && file.lengthSync() > minBytes;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> modelPath() async {
    if (!await isReady()) return null;
    final dir = await modelDir();
    return dir == null ? null : '$dir/$fileName';
  }

  /// Ensures the model is on disk, downloading it if needed. Single-flight:
  /// concurrent callers await the same transfer. Returns the model file, or
  /// null when it could not be obtained.
  static Future<File?> ensure({
    void Function(int received, int? total)? onProgress,
    void Function(String)? onEvent,
  }) {
    final running = _tasks[_taskKey];
    if (running != null) {
      onEvent?.call('downloading speaker model… (already running)');
      return running.done;
    }
    final task = _SpeakerDownloadTask(onProgress, onEvent);
    _tasks[_taskKey] = task;
    task.done.whenComplete(() => _tasks.remove(_taskKey));
    task.done.ignore();
    return task.done;
  }

  static bool get active => _tasks.isNotEmpty;
}

const int _speakerMaxAttempts = 3;

final class _SpeakerDownloadTask {
  _SpeakerDownloadTask(this.onProgress, this.onEvent);

  final void Function(int received, int? total)? onProgress;
  final void Function(String)? onEvent;

  late final Future<File?> done = _run();

  Future<File?> _run() async {
    try {
      final dir = await SpeakerModelCoordinator.modelDir();
      if (dir == null) return null;
      final dest = File('$dir/$kSpeakerEmbeddingFileName');
      if (dest.existsSync() && dest.lengthSync() > 1024 * 1024) return dest;

      for (var attempt = 1; attempt <= _speakerMaxAttempts; attempt++) {
        try {
          final file = await _transfer(dir);
          if (file != null) return file;
        } catch (e) {
          debugPrint('[tanu] speaker model attempt $attempt failed: $e');
          if (attempt == _speakerMaxAttempts) {
            onEvent?.call('speaker model download failed: $e');
            return null;
          }
        }
        onEvent?.call(
          'downloading speaker model… retry $attempt/$_speakerMaxAttempts',
        );
        await Future<void>.delayed(Duration(seconds: 2 * attempt));
      }
      return null;
    } catch (e) {
      debugPrint('[tanu] speaker model download failed: $e');
      return null;
    }
  }

  Future<File?> _transfer(String dir) async {
    final dest = File('$dir/$kSpeakerEmbeddingFileName');
    final part = File('$dir/$kSpeakerEmbeddingFileName.part');

    var start = part.existsSync() ? part.lengthSync() : 0;
    if (start > 0 && dest.existsSync()) {
      try {
        await dest.delete();
      } catch (_) {}
    }

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(kSpeakerEmbeddingUrl));
      if (start > 0) {
        request.headers[HttpHeaders.rangeHeader] = 'bytes=$start-';
      }
      final response = await client.send(request);

      final bool append;
      if (response.statusCode == 206) {
        append = true;
      } else if (response.statusCode == 200) {
        // Server ignored Range: restart from scratch.
        if (await part.exists()) await part.delete();
        start = 0;
        append = false;
      } else {
        throw HttpException(
          'speaker model HTTP ${response.statusCode}',
        );
      }

      final total = _totalLength(response, start);
      var received = start;
      onProgress?.call(received, total);

      final sink = part.openWrite(mode: append ? FileMode.append : FileMode.write);
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
        }
      } finally {
        await sink.close();
      }

      final len = part.lengthSync();
      if (total != null && len < total) {
        throw const FormatException('speaker model transfer stopped short');
      }
      if (len <= 1024 * 1024) {
        await part.delete();
        throw const FormatException(
          'speaker model file implausibly small (likely an error page)',
        );
      }
      await part.rename(dest.path);
      onProgress?.call(len, len);
      return dest;
    } finally {
      client.close();
    }
  }

  int? _totalLength(http.StreamedResponse response, int start) {
    // Prefer Content-Range ("bytes 100-200/12345"), fall back to
    // Content-Length shifted by the resume offset.
    final range = response.headers['content-range'];
    if (range != null) {
      final slash = range.lastIndexOf('/');
      if (slash != -1) return int.tryParse(range.substring(slash + 1));
    }
    final len = response.headers['content-length'];
    if (len != null) {
      final n = int.tryParse(len);
      if (n != null) return n + start;
    }
    return null;
  }
}
