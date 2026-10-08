import '../../constants.dart';
import '../../models/transcript.dart';
import 'embedding_service.dart';
import 'vector_store.dart';

/// Chunks sessions into embeddable text and indexes them in the VectorStore.
class MemoryIndexer {
  MemoryIndexer(this._embeddings, this._store);

  final EmbeddingService _embeddings;
  final VectorStore _store;

  /// Split a session into chunks: prefers the cleaned transcript, falls back
  /// to timestamped segments. Chunks are <= [kRagChunkMaxChars].
  /// Static and pure (never touches embeddings/store) so it is unit-tested.
  static List<MemoryChunk> chunkStatic(ConversationSession session) {
    final chunks = <MemoryChunk>[];

    final cleaned = session.cleanedTranscript?.trim();
    if (cleaned != null && cleaned.isNotEmpty) {
      final sentences = cleaned.split(RegExp(r'(?<=[.!?\n])\s+'));
      final buffer = StringBuffer();
      String? previousTail;
      int index = 0;

      for (final sentence in sentences) {
        if (buffer.length + sentence.length > kRagChunkMaxChars &&
            buffer.isNotEmpty) {
          final text = buffer.toString().trim();
          if (text.length >= kRagMinSliceChars) {
            chunks.add(MemoryChunk(
              id: '${session.id}:$index',
              sessionId: session.id,
              text: text,
              startMs: 0,
          title: session.title,
            ));
            index++;
            previousTail = text.length > kRagChunkOverlapChars
                ? text.substring(text.length - kRagChunkOverlapChars)
                : text;
          }
          buffer.clear();
          if (previousTail != null) {
            buffer.write(previousTail);
            buffer.write(' ');
          }
        }
        buffer.write(sentence);
        buffer.write(' ');
      }
      final tail = buffer.toString().trim();
      if (tail.length >= kRagMinSliceChars) {
        chunks.add(MemoryChunk(
          id: '${session.id}:$index',
          sessionId: session.id,
          text: tail,
          startMs: 0,
          title: session.title,
        ));
      }
      return chunks;
    }

    var group = <TranscriptSegment>[];
    void flush() {
      if (group.isEmpty) return;
      final text = group.map((s) => s.text.trim()).join(' ').trim();
      if (text.isNotEmpty) {
        chunks.add(MemoryChunk(
          id: '${session.id}:${chunks.length}',
          sessionId: session.id,
          text: text,
          startMs: group.first.startMs,
          title: session.title,
        ));
      }
      group = [];
    }

    for (final seg in session.segments) {
      final current = group.map((s) => s.text).join(' ');
      final lastEnd = group.isEmpty ? 0 : (group.last.endMs ?? group.last.startMs);
      if (group.isNotEmpty &&
          (seg.startMs - lastEnd >= 3000 ||
              current.length + seg.text.length > kRagChunkMaxChars)) {
        flush();
      }
      group.add(seg);
    }
    flush();
    return chunks;
  }

  /// Instance delegate for the pure static chunker.
  List<MemoryChunk> chunkSession(ConversationSession session) =>
      chunkStatic(session);

  Future<int> indexSession(ConversationSession session) async {
    final chunks = chunkSession(session);
    if (chunks.isEmpty) return 0;

    // Skip unchanged sessions that already have chunks indexed.
    if (_store.hasSession(session.id)) {
      return 0;
    }

    var embedded = 0;
    for (var i = 0; i < chunks.length; i += kRagEmbedBatchSize) {
      final batch = chunks.sublist(
        i,
        (i + kRagEmbedBatchSize).clamp(0, chunks.length),
      );
      final vectors = await _embeddings
          .embedDocuments(batch.map((c) => c.text).toList());
      _store.upsertChunks(batch, vectors);
      embedded += batch.length;
    }
    return embedded;
  }

  /// Backfill sessions missing from the store, capped per call so the UI
  /// stays responsive. Retries can call it again on later launches.
  Future<void> backfill(List<ConversationSession> sessions, {int maxSessions = 5}) async {
    var indexed = 0;
    for (final s in sessions) {
      if (indexed >= maxSessions) return;
      if (_store.hasSession(s.id)) continue;
      try {
        final n = await indexSession(s);
        if (n > 0) indexed++;
      } catch (_) {
        // Skip sessions that fail (e.g. offline) — they can be retried later.
      }
    }
  }
}
