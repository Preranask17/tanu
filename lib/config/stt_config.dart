/// Single source of truth for the on-device STT stack.
///
/// Everything the Whisper Small engine and its Silero VAD feed on lives
/// here so tuning language / VAD sensitivity never requires touching the
/// engine implementation.
class SttConfig {
  SttConfig._();

  /// Short id of the active model bundle (matches the download dir stem).
  static const String modelName = 'whisper-small';

  /// Whisper language hint. `''` = auto-detect; otherwise a Whisper language
  /// code such as `'en'`, `'kn'` (Kannada), `'ta'` (Tamil), `'te'` (Telugu)
  /// or `'ml'` (Malayalam).
  static const String language = '';

  /// Threads handed to the offline recognizer decode.
  static const int numThreads = 4;

  /// Whisper task: `'transcribe'` (or `'translate'` to English).
  static const String task = 'transcribe';

  /// Silero VAD probability above which audio counts as speech.
  static const double vadThreshold = 0.5;

  /// Trailing silence (seconds) required to close a speech segment.
  static const double vadMinSilence = 0.4;

  /// Minimum segment length (seconds) kept by the VAD.
  static const double vadMinSpeech = 0.25;

  /// Maximum segment length (seconds); also the VAD ring-buffer size.
  static const double vadMaxSpeech = 25.0;

  /// Silero window size in samples (32 ms @ 16 kHz).
  static const int vadWindowSize = 512;

  /// PCM sample rate expected by both the VAD and the recognizer.
  static const int sampleRate = 16000;

  /// Indic languages the on-device Whisper Small bundle decodes. The bundle
  /// is multilingual, so each entry is served by the shared 375 MB download
  /// with an explicit language hint (no auto-detect) — faster and more
  /// accurate than language detection, and it keeps every language model
  /// already on disk: no extra downloads, no extra storage.
  /// (code: Whisper language id, label: Settings display name)
  static const List<({String code, String label})> indicLanguages = [
    (code: 'hi', label: 'Hindi'),
    (code: 'kn', label: 'Kannada'),
    (code: 'ta', label: 'Tamil'),
    (code: 'te', label: 'Telugu'),
    (code: 'ml', label: 'Malayalam'),
    (code: 'bn', label: 'Bengali'),
    (code: 'mr', label: 'Marathi'),
    (code: 'gu', label: 'Gujarati'),
  ];

  /// Display label for a language [code], or null when the code is not a
  /// supported Indic language (caller falls back to auto-detect).
  static String? indicLabelFor(String code) {
    for (final entry in indicLanguages) {
      if (entry.code == code) return entry.label;
    }
    return null;
  }
}
