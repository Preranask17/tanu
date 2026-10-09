import 'dart:typed_data';

/// Pure helpers shared by the STT worker isolates (importable without native
/// bindings, so unit-testable).

/// Splits [samples] into back-to-back windows of at most [maxWindow] items
/// for bounded synchronous decodes. Returns the input untouched when it
/// already fits; never drops or reorders a sample.
List<Float32List> splitDecodeWindows(List<double> samples, int maxWindow) {
  assert(maxWindow > 0);
  if (samples.length <= maxWindow) {
    return [Float32List.fromList(samples)];
  }
  final out = <Float32List>[];
  var offset = 0;
  while (offset < samples.length) {
    final end = (offset + maxWindow < samples.length)
        ? offset + maxWindow
        : samples.length;
    out.add(Float32List.fromList(samples.sublist(offset, end)));
    offset = end;
  }
  return out;
}
