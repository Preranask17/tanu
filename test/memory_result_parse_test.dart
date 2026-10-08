import 'package:flutter_test/flutter_test.dart';
import 'package:tanu_app/services/agent/gemini_agent_engine.dart';

void main() {
  group('parseMemoryResult', () {
    test('parses bare JSON with all fields', () {
      final r = GeminiMemoryProcessor.parseMemoryResult(
        '{"title": "Project sync", "summary": "Agreed Friday.", '
        '"cleaned_transcript": "Speaker 1: Agreed Friday.", '
        '"commitments": [{"is_commitment": true, "action": "send report"}]}',
      );
      expect(r.title, 'Project sync');
      expect(r.summary, 'Agreed Friday.');
      expect(r.cleanedTranscript, contains('Speaker 1'));
      expect(r.commitments.length, 1);
      expect(r.commitments.first.action, 'send report');
    });

    test('strips markdown fences', () {
      final r = GeminiMemoryProcessor.parseMemoryResult(
        '```json\n{"title": "T", "summary": "S", "commitments": []}\n```',
      );
      expect(r.title, 'T');
      expect(r.summary, 'S');
    });

    test('prose without JSON is a retry-queue failure marker', () {
      final r = GeminiMemoryProcessor.parseMemoryResult(
        'Sorry, I could not do that.',
      );
      expect(r.summary, 'Could not parse response');
    });

    test('malformed JSON is a failure marker', () {
      final r = GeminiMemoryProcessor.parseMemoryResult('{"title": ');
      expect(r.summary, 'Could not parse response');
    });
  });
}
