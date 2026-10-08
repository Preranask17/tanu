import 'package:flutter_test/flutter_test.dart';
import 'package:tanu_app/services/agent/gemini_agent_engine.dart';
import 'package:tanu_app/services/agent/mistral_agent_engine.dart'
    show AgentException;

void main() {
  Map<String, dynamic> response(List<Map<String, dynamic>> parts) => {
    'candidates': [
      {
        'content': {'parts': parts},
      },
    ],
  };

  group('extractGeminiAnswerText', () {
    test('skips leading thought parts, returns the answer', () {
      expect(
        extractGeminiAnswerText(
          response([
            {'thought': true, 'text': 'Let me think about {"title"...'},
            {'text': '{"title": "Project sync"}'},
          ]),
        ),
        '{"title": "Project sync"}',
      );
    });

    test('plain answer without thought parts still works', () {
      expect(
        extractGeminiAnswerText(
          response([
            {'text': '  {"title": "Hi"}  '},
          ]),
        ),
        '{"title": "Hi"}',
      );
    });

    test('skips empty texts, throws when only thoughts remain', () {
      expect(
        () => extractGeminiAnswerText(
          response([
            {'thought': true, 'text': 'reasoning'},
          ]),
        ),
        throwsA(isA<AgentException>()),
      );
    });

    test('throws on missing candidates and empty parts', () {
      expect(
        () => extractGeminiAnswerText({'candidates': []}),
        throwsA(isA<AgentException>()),
      );
      expect(
        () => extractGeminiAnswerText({
          'candidates': [
            {
              'content': {'parts': []},
            },
          ],
        }),
        throwsA(isA<AgentException>()),
      );
    });
  });
}
