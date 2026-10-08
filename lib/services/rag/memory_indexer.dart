import '../../constants.dart';
import '../../models/transcript.dart';
import 'embedding_service.dart';
import 'vector_store.dart';

/// Chunks sessions into embeddable text and indexes them in the VectorStore.
class MemoryIndexer {
  MemoryIndexer(this._embeddings, this._store);

  final EmbeddingService _embeddings;
  final VectorStore _store;

  /// Split a session into chunks, richest source first:
  /// 1. structured speaker turns (each line self-describing as
  ///    `Speaker: text`, chunk attributed to its starting speaker), plus a
  ///    summary gist chunk so "what was that meeting about" retrieves the
  ///    point without wading through verbatim;
  /// 2. the cleaned transcript;
  /// 3. raw timestamped segments.
  List<MemoryChunk> chunkSession(ConversationSession session) {
    if (session.turns.isNotEmpty) return chunkTurns(session);

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

  /// Chunks structured speaker turns. Every line is prefixed with its
  /// speaker (`You: …`), so chunks stay attributable even after retrieval
  /// reorders them; each chunk records the speaker of its first line.
  /// A leading summary gist chunk captures the point of the memory for
  /// "what was that about" questions. Static (and side-effect free) so the
  /// chunking contract is unit-testable without embeddings or SQLite.
  static List<MemoryChunk> chunkTurns(ConversationSession session) {
    final chunks = <MemoryChunk>[];
    final title = session.title;
    var index = 0;

    final gist = [
      title.trim(),
      (session.summary ?? '').trim(),
    ].where((s) => s.isNotEmpty).join('. ');
    if (gist.length >= kRagMinSliceChars) {
      chunks.add(
        MemoryChunk(
          id: '${session.id}:summary',
          sessionId: session.id,
          text: gist,
          startMs: 0,
          title: title,
        ),
      );
    }

    // Merge consecutive same-speaker turns into runs; a run is the atomic
    // unit — chunks never cut mid-sentence inside one speaker's flow unless
    // the run itself exceeds the cap (then it splits on sentences).
    final runs = <_TurnRun>[];
    for (final t in session.turns) {
      final text = t.text.trim();
      if (text.isEmpty) continue;
      if (runs.isNotEmpty && runs.last.speaker == t.speaker) {
        runs.last.text = '${runs.last.text} $text';
      } else {
        runs.add(_TurnRun(speaker: t.speaker, text: text, startMs: t.startMs));
      }
    }

    final buffer = StringBuffer();
    var bufEmpty = true;
    var chunkSpeaker = '';
    var chunkStart = 0;
    var lastSpeaker = '';
    var lastStart = 0;

    void flush() {
      final text = buffer.toString().trim();
      buffer.clear();
      bufEmpty = true;
      if (text.length >= kRagMinSliceChars) {
        chunks.add(
          MemoryChunk(
            id: '${session.id}:$index',
            sessionId: session.id,
            text: text,
            startMs: chunkStart,
            title: title,
            speaker: chunkSpeaker,
          ),
        );
        index++;
        // Overlap: carry the tail re-tagged with its speaker so the next
        // chunk's embedding still sees who was talking.
        final tail = text.length > kRagChunkOverlapChars
            ? text.substring(text.length - kRagChunkOverlapChars)
            : text;
        buffer.write('$lastSpeaker: ...$tail\n');
        bufEmpty = false;
        chunkSpeaker = lastSpeaker;
        chunkStart = lastStart;
      } else {
        chunkSpeaker = '';
      }
    }

    for (final run in runs) {
      for (final piece in _splitLong(run.text)) {
        final line = '${run.speaker}: $piece\n';
        if (!bufEmpty && buffer.length + line.length > kRagChunkMaxChars) {
          flush();
        }
        if (bufEmpty) {
          chunkSpeaker = run.speaker;
          chunkStart = run.startMs;
          bufEmpty = false;
        }
        buffer.write(line);
        lastSpeaker = run.speaker;
        lastStart = run.startMs;
      }
    }
    flush();
    return chunks;
  }

  /// Splits an over-long run on sentence boundaries into pieces that each
  /// fit the chunk cap. Short text passes through untouched.
  static List<String> _splitLong(String text) {
    if (text.length <= kRagChunkMaxChars) return [text];
    final sentences = text.split(RegExp(r'(?<=[.!?\n])\s+'));
    final pieces = <String>[];
    final buffer = StringBuffer();
    for (final s in sentences) {
      if (buffer.isNotEmpty &&
          buffer.length + s.length + 1 > kRagChunkMaxChars) {
        pieces.add(buffer.toString().trim());
        buffer.clear();
      }
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(s);
    }
    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) pieces.add(tail);
    // A single pathological sentence longer than the cap still gets a chunk.
    if (pieces.isEmpty) pieces.add(text);
    return pieces;
  }

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

  /// Replaces a session's chunks wholesale, then indexes fresh. Used after
  /// memory processing: a session first indexed from raw segments (or from
  /// an older pipeline generation) gets speaker-attributed turn chunks and
  /// a summary gist instead of accumulating stale duplicates.
  Future<int> reindexSession(ConversationSession session) async {
    _store.deleteSession(session.id);
    return indexSession(session);
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

/// One speaker's uninterrupted run inside [MemoryIndexer.chunkTurns].
class _TurnRun {
  _TurnRun({required this.speaker, required this.text, required this.startMs});

  final String speaker;
  String text;
  final int startMs;
}
