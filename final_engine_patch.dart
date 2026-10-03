import 'dart:io';

void main() {
  final engineFile = File('lib/services/stt/zipformer_stt_engine.dart');
  var e = engineFile.readAsStringSync();
  e = e.replaceAll('sherpa-onnx-streaming-zipformer-en-2023-06-26', 'sherpa-onnx-streaming-zipformer-en-2023-02-21');
  e = e.replaceAll('chunk-16-left-128.', '');
  e = e.replaceAll('.onnx', '.int8.onnx');
  // Revert any mistaken int8 conversions on the directory names or already-converted files
  e = e.replaceAll('.int8.int8.onnx', '.int8.onnx');
  e = e.replaceAll('sherpa-onnx.int8.onnx', 'sherpa-onnx');
  engineFile.writeAsStringSync(e);
}