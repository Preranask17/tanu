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
  List<MemoryChunk> chunkSession(ConversationSession session) {
    final chunks = <MemoryChunk>[];

    final cleaned = session.cleanedTranscript?.trim();
    if (cleaned != null && cleaned.isNotEmpty) {
      var start = 0;
      var index = 0;
      while (start < cleaned.length) {
        var end = start + kRagChunkMaxChars;
        if (end < cleaned.length) {
          final newline = cleaned.lastIndexOf('\n', end);
          final period = cleaned.lastIndexOf('. ', end);
          final cut = newline > start ? newline : (period > start ? period + 1 : -1);
          if (cut > start) end = cut;
        } else {
          end = cleaned.length;
        }
        chunks.add(MemoryChunk(
          id: '${session.id}:$index',
          sessionId: session.id,
          text: cleaned.substring(start, end).trim(),
          startMs: 0,
        ));
        index++;
        start = end;
        while (start < cleaned.length && cleaned[start] == '\n') {
          start++;
        }
      }
      return chunks.where((c) => c.text.isNotEmpty).toList();
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

  Future<int> indexSession(ConversationSession session) async {
    final chunks = chunkSession(session);
    if (chunks.isEmpty) return 0;
    final vectors = await _embeddings.embedDocuments(chunks.map((c) => c.text).toList());
    _store.upsertChunks(chunks, vectors);
    return chunks.length;
  }

  /// Backfill every session missing from the store. Cheap no-op when indexed.
  Future<void> backfill(List<ConversationSession> sessions) async {
    if (_store.chunkCount > 0) return;
    for (final s in sessions) {
      try {
        await indexSession(s);
      } catch (_) {
        // Skip sessions that fail (e.g. offline) — they can be retried later.
      }
    }
  }
}
