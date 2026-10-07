import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../abstractions/agent_engine.dart';
import '../../constants.dart';
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
      },
    });

    try {
      final response = await http
          .post(
            Uri.parse('$endpoint?key=$apiKey'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 45));

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
      return ((parts.first as Map<String, dynamic>)['text'] as String?)?.trim() ?? '';
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

  Future<MemoryResult> process(String conversation) async {
    try {
      final raw = await _engine.prompt(
        conversation,
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
      return _parse(raw);
    } catch (e) {
      return MemoryResult(
        title: 'Memory',
        summary: 'Failed to process memory: $e',
        commitments: const [],
      );
    }
  }

  MemoryResult _parse(String raw) {
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
