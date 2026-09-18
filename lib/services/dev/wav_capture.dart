import 'dart:io';
import 'dart:typed_data';

/// Streams PCM16 mono 16 kHz audio into a valid RIFF/WAVE container on disk.
/// Used by the dev "Record wav" tool to capture the pendant's decoded audio
/// for offline verification. The 44-byte header is written up front with zero
/// sizes and patched with the real length on close.
class WavCapture {
  WavCapture._(this._file, this._sink);

  final File _file;
  final IOSink _sink;
  int _dataBytes = 0;
  bool _closed = false;

  static const int sampleRate = 16000;
  static const int channels = 1;
  static const int bitsPerSample = 16;

  static Future<WavCapture> create(File file) async {
    final sink = file.openWrite(mode: FileMode.write);
    sink.add(_header(0));
    return WavCapture._(file, sink);
  }

  int get bytesWritten => _dataBytes;

  void add(Uint8List pcm16) {
    if (_closed) return;
    _sink.add(pcm16);
    _dataBytes += pcm16.length;
  }

  /// Patches the header sizes, closes the file, and returns the saved path.
  Future<String> close() async {
    if (_closed) {
      throw StateError('WavCapture is already closed');
    }
    _closed = true;
    await _sink.close();
    _patchHeader();
    return _file.path;
  }

  void _patchHeader() {
    final raf = _file.openSync(mode: FileMode.append);
    try {
      raf.setPositionSync(0);
      raf.writeFromSync(_patch(_header(0), _dataBytes));
    } finally {
      raf.closeSync();
    }
  }

  static Uint8List _patch(Uint8List header, int dataBytes) {
    final d = ByteData.sublistView(header);
    d.setUint32(4, 36 + dataBytes, Endian.little);
    d.setUint32(40, dataBytes, Endian.little);
    return header;
  }

  static Uint8List _header(int dataBytes) {
    final d = ByteData(44);
    void ascii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        d.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    d.setUint32(4, 36 + dataBytes, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    d.setUint32(16, 16, Endian.little);
    d.setUint16(20, 1, Endian.little);
    d.setUint16(22, channels, Endian.little);
    d.setUint32(24, sampleRate, Endian.little);
    d.setUint32(28, sampleRate * channels * bitsPerSample ~/ 8, Endian.little);
    d.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little);
    d.setUint16(34, bitsPerSample, Endian.little);
    ascii(36, 'data');
    d.setUint32(40, dataBytes, Endian.little);
    return d.buffer.asUint8List();
  }
}
