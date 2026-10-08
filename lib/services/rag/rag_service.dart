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

  Future<RagAnswer> answer(String question, {String? sessionId}) async {
    final queryVector = await _embeddings.embedQuery(question);
    final matches = _store.query(queryVector, kRagTopK, sessionId: sessionId);

    if (matches.isEmpty) {
      return RagAnswer(
        answer: 'I could not find anything about that in your memories yet.',
        sources: const [],
      );
    }

    final context = matches
        .map((m) => '[memory ${m.chunk.sessionId} @ ${m.chunk.startMs}ms]\n${m.chunk.text}')
        .join('\n\n');

    final reply = await _engine.prompt(
      'Context from the user\'s memories:\n$context\n\nQuestion: $question',
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
