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

/// ---- Deepgram cloud streaming (primary recognizer) ----------------------
/// Leave [kDeepgramApiKey] empty to fall back to the on-device Moonshine model.
const String kDeepgramApiKey = "9526c9ee35dc7da6ff961dd1019d291511b4bc45";
const String kDeepgramEndpoint = 'wss://api.deepgram.com/v1/listen';
const String kDeepgramModel = 'nova-3';
const String kDeepgramLanguage = 'en-US';
const String kDeepgramEncoding = 'linear16';
const int kDeepgramSampleRate = 16000;
const int kDeepgramInterimResults = 1; // 0/1 boolean-encoded query string value
const int kDeepgramEndpointing = 300; // ms of trailing silence → final result
const int kDeepgramSmartFormat = 1;

/// ---- Moonshine v2 on-device bundle (fallback recognizer) ----------------
/// Quantized "tiny-en" bundle, ~43 MB, tar.bz2. The single download replaces
/// the retired on-device ggml-base.en.bin (~148 MB) one-for-one: same storage
/// slot in app support, downloaded the same way, but ~3.4× lighter and built
/// for streaming feedback latency. `sherpa_onnx` ships the ofn runtime; this
/// is just the weights + tokens.
const String kMoonshineBundleUrl =
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/'
    'sherpa-onnx-moonshine-tiny-en-quantized-2026-02-27.tar.bz2';
const String kMoonshineBundleFileName = 'moonshine-tiny-en.tar.bz2';

/// The archive extracts into a directory of the same stem name inside app
/// support; these are the three files sherpa_onnx loads, with the bytes the
/// archive should contain. `decoder_model_merged.ort` is the merged-decoder
/// variant (no separate cached/uncached decoder pairs), matching
/// `OfflineMoonshineModelConfig.mergedDecoder`.
const List<({String name, int bytes})> kMoonshineBundleFiles = [
  (name: 'encoder_model.ort', bytes: 13631488), // 13 MB
  (name: 'decoder_model_merged.ort', bytes: 32662016), // ~31 MB
  (name: 'tokens.txt', bytes: 548864), // ~536 KB
];

/// Human label shown in Settings and the Home warm-up chip.
const String kMoonshineModelLabel = 'Moonshine tiny-en · 43 MB';

/// Names of on-disk bundles that are no longer the on-device fallback model.
/// Any of these found in app support are deleted on startup. The retired
/// on-device model shipped under `ggml-...` file names.
const List<String> kRetiredModelBundles = ['ggml-base.en.bin', 'ggml-tiny.en.bin'];

const String kMistralEndpoint = 'https://api.mistral.ai/v1/chat/completions';
const String kMistralModel = 'mistral-medium-latest';
const String kMistralApiKeyDefine = String.fromEnvironment('MISTRAL_API_KEY');

/// Tanu pendant GATT layout (reuses Omi DevKit layout).
final Guid kOmiService = Guid('19B10000-E8F2-537E-4F6C-D104768A1214');
final Guid kAudioDataChar = Guid('19B10001-E8F2-537E-4F6C-D104768A1214');
final Guid kCodecTypeChar = Guid('19B10002-E8F2-537E-4F6C-D104768A1214');
final Guid kButtonEventChar = Guid('19B10003-E8F2-537E-4F6C-D104768A1214');

const int kSampleRate = 16000;

/// Button event byte values.
const int kButtonShortPress = 0;
const int kButtonLongPress = 1;

/// System prompt used for every Mistral agent turn.
const String kAgentSystemPrompt = '''
You are Tanu, a small, warm AI companion that lives with the user. You are
present, helpful, and concise. You answer questions directly and usefully,
and you naturally remember what the user tells you.

Guidelines:
- Keep responses under three sentences unless the user explicitly asks for detail.
- Use everyday, warm language. Never refer to yourself as an AI model or chatbot.
- If the user mentions an intention, commitment, or reminder ("I'll send Rahul
  the deck Friday"), acknowledge it briefly so it can be captured.
- You can only receive spoken input, so never ask the user to click things or
  type; they can just speak to you.
''';

/// Prompt for the single-shot commitment extraction call.
const String kCommitmentExtractionPrompt = '''
You are a reminder assistant. Given a recent conversation, extract any
commitments, reminders, or to-dos the user expressed — anything they intend to
do for someone or at a later time.

Reply with ONLY a JSON object, no commentary:

{
  "commitments": [
    {
      "is_commitment": true,
      "action": "short description of the commitment",
      "person": "who it is for, or null",
      "due": "YYYY-MM-DD or null"
    }
  ]
}

If nothing in the conversation sounds like a commitment, return
{"commitments": []}.
Tone is irrelevant; only include concrete intentions.
''';