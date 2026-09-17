import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
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
import '../widgets/conversation_tile.dart';
import '../widgets/device_picker_sheet.dart';
import '../widgets/home_chat_bar.dart';

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
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => const DevicePickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(pendantStatusProvider).value ?? const PendantStatus();
    final conversation = ref.watch(conversationProvider);
    
    // Calculate padding for the persistent bottom chat bar
    final bottomInset = MediaQuery.paddingOf(context).bottom + 50 + 62 + 16; 

    final recent = conversation.conversations.length > 3
        ? conversation.conversations
            .sublist(conversation.conversations.length - 3)
            .reversed
            .toList()
        : conversation.conversations.reversed.toList();

    return CupertinoPageScaffold(
      child: Stack(
        children: [
          CustomScrollView(
            controller: _scroll,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: const Text('Capture'),
                trailing: _PendantStatusIndicator(status: status, onConnect: _openDevicePicker),
              ),
              CupertinoSliverRefreshControl(
                onRefresh: () async =>
                    ref.read(conversationProvider.notifier).reloadFromStorage(),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 16, bottom: bottomInset),
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
                        const SizedBox(height: 32),
                        _SectionHeader(
                          title: 'Recent Memories',
                          pillLabel: 'View All',
                          interactive: true,
                          onPillTap: () => ref
                              .read(navigationTabProvider.notifier)
                              .goToConversations(),
                        ),
                        const SizedBox(height: 8),
                        for (final (i, session) in recent.indexed)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ConversationTile(session: session, isNew: i == 0),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 50 + 16, // Tab bar height + padding
            child: const HomeChatBar(),
          ),
        ],
      ),
    );
  }
}

class _PendantStatusIndicator extends StatelessWidget {
  const _PendantStatusIndicator({required this.status, required this.onConnect});
  final PendantStatus status;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final connected = status.isConnected;
    
    final Widget leading;
    if (!connected) {
      leading = Icon(CupertinoIcons.bluetooth, size: 20, color: CupertinoColors.systemGrey);
    } else if (status.state == PendantState.reconnecting) {
      leading = Icon(CupertinoIcons.arrow_2_circlepath, size: 20, color: CupertinoColors.systemOrange);
    } else {
      leading = Icon(CupertinoIcons.bluetooth, size: 20, color: CupertinoColors.systemGreen);
    }

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onConnect,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          if (connected && status.batteryPercent != null) ...[
            const SizedBox(width: 6),
            Text(
              '${status.batteryPercent}%',
              style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(
            CupertinoPageRoute(fullscreenDialog: true, builder: (_) => const ChatPage()),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.systemGrey.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Equalizer(
                    color: CupertinoColors.activeBlue,
                    level: conversation.micLevel,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    status.deviceName ?? 'Pendant',
                    style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
                  ),
                ],
              ),
              if (active != null && active.segments.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    minSize: 0,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.read(conversationProvider.notifier).forceEndSession();
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.add_circled, size: 18),
                        SizedBox(width: 4),
                        Text(
                          'New memory',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  preview,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontStyle: words.isNotEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                    color: CupertinoColors.label.withValues(alpha: 0.8),
                    fontSize: 17,
                    height: 1.3,
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

/// Animated 4-bar voice meter.
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
                  color: widget.color,
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.bluetooth, color: CupertinoColors.systemGrey, size: 28),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No pendant yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Connect your pendant to start talking.',
                    style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 14),
                  ),
                ],
              ),
            ),
            CupertinoButton.filled(
              onPressed: onConnect,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              borderRadius: BorderRadius.circular(20),
              child: const Text('Scan', style: TextStyle(fontWeight: FontWeight.w600)),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: interactive ? onPillTap : null,
            child: Text(
              pillLabel,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: Column(
          children: [
            const Icon(CupertinoIcons.mic_slash, color: CupertinoColors.systemGrey, size: 48),
            const SizedBox(height: 16),
            Text(
              connected
                  ? 'Listening… speak to capture a memory.'
                  : 'Nothing here yet.\nConnect your pendant and say something.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: CupertinoColors.systemGrey, height: 1.5, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}