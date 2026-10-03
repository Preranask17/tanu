import 'dart:io';

void main() {
  final engineFile = File('lib/services/stt/zipformer_stt_engine.dart');
  var e = engineFile.readAsStringSync();
  e = e.replaceAll('-onnx', '.int8.onnx');
  engineFile.writeAsStringSync(e);
}