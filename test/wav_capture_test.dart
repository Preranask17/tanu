import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tanu_app/services/dev/wav_capture.dart';

void main() {
  group('WavCapture', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('wav_capture_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('writes a valid RIFF/WAVE header with correct sizes', () async {
      final file = File('${dir.path}/test.wav');
      final pcm = Uint8List.fromList(List<int>.generate(3200, (i) => i & 0xFF));
      final capture = await WavCapture.create(file);
      capture.add(pcm);
      final path = await capture.close();

      expect(path, file.path);
      final bytes = await file.readAsBytes();
      expect(bytes.length, 44 + pcm.length);

      final d = ByteData.sublistView(bytes);
      String ascii(int offset, int length) =>
          String.fromCharCodes(bytes.sublist(offset, offset + length));
      expect(ascii(0, 4), 'RIFF');
      expect(ascii(8, 4), 'WAVE');
      expect(ascii(12, 4), 'fmt ');
      expect(ascii(36, 4), 'data');
      expect(d.getUint16(20, Endian.little), 1); // PCM
      expect(d.getUint16(22, Endian.little), 1); // mono
      expect(d.getUint32(24, Endian.little), 16000);
      expect(d.getUint32(28, Endian.little), 32000); // byte rate
      expect(d.getUint16(32, Endian.little), 2); // block align
      expect(d.getUint16(34, Endian.little), 16); // bits per sample
      expect(d.getUint32(40, Endian.little), pcm.length); // data size
      expect(d.getUint32(4, Endian.little), 36 + pcm.length); // RIFF size
      expect(bytes.sublist(44), pcm); // raw data intact
    });

    test('rejects close after close', () async {
      final capture = await WavCapture.create(File('${dir.path}/x.wav'));
      capture.add(Uint8List(64));
      await capture.close();
      expect(() => capture.close(), throwsStateError);
    });
  });
}
