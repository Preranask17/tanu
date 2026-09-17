import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/conversation_provider.dart';
import '../screens/chat_screen.dart';
import '../theme.dart';

/// The floating home row Omi keeps above its bottom nav: a rounded memory bar
/// and a round record button. Tapping either opens the live memory page;
/// long-pressing the record button offers a phone-mic test.
class HomeChatBar extends ConsumerWidget {
  const HomeChatBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(child: _ChatPill()),
        const SizedBox(width: 12),
        _RecordButton(ref: ref),
      ],
    );
  }
}

class _ChatPill extends StatelessWidget {
  void _openLive(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const ChatPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        _openLive(context);
      },
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: kTanuInk,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Row(
          children: [
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                'Live memory…',
                style: TextStyle(
                  color: kTanuBg.withValues(alpha: 0.75),
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _openLive(context);
              },
              child: Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(right: 8),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: kTanuBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic, size: 17, color: kTanuInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(fullscreenDialog: true, builder: (_) => const ChatPage()),
        );
      },
      onLongPress: () => _showOptions(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 62,
        height: 62,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: kTanuWarm,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, size: 28, color: Colors.white),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kTanuSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kTanuLine,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.mic, color: kTanuWarm),
                title: const Text('Microphone test'),
                subtitle: Text(
                  'Listen from the phone mic and see the words land',
                  style: TextStyle(color: kTanuMuted, fontSize: 13),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  ref.read(conversationProvider.notifier).microphoneTest();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}