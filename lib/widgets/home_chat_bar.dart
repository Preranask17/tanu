import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/conversation_provider.dart';
import '../screens/chat_screen.dart';

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
      CupertinoPageRoute(fullscreenDialog: true, builder: (_) => const ChatPage()),
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
          color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: CupertinoColors.systemGrey5.resolveFrom(context)),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.resolveFrom(context).withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 18),
            const Expanded(
              child: Text(
                'Live memory…',
                style: TextStyle(
                  color: CupertinoColors.systemGrey,
                  fontSize: 16,
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
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey5.resolveFrom(context),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.mic_solid, size: 17, color: CupertinoColors.activeBlue),
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
          CupertinoPageRoute(fullscreenDialog: true, builder: (_) => const ChatPage()),
        );
      },
      onLongPress: () => _showOptions(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 62,
        height: 62,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: CupertinoColors.activeBlue,
          shape: BoxShape.circle,
        ),
        child: const Icon(CupertinoIcons.add, size: 28, color: CupertinoColors.white),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    HapticFeedback.mediumImpact();
    // Use the native iOS action sheet for the microphone test option
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('Developer Options'),
        message: const Text('These options are useful for debugging your pendant audio.'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              ref.read(conversationProvider.notifier).microphoneTest();
            },
            child: const Text('Microphone test'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}