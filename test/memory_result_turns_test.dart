import 'package:flutter_test/flutter_test.dart';
import 'package:tanu_app/services/agent/gemini_agent_engine.dart';

/// Guards the structured memory contract: [GeminiMemoryProcessor.parseMemoryJson]
/// must extract turns alongside title/summary/commitments, and degrade to a
/// retriable error (never silent garbage) on malformed model output.
void main() {
  group('GeminiMemoryProcessor.parseMemoryJson', () {
    test('parses turns with timestamps and speakers', () {
      final result = GeminiMemoryProcessor.parseMemoryJson('''
{
  "title": "Lunch plan",
  "summary": "Decided on tacos.",
  "cleaned_transcript": "You: tacos then. Other 1: sounds good.",
  "turns": [
    {"speaker": "You", "start_ms": 0, "end_ms": 2000, "text": "tacos then"},
    {"speaker": "Other 1", "start_ms": 2500, "end_ms": 4000, "text": "sounds good"}
  ],
  "commitments": []
}
''');

      expect(result.error, isNull);
      expect(result.title, 'Lunch plan');
      expect(result.summary, 'Decided on tacos.');
      expect(result.turns.length, 2);
      expect(result.turns.first.speaker, 'You');
      expect(result.turns.first.startMs, 0);
      expect(result.turns.first.endMs, 2000);
      expect(result.turns.last.speaker, 'Other 1');
    });

    test('strips markdown fences the model adds anyway', () {
      final result = GeminiMemoryProcessor.parseMemoryJson(
        '```json\n{"title": "T", "summary": "S", "turns": []}\n```',
      );

      expect(result.error, isNull);
      expect(result.title, 'T');
      expect(result.turns, isEmpty);
    });

    test('drops empty-text turns and defaults blank speakers', () {
      final result = GeminiMemoryProcessor.parseMemoryJson(
        '{"title": "T", "summary": "S", "turns": ['
        '{"speaker": "", "text": "  "},'
        '{"speaker": "", "text": "kept"}'
        ']}',
      );

      expect(result.error, isNull);
      expect(result.turns.length, 1);
      expect(result.turns.first.speaker, 'Other 1');
      expect(result.turns.first.text, 'kept');
    });

    test('missing turns array means text-only legacy output', () {
      final result = GeminiMemoryProcessor.parseMemoryJson(
        '{"title": "T", "summary": "S"}',
      );

      expect(result.error, isNull);
      expect(result.turns, isEmpty);
    });

    test('non-JSON output is a retriable error, not garbage', () {
      final result = GeminiMemoryProcessor.parseMemoryJson(
        'Sorry, I cannot do that right now.',
      );

      expect(result.error, isNotNull);
      expect(result.turns, isEmpty);
    });

    test('parses commitments alongside turns', () {
      final result = GeminiMemoryProcessor.parseMemoryJson(
        '{"title": "T", "summary": "S", "turns": [], '
        '"commitments": [{"is_commitment": true, "action": "call mom", '
        '"person": "mom", "due": "2026-10-09"}]}',
      );

      expect(result.error, isNull);
      expect(result.commitments.length, 1);
      expect(result.commitments.first.action, 'call mom');
    });
  });
}
