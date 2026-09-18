import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Standard battery service.
final Guid kBatteryService = Guid('0000180F-0000-1000-8000-00805F9B34FB');
final Guid kBatteryLevelChar = Guid('00002A19-0000-1000-8000-00805F9B34FB');

/// Locale used by the pendant (Omi ambient audio + button semantics). Kept as
/// a single knob so the app and the emissary prompt never drift.
const String kPendantLanguage = 'en-US';

/// Device advertises as "Omi" on stock firmware for now.
/// Change this once the firmware is renamed to "Tanu".
const String kPendantName = 'Omi';



/// ---- Moonshine v2 on-device bundle (fallback recognizer) ----------------
/// Quantized "base-en" bundle, ~85 MB, tar.bz2. The single download replaces
/// the retired on-device ggml-base.en.bin (~148 MB) one-for-one: same storage
/// slot in app support, downloaded the same way, but ~1.7× lighter and built
/// for streaming feedback latency. `sherpa_onnx` ships the onnx runtime; this
/// is just the weights + tokens.
const String kOfflineBundleUrl =
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/'
    'sherpa-onnx-moonshine-base-en-quantized-2026-02-27.tar.bz2';
const String kOfflineBundleFileName = 'sherpa-onnx-moonshine-base-en-quantized-2026-02-27.tar.bz2';

const String kSileroVadUrl =
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx';
const String kSileroVadFileName = 'silero_vad.onnx';

/// The archive extracts into a directory of the same stem name inside app
/// support; these are the three files sherpa_onnx loads, with the bytes the
/// archive should contain. `decoder_model_merged.ort` is the merged-decoder
/// variant (no separate cached/uncached decoder pairs), matching
/// `OfflineMoonshineModelConfig.mergedDecoder`.
const List<({String name, int bytes})> kOfflineBundleFiles = [
  (name: 'encoder_model.ort', bytes: 0),
  (name: 'decoder_model_merged.ort', bytes: 0),
  (name: 'tokens.txt', bytes: 0),
];

/// Human label shown in Settings and the Home warm-up chip.
const String kOfflineModelLabel = 'Moonshine Base · 85 MB';

/// Names of on-disk bundles that are no longer the on-device fallback model.
/// Any of these found in app support are deleted on startup. The retired
/// on-device model shipped under `ggml-...` file names.
const List<String> kRetiredModelBundles = [
  'ggml-base.en.bin',
  'ggml-tiny.en.bin',
  'moonshine-tiny-en.tar.bz2',
  'sherpa-onnx-whisper-base.tar.bz2',
  'sherpa-onnx-whisper-base',
];



/// Tanu pendant GATT layout (reuses Omi DevKit layout).
final Guid kOmiService = Guid('19B10000-E8F2-537E-4F6C-D104768A1214');
final Guid kAudioDataChar = Guid('19B10001-E8F2-537E-4F6C-D104768A1214');
final Guid kCodecTypeChar = Guid('19B10002-E8F2-537E-4F6C-D104768A1214');
final Guid kButtonEventChar = Guid('19B10003-E8F2-537E-4F6C-D104768A1214');

const int kSampleRate = 16000;

/// Button event byte values.
const int kButtonShortPress = 0;
const int kButtonLongPress = 1;

