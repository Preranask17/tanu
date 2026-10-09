import 'package:flutter_test/flutter_test.dart';
import 'package:tanu_app/models/transcript.dart';
import 'package:tanu_app/services/rag/memory_indexer.dart';

ConversationSession _session(String? cleaned) => ConversationSession(
      id: 's1',
      title: 'Demo title',
      startedAt: DateTime(2026, 1, 1),
      cleanedTranscript: cleaned,
    );

void main() {
  group('chunkStatic cleaned path', () {
    test('splits on sentences with overlap and min-slice filter', () {
      final text = List.generate(
        30,
        (i) => 'Sentence number $i carries enough words to matter. ',
      ).join();
      final chunks = MemoryIndexer.chunkStatic(_session(text));
      expect(chunks.length, greaterThan(1));
      for (final c in chunks) {
        expect(c.text.length, greaterThanOrEqualTo(20));
        expect(c.text.length, lessThanOrEqualTo(1000 + 150));
        expect(c.sessionId, 's1');
        expect(c.title, 'Demo title');
      }
      // Overlap: second chunk shares words with the first chunk's tail.
      final firstWords = chunks[0].text.split(' ');
      final secondWords = chunks[1].text.split(' ');
      final tail = firstWords.sublist(firstWords.length > 10
          ? firstWords.length - 10
          : 0);
      expect(
        secondWords.take(15).any((w) => tail.contains(w)),
        isTrue,
      );
    });

    test('single short transcript yields one chunk', () {
      final chunks = MemoryIndexer.chunkStatic(
        _session('Hello world, this is a real memory with content.'),
      );
      expect(chunks.length, 1);
    });

    test('filler-only transcript yields no chunks', () {
      final chunks = MemoryIndexer.chunkStatic(_session('hi. ok.'));
      expect(chunks, isEmpty);
    });
  });
}
