import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../abstractions/audio_source.dart';
import '../models/conversation.dart';
import '../providers/ble_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/navigation_provider.dart';
import '../screens/chat_screen.dart';
import '../theme.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/conversation_tile.dart';
import '../widgets/device_picker_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pendantReconnectProvider)();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void scrollToTop() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _openDevicePicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DevicePickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(pendantStatusProvider).value ?? const PendantStatus();
    final conversation = ref.watch(conversationProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final recent = conversation.conversations.length > 3
        ? conversation.conversations
            .sublist(conversation.conversations.length - 3)
            .reversed
            .toList()
        : conversation.conversations.reversed.toList();

    return RefreshIndicator(
      onRefresh: () async =>
          ref.read(conversationProvider.notifier).reloadFromStorage(),
      color: kTanuWarm,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                top: 8,
                bottom: 92 +
                    kBottomNavChatBarGap +
                    bottomInset +
                    62 +
                    16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (conversation.active != null ||
                      conversation.isListening ||
                      conversation.liveTranscript.isNotEmpty)
                    _LiveCaptureCard(
                      status: status,
                      conversation: conversation,
                    ),
                  if (!status.isConnected && conversation.active == null)
                    _ConnectionCard(onConnect: _openDevicePicker),
                  if (conversation.active == null &&
                      conversation.conversations.isEmpty)
                    _EmptyState(connected: status.isConnected)
                  else ...[
                    const SizedBox(height: 20),
                    _SectionHeader(
                      title: 'Conversations',
                      pillLabel: 'View All',
                      interactive: true,
                      onPillTap: () => ref
                          .read(navigationTabProvider.notifier)
                          .goToConversations(),
                    ),
                    const SizedBox(height: 4),
                    for (final (i, session) in recent.indexed)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: ConversationTile(session: session, isNew: i == 0),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveCaptureCard extends ConsumerWidget {
  const _LiveCaptureCard({
    required this.status,
    required this.conversation,
  });

  final PendantStatus status;
  final ConversationState conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final words = conversation.liveTranscript.trim();
    final active = conversation.active;
    final label = switch (conversation.sttEvent) {
      'stt unavailable' => 'Transcription unavailable',
      _ => conversation.isListening ? 'Listening…' : 'Capturing…',
    };

    final preview = words.isNotEmpty
        ? words
        : (active != null && active.segments.isNotEmpty
            ? active.segments.last.text.trim()
            : '');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(
            MaterialPageRoute(fullscreenDialog: true, builder: (_) => const ChatPage()),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: kTanuSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kTanuLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Equalizer(
                    color: kTanuGreen,
                    level: conversation.micLevel,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: kTanuInk,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    status.deviceName ?? 'Pendant',
                    style: const TextStyle(fontSize: 12, color: kTanuMuted),
                  ),
                ],
              ),
              if (active != null && active.segments.isNotEmpty) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.read(conversationProvider.notifier).forceEndSession();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: kTanuWarm,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.post_add, size: 18),
                    label: const Text(
                      'New memory',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontStyle: words.isNotEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                    color: kTanuInk.withValues(alpha: 0.85),
                    fontSize: 16,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated 4-bar voice meter, Tanu-colored.
class _Equalizer extends StatefulWidget {
  const _Equalizer({required this.color, required this.level});

  final Color color;
  final double level;

  @override
  State<_Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<_Equalizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const barCount = 4;
    final frequencies = [0.9, 1.4, 1.1, 0.7];
    final phases = [0.0, 1.7, 0.9, 2.6];

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value * 2 * math.pi;
        final amp = 0.3 + 0.7 * widget.level.clamp(0.0, 1.0);
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < barCount; i++)
              Container(
                width: 3.5,
                height: 12 +
                    (16 * amp) *
                        (0.5 +
                            0.5 *
                                math.sin(
                                    i * 0.9 + t * frequencies[i] + phases[i])),
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.onConnect});

  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kTanuSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kTanuLine),
        ),
        child: Row(
          children: [
            Icon(Icons.bluetooth_disabled, color: kTanuMuted, size: 24),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No pendant yet',
                    style: TextStyle(
                      color: kTanuInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Connect your pendant to start talking.',
                    style: TextStyle(color: kTanuMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: onConnect,
              child: const Text('Scan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.pillLabel,
    this.interactive = false,
    this.onPillTap,
  });

  final String title;
  final String pillLabel;
  final bool interactive;
  final VoidCallback? onPillTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kTanuInk,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          InkWell(
            onTap: interactive ? onPillTap : null,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: kTanuChip,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                pillLabel,
                style: TextStyle(
                  color: interactive ? kTanuInk : kTanuMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.record_voice_over_outlined, color: kTanuMuted, size: 36),
            const SizedBox(height: 12),
            Text(
              connected
                  ? 'Listening… speak or tap + to view a memory'
                  : 'Nothing here yet.\nConnect your pendant and say something.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: kTanuMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}