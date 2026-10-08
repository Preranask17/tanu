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
/// and 90+ more), ~375 MB download. `sherpa_onnx` ships the runtime; this is
/// just int8 weights + tokens. Extracts into
/// `appSupport/<kWhisperSmallDirName>/`.
const String kWhisperSmallTarUrl =
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-small.tar.bz2';
const String kWhisperSmallTarFileName = 'sherpa-onnx-whisper-small.tar.bz2';
const String kWhisperSmallDirName = 'sherpa-onnx-whisper-small';


const String kSileroVadUrl =
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx';
const String kSileroVadFileName = 'silero_vad.onnx';

/// Files the Whisper Small recognizer loads from the model directory.
/// `silero_vad.onnx` is fetched separately via [kSileroVadUrl].
const List<({String name, int bytes})> kWhisperSmallBundleFiles = [
  (name: 'small-encoder.int8.onnx', bytes: 0),
  (name: 'small-decoder.int8.onnx', bytes: 0),
  (name: 'small-tokens.txt', bytes: 0),
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

/// ---- Speaker ID (on-device diarization) -----------------------------------
/// Post-session speaker labeling runs fully offline: one 25 MB embedding
/// model turns each VAD-gated STT segment into a voiceprint, pure-Dart
/// clustering groups voiceprints into speakers, and mic-energy picks the
/// wearer. No audio or embedding ever leaves the phone.
///
/// Single `.onnx` streamed straight to disk with range-resume (same pattern
/// as the Whisper bundle) into `appSupport/<kSpeakerModelDirName>/`. English
/// VoxCeleb embedding — language-agnostic enough for en + Indian languages.
const String kSpeakerEmbeddingUrl =
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-recongition-models/3dspeaker_speech_eres2net_sv_en_voxceleb_16k.onnx';
const String kSpeakerModelDirName = 'speaker-id';
const String kSpeakerEmbeddingFileName =
    '3dspeaker_speech_eres2net_sv_en_voxceleb_16k.onnx';

/// Human label shown in Settings next to the speaker model row.
const String kSpeakerModelLabel = 'Speaker ID · 25 MB';

/// Cosine similarity at or above which two segment voiceprints count as the
/// same speaker (eres2net cosine; 0.4–0.6 is the sane band).
const double kSpeakerClusterThreshold = 0.45;

/// Minimum speech audio (seconds) needed for a trustworthy voiceprint.
/// Shorter segments are merged with a neighbor before embedding.
const double kSpeakerMinWindowSeconds = 1.0;

/// Maximum audio (seconds) embedded in one shot; longer spans are split so
/// one window never straddles two speakers for long.
const double kSpeakerMaxWindowSeconds = 10.0;

/// The loudest cluster is called the wearer only when its mean RMS energy
/// exceeds the runner-up by this ratio — the pendant mic sits on the
/// wearer's chest, so their voice dominates. Below the margin every speaker
/// stays anonymous (`Other N`) rather than mislabeling someone as you.
const double kWearerEnergyMargin = 1.6;

/// Canonical wearer label used across turns, chunks and the UI.
const String kSpeakerYou = 'You';

/// Label for the Nth non-wearer cluster (1-based): `Other 1`, `Other 2`, …
String kSpeakerOther(int n) => 'Other $n';

/// ---- Session audio retention ----------------------------------------------
/// Per-session 16 kHz mono WAVs under `appSupport/<kSessionAudioDirName>/`,
/// captured alongside STT so post-session diarization has a waveform to work
/// on. Deleted right after processing unless the user opted into keeping
/// them in Settings.
const String kSessionAudioDirName = 'session_audio';

/// Recorder stops appending past this many minutes (stale/forgotten
/// sessions must not fill the disk): ~345 MB at 16 kHz mono 16-bit.
const int kSessionAudioMaxMinutes = 180;

/// Session WAVs older than this are purged on launch (safety net for
/// crashes between close and processing).
const Duration kSessionAudioMaxAge = Duration(days: 7);

/// ---- Gemini (agent brain) -------------------------------------------------
/// Cloud agent used for memory processing and in-memory chat.
const String kGeminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
const String kGeminiModel = 'gemini-3.5-flash';
const String kGeminiEndpoint =
    'https://generativelanguage.googleapis.com/v1beta/models/$kGeminiModel:generateContent';

/// Gemini embeddings used by the RAG pipeline.
const String kGeminiEmbeddingModel = 'gemini-embedding-001';
const int kEmbeddingDims = 768;
const int kRagChunkMaxChars = 1000;
const int kRagTopK = 8;
const int kRagTopKSession = 6;
const int kRagEmbedBatchSize = 10;
const int kRagChunkOverlapChars = 150;
const int kRagContextMaxChars = 2000;
const int kRagMinSliceChars = 20;
const int kRagQueryCacheTtlSeconds = 300;
const double kRagMinDistance = 0.6;
const int kGeminiMinGapEmbedMs = 500;
const int kGeminiMinGapChatMs = 2000;
