import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../abstractions/agent_engine.dart';
import '../models/transcript.dart';
import '../providers/conversation_provider.dart';
import '../providers/rag_provider.dart';
import '../services/rag/vector_store.dart';
import 'chat_screen.dart';

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

  /// Assistant message index -> RAG chunks that grounded it.
  final Map<int, List<ScoredChunk>> _answerSources = {};
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
          _messages.add(ChatMessage(role: 'assistant', content: result.answer));
          if (result.sources.isNotEmpty) {
            _answerSources[_messages.length - 1] = result.sources;
          }
          _busy = false;
        });
        _scrollToBottom();
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

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
                    itemBuilder: (context, i) {
                      final sources = _answerSources[i];
                      return Column(
                        crossAxisAlignment:
                            _messages[i].role == 'user'
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                        children: [
                          Align(
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
                          if (sources != null && sources.isNotEmpty)
                            _SourceChips(sources: sources),
                        ],
                      );
                    },
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

/// Per-source memory chips under an Ask answer. Tapping opens that memory.
class _SourceChips extends ConsumerWidget {
  const _SourceChips({required this.sources});

  final List<ScoredChunk> sources;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // One chip per memory, in retrieval order.
    final seen = <String>{};
    final unique =
        sources.where((s) => seen.add(s.chunk.sessionId)).toList();
    final conversations = ref.watch(conversationProvider).conversations;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in unique)
            ActionChip(
              label: Text(
                _labelFor(s, conversations),
                style: const TextStyle(fontSize: 12),
              ),
              avatar: const Icon(Icons.history, size: 14),
              onPressed: () {
                ConversationSession? session;
                try {
                  session = conversations.firstWhere(
                    (c) => c.id == s.chunk.sessionId,
                  );
                } catch (_) {
                  session = null;
                }
                if (session != null && context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SessionDetailPage(session: session!),
                    ),
                  );
                }
              },
            ),
        ],
      ),
    );
  }

  static String _labelFor(
    ScoredChunk s,
    List<ConversationSession> conversations,
  ) {
    try {
      final session =
          conversations.firstWhere((c) => c.id == s.chunk.sessionId);
      if (session.title.trim().isNotEmpty) {
        final t = session.title.trim();
        return t.length > 28 ? '${t.substring(0, 28)}…' : t;
      }
    } catch (_) {}
    if (s.chunk.title.trim().isNotEmpty) {
      final t = s.chunk.title.trim();
      return t.length > 28 ? '${t.substring(0, 28)}…' : t;
    }
    return 'memory ${s.chunk.sessionId.length > 6 ? s.chunk.sessionId.substring(s.chunk.sessionId.length - 6) : s.chunk.sessionId}';
  }
}
