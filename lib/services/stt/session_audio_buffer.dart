import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../constants.dart';
import '../dev/wav_capture.dart';

/// Per-session PCM tap: streams the pendant's 16 kHz mono PCM16 chunks into
/// a WAV file on disk while a memory is being captured.
///
/// The STT engine consumes PCM as a throwaway stream, so without this sink
/// there would be no waveform left for post-session speaker diarization.
/// Files live under `appSupport/<kSessionAudioDirName>/<sessionId>.wav`,
/// are capped at [kSessionAudioMaxMinutes], and are deleted right after the
/// session is processed unless the user opted into keeping them.
///
/// One buffer is open at a time per session id; the conversation provider
/// owns the lifecycle (begin on session start, finish on session close).
class SessionAudioBuffer {
  SessionAudioBuffer._(this.sessionId, this._capture, this._file);

  final String sessionId;
  final WavCapture _capture;
  final File _file;
  bool _done = false;

  /// 16 kHz mono 16-bit cap in bytes.
  static int get maxBytes => kSessionAudioMaxMinutes * 60 * 16000 * 2;

  /// Minimum bytes kept: anything shorter than ~1 s of audio is silence /
  /// a tapped-out session and is discarded instead of finalized.
  static const int minBytes = 32000;

  /// Opens `<sessionId>.wav` for appending. Returns null when storage is
  /// unavailable — capture must never fail because the tap failed.
  static Future<SessionAudioBuffer?> begin(String sessionId) async {
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory('${support.path}/$kSessionAudioDirName');
      await dir.create(recursive: true);
      final file = File('${dir.path}/$sessionId.wav');
      final capture = await WavCapture.create(file);
      return SessionAudioBuffer._(sessionId, capture, file);
    } catch (e) {
      debugPrint('[tanu] session audio tap unavailable: $e');
      return null;
    }
  }

  /// Appends one PCM16 chunk. Chunks past the cap are dropped (the file
  /// stays a valid prefix) so a forgotten session cannot fill the disk.
  void add(Uint8List pcm16) {
    if (_done) return;
    if (_capture.bytesWritten >= maxBytes) return;
    try {
      _capture.add(pcm16);
    } catch (e) {
      debugPrint('[tanu] session audio write failed: $e');
    }
  }

  /// Closes the WAV and returns its path, or null when nothing worth
  /// diarizing was captured (the file is deleted in that case).
  Future<String?> finish() async {
    if (_done) return null;
    _done = true;
    try {
      if (_capture.bytesWritten < minBytes) {
        await _deleteFile();
        return null;
      }
      return await _capture.close();
    } catch (e) {
      debugPrint('[tanu] session audio finalize failed: $e');
      await _deleteFile();
      return null;
    }
  }

  /// Abandons the recording and deletes the file.
  Future<void> discard() async {
    if (_done) return;
    _done = true;
    await _deleteFile();
  }

  Future<void> _deleteFile() async {
    try {
      if (await _file.exists()) await _file.delete();
    } catch (_) {}
  }

  /// Deletes WAVs older than [kSessionAudioMaxAge] — the safety net for
  /// crashes between session close and processing. Keeps anything newer
  /// (a retry may still want it) regardless of the keep-audio setting.
  static Future<void> purgeStale() async {
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory('${support.path}/$kSessionAudioDirName');
      if (!await dir.exists()) return;
      final cutoff = DateTime.now().subtract(kSessionAudioMaxAge);
      await for (final e in dir.list()) {
        if (e is! File || !e.path.endsWith('.wav')) continue;
        try {
          final stat = await e.stat();
          if (stat.modified.isBefore(cutoff)) await e.delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[tanu] session audio purge failed: $e');
    }
  }

  /// Total bytes currently held by session WAVs, for the Settings row.
  static Future<int> storedBytes() async {
    var total = 0;
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory('${support.path}/$kSessionAudioDirName');
      if (!await dir.exists()) return 0;
      await for (final e in dir.list()) {
        if (e is! File || !e.path.endsWith('.wav')) continue;
        try {
          total += await e.length();
        } catch (_) {}
      }
    } catch (_) {}
    return total;
  }

  /// Deletes every session WAV. Used by the Settings "delete audio" action.
  static Future<void> deleteAll() async {
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory('${support.path}/$kSessionAudioDirName');
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('[tanu] session audio delete-all failed: $e');
    }
  }
}
