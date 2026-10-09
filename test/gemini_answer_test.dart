import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tanu_app/services/agent/gemini_agent_engine.dart';
import 'package:tanu_app/services/agent/mistral_agent_engine.dart'
    show AgentException;

void main() {
  policyHelperTests();

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

void policyHelperTests() {
  group('throttle/retry policy helpers', () {
    test('only transient failures retry', () {
      expect(isTransientGeminiFailure(statusCode: 429), isTrue);
      expect(isTransientGeminiFailure(statusCode: 500), isTrue);
      expect(isTransientGeminiFailure(statusCode: 503), isTrue);
      expect(isTransientGeminiFailure(statusCode: 400), isFalse);
      expect(isTransientGeminiFailure(statusCode: 401), isFalse);
      expect(isTransientGeminiFailure(statusCode: 404), isFalse);
      expect(
        isTransientGeminiFailure(error: TimeoutException('t')),
        isTrue,
      );
      expect(
        isTransientGeminiFailure(error: http.ClientException('boom')),
        isTrue,
      );
      expect(isTransientGeminiFailure(error: StateError('x')), isFalse);
      expect(isTransientGeminiFailure(), isFalse);
    });

    test('backoff honors server hint, else 5s then 15s', () {
      expect(chatBackoffFor(0), const Duration(seconds: 5));
      expect(chatBackoffFor(1), const Duration(seconds: 15));
      expect(
        chatBackoffFor(0, serverHint: const Duration(seconds: 20)),
        const Duration(seconds: 20),
      );
      expect(
        chatBackoffFor(1, serverHint: const Duration(seconds: 20)),
        const Duration(seconds: 20),
      );
    });

    test('transcript cap keeps head and tail with a marker', () {
      const short = 'hello world';
      expect(capPromptTranscript(short), same(short));
      final long = List.filled(20000, 'w').join();
      final capped = capPromptTranscript(long);
      expect(capped.length, lessThan(long.length));
      expect(capped.startsWith('ww'), isTrue);
      expect(capped.endsWith('ww'), isTrue);
      expect(capped, contains('omitted'));
    });

    test('fnv1a32 is deterministic and discriminating', () {
      expect(fnv1a32('abc'), fnv1a32('abc'));
      expect(fnv1a32('abc'), isNot(fnv1a32('abd')));
      expect(fnv1a32(''), isNot(fnv1a32(' ')));
    });
  });
}
