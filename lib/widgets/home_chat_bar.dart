import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/conversation_provider.dart';
import '../screens/chat_screen.dart';
import 'voice_pill.dart';

/// Floating Capture control: a compact mic that expands into a listening pill
/// with live transcript / timer, waveform, and visible pause/resume/stop controls.
/// Idle tap starts listening and opens the live memory page.
/// Pause stops STT but keeps the in-progress memory.
/// Swipe left cancels and discards. Stop (when paused) saves the memory.
class HomeChatBar extends ConsumerWidget {
  const HomeChatBar({super.key});

  void _openChat(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ChatPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversation = ref.watch(conversationProvider);
    final isListening = conversation.isListening;
    final hasActiveSession = conversation.active != null;
    final micLevel = conversation.micLevel;

    // Derive pill state from conversation state
    VoicePillState pillState;
    if (isListening) {
      pillState = VoicePillState.listening;
    } else if (hasActiveSession) {
      pillState = VoicePillState.paused;
    } else {
      pillState = VoicePillState.idle;
    }

    final words = conversation.liveTranscript.trim();
    final active = conversation.active;
    final preview = words.isNotEmpty
        ? words
        : (active != null && active.segments.isNotEmpty
              ? active.segments.last.text.trim()
              : '');

    return VoicePill(
      state: pillState,
      micLevel: micLevel,
      liveTranscript: preview,
      onStart: () {
        ref.read(conversationProvider.notifier).resumeListening();
        _openChat(context);
      },
      onPause: () {
        ref.read(conversationProvider.notifier).pauseListening();
      },
      onResume: () {
        ref.read(conversationProvider.notifier).resumeListening();
        _openChat(context);
      },
      onStop: () {
        ref.read(conversationProvider.notifier).stopListening('manual');
      },
      onCancel: () {
        ref.read(conversationProvider.notifier).stopListening('cancel');
      },
    );
  }
}