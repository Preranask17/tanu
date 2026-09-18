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
import '../providers/stt_model_provider.dart';
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
      _checkRetiredModels();
    });
  }

  Future<void> _checkRetiredModels() async {
    final hasRetired = await ref
        .read(sttModelProvider.notifier)
        .hasRetiredModels();
    if (hasRetired && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('STT Model Upgrade'),
          content: const Text(
            'We\'ve upgraded the offline speech engine to a highly accurate Moonshine model. '
            'Please delete the old model to make room and install the latest one.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(sttModelProvider.notifier).deleteModel().then((_) {
                  ref.read(sttModelProvider.notifier).download();
                });
              },
              child: const Text('Delete & Upgrade'),
            ),
          ],
        ),
      );
    }
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
    final status =
        ref.watch(pendantStatusProvider).value ?? const PendantStatus();
    final conversation = ref.watch(conversationProvider);

    // Calculate padding for the persistent bottom chat bar
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;
    // On mobile, bottom dock is safeAreaBottom + 16 (bottom offset) + 64 (height) = safeAreaBottom + 80.
    // We want 16px padding above the dock, so we need 96.
    final bottomPadding =
        MediaQuery.paddingOf(context).bottom + (isDesktop ? 16 : 96);
    final bottomInset = bottomPadding + 62 + 16; // space for chat bar

    final recent = conversation.conversations.length > 3
        ? conversation.conversations
              .sublist(conversation.conversations.length - 3)
              .reversed
              .toList()
        : conversation.conversations.reversed.toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async =>
                ref.read(conversationProvider.notifier).reloadFromStorage(),
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverAppBar(
                  expandedHeight: 160,
                  floating: true,
                  pinned: true,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      'Capture',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                  ),
                  actions: [
                    _PendantStatusIndicator(
                      status: status,
                      onConnect: _openDevicePicker,
                    ),
                    const SizedBox(width: 8),
                  ],
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
                            conversation.conversations.isEmpty &&
                            status.isConnected)
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: ConversationTile(
                                session: session,
                                isNew: i == 0,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomPadding,
            child: const Center(child: HomeChatBar()),
          ),
        ],
      ),
    );
  }
}

class _PendantStatusIndicator extends StatelessWidget {
  const _PendantStatusIndicator({
    required this.status,
    required this.onConnect,
  });
  final PendantStatus status;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final connected = status.isConnected;

    final Widget leading;
    if (!connected) {
      leading = const Icon(
        Icons.bluetooth,
        size: 20,
        color: Color(0xFF888888),
      );
    } else if (status.state == PendantState.reconnecting) {
      leading = const Icon(
        Icons.sync,
        size: 20,
        color: Colors.orange,
      );
    } else {
      leading = const Icon(
        Icons.bluetooth_connected,
        size: 20,
        color: Colors.green,
      );
    }

    return TextButton(
      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
      onPressed: onConnect,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          if (connected && status.batteryPercent != null) ...[
            const SizedBox(width: 6),
            Text(
              '${status.batteryPercent}%',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF888888),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LiveCaptureCard extends ConsumerWidget {
  const _LiveCaptureCard({required this.status, required this.conversation});

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
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => const ChatPage(),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Equalizer(
                    color: Theme.of(context).primaryColor,
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
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF888888),
                    ),
                  ),
                ],
              ),
              if (active != null && active.segments.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.read(conversationProvider.notifier).forceEndSession();
                    },
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text(
                      'New memory',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
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
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.8),
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
                height:
                    12 +
                    (16 * amp) *
                        (0.5 +
                            0.5 *
                                math.sin(
                                  i * 0.9 + t * frequencies[i] + phases[i],
                                )),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.bluetooth,
              color: Color(0xFF888888),
              size: 28,
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No pendant yet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Connect your pendant to start talking.',
                    style: TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: onConnect,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: interactive ? onPillTap : null,
            child: Text(
              pillLabel,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
            const Icon(
              Icons.mic_off,
              color: Color(0xFF888888),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              connected
                  ? 'Listening… speak to capture a memory.'
                  : 'Nothing here yet.\nConnect your pendant and say something.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF888888),
                height: 1.5,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
