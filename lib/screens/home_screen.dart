import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../abstractions/audio_source.dart';
import '../models/conversation.dart';
import '../providers/ble_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/stt_model_provider.dart';
import '../screens/chat_screen.dart';
import '../widgets/ai_presence_orb.dart';
import '../widgets/device_picker_sheet.dart';
import '../widgets/device_status_controls.dart';
import '../widgets/page_header.dart';

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
      _ensureSttModel();
    });
  }

  /// Auto-downloads the Moonshine STT model on first launch, or upgrades
  /// from a retired model if one exists.
  Future<void> _ensureSttModel() async {
    final notifier = ref.read(sttModelProvider.notifier);

    // If there is a retired (old) model, prompt the user to upgrade.
    final hasRetired = await notifier.hasRetiredModels();
    if (hasRetired && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('STT Model Upgrade'),
          content: const Text(
            'We\'ve upgraded the offline speech engine to Moonshine '
            '(fast, accurate English, fully offline). '
            'Please delete the old model to make room and install the latest one.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                notifier.deleteModel().then((_) => notifier.download());
              },
              child: const Text('Delete & Upgrade'),
            ),
          ],
        ),
      );
      return;
    }

    // If the model is simply missing (fresh install), auto-download it.
    await notifier.refresh();
    final state = ref.read(sttModelProvider);
    if (state.phase == SttModelPhase.missing) {
      debugPrint('[tanu] STT model missing -- auto-downloading...');
      // notifier.download(); // Auto-download disabled
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

    // Bottom cushion clears the floating nav dock (no chat bar anymore).
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;
    final bottomPadding =
        MediaQuery.paddingOf(context).bottom + (isDesktop ? 16 : 96);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.read(conversationProvider.notifier).reloadFromStorage(),
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // Consistent page header: logo top-left, status top-right,
            // heading below. UI only: reads existing status, opens the
            // existing picker.
            SliverToBoxAdapter(
              child: PageHeader(
                title: 'Capture',
                actions: [
                  DeviceStatusActions(
                    status: status,
                    onBluetoothTap: _openDevicePicker,
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 8, bottom: bottomPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Calm AI presence. Pure visual: only reads the
                    // already-watched mic level / listening flag.
                    AiPresenceOrb(
                      level: conversation.micLevel,
                      listening: conversation.isListening,
                    ),
                    // Live transcription: always visible (placeholder when
                    // idle), capped height with internal scrolling.
                    _LiveCaptureCard(
                      status: status,
                      conversation: conversation,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
    // The one existing capture flag: STT session live or not. Nothing else
    // drives this badge, and nothing here writes any backend state.
    final capturing = conversation.isListening;
    final label = switch (conversation.sttEvent) {
      'stt unavailable' => 'Transcription unavailable',
      'Model missing. Download in Settings.' =>
        'Model missing. Download in Settings.',
      _ => capturing ? 'Capturing...' : 'Ready',
    };

    final preview = words.isNotEmpty
        ? words
        : (active != null && active.segments.isNotEmpty
              ? active.segments.last.text.trim()
              : '');

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final listening = conversation.isListening;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : const Color(0xFFE5E5E5),
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
                  // Status badge: fades between Capturing... (pulsing accent
                  // dot) and muted Ready as the existing capture flag flips.
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Row(
                        key: ValueKey<bool>(capturing),
                        children: [
                          if (capturing) ...[
                            _BlinkDot(
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: capturing
                                    ? null
                                    : const Color(0xFF888888),
                              ),
                            ),
                          ),
                        ],
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
              const SizedBox(height: 16),
              // Capped transcript area: placeholder when idle, internal
              // scroll when the stream grows long.
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: preview.isNotEmpty
                      ? Text(
                          preview,
                          style: TextStyle(
                            fontStyle: words.isNotEmpty
                                ? FontStyle.italic
                                : FontStyle.normal,
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.85),
                            fontSize: 16,
                            height: 1.4,
                          ),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                listening
                                    ? 'Listening…'
                                    : 'Transcription will appear here…',
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Color(0xFF888888),
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            if (listening) ...[
                              const SizedBox(width: 8),
                              _BlinkDot(
                                color: Theme.of(context).primaryColor,
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Subtle blinking cursor dot shown while transcription is live.
class _BlinkDot extends StatefulWidget {
  const _BlinkDot({this.color = const Color(0xFFE5484D)});

  final Color color;

  @override
  State<_BlinkDot> createState() => _BlinkDotState();
}

class _BlinkDotState extends State<_BlinkDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.25).animate(_blink),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
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
