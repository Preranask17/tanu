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
      // Speaker provenance travels with the excerpt so answers can say who
      // said what ("You" is the wearer; "Other N" is session-local).
      final who = m.chunk.speaker.trim().isNotEmpty
          ? ' · says ${m.chunk.speaker.trim()}'
          : '';
      final slice =
          '[memory $header @ ${m.chunk.startMs}ms$who]\n${m.chunk.text}\n\n';
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
              'the excerpts, say so honestly. Be concise. '
              'Excerpts are tagged with who said each line ("You" is the user '
              'wearing the pendant; "Other N" labels are local to one memory, '
              'never the same person across memories): attribute claims to '
              'their speaker, e.g. "You said…" or "Ramesh said…" is wrong — '
              'say "the other person said…" unless a name was spoken.',
        ),
      ],
    );

    return RagAnswer(answer: reply, sources: matches);
  }
}
