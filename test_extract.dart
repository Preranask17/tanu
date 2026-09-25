import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';

void main() async {
  final bytes = await File('test_zipformer.tar.bz2').readAsBytes();
  try {
    final tarBytes = Uint8List.fromList(BZip2Decoder().decodeBytes(bytes, verify: true));
    print('bzip2 decoded ${tarBytes.length} bytes');
    final archive = TarDecoder().decodeBytes(tarBytes);
    print('tar decoded ${archive.files.length} files');
  } catch (e) {
    print('Failed: $e');
  }
}
