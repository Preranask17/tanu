/// End-of-conversation phrases per speech language: the data behind memory
/// segmentation (closing the current memory so the next topic starts fresh).
///
/// Design mirrors the original English detector: full-utterance anchored
/// matching. Each entry is an unambiguous, standard closing — the equivalent
/// of "thank you / bye" certainty in that language. Rules enforced by tests:
/// - STRONG closes the memory immediately.
/// - SOFT only arms the ~20 s silence timer.
/// - Anything that doubles as a greeting, filler, or common mid-sentence
///   word is excluded, or soft-only at most. A session must never die on its
///   opening greeting or on "I said thanks and left".
/// - Matching is end-anchored (trailing punctuation stripped): the closer
///   must FINISH the utterance, with at most a short opener ("okay", "well"
///   and per-language equivalents) before it.
///
/// `en` reproduces the long-standing English patterns verbatim (moved here
/// unchanged); other codes add native-script closers beside them.
class ConversationEndPhrases {
  ConversationEndPhrases._();

  /// Strong closers per language: whole-utterance alternatives.
  static const Map<String, List<String>> strong = {
    'en': [
      r'(?:okay|ok|alright|well|so)?\s*(?:thank you|thanks(?: a lot| so much| everyone| all)?|'
          r'got it[.,]? thanks|bye+|goodbye|see (?:you|ya)(?: later| all)?|farewell|take care|'
          r'talk (?:later|soon)|catch you later|'
          r"that's (?:all|it)(?: for (?:today|now))?|"
          r"that's enough(?: for (?:today|now))?|we'?re (?:done|finished|wrapped up)|"
          "i'?m done(?: now| here)?|(?:let'?s|we can|let us) (?:call it a day|wrap (?:it )?up|finish up|end here)|"
          r'end of (?:meeting|discussion|conversation)|meeting adjourned|'
          r"let'?s end here|"
          r'perfect[.,]? (?:thanks|thank you)|great[.,]? thanks|sounds good[.,]? (?:thanks|thank you)|'
          r'agreed[.,]? (?:thanks|thank you)|'
          "i think that'?s (?:it|all|everything)|"
          r'no (?:more )?questions(?:[.,]? ?(?:\w+ \w+)?)?|any other business|'
          r"i'?ll let you go|i appreciate (?:your time|it)|have a (?:good|great) (?:day|one)|"
          r'thanks everybody|thank you everyone)',
    ],
    // Hindi: धन्यवाद/शुक्रिया = thanks, अलविदा = farewell.
    // नमस्ते excluded: hello as often as goodbye.
    'hi': [
      r'(?:धन्यवाद|बहुत[ -]?बहुत धन्यवाद|शुक्रिया|अलविदा|फिर मिलेंगे)',
    ],
    // Kannada: ಧನ್ಯವಾದ = thanks. ನಮಸ್ಕಾರ excluded (hello/goodbye both).
    'kn': [
      r'(?:ಧನ್ಯವಾದಗಳು|ಧನ್ಯವಾದ|ವಿದಾಯ|ಮತ್ತೆ ಸಿಗೋಣ)',
    ],
    // Tamil: நன்றி = thanks, விடைபெறுகிறேன் = taking leave.
    // வணக்கம் excluded (hello/goodbye both).
    'ta': [
      r'(?:நன்றி|மிக்க நன்றி|விடைபெறுகிறேன்|மீண்டும் சந்திப்போம்)',
    ],
    // Telugu: ధన్యవాదాలు = thanks, వీడ్కోలు = farewell.
    // నమస్కారం excluded (hello/goodbye both).
    'te': [
      r'(?:ధన్యవాదాలు|ధన్యవాదాలు చాలా|వీడ్కోలు|మళ్ళీ కలుద్దాం)',
    ],
    // Malayalam: നന്ദി = thanks, വിട = farewell.
    // നമസ്കാരം excluded (hello/goodbye both).
    'ml': [
      r'(?:നന്ദി|വളരെ നന്ദി|വിട|വീണ്ടും കാണാം)',
    ],
    // Bengali: ধন্যবাদ = thanks, বিদায় = farewell.
    // নমস্কার excluded (hello/goodbye both).
    'bn': [
      r'(?:ধন্যবাদ|অনেক ধন্যবাদ|বিদায়|আবার দেখা হবে)',
    ],
    // Marathi: धन्यवाद/आभारी = thanks, निरोप = farewell.
    // नमस्कार excluded (hello/goodbye both).
    'mr': [
      r'(?:धन्यवाद|मनापासून धन्यवाद|आभारी आहे|निरोप घेतो|पुन्हा भेटू)',
    ],
    // Gujarati: આભાર = thanks, વિદાય = farewell.
    // નમસ્તે excluded (hello/goodbye both).
    'gu': [
      r'(?:આભાર|ખૂબ ખૂબ આભાર|વિદાય|ફરી મળીશું)',
    ],
  };

  /// Soft closers per language: arm the silence timer, cancelled by speech.
  static const Map<String, List<String>> soft = {
    'en': [
      r'(?:great|okay|ok|right|well|so|alright|cool|nice|perfect|understood|sure|fine|'
          r'works for me|that works|sounds good|no problem|no worries|all right|'
          r'yeah|yes|maybe|hmm|uh|mm)',
    ],
    'hi': [r'(?:ठीक है|अच्छा|सही है|हम्म|हाँ|समझ गया|कोई बात नहीं)'],
    'kn': [r'(?:ಸರಿ|ಆಯ್ತು|ಹೌದು|ಹ್ಮ್ಮ್|ಪರವಾಗಿಲ್ಲ|ಅರ್ಥ ಆಯ್ತು)'],
    'ta': [r'(?:சரி|ஆமாம்|ம்ம்|பரவாயில்லை|புரிந்தது)'],
    'te': [r'(?:సరే|అవును|మ్మ్|పర్లేదు|అర్థమైంది)'],
    'ml': [r'(?:ശരി|അതെ|മ്മ്|കുഴപ്പമില്ല|മനസ്സിലായി)'],
    'bn': [r'(?:ঠিক আছে|আচ্ছা|হ্যাঁ|হুম|কোনো ব্যাপার না|বুঝেছি)'],
    'mr': [r'(?:ठीक आहे|बरं|हो|हम्म|हरकत नाही|समजलं)'],
    'gu': [r'(?:બરાબર|સારું|હા|હમ્મ|કંઈ વાંધો નહીં|સમજાયું)'],
  };

  /// Trailing-closer fallback: the last [maxWords] of an utterance may carry
  /// a strong closer ("thanks all, see you tomorrow, bye"). Only entries in
  /// [strong] qualify, and greetings are in no strong list, so neither a
  /// greeting nor a mid-sentence mention can trigger it.
  static const int trailingWordWindow = 4;

  /// Trailing punctuation stripped before matching, including the Indic
  /// danda/double-danda that terminate Hindi-family utterances.
  static const String trailingPunct = r'[.!?…।॥,"\s]';

  /// Builds a full-utterance pattern from [alternatives]. The end guard is a
  /// Unicode letter/mark/number lookahead instead of `\b`: `\b` is
  /// ASCII-only and never fires after Indic script, while the lookahead
  /// keeps "thanks" from matching "thanksgiving" in every script.
  static RegExp fullMatch(List<String> alternatives) {
    return RegExp(
      '^(?:${alternatives.join('|')})(?![\\p{L}\\p{M}\\p{N}])$trailingPunct*\$',
      caseSensitive: false,
      unicode: true,
    );
  }

  /// Compiled full-utterance strong pattern for [code], or null when the
  /// code has no table (caller keeps previous behavior).
  static RegExp? strongPattern(String code) {
    final list = strong[code];
    if (list == null || list.isEmpty) return null;
    return fullMatch(list);
  }

  /// Compiled full-utterance soft pattern for [code], or null as above.
  static RegExp? softPattern(String code) {
    final list = soft[code];
    if (list == null || list.isEmpty) return null;
    return fullMatch(list);
  }

  /// True when the END of [utterance] (last [trailingWordWindow] words,
  /// punctuation stripped) is exactly a strong closer in [code].
  static bool endsWithStrongCloser(String utterance, String code) {
    final list = strong[code];
    if (list == null || list.isEmpty) return false;
    final words = utterance
        .replaceAll(RegExp(r'[.!?…।॥,"\s]+$'), '')
        .trim()
        .split(RegExp(r'\s+'));
    if (words.isEmpty) return false;
    final tail = words.length <= trailingWordWindow
        ? words.join(' ')
        : words.sublist(words.length - trailingWordWindow).join(' ');
    for (final entry in list) {
      // Each table entry is alternation-safe: anchor it to the tail end
      // with the same Unicode end guard as full matching.
      final pattern = RegExp(
        '(?:$entry)(?![\\p{L}\\p{M}\\p{N}])${ConversationEndPhrases.trailingPunct}*\$',
        caseSensitive: false,
        unicode: true,
      );
      if (pattern.hasMatch(tail)) return true;
    }
    return false;
  }
}
