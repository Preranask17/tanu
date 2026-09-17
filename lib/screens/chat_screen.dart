import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transcript.dart';
import '../providers/conversation_provider.dart';
import '../providers/stt_model_provider.dart';
import '../providers/ble_provider.dart';
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
class SessionDetailPage extends StatelessWidget {
  const SessionDetailPage({super.key, required this.session});

  final ConversationSession session;

  @override
  Widget build(BuildContext context) {
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
        top: false,
        child: session.segments.isEmpty
            ? const Center(
                child: Text(
                  'Nothing was captured in this session.',
                  style: TextStyle(color: kTanuMuted),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: session.segments.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) =>
                    _SegmentRow(segment: session.segments[i]),
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