import 'package:flutter_test/flutter_test.dart';
import 'package:tanu_app/config/conversation_end_phrases.dart';

// Verbatim originals from conversation_provider.dart (pre-move).
final origStrong = RegExp(
  r'^(?:okay|ok|alright|well|so)?\s*(?:thank you|thanks(?: a lot| so much| everyone| all)?|'
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
  r'thanks everybody|thank you everyone)\b[.!\s]*$',
  caseSensitive: false,
);
final origSoft = RegExp(
  r'^(?:great|okay|ok|right|well|so|alright|cool|nice|perfect|understood|sure|fine|'
  r'works for me|that works|sounds good|no problem|no worries|all right|'
  r'yeah|yes|maybe|hmm|uh|mm)[.!?…\s]*$',
  caseSensitive: false,
);

String clean(String u) => u.replaceAll(RegExp(r'[.!?…,"\s]+$'), '').trim();

void main() {
  test('moved English tables match originals on tricky inputs', () {
    final inputs = [
      'thanks', 'okay thanks', 'THANKS', 'Thanks!', 'thanksgiving',
      'thanks a lot', 'thanks so much', 'thanks everyone', 'thanks all',
      'got it, thanks', 'bye', 'byeee', 'BYE', 'goodbye', 'goodbye cruel world',
      'see you', 'see ya later', 'farewell', 'take care', 'talk soon',
      'catch you later', "that's all", "that's all for today",
      "that's enough", "we're done", "we're wrapped up", "i'm done",
      "let's call it a day", "let's wrap up", 'end of meeting',
      'meeting adjourned', "let's end here", 'perfect, thanks',
      'great thanks', 'sounds good, thank you', 'agreed, thanks',
      "i think that's it", 'no questions', 'no more questions',
      'no more questions for john doe', 'any other business',
      "i'll let you go", 'i appreciate your time', 'have a good day',
      'have a great one', 'thanks everybody', 'thank you everyone',
      'ok', 'okay', 'yeah', 'yes', 'maybe...', 'hmm', 'sounds good',
      'no problem', 'works for me', 'hello world', 'I said thanks and left',
      'thank you', 'thank you very much',
    ];
    final movedStrong = ConversationEndPhrases.strongPattern('en')!;
    final movedSoft = ConversationEndPhrases.softPattern('en')!;
    for (final input in inputs) {
      final c = clean(input);
      expect(movedStrong.hasMatch(c), origStrong.hasMatch(c),
          reason: 'strong: $input');
      expect(movedSoft.hasMatch(c), origSoft.hasMatch(c),
          reason: 'soft: $input');
    }
  });
}
