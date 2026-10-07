import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../abstractions/agent_engine.dart';

class AgentException implements Exception {
  AgentException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => 'AgentException: $message (${statusCode ?? 'no code'})';
}

/// Agent backed by Mistral's cloud chat completions API.
class MistralAgentEngine implements AgentEngine {
  MistralAgentEngine({
    required this.apiKey,
    required this.model,
    this.endpoint = const String.fromEnvironment('TANU_MISTRAL_ENDPOINT'),
    this.systemPrompt,
  });

  final String apiKey;
  final String model;
  final String endpoint;
  final String? systemPrompt;

  static const String _defaultEndpoint =
      'https://api.mistral.ai/v1/chat/completions';

  @override
  Future<String> prompt(String transcript, {List<ChatMessage>? history}) async {
    if (apiKey.isEmpty) {
      await Future.delayed(const Duration(seconds: 1));
      if (history != null &&
          history.any((m) => m.content.contains('"title"'))) {
        return '{"title": "Mock Chat Memory", "summary": "This is a mock summary generated because no Mistral API key was provided.", "commitments": []}';
      }
      return 'This is a mock AI response since no API key is provided. You said: "$transcript"';
    }

    final messages = <Map<String, String>>[
      if (systemPrompt != null) {'role': 'system', 'content': systemPrompt!},
      ...?history?.map((m) => m.toJson()),
      {'role': 'user', 'content': transcript},
    ];

    final body = jsonEncode({
      'model': model,
      'messages': messages,
      'temperature': 0.6,
      'max_tokens': 200,
    });

    final uri = endpoint.isNotEmpty ? endpoint : _defaultEndpoint;

    try {
      final response = await http
          .post(
            Uri.parse(uri),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode != 200) {
        throw AgentException(
          'Mistral returned ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = decoded['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw AgentException('Mistral returned no choices');
      }
      final content =
          (choices.first as Map<String, dynamic>)['message']
              as Map<String, dynamic>;
      return (content['content'] as String?)?.trim() ?? '';
    } on AgentException {
      rethrow;
    } catch (e) {
      throw AgentException('Network error calling Mistral: $e');
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
  });

  final String title;
  final String summary;
  final List<AgentCommitment> commitments;
}

/// Single-shot Mistral call asking the model to process a memory into a JSON summary.
class MemoryProcessor {
  MemoryProcessor(this._engine);

  final MistralAgentEngine _engine;

  Future<MemoryResult> process(String conversation) async {
    try {
      final raw = await _engine.prompt(
        conversation,
        history: [
          ChatMessage(
            role: 'system',
            content: '''
You process a user's transcribed conversation memory.
Given the conversation transcript, extract a title, a short summary, and any commitments or action items.
Reply with ONLY a JSON object shaped exactly like this:
{
  "title": "A short 3-4 word title",
  "summary": "A 1-2 sentence concise summary.",
  "commitments": [{"is_commitment": true, "action": "...", "person": "...", "due": "YYYY-MM-DD"}]
}
No commentary, no markdown.
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

/// Convert a raw PCM utterance to a WAV string usable by hosted STT
/// (kept for the future hosted path; unused by the placeholder).
String pcmToWavPcm16(Uint8List pcm, {int sampleRate = 16000}) {
  final bytesPerSample = 2;
  final dataSize = pcm.length;
  final buffer = BytesBuilder();
  buffer.add('RIFF'.codeUnits);
  buffer.add(_uint32(36 + dataSize));
  buffer.add('WAVE'.codeUnits);
  buffer.add('fmt '.codeUnits);
  buffer.add(_uint32(16));
  buffer.add(_uint16(1));
  buffer.add(_uint16(1));
  buffer.add(_uint32(sampleRate));
  buffer.add(_uint32(sampleRate * bytesPerSample));
  buffer.add(_uint16(bytesPerSample));
  buffer.add(_uint16(16));
  buffer.add('data'.codeUnits);
  buffer.add(_uint32(dataSize));
  buffer.add(pcm);
  return String.fromCharCodes(buffer.toBytes());
}

List<int> _uint32(int value) => [
  value & 0xff,
  (value >> 8) & 0xff,
  (value >> 16) & 0xff,
  (value >> 24) & 0xff,
];

List<int> _uint16(int value) => [value & 0xff, (value >> 8) & 0xff];
