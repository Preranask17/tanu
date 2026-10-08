import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../abstractions/agent_engine.dart';
import '../../constants.dart';
import '../rag/rate_limiter.dart';
import 'mistral_agent_engine.dart' show AgentException;

/// Throttle + retry policy shared by every chat-path Gemini call
/// (structuring, memory chat, RAG answers). The embeddings path already
/// paces itself; this is the same discipline for the prompt path so one
/// 429 can no longer start a retry death spiral.
RateLimiter get chatRateLimiter => _chatLimiter;
final RateLimiter _chatLimiter =
    RateLimiter(Duration(milliseconds: kGeminiMinGapChatMs));

/// True for failures worth retrying: rate limits, server errors, transport
/// timeouts. Everything else (bad key, bad request, deterministic shape
/// errors) fails fast — resending never helps those.
bool isTransientGeminiFailure({int? statusCode, Object? error}) {
  if (statusCode != null) {
    return statusCode == 429 || statusCode >= 500;
  }
  return error is TimeoutException || error is http.ClientException;
}

/// Backoff before retry number [attempt] (0-based): the server's
/// `retryDelay` hint wins when present, else 5 s then 15 s.
Duration chatBackoffFor(int attempt, {Duration? serverHint}) {
  if (serverHint != null) return serverHint;
  return attempt <= 0 ? const Duration(seconds: 5) : const Duration(seconds: 15);
}

/// Token budget for a single prompt: head-biased cut that keeps the opening
/// (topic) and the tail (where closers and commitments usually land),
/// with an explicit marker so the model knows middle is missing.
String capPromptTranscript(String text) {
  if (text.length <= kGeminiPromptMaxChars) return text;
  final head = text.substring(0, kGeminiPromptHeadChars);
  final tail = text.substring(text.length - kGeminiPromptTailChars);
  return '$head\n…[${text.length - kGeminiPromptMaxChars} chars omitted]…\n$tail';
}

/// 32-bit FNV-1a: dependency-free content hash for the result cache.
int fnv1a32(String text) {
  var hash = 0x811c9dc5;
  for (var i = 0; i < text.length; i++) {
    hash ^= text.codeUnitAt(i);
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}

/// Agent backed by Google's Gemini generateContent API.
class GeminiAgentEngine implements AgentEngine {
  GeminiAgentEngine({
    String? apiKey,
    String? model,
    this.endpoint = kGeminiEndpoint,
    this.systemPrompt,
  })  : apiKey = apiKey ?? kGeminiApiKey,
        model = model ?? kGeminiModel;

  final String apiKey;
  final String model;
  final String endpoint;
  final String? systemPrompt;

  @override
  Future<String> prompt(String transcript, {List<ChatMessage>? history}) async {
    if (apiKey.isEmpty) {
      throw AgentException('Gemini API key is empty');
    }

    final contents = <Map<String, dynamic>>[];
    final systemBuffer = StringBuffer();
    if (systemPrompt != null) systemBuffer.writeln(systemPrompt);

    for (final m in history ?? const <ChatMessage>[]) {
      if (m.role == 'system') {
        systemBuffer.writeln(m.content);
      } else {
        contents.add({
          'role': m.role == 'assistant' ? 'model' : 'user',
          'parts': [
            {'text': m.content},
          ],
        });
      }
    }
    contents.add({
      'role': 'user',
      'parts': [
        {'text': transcript},
      ],
    });

    final body = jsonEncode({
      if (systemBuffer.isNotEmpty)
        'system_instruction': {
          'parts': [
            {'text': systemBuffer.toString().trim()},
          ],
        },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.6,
        'maxOutputTokens': 1024,
        'responseMimeType': 'application/json',
      },
    });

    try {
      var attempt = 0;
      while (true) {
        http.Response response;
        try {
          response = await _chatLimiter.run(
            () => http
                .post(
                  Uri.parse('$endpoint?key=$apiKey'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                  },
                  body: body,
                )
                .timeout(const Duration(seconds: 45)),
          );
        } on TimeoutException {
          if (attempt >= kGeminiChatMaxRetries) {
            throw AgentException('Gemini timed out');
          }
          await Future.delayed(chatBackoffFor(attempt));
          attempt++;
          continue;
        } catch (e) {
          if (e is http.ClientException && attempt < kGeminiChatMaxRetries) {
            await Future.delayed(chatBackoffFor(attempt));
            attempt++;
            continue;
          }
          throw AgentException('Network error calling Gemini: $e');
        }

        if (isTransientGeminiFailure(statusCode: response.statusCode)) {
          if (attempt >= kGeminiChatMaxRetries) {
            throw AgentException(
              'Gemini returned ${response.statusCode}: ${response.body}',
              statusCode: response.statusCode,
            );
          }
          await Future.delayed(
            chatBackoffFor(
              attempt,
              serverHint: retryDelayFromBody(response.body),
            ),
          );
          attempt++;
          continue;
        }

        if (response.statusCode != 200) {
          throw AgentException(
            'Gemini returned ${response.statusCode}: ${response.body}',
            statusCode: response.statusCode,
          );
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return extractGeminiAnswerText(decoded);
      }
    } on AgentException {
      rethrow;
    } catch (e) {
      throw AgentException('Network error calling Gemini: $e');
    }
  }
}

/// Picks the answer text out of a generateContent response: the first
/// NON-thought text part. Thinking models lead with thought parts
/// ({'thought': true}); reading parts.first blindly parses thinking prose
/// as JSON and fails every memory. Pure, unit-tested.
String extractGeminiAnswerText(Map<String, dynamic> decoded) {
  final candidates = decoded['candidates'] as List<dynamic>?;
  if (candidates == null || candidates.isEmpty) {
    throw AgentException('Gemini returned no candidates');
  }
  final content =
      (candidates.first as Map<String, dynamic>)['content']
          as Map<String, dynamic>;
  final parts = content['parts'] as List<dynamic>?;
  if (parts == null || parts.isEmpty) {
    throw AgentException('Gemini returned empty content');
  }
  for (final part in parts) {
    final map = part as Map<String, dynamic>;
    if (map['thought'] == true) continue;
    final text = (map['text'] as String?)?.trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  throw AgentException('Gemini returned no answer text');
}

/// Typed result of commitment extraction.
class AgentCommitment {
  const AgentCommitment({
    required this.isCommitment,
    this.action,
    this.person,
    this.due,
  });

  final bool isCommitment;
  final String? action;
  final String? person;
  final String? due;
}

/// Typed result of memory processing.
class MemoryResult {
  const MemoryResult({
    required this.title,
    required this.summary,
    required this.commitments,
    this.cleanedTranscript = '',
  });

  final String title;
  final String summary;
  final List<AgentCommitment> commitments;

  /// The raw transcript rewritten into clean, speaker-labeled prose.
  final String cleanedTranscript;
}

/// Single-shot Gemini call that turns a raw transcript into a structured,
/// clean memory: title, summary, speaker-labeled cleaned transcript, and
/// extracted commitments.
class GeminiMemoryProcessor {
  GeminiMemoryProcessor(this._engine);

  final GeminiAgentEngine _engine;

  /// Structuring results keyed by content hash: queue re-runs and duplicate
  /// processing return instantly with zero API calls. Memory-only, bounded,
  /// TTL'd — never persisted (summaries live on their sessions instead).
  final Map<int, ({MemoryResult result, DateTime at})> _resultCache = {};

  Future<MemoryResult> process(
    String conversation, {
    bool bypassCache = false,
  }) async {
    final capped = capPromptTranscript(conversation);
    final key = fnv1a32(capped);
    if (!bypassCache) {
      final hit = _resultCache[key];
      if (hit != null &&
          DateTime.now().difference(hit.at).inMinutes <
              kGeminiResultCacheTtlMinutes) {
        return hit.result;
      }
    }
    try {
      final raw = await _engine.prompt(
        capped,
        history: [
          const ChatMessage(
            role: 'system',
            content: '''
You process a user's transcribed conversation memory.
Given the raw speech-to-text transcript, produce a structured memory.

Reply with ONLY a JSON object shaped exactly like this:
{
  "title": "A short 3-5 word title",
  "summary": "A 1-2 sentence concise summary.",
  "cleaned_transcript": "A clean rewrite of the full conversation: proper punctuation and capitalization, filler and jargon smoothed into clear sentences, attributed to speakers as 'Speaker 1:', 'Speaker 2:' etc. (or inferred names when obvious). Keep it faithful, do not invent content.",
  "commitments": [{"is_commitment": true, "action": "...", "person": "...", "due": "YYYY-MM-DD"}]
}
No commentary, no markdown fences.
''',
          ),
        ],
      );
      final result = _parse(raw);
      _storeResult(key, result);
      return result;
    } catch (e) {
      return MemoryResult(
        title: 'Memory',
        summary: 'Failed to process memory: $e',
        commitments: const [],
      );
    }
  }

  void _storeResult(int key, MemoryResult result) {
    _resultCache[key] = (result: result, at: DateTime.now());
    while (_resultCache.length > kGeminiResultCacheSize) {
      _resultCache.remove(_resultCache.keys.first);
    }
  }

  MemoryResult _parse(String raw) => parseMemoryResult(raw);

  /// Parses a structuring response into a [MemoryResult]. Fenced or bare
  /// JSON both parse (first `{` to last `}`); anything else is a failure
  /// marker the retry queue keys off. Pure, unit-tested.
  static MemoryResult parseMemoryResult(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start == -1 || end == -1) {
      return const MemoryResult(
        title: 'Memory',
        summary: 'Could not parse response',
        commitments: [],
      );
    }
    final jsonStr = raw.substring(start, end + 1);

    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final items = decoded['commitments'] as List<dynamic>?;
      final commitments =
          items?.map((item) {
            final m = item as Map<String, dynamic>;
            return AgentCommitment(
              isCommitment: m['is_commitment'] as bool? ?? true,
              action: m['action'] as String?,
              person: m['person'] as String?,
              due: m['due'] as String?,
            );
          }).toList() ??
          [];

      return MemoryResult(
        title: decoded['title'] as String? ?? 'Memory',
        summary: decoded['summary'] as String? ?? '',
        commitments: commitments,
        cleanedTranscript: decoded['cleaned_transcript'] as String? ?? '',
      );
    } catch (_) {
      return const MemoryResult(
        title: 'Memory',
        summary: 'Could not parse response',
        commitments: [],
      );
    }
  }
}
