import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../abstractions/agent_engine.dart';
import '../providers/conversation_provider.dart';
import '../providers/rag_provider.dart';
import '../services/rag/vector_store.dart';

/// Cross-memory Q&A over the RAG pipeline: ask anything about your saved
/// memories and get an answer grounded in the actual transcript chunks.
class AskScreen extends ConsumerStatefulWidget {
  const AskScreen({super.key});

  @override
  ConsumerState<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends ConsumerState<AskScreen> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _busy = false;
  bool _backfilled = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _busy = true;
    });

    try {
      final indexer = await ref.read(memoryIndexerProvider.future);
      if (!_backfilled) {
        _backfilled = true;
        // Fire-and-forget: don't block the user's answer on backfill.
        unawaited(indexer.backfill(ref.read(conversationProvider).conversations));
      }
      final rag = await ref.read(ragServiceProvider.future);
      final result = await rag.answer(text);
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            role: 'assistant',
            content: result.sources.isEmpty
                ? result.answer
                : '${result.answer}\n\n(from ${result.sources.length} memory excerpts${_speakerSuffix(result.sources)})',
          ));
          _busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(role: 'assistant', content: 'Failed: $e'));
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Ask Tanu')),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Ask anything about your memories — “What did I decide about the project?”',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF888888), height: 1.5),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) => Align(
                      alignment: _messages[i].role == 'user'
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _messages[i].role == 'user'
                              ? (isDark
                                  ? const Color(0xFF333333)
                                  : const Color(0xFFE5E5E5))
                              : (isDark
                                  ? const Color(0xFF111111)
                                  : const Color(0xFFFFFFFF)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_messages[i].content,
                            style: const TextStyle(fontSize: 15, height: 1.4)),
                      ),
                    ),
                  ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Ask about your memories...',
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1C1C1E)
                          : const Color(0xFFF2F2F7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _busy ? null : _send,
                  icon: const Icon(Icons.arrow_upward),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Speaker attribution suffix for RAG citations, e.g. " · You, Other 1".
/// Empty when none of the grounding chunks carries a speaker.
String _speakerSuffix(List<ScoredChunk> sources) {
  final speakers = sources
      .map((s) => s.chunk.speaker.trim())
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  if (speakers.isEmpty) return '';
  return ' · ${speakers.join(', ')}';
}
