import 'dart:io';

void main() {
  final file = File('lib/constants.dart');
  var content = file.readAsStringSync();
  content = content.replaceAll('sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17.tar.bz2', 'sherpa-onnx-streaming-zipformer-en-2023-06-26.tar.bz2');
  content = content.replaceAll(
    "(name: 'model.int8.onnx', bytes: 0),",
    "(name: 'encoder-epoch-99-avg-1-chunk-16-left-128.onnx', bytes: 0),\n  (name: 'decoder-epoch-99-avg-1-chunk-16-left-128.onnx', bytes: 0),\n  (name: 'joiner-epoch-99-avg-1-chunk-16-left-128.onnx', bytes: 0),"
  );
  file.writeAsStringSync(content);
  print('constants patched successfully');
}