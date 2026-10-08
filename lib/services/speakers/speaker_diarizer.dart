import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../constants.dart';
import '../../models/transcript.dart';
import 'speaker_cluster.dart';
import 'speaker_model_coordinator.dart';

/// Post-session, on-device speaker labeling.
///
/// STT gives VAD-gated speech segments with timestamps but no identities;
/// this service fills that gap without any cloud call: the session WAV is
/// sliced into embeddable windows, each window gets a voiceprint from the
/// sherpa-onnx speaker embedding model (25 MB, running in a worker isolate
/// so capture never janks), pure-Dart clustering groups voiceprints into
/// speakers, and mic energy picks the wearer.
///
/// Returns null whenever labeling is impossible (no model, no audio, too
/// little speech, native failure) — callers fall back to text-only
/// structured processing. Never throws.
class SpeakerDiarizer {
  /// True when the embedding model is on disk.
  Future<bool> isAvailable() => SpeakerModelCoordinator.isReady();

  /// Labels [segments] as `You` / `Other N` (session-local).
  Future<SpeakerLabels?> diarize({
    required String wavPath,
    required List<TranscriptSegment> segments,
  }) async {
    try {
      return await _diarize(wavPath, segments);
    } catch (e) {
      debugPrint('[tanu] diarization failed, continuing without labels: $e');
      return null;
    }
  }

  Future<SpeakerLabels?> _diarize(
    String wavPath,
    List<TranscriptSegment> segments,
  ) async {
    if (!File(wavPath).existsSync()) return null;
    final modelPath = await SpeakerModelCoordinator.modelPath();
    if (modelPath == null) return null;

    final refs = <SegmentRef>[];
    for (final s in segments) {
      if (s.text.trim().isEmpty) continue;
      final end = s.endMs ?? s.startMs;
      if (end <= s.startMs) continue;
      refs.add(SegmentRef(id: s.id, startMs: s.startMs, endMs: end));
    }
    if (refs.isEmpty) return null;

    var windows = SpeakerClusterer.buildWindows(refs);
    windows = _normalizeTrailing(windows);
    if (windows.isEmpty) return null;

    final payload = [
      for (final w in windows)
        [w.startMs, w.endMs, w.segmentIds],
    ];

    final port = ReceivePort();
    await Isolate.spawn(
      _diarizeWorker,
      [modelPath, wavPath, payload, port.sendPort],
    );
    final reply = await port.first;
    port.close();
    if (reply is! List || reply.isEmpty || reply[0] != 'ok') return null;
    final rawLabels = Map<String, String>.from(reply[1] as Map);
    if (rawLabels.isEmpty) return null;
    return SpeakerLabels(
      labels: rawLabels,
      speakerCount: reply[2] as int,
      youConfident: reply[3] as bool,
    );
  }

  /// The final flush of [SpeakerClusterer.buildWindows] can be shorter than
  /// the trustworthy embedding length. Fold it into the previous window
  /// (same ids, extended span) instead of embedding noise; a lone short
  /// window means there is too little speech to label at all.
  List<SpeakerWindow> _normalizeTrailing(List<SpeakerWindow> windows) {
    if (windows.isEmpty) return windows;
    final minMs = (kSpeakerMinWindowSeconds * 1000).round();
    final last = windows.last;
    if (last.durationMs >= minMs) return windows;
    if (windows.length == 1) return const [];
    final prev = windows[windows.length - 2];
    final merged = SpeakerWindow(
      segmentIds: [...prev.segmentIds, ...last.segmentIds],
      startMs: prev.startMs,
      endMs: last.endMs,
    );
    return [...windows.sublist(0, windows.length - 2), merged];
  }
}

/// Worker isolate: loads the embedding model, voiceprints every window,
/// clusters, and replies
/// `['ok', labels, speakerCount, youConfident]` or `['error', message]`.
Future<void> _diarizeWorker(List<dynamic> args) async {
  final modelPath = args[0] as String;
  final wavPath = args[1] as String;
  final payload = args[2] as List;
  final replyPort = args[3] as SendPort;

  void fail(Object e) => replyPort.send(['error', '$e']);

  try {
    await sherpa.initBindingsAsync();

    final wav = _readWavMono16k(wavPath);
    if (wav.sampleCount == 0) {
      fail('empty session audio');
      return;
    }

    final extractor = sherpa.SpeakerEmbeddingExtractor(
      config: sherpa.SpeakerEmbeddingExtractorConfig(
        model: modelPath,
        numThreads: 2,
      ),
    );
    try {
      final done = <SpeakerWindow>[];
      for (final raw in payload) {
        final startMs = raw[0] as int;
        final endMs = raw[1] as int;
        final ids = (raw[2] as List).cast<String>();
        final slice = wav.slice(startMs, endMs);
        if (slice.isEmpty) continue;
        final energy = SpeakerClusterer.rms(slice);
        var emb = <double>[];
        try {
          final stream = extractor.createStream();
          stream.acceptWaveform(samples: slice, sampleRate: wav.sampleRate);
          if (extractor.isReady(stream)) {
            emb = extractor.compute(stream).toList();
          }
          stream.free();
        } catch (_) {
          // One bad window must not sink the session: it simply stays
          // unlabeled and the LLM infers it from context.
        }
        done.add(
          SpeakerWindow(
            segmentIds: ids,
            startMs: startMs,
            endMs: endMs,
            embedding: emb,
            rms: energy,
          ),
        );
      }
      final result = SpeakerClusterer.assignLabels(done);
      replyPort.send([
        'ok',
        result.labels,
        result.speakerCount,
        result.youConfident,
      ]);
    } finally {
      extractor.free();
    }
  } catch (e) {
    fail(e);
  }
}

/// Minimal 16-bit PCM mono WAV reader for files this app wrote itself.
/// Reads the header, validates the format, and slices int16 ranges into
/// float32 on demand so a multi-hour session never needs two full-size
/// float copies in memory at once.
class _SessionWav {
  _SessionWav._(this._bytes, this._dataOffset, this.sampleRate);

  final Uint8List _bytes;
  final int _dataOffset;
  final int sampleRate;

  int get sampleCount => (_bytes.length - _dataOffset) ~/ 2;

  Float32List slice(int startMs, int endMs) {
    var start = (startMs * sampleRate) ~/ 1000;
    var end = (endMs * sampleRate) ~/ 1000;
    if (start < 0) start = 0;
    if (end > sampleCount) end = sampleCount;
    if (end <= start) return Float32List(0);
    final out = Float32List(end - start);
    final bd = ByteData.sublistView(_bytes);
    for (var i = 0; i < out.length; i++) {
      out[i] = bd.getInt16(_dataOffset + (start + i) * 2, Endian.little) /
          32768.0;
    }
    return out;
  }
}

_SessionWav _readWavMono16k(String path) {
  final bytes = File(path).readAsBytesSync();
  if (bytes.length < 44) throw const FormatException('wav too small');
  final bd = ByteData.sublistView(bytes);

  String ascii(int offset, int len) =>
      String.fromCharCodes(bytes.sublist(offset, offset + len));
  if (ascii(0, 4) != 'RIFF' || ascii(8, 4) != 'WAVE') {
    throw const FormatException('not a RIFF/WAVE file');
  }

  var fmtRate = 0;
  var fmtChannels = 0;
  var fmtBits = 0;
  var dataOffset = -1;

  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = ascii(offset, 4);
    final size = bd.getUint32(offset + 4, Endian.little);
    if (id == 'fmt ') {
      final audioFormat = bd.getUint16(offset + 8, Endian.little);
      if (audioFormat != 1) {
        throw const FormatException('wav is not PCM');
      }
      fmtChannels = bd.getUint16(offset + 10, Endian.little);
      fmtRate = bd.getUint32(offset + 12, Endian.little);
      fmtBits = bd.getUint16(offset + 22, Endian.little);
    } else if (id == 'data') {
      dataOffset = offset + 8;
      break;
    }
    offset += 8 + size;
  }

  if (dataOffset < 0) throw const FormatException('wav has no data chunk');
  if (fmtChannels != 1 || fmtRate != kSampleRate || fmtBits != 16) {
    throw FormatException(
      'unsupported wav format: $fmtChannels ch, $fmtRate Hz, $fmtBits bit',
    );
  }
  return _SessionWav._(bytes, dataOffset, fmtRate);
}
