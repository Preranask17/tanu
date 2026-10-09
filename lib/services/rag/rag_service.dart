import '../../abstractions/agent_engine.dart';
import '../agent/gemini_agent_engine.dart';
import '../../constants.dart';
import 'embedding_service.dart';
import 'vector_store.dart';

/// Answer to a RAG question, with the chunks that grounded it.
class RagAnswer {
  const RagAnswer({required this.answer, required this.sources});

  final String answer;
  final List<ScoredChunk> sources;
}

class RagService {
  RagService(this._embeddings, this._store, this._engine);

  final EmbeddingService _embeddings;
  final VectorStore _store;
  final GeminiAgentEngine _engine;

  /// Bounded LRU of recent query embeddings: query text + time.
  final Map<String, ({List<double> vector, DateTime at})> _queryCache = {};

  Future<RagAnswer> answer(String question, {String? sessionId}) async {
    final cached = _queryCache[question];
    final List<double> queryVector;
    if (cached != null &&
        DateTime.now().difference(cached.at).inSeconds <
            kRagQueryCacheTtlSeconds) {
      queryVector = cached.vector;
    } else {
      queryVector = await _embeddings.embedQuery(question);
      _queryCache[question] = (vector: queryVector, at: DateTime.now());
      if (_queryCache.length > 10) {
        _queryCache.remove(_queryCache.keys.first);
      }
    }

    final topK = sessionId == null ? kRagTopK : kRagTopKSession;
    final matches = _store.query(queryVector, topK, sessionId: sessionId);

    if (matches.isEmpty || matches.first.distance > kRagMinDistance) {
      return RagAnswer(
        answer: 'I could not find anything about that in your memories yet.',
        sources: const [],
      );
    }

    final contextBuffer = StringBuffer();
    for (final m in matches) {
      final header = m.chunk.title.isNotEmpty
          ? m.chunk.title
          : m.chunk.sessionId;
      // Cleaned-transcript chunks all carry startMs 0 — a meaningless
      // offset. Only show the timestamp when it is real provenance.
      final slice = m.chunk.startMs > 0
          ? '[memory $header @ ${m.chunk.startMs}ms]\n${m.chunk.text}\n\n'
          : '[memory $header]\n${m.chunk.text}\n\n';
      if (contextBuffer.length + slice.length > kRagContextMaxChars) break;
      contextBuffer.write(slice);
    }

    final reply = await _engine.prompt(
      'Context from the user\'s memories:\n$contextBuffer\nQuestion: $question',
      history: [
        const ChatMessage(
          role: 'system',
          content:
              'You are Tanu, answering questions about the user\'s own memories. '
              'Use ONLY the provided transcript excerpts. If the answer is not in '
              'the excerpts, say so honestly. Be concise.',
        ),
      ],
    );

    return RagAnswer(answer: reply, sources: matches);
  }
}
