import 'dart:convert';

import '../../abstractions/agent_engine.dart';

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

class MemoryProcessor {
  MemoryProcessor(this._engine);

  final LocalHeuristicAgentEngine _engine;

  Future<MemoryResult> process(String conversation) async {
    try {
      final raw = await _engine.prompt(conversation);
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
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
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

/// A 100% offline heuristic agent engine.
/// Since Mistral (Cloud LLM) was removed, this parser generates basic
/// titles and extracts commitments based on simple keyword matching.
class LocalHeuristicAgentEngine implements AgentEngine {
  @override
  Future<String> prompt(String transcript, {List<ChatMessage>? history}) async {
    // Simulate slight processing delay
    await Future.delayed(const Duration(milliseconds: 500));

    final cleanTranscript = transcript.trim();
    if (cleanTranscript.isEmpty) {
      return _buildResult("Empty Conversation", "No speech detected.", []);
    }

    final title = _generateTitle(cleanTranscript);
    final commitments = _extractCommitments(cleanTranscript);

    return _buildResult(title, cleanTranscript, commitments);
  }

  String _generateTitle(String transcript) {
    final words = transcript.split(RegExp(r'\s+'));
    if (words.length <= 5) return transcript;
    return '${words.take(5).join(' ')}...';
  }

  List<Map<String, dynamic>> _extractCommitments(String transcript) {
    final commitments = <Map<String, dynamic>>[];
    
    // Simple sentence splitting
    final sentences = transcript.split(RegExp(r'(?<=[.!?])\s+'));
    
    final keywords = [
      'remind me to',
      'i need to',
      'i have to',
      'i promise to',
      'i will',
      'i\'ll',
      'make sure i',
      'don\'t let me forget',
    ];

    for (var sentence in sentences) {
      final lower = sentence.toLowerCase();
      for (var keyword in keywords) {
        if (lower.contains(keyword)) {
          // Find where the keyword starts
          final idx = lower.indexOf(keyword);
          // The action is everything after the keyword (and maybe the keyword itself for context)
          var action = sentence.substring(idx).trim();
          
          // Remove trailing punctuation
          action = action.replaceAll(RegExp(r'[.!?]+$'), '');
          
          commitments.add({
            'is_commitment': true,
            'action': action,
            'person': null,
            'due': null,
          });
          break; // Found a commitment in this sentence, move to next sentence
        }
      }
    }

    return commitments;
  }

  String _buildResult(String title, String summary, List<Map<String, dynamic>> commitments) {
    return jsonEncode({
      "title": title,
      "summary": summary,
      "commitments": commitments,
    });
  }
}
