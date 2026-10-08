import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../abstractions/agent_engine.dart';
import '../../constants.dart';
import '../../models/transcript.dart';
import '../rag/rate_limiter.dart';
import 'mistral_agent_engine.dart' show AgentException;

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

  static final _limiter = RateLimiter(
    Duration(milliseconds: kGeminiMinGapChatMs),
  );

  @override
  Future<String> prompt(
    String transcript, {
    List<ChatMessage>? history,
    bool jsonMode = false,
  }) async {
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
        // Structured memory output (turns + cleanup) is far longer than a
        // chat reply; plain chat keeps the old tight budget.
        'maxOutputTokens': jsonMode ? 4096 : 1024,
        if (jsonMode) ...{
          'responseMimeType': 'application/json',
          'responseSchema': _memoryResponseSchema,
        },
      },
    });

    try {
      final response = await _limiter.run(() async {
        var r = await http
            .post(
              Uri.parse('$endpoint?key=$apiKey'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: body,
            )
            .timeout(const Duration(seconds: 45));
        if (r.statusCode == 429) {
          final wait = retryDelayFromBody(r.body) ?? const Duration(seconds: 5);
          await Future.delayed(wait);
          r = await http
              .post(
                Uri.parse('$endpoint?key=$apiKey'),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
                body: body,
              )
              .timeout(const Duration(seconds: 45));
        }
        return r;
      });

      if (response.statusCode != 200) {
        throw AgentException(
          'Gemini returned ${response.statusCode}: ${response.body}',
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw AgentException('Gemini returned no candidates');
      }
      final content =
          (candidates.first as Map<String, dynamic>)['content'] as Map<String, dynamic>;
      final parts = content['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) {
        throw AgentException('Gemini returned empty content');
      }
      String? text;
      for (final p in parts) {
        final m = p as Map<String, dynamic>;
        if (m['thought'] == true) continue;
        final t = m['text'] as String?;
        if (t != null && t.trim().isNotEmpty) {
          text = t;
          break;
        }
      }
      text ??= ((parts.first as Map<String, dynamic>)['text'] as String?);
      if (text == null || text.trim().isEmpty) {
        throw AgentException('Gemini returned no text');
      }
      return text.trim();
    } on AgentException {
      rethrow;
    } catch (e) {
      throw AgentException('Network error calling Gemini: $e');
    }
  }
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
    this.turns = const [],
    this.error,
  });

  final String title;
  final String summary;
  final List<AgentCommitment> commitments;

  /// The raw transcript rewritten into clean, speaker-labeled prose.
  final String cleanedTranscript;

  /// Structured speaker turns: the reviewable, indexable form of the
  /// memory. Empty when the model returned none (old path / parse fallback).
  final List<TranscriptTurn> turns;

  /// Set when processing failed (network/parse) — caller should retry later.
  final String? error;
}

/// JSON schema enforced on the memory-processor call (`responseMimeType:
/// application/json`). The model cannot drift field names or wrap the answer
/// in fences — failures become retriable errors instead of silent garbage.
const Map<String, Object> _memoryResponseSchema = {
  'type': 'OBJECT',
  'properties': {
    'title': {'type': 'STRING'},
    'summary': {'type': 'STRING'},
    'cleaned_transcript': {'type': 'STRING'},
    'turns': {
      'type': 'ARRAY',
      'items': {
        'type': 'OBJECT',
        'properties': {
          'speaker': {'type': 'STRING'},
          'start_ms': {'type': 'INTEGER'},
          'end_ms': {'type': 'INTEGER'},
          'text': {'type': 'STRING'},
        },
        'required': ['speaker', 'text'],
      },
    },
    'commitments': {
      'type': 'ARRAY',
      'items': {
        'type': 'OBJECT',
        'properties': {
          'is_commitment': {'type': 'BOOLEAN'},
          'action': {'type': 'STRING'},
          'person': {'type': 'STRING'},
          'due': {'type': 'STRING'},
        },
      },
    },
  },
  'required': ['title', 'summary', 'turns'],
};

/// Single-shot Gemini call that turns a raw transcript into a structured,
/// clean memory: title, summary, speaker-labeled cleaned transcript, and
/// extracted commitments.
class GeminiMemoryProcessor {
  GeminiMemoryProcessor(this._engine);

  final GeminiAgentEngine _engine;

  Future<MemoryResult> process(String conversation) async {
    try {
      final raw = await _engine.prompt(
        conversation,
        jsonMode: true,
        history: [
          const ChatMessage(
            role: 'system',
            content: '''
You process a user's transcribed conversation memory.
The input is timestamped speech segments in order, like
[00:12-00:18] hello there
[pause 4.2s]
[00:22-00:31] ….
Lines tagged [You] / [Other 1] / [Other 2] were labeled by on-device voice
analysis — TRUST those tags and keep them. Lines tagged [?] have no acoustic
label: infer the speaker from turn-taking (a pause usually means a turn
change) and content, but stay conservative — when in doubt, continue the
previous speaker rather than inventing a new one. The wearer is always "You".

Given the raw speech-to-text transcript, produce a structured memory.

Reply with ONLY a JSON object shaped exactly like this:
{
  "title": "A short 3-5 word title",
  "summary": "A 1-2 sentence concise summary.",
  "cleaned_transcript": "A clean rewrite of the full conversation: proper punctuation and capitalization, filler and jargon smoothed into clear sentences, attributed to speakers as 'You:', 'Other 1:' etc. Keep it faithful, do not invent content.",
  "turns": [{"speaker": "You", "start_ms": 12000, "end_ms": 18000, "text": "cleaned turn text"}],
  "commitments": [{"is_commitment": true, "action": "...", "person": "...", "due": "YYYY-MM-DD"}]
}
One turn per speaker run: merge consecutive lines from the same speaker into
a single turn. start_ms/end_ms come from the input timestamps (0 when the
input line has none). No commentary, no markdown fences.
''',
          ),
        ],
      );
      return parseMemoryJson(raw);
    } catch (e) {
      return MemoryResult(
        title: 'Memory',
        summary: '',
        commitments: const [],
        error: e.toString(),
      );
    }
  }

  /// Parses one memory-processor response. Public (and static) so the
  /// contract is unit-testable without a network call.
  static MemoryResult parseMemoryJson(String raw) {
    return _parse(raw);
  }

  static MemoryResult _parse(String raw) {
    // Strip markdown fences Gemini sometimes adds despite instructions.
    var cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'```$'), '');
    }
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start == -1 || end == -1) {
      return const MemoryResult(
        title: 'Memory',
        summary: '',
        commitments: [],
        error: 'Could not parse response',
      );
    }
    final jsonStr = cleaned.substring(start, end + 1);

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

      final rawTurns = decoded['turns'] as List<dynamic>?;
      final turns =
          rawTurns
              ?.whereType<Map>()
              .map((t) {
                final m = Map<String, dynamic>.from(t);
                return TranscriptTurn(
                  speaker: (m['speaker'] as String? ?? '').trim().isEmpty
                      ? 'Other 1'
                      : (m['speaker'] as String).trim(),
                  text: m['text'] as String? ?? '',
                  startMs: (m['start_ms'] as num?)?.toInt() ?? 0,
                  endMs: (m['end_ms'] as num?)?.toInt(),
                );
              })
              .where((t) => t.text.trim().isNotEmpty)
              .toList() ??
          [];

      return MemoryResult(
        title: decoded['title'] as String? ?? 'Memory',
        summary: decoded['summary'] as String? ?? '',
        commitments: commitments,
        cleanedTranscript: decoded['cleaned_transcript'] as String? ?? '',
        turns: turns,
      );
    } catch (_) {
      return const MemoryResult(
        title: 'Memory',
        summary: '',
        commitments: [],
        error: 'Could not parse response',
      );
    }
  }
}
