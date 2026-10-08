import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transcript.dart';
import '../providers/conversation_provider.dart';
import '../providers/ble_provider.dart';
import '../providers/agent_provider.dart';
import '../providers/rag_provider.dart';
import '../abstractions/agent_engine.dart';
import '../abstractions/audio_source.dart';
import '../widgets/audio_waveform.dart';

/// Live memory page: the in-progress session's timestamped transcript streams
/// here, partial words in italic, locked lines in place — Omi's chat. Pushed
/// from the home capture card and the home chat bar.
class ChatPage extends ConsumerWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversation = ref.watch(conversationProvider);
    final status =
        ref.watch(pendantStatusProvider).value ?? const PendantStatus();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _LiveHeader(
              status: status,
              onClose: () => Navigator.of(context).maybePop(),
            ),
            if (conversation.isListening)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: AudioWaveform(level: conversation.micLevel),
              ),
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

class _LiveHeader extends StatelessWidget {
  const _LiveHeader({required this.status, required this.onClose});

  final PendantStatus status;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final statusColor = status.isConnected
        ? Colors.greenAccent
        : Colors.white54;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Close',
                onPressed: onClose,
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
            ),
            const Text(
              'Tanu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    status.isConnected
                        ? Icons.bluetooth
                        : Icons.bluetooth_disabled,
                    color: statusColor,
                    size: 16,
                  ),
                  if (status.batteryPercent != null) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.battery_full_rounded,
                      color: Colors.white60,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${status.batteryPercent}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
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
  bool _showCleaned = true;
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

    try {
      final ragFuture = ref.read(ragServiceProvider.future);
      final rag = await ragFuture;
      final result = await rag.answer(
        text,
        sessionId: widget.session.id,
      );
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            role: 'assistant',
            content: result.sources.isEmpty
                ? result.answer
                : '${result.answer}\n\n(from ${result.sources.length} excerpts in this memory)',
          ));
          _isGenerating = false;
        });
        _scrollToBottom();
      }
      return;
    } catch (_) {
      // Fall through to direct context chat on any RAG failure.
    }

    final engine = ref.read(geminiEngineProvider);
    try {
      final reply = await engine.prompt(
        (widget.session.cleanedTranscript?.trim().isNotEmpty ?? false)
            ? widget.session.cleanedTranscript!
            : widget.session.transcriptText,
        history: [
          const ChatMessage(
            role: 'system',
            content:
                'You are an AI assistant helping a user recall details from their memory. Use the provided transcript context to answer.',
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
          _messages.add(
            ChatMessage(
              role: 'assistant',
              content: 'Failed to query memory: $e',
            ),
          );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          session.title.isEmpty ? 'Memory' : session.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  if (session.summary != null &&
                      session.summary!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF111111)
                            : const Color(0xFFFFFFFF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFE5E5E5),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 16,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'AI Summary',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            session.summary!,
                            style: const TextStyle(height: 1.4, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (session.cleanedTranscript != null &&
                      session.cleanedTranscript!.trim().isNotEmpty) ...[
                    Row(
                      children: [
                        _TranscriptToggle(
                          label: 'Cleaned',
                          selected: _showCleaned,
                          onTap: () => setState(() => _showCleaned = true),
                        ),
                        const SizedBox(width: 8),
                        _TranscriptToggle(
                          label: 'Raw',
                          selected: !_showCleaned,
                          onTap: () => setState(() => _showCleaned = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_showCleaned &&
                      session.cleanedTranscript != null &&
                      session.cleanedTranscript!.trim().isNotEmpty)
                    Text(
                      session.cleanedTranscript!,
                      style: const TextStyle(height: 1.6, fontSize: 15),
                    )
                  else if (session.segments.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'Nothing was captured in this session.',
                          style: TextStyle(color: Color(0xFF888888)),
                        ),
                      ),
                    )
                  else
                    ...() {
                      final List<List<TranscriptSegment>> groupedSegments = [];
                      for (final seg in session.segments) {
                        if (groupedSegments.isEmpty) {
                          groupedSegments.add([seg]);
                        } else {
                          final lastGroup = groupedSegments.last;
                          final lastSeg = lastGroup.last;
                          final lastEnd = lastSeg.endMs ?? lastSeg.startMs;
                          if (seg.startMs - lastEnd < 3000) {
                            lastGroup.add(seg);
                          } else {
                            groupedSegments.add([seg]);
                          }
                        }
                      }
                      return groupedSegments.asMap().entries.map(
                        (e) => _SegmentGroupRow(
                          segments: e.value,
                          isLast: e.key == groupedSegments.length - 1,
                        ),
                      );
                    }(),
                  if (_messages.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Container(
                      height: 1,
                      color: Theme.of(context).dividerTheme.color,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Memory Chat',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF888888),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._messages.map((m) => _ChatBubble(message: m)),
                  ],
                  if (_isGenerating)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
            Container(
              margin: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                12 + MediaQuery.paddingOf(context).bottom,
              ),
              padding: const EdgeInsets.only(left: 20, right: 6, top: 6, bottom: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1C1C1E)
                    : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context)
                        .primaryColor
                        .withValues(alpha: 0.35),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Ask about this memory...',
                        hintStyle: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 15,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _isGenerating ? null : _send,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isGenerating
                            ? const Color(0xFF888888)
                            : Theme.of(context).primaryColor,
                      ),
                      child: _isGenerating
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.arrow_upward,
                              size: 20,
                              color: Colors.white,
                            ),
                    ),
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

class _TranscriptToggle extends StatelessWidget {
  const _TranscriptToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).primaryColor
              : (isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF888888),
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser
              ? (isDark ? const Color(0xFF333333) : const Color(0xFFE5E5E5))
              : (isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF)),
          borderRadius: BorderRadius.circular(12),
          border: isUser
              ? null
              : Border.all(
                  color: isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFE5E5E5),
                  width: 1,
                ),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isUser
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? Colors.white : Colors.black),
            fontSize: 15,
            height: 1.4,
          ),
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
              status.isConnected ? Icons.mic : Icons.mic_none,
              size: 48,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'Connect your pendant over Bluetooth and just talk.\nTanu transcribes into a memory, right here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.5),
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
    // Smart Segment Grouping: Combine segments if they are within 3 seconds of each other
    final List<List<TranscriptSegment>> groupedSegments = [];
    for (final seg in session.segments) {
      if (groupedSegments.isEmpty) {
        groupedSegments.add([seg]);
      } else {
        final lastGroup = groupedSegments.last;
        final lastSeg = lastGroup.last;
        final lastEnd = lastSeg.endMs ?? lastSeg.startMs;
        if (seg.startMs - lastEnd < 3000) {
          lastGroup.add(seg);
        } else {
          groupedSegments.add([seg]);
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        for (int i = 0; i < groupedSegments.length; i++)
          _SegmentGroupRow(
            segments: groupedSegments[i],
            isLast:
                i == groupedSegments.length - 1 &&
                livePartial.trim().isEmpty &&
                !isListening,
          ),

        if (livePartial.trim().isNotEmpty)
          _LivePartialRow(
            partial: livePartial,
            ms: session.segments.isNotEmpty
                ? (session.segments.last.endMs ?? session.segments.last.startMs)
                : 0,
          ),
      ],
    );
  }
}

class _LivePartialRow extends StatelessWidget {
  const _LivePartialRow({required this.partial, required this.ms});
  final String partial;
  final int ms;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Text(
                  _offsetLabel(ms),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context).primaryColor.withOpacity(0.5),
                          Theme.of(context).primaryColor.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.05),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Text(
                  partial.trim(),
                  key: ValueKey<String>(partial.trim()),
                  style: const TextStyle(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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

class _SegmentGroupRow extends StatelessWidget {
  const _SegmentGroupRow({required this.segments, required this.isLast});
  final List<TranscriptSegment> segments;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final combinedText = segments.map((s) => s.text.trim()).join(' ');
    final startMs = segments.first.startMs;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline column
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Text(
                  _offsetLabel(startMs),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                  ),
                ),
                const SizedBox(height: 8),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Theme.of(context).primaryColor.withOpacity(0.5),
                            Theme.of(context).primaryColor.withOpacity(0.1),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Bubble column
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF161618)
                      : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2A2A2C)
                        : const Color(0xFFE9ECEF),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  combinedText.isEmpty ? '...' : combinedText,
                  style: const TextStyle(height: 1.5, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
