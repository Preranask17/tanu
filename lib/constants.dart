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



/// ---- Whisper Small (multilingual) on-device bundle ---------------------
/// Multilingual speech recognition (English + Kannada/Tamil/Telugu/Malayalam
/// and 90+ more), 375 MB total. The three int8 files are streamed straight
/// to disk from the Hugging Face mirror with range-resume — never as one
/// archive: the GitHub `.tar.bz2` is 610 MB and unpacks to ~1.3 GB in RAM,
/// which Android kills mid-extract. Files land in
/// `appSupport/<kWhisperSmallDirName>/`.
const String kWhisperSmallFilesBaseUrl =
    'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small/resolve/main';

/// Legacy GitHub bundle archive name (610 MB). Kept only so downloads can
/// purge the leftover archive and `.part` from older builds.
const String kWhisperSmallTarFileName = 'sherpa-onnx-whisper-small.tar.bz2';
const String kWhisperSmallDirName = 'sherpa-onnx-whisper-small';


const String kSileroVadUrl =
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx';
const String kSileroVadFileName = 'silero_vad.onnx';

/// Files the Whisper Small recognizer loads from the model directory, with
/// their exact byte sizes (used for progress totals and integrity checks).
/// `silero_vad.onnx` is fetched separately via [kSileroVadUrl].
const List<({String name, int bytes})> kWhisperSmallBundleFiles = [
  (name: 'small-encoder.int8.onnx', bytes: 112442483),
  (name: 'small-decoder.int8.onnx', bytes: 262226114),
  (name: 'small-tokens.txt', bytes: 816730),
];


/// Human label shown in Settings and the Home warm-up chip.
const String kOfflineModelLabel = 'Whisper Small · 375 MB';

/// Names of on-disk bundles that are no longer the on-device model.
/// Any of these found in app support are deleted on upgrade, along with
/// their `.part` files and any `stt-*` per-language directories left over
/// from the multilingual experiment.
const List<String> kRetiredModelBundles = [
  'ggml-base.en.bin',
  'ggml-tiny.en.bin',
  'moonshine-tiny-en.tar.bz2',
  'sherpa-onnx-moonshine-base-en-quantized-2026-02-27.tar.bz2',
  'sherpa-onnx-moonshine-base-en-quantized-2026-02-27',
  'sherpa-onnx-whisper-base.tar.bz2',
  'sherpa-onnx-whisper-base',
  'sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17.tar.bz2',
  'sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17',
  'sherpa-onnx-streaming-zipformer-en-kroko-2025-08-06',
  'indic-conformer-multi',
];

/// Directory prefixes retired as a group (the per-language `stt-<code>`
/// experiment). Any app-support directory starting with one of these is
/// deleted on upgrade.
const List<String> kRetiredModelPrefixes = ['stt-'];



/// Tanu pendant GATT layout (reuses Omi DevKit layout).
final Guid kOmiService = Guid('19B10000-E8F2-537E-4F6C-D104768A1214');
final Guid kAudioDataChar = Guid('19B10001-E8F2-537E-4F6C-D104768A1214');
final Guid kCodecTypeChar = Guid('19B10002-E8F2-537E-4F6C-D104768A1214');
final Guid kButtonEventChar = Guid('19B10003-E8F2-537E-4F6C-D104768A1214');

const int kSampleRate = 16000;

/// Button event byte values.
const int kButtonShortPress = 0;
const int kButtonLongPress = 1;

/// ---- PostHog analytics ---------------------------------------------------
/// Public write key, supplied at build time and never committed:
///   flutter run --dart-define=POSTHOG_TOKEN=phc_xxx
/// An empty token leaves [AnalyticsService] inert, so a plain `flutter run`
/// without the define produces a clean, silent build.
const String kPostHogToken = String.fromEnvironment('POSTHOG_TOKEN');

/// `https://us.i.posthog.com` (US) or `https://eu.i.posthog.com` (EU).
const String kPostHogHost = String.fromEnvironment(
  'POSTHOG_HOST',
  defaultValue: 'https://us.i.posthog.com',
);

/// ---- Gemini (agent brain) -------------------------------------------------
/// Cloud agent used for memory processing and in-memory chat.
const String kGeminiApiKey = 'AIzaSyCJhOvW1GqEiYVhREytzohUJCBSwMv7FT4';
const String kGeminiModel = 'gemini-3.5-flash';
const String kGeminiEndpoint =
    'https://generativelanguage.googleapis.com/v1beta/models/$kGeminiModel:generateContent';

/// Gemini embeddings used by the RAG pipeline.
const String kGeminiEmbeddingModel = 'gemini-embedding-001';
const int kEmbeddingDims = 768;
const int kRagChunkMaxChars = 1000;
const int kRagTopK = 6;
