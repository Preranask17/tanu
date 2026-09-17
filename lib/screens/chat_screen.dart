import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transcript.dart';
import '../providers/conversation_provider.dart';
import '../providers/stt_model_provider.dart';
import '../providers/ble_provider.dart';
import '../providers/agent_provider.dart';
import '../abstractions/agent_engine.dart';
import '../abstractions/audio_source.dart';
import '../theme.dart';
import '../widgets/connection_status_bar.dart';
import '../widgets/state_indicator.dart';

/// Live memory page: the in-progress session's timestamped transcript streams
/// here, partial words in italic, locked lines in place — Omi's chat. Pushed
/// from the home capture card and the home chat bar.
class ChatPage extends ConsumerWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversation = ref.watch(conversationProvider);
    final status = ref.watch(pendantStatusProvider).value ?? const PendantStatus();
    final model = ref.watch(sttModelProvider);
    final engine = ref.watch(sttEngineProvider);

    return Scaffold(
      backgroundColor: kTanuBg,
      appBar: AppBar(
        title: Text(
          conversation.active?.title.isNotEmpty == true
              ? conversation.active!.title
              : 'Tanu',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: engine.warmingUp,
            builder: (context, warming, _) {
              final show = model.busy || warming;
              if (!show) return const SizedBox.shrink();
              final title = model.phase == SttModelPhase.downloading
                  ? model.label
                  : 'Loading model…';
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _ModelLoadingChip(title: title),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ConnectionStatusBar(),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: StateIndicator(
                state: status.state,
                isListening: conversation.isListening,
                isThinking: false,
                error: conversation.error,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: conversation.active == null
                  ? _ChatWelcome(status: status)
                  : _SessionTranscript(
                      session: conversation.active!,
                      livePartial: conversation.liveTranscript,
                      isListening: conversation.isListening,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Read-only transcript of a completed memory.
class SessionDetailPage extends ConsumerStatefulWidget {
  const SessionDetailPage({super.key, required this.session});

  final ConversationSession session;

  @override
  ConsumerState<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends ConsumerState<SessionDetailPage> {
  final _chatCtrl = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isGenerating = false;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty || _isGenerating) return;

    _chatCtrl.clear();
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _isGenerating = true;
    });
    _scrollToBottom();

    final engine = ref.read(mistralEngineProvider);
    try {
      final reply = await engine.prompt(
        widget.session.transcriptText,
        history: [
          const ChatMessage(
            role: 'system',
            content: 'You are an AI assistant helping a user recall details from their memory. Use the provided transcript context to answer.',
          ),
          ..._messages,
        ],
      );
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(role: 'assistant', content: reply));
          _isGenerating = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(role: 'assistant', content: 'Failed to query memory: $e'));
          _isGenerating = false;
        });
        _scrollToBottom();
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
    final session = widget.session;
    return Scaffold(
      backgroundColor: kTanuBg,
      appBar: AppBar(
        title: Text(
          session.title.isEmpty ? 'Memory' : session.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (session.summary != null && session.summary!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: kTanuSurface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: TanuTheme.softShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.auto_awesome, size: 16, color: kTanuInk),
                              SizedBox(width: 8),
                              Text('AI Summary', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kTanuInk)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(session.summary!, style: const TextStyle(height: 1.4, fontSize: 15, color: kTanuInk)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: kTanuLine),
                    const SizedBox(height: 16),
                  ],
                  if (session.segments.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'Nothing was captured in this session.',
                          style: TextStyle(color: kTanuMuted),
                        ),
                      ),
                    )
                  else
                    ...session.segments.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _SegmentRow(segment: s),
                        )),
                  if (_messages.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Divider(color: kTanuLine),
                    const SizedBox(height: 16),
                    const Text('Memory Chat', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kTanuMuted)),
                    const SizedBox(height: 12),
                    ..._messages.map((m) => _ChatBubble(message: m)),
                  ],
                  if (_isGenerating)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: kTanuInk)),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: const BoxDecoration(
                color: kTanuBg,
                border: Border(top: BorderSide(color: kTanuLine)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatCtrl,
                      decoration: InputDecoration(
                        hintText: 'Ask about this memory...',
                        filled: true,
                        fillColor: kTanuSurface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: kTanuInk)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isGenerating ? null : _send,
                    icon: const Icon(Icons.arrow_upward),
                    style: IconButton.styleFrom(backgroundColor: kTanuInk, foregroundColor: kTanuBg),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? kTanuInk : kTanuSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isUser ? null : TanuTheme.softShadow,
        ),
        child: Text(
          message.content,
          style: TextStyle(color: isUser ? kTanuBg : kTanuInk, fontSize: 15, height: 1.4),
        ),
      ),
    );
  }
}

class _ChatWelcome extends StatelessWidget {
  const _ChatWelcome({required this.status});

  final PendantStatus status;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status.isConnected ? Icons.record_voice_over : Icons.mic_none,
              size: 44,
              color: kTanuWarm,
            ),
            const SizedBox(height: 16),
            const Text(
              'Connect your pendant over Bluetooth and just talk.\nTanu transcribes into a memory, right here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: kTanuInk, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionTranscript extends StatelessWidget {
  const _SessionTranscript({
    required this.session,
    required this.livePartial,
    required this.isListening,
  });

  final ConversationSession session;
  final String livePartial;
  final bool isListening;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        for (final segment in session.segments)
          _SegmentRow(segment: segment),
        if (livePartial.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _offsetLabel(session.segments.isNotEmpty
                      ? livePartialMs(session)
                      : 0),
                  style: const TextStyle(fontSize: 12, color: kTanuMuted),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    livePartial.trim(),
                    style: const TextStyle(
                      color: kTanuInk,
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (isListening && livePartial.trim().isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic, size: 14, color: kTanuWarm),
                SizedBox(width: 6),
                Text('Listening…', style: TextStyle(color: kTanuWarm)),
              ],
            ),
          ),
      ],
    );
  }

  int livePartialMs(ConversationSession session) {
    final last = session.segments.isEmpty ? null : session.segments.last;
    return last?.endMs ?? 0;
  }
}

String _offsetLabel(int ms) {
  final d = Duration(milliseconds: ms);
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

class _SegmentRow extends StatelessWidget {
  const _SegmentRow({required this.segment});

  final TranscriptSegment segment;

  @override
  Widget build(BuildContext context) {
    final text = segment.text.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 44,
          child: Text(
            _offsetLabel(segment.startMs),
            style: const TextStyle(fontSize: 12, color: kTanuMuted),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kTanuSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kTanuLine),
            ),
            child: Text(
              text.isEmpty ? '…' : text,
              style: const TextStyle(color: kTanuInk, height: 1.4, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModelLoadingChip extends StatelessWidget {
  const _ModelLoadingChip({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: kTanuChip,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.8, color: kTanuWarm),
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: kTanuInk.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}