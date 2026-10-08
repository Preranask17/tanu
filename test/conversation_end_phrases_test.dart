import 'package:flutter_test/flutter_test.dart';
import 'package:tanu_app/config/conversation_end_phrases.dart';

void main() {
  group('English behavior is unchanged', () {
    final strong = ConversationEndPhrases.strongPattern('en')!;
    final soft = ConversationEndPhrases.softPattern('en')!;

    test('bare closers match', () {
      for (final text in ['thanks', 'okay thanks', 'bye', 'goodbye']) {
        expect(strong.hasMatch(text), isTrue, reason: text);
      }
    });

    test('mid-sentence mentions do not match', () {
      for (final text in [
        'I said thanks and left',
        'bye week was busy',
        'say goodbye to bad habits',
      ]) {
        expect(strong.hasMatch(text), isFalse, reason: text);
      }
    });

    test('trailing closer closes multi-phrase utterances', () {
      expect(
        ConversationEndPhrases.endsWithStrongCloser(
          'thanks all, see you tomorrow, bye',
          'en',
        ),
        isTrue,
      );
      expect(
        ConversationEndPhrases.endsWithStrongCloser(
          'I said thanks and left',
          'en',
        ),
        isFalse,
      );
    });

    test('soft words match soft only', () {
      expect(soft.hasMatch('okay'), isTrue);
      expect(strong.hasMatch('okay'), isFalse);
    });
  });

  group('Indic strong closers finish a memory', () {
    const cases = {
      'hi': ['धन्यवाद', 'बहुत-बहुत धन्यवाद', 'अलविदा', 'फिर मिलेंगे'],
      'kn': ['ಧನ್ಯವಾದಗಳು', 'ವಿದಾಯ', 'ಮತ್ತೆ ಸಿಗೋಣ'],
      'ta': ['நன்றி', 'மிக்க நன்றி', 'விடைபெறுகிறேன்'],
      'te': ['ధన్యవాదాలు', 'వీడ్కోలు', 'మళ్ళీ కలుద్దాం'],
      'ml': ['നന്ദി', 'വിട', 'വീണ്ടും കാണാം'],
      'bn': ['ধন্যবাদ', 'বিদায়', 'আবার দেখা হবে'],
      'mr': ['धन्यवाद', 'निरोप घेतो', 'पुन्हा भेटू'],
      'gu': ['આભાર', 'વિદાય', 'ફરી મળીશું'],
    };
    cases.forEach((code, texts) {
      test('$code bare closers match', () {
        final strong = ConversationEndPhrases.strongPattern(code)!;
        for (final text in texts) {
          expect(strong.hasMatch(text), isTrue, reason: text);
        }
      });
    });
  });

  group('greetings alone never close', () {
    // Each doubles as hello AND goodbye: must be in no strong list.
    const greetings = {
      'hi': 'नमस्ते',
      'kn': 'ನಮಸ್ಕಾರ',
      'ta': 'வணக்கம்',
      'te': 'నమస్కారం',
      'ml': 'നമസ്കാരം',
      'bn': 'নমস্কার',
      'mr': 'नमस्कार',
      'gu': 'નમસ્તે',
    };
    greetings.forEach((code, greeting) {
      test('$code greeting matches nothing strong', () {
        expect(
          ConversationEndPhrases.strongPattern(code)!.hasMatch(greeting),
          isFalse,
        );
        expect(
          ConversationEndPhrases.endsWithStrongCloser(greeting, code),
          isFalse,
        );
      });
    });
  });

  group('Indic soft arms the timer only', () {
    const softCases = {
      'hi': 'ठीक है',
      'kn': 'ಸರಿ',
      'ta': 'சரி',
      'te': 'సరే',
      'ml': 'ശരി',
      'bn': 'ঠিক আছে',
      'mr': 'ठीक आहे',
      'gu': 'બરાબર',
    };
    softCases.forEach((code, word) {
      test('$code soft matches soft, never strong', () {
        expect(
          ConversationEndPhrases.softPattern(code)!.hasMatch(word),
          isTrue,
        );
        expect(
          ConversationEndPhrases.strongPattern(code)!.hasMatch(word),
          isFalse,
        );
      });
    });
  });

  group('unknown codes degrade safely', () {
    test('no tables, no crash', () {
      expect(ConversationEndPhrases.strongPattern('xx'), isNull);
      expect(ConversationEndPhrases.softPattern('xx'), isNull);
      expect(
        ConversationEndPhrases.endsWithStrongCloser('bye', 'xx'),
        isFalse,
      );
    });
  });
}
