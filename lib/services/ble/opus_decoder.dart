import 'dart:typed_data';

import 'package:opus_dart/opus_dart.dart';
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;

class OpusException implements Exception {
  OpusException(this.message);
  final String message;
  @override
  String toString() => 'OpusException: $message';
}

/// Loads libopus once and decodes Opus packets to PCM16 (mono, 16 kHz).
class OpusDecoder {
  OpusDecoder._(this._decoder);

  final SimpleOpusDecoder _decoder;
  static OpusDecoder? _instance;

  static Future<OpusDecoder> get instance async {
    if (_instance != null) return _instance!;
    final lib = await opus_flutter.load();
    initOpus(lib);
    final decoder = OpusDecoder._(
      SimpleOpusDecoder(sampleRate: 16000, channels: 1),
    );
    _instance = decoder;
    return decoder;
  }

  /// Decode a single Opus packet into PCM16 interleaved bytes.
  Uint8List decode(Uint8List opusFrame) {
    try {
      final Int16List pcm16 = _decoder.decode(input: opusFrame);
      return int16ListToUint8List(pcm16);
    } catch (e) {
      throw OpusException('op decode failed: $e');
    }
  }

  void dispose() {
    _decoder.destroy();
  }
}

Uint8List int16ListToUint8List(Int16List data) {
  final out = Uint8List(data.length * 2);
  final bd = ByteData.view(out.buffer);
  for (int i = 0; i < data.length; i++) {
    bd.setInt16(i * 2, data[i], Endian.little);
  }
  return out;
}