import 'package:flutter/material.dart';
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
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ChatPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        _openLive(context);
      },
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
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
                  color: Color(0xFF888888),
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
                  color: isDark ? const Color(0xFF222222) : const Color(0xFFF0F0F0),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mic,
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ),
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
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const ChatPage(),
          ),
        );
      },
      onLongPress: () => _showOptions(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 62,
        height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.add,
          size: 28,
          color: Colors.white,
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    HapticFeedback.mediumImpact();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Developer Options',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'These options are useful for debugging your pendant audio.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF888888),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  ref.read(conversationProvider.notifier).microphoneTest();
                },
                child: const Text('Microphone test'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
