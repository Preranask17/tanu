import 'package:flutter_test/flutter_test.dart';
import 'package:tanu_app/models/transcript.dart';
import 'package:tanu_app/services/rag/memory_indexer.dart';

/// Guards speaker-aware chunking: the summary gist, per-line speaker
/// prefixes, chunk speaker attribution, and the size cap. Retrieval quality
/// ("what did the other person say?") stands or falls here.
ConversationSession _session({
  String title = 'Lunch plan',
  String? summary = 'Decided on tacos.',
  required List<TranscriptTurn> turns,
}) {
  return ConversationSession(
    id: 's1',
    title: title,
    startedAt: DateTime(2026, 1, 1),
    summary: summary,
    turns: turns,
  );
}

void main() {
  group('MemoryIndexer.chunkTurns', () {
    test('summary gist chunk comes first', () {
      final chunks = MemoryIndexer.chunkTurns(
        _session(turns: const [
          TranscriptTurn(speaker: 'You', text: 'tacos then', startMs: 0),
        ]),
      );

      expect(chunks.first.id, 's1:summary');
      expect(chunks.first.text, contains('Lunch plan'));
      expect(chunks.first.text, contains('Decided on tacos.'));
    });

    test('lines are speaker-prefixed and chunks attributed', () {
      final chunks = MemoryIndexer.chunkTurns(
        _session(
          summary: null,
          title: '',
          turns: const [
            TranscriptTurn(speaker: 'You', text: 'let us go', startMs: 0),
            TranscriptTurn(speaker: 'Other 1', text: 'where to', startMs: 2000),
          ],
        ),
      );

      expect(chunks.length, 1);
      expect(chunks.first.text, contains('You: let us go'));
      expect(chunks.first.text, contains('Other 1: where to'));
      expect(chunks.first.speaker, 'You');
      expect(chunks.first.startMs, 0);
    });

    test('consecutive same-speaker turns merge into one run', () {
      final chunks = MemoryIndexer.chunkTurns(
        _session(
          summary: null,
          title: '',
          turns: const [
            TranscriptTurn(speaker: 'You', text: 'first thought', startMs: 0),
            TranscriptTurn(
              speaker: 'You',
              text: 'second thought',
              startMs: 3000,
            ),
          ],
        ),
      );

      expect(chunks.length, 1);
      expect(chunks.first.text, 'You: first thought second thought');
    });

    test('long sessions split under the char cap with speaker tags kept', () {
      final turns = List<TranscriptTurn>.generate(
        40,
        (i) => TranscriptTurn(
          speaker: i.isEven ? 'You' : 'Other 1',
          text:
              'this is turn number $i with enough words to push the total length well past the chunk cap',
          startMs: i * 3000,
        ),
      );
      final chunks = MemoryIndexer.chunkTurns(_session(turns: turns));

      expect(chunks.length, greaterThan(2));
      for (final c in chunks) {
        if (c.id.endsWith(':summary')) continue;
        expect(c.text.length, lessThanOrEqualTo(1000 + 200));
        expect(c.speaker, isNotEmpty);
      }
    });

    test('tiny fragments below the slice floor are dropped', () {
      final chunks = MemoryIndexer.chunkTurns(
        _session(
          summary: null,
          title: '',
          turns: const [
            TranscriptTurn(speaker: 'You', text: 'ok', startMs: 0),
          ],
        ),
      );

      expect(chunks, isEmpty);
    });

    test('turns round-trip through session JSON', () {
      final session = _session(turns: const [
        TranscriptTurn(speaker: 'Other 2', text: 'hi', startMs: 5, endMs: 9),
      ]);
      final restored = ConversationSession.fromJson(session.toJson());

      expect(restored.turns.length, 1);
      expect(restored.turns.first.speaker, 'Other 2');
      expect(restored.turns.first.startMs, 5);
      expect(restored.turns.first.endMs, 9);
    });

    test('legacy JSON without turns loads as empty', () {
      final restored = ConversationSession.fromJson({
        'id': 'old',
        'title': 't',
        'status': 'completed',
        'segments': [],
      });

      expect(restored.turns, isEmpty);
    });
  });
}
