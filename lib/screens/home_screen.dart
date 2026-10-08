import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../abstractions/audio_source.dart';
import '../models/conversation.dart';
import '../providers/ble_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/stt_model_provider.dart';
import '../widgets/ai_presence_orb.dart';
import '../widgets/device_picker_sheet.dart';
import '../widgets/home_chat_bar.dart';
import '../widgets/pinned_header.dart';

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

  /// Auto-downloads the Whisper Small STT model on first launch, or upgrades
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
            'We\'ve upgraded the offline speech engine '
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

    final isDesktop = MediaQuery.sizeOf(context).width >= 600;
    final bottomPadding =
        MediaQuery.paddingOf(context).bottom + (isDesktop ? 16 : 96);
    final bottomInset = bottomPadding + 62 + 16;

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
                PinnedHeader(
                  title: 'Capture',
                  actions: [
                    if (status.isConnected &&
                        status.batteryPercent != null)
                      _BatteryPill(
                        percent: status.batteryPercent!,
                      ),
                    _PendantButton(
                      status: status,
                      onTap: _openDevicePicker,
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 8, bottom: bottomInset),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AiPresenceOrb(
                          level: conversation.micLevel,
                          listening: conversation.isListening,
                        ),
                        const SizedBox(height: 4),
                        _LiveCaptureStrip(
                          conversation: conversation,
                        ),
                        const SizedBox(height: 20),
                        _CaptureHero(
                          micLevel: conversation.micLevel,
                          isConnected: status.isConnected,
                          deviceName: status.deviceName,
                        ),
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

/// Solid pendant status button with a live pulse while disconnected.
/// Connected: solid green, white icon. Otherwise: solid dark body, red glow
/// and an expanding pulse ring (rotating sync while reconnecting). Opens the
/// existing device picker; all BLE logic lives elsewhere and is untouched.
class _PendantButton extends StatefulWidget {
  const _PendantButton({
    required this.status,
    required this.onTap,
  });

  final PendantStatus status;
  final VoidCallback onTap;

  @override
  State<_PendantButton> createState() => _PendantButtonState();
}

class _PendantButtonState extends State<_PendantButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final connected = status.isConnected;
    final reconnecting = status.state == PendantState.reconnecting ||
        status.state == PendantState.scanning ||
        status.state == PendantState.connecting;

    final IconData icon;
    final Color body;
    final Color iconColor;
    if (connected) {
      icon = Icons.bluetooth_connected;
      body = const Color(0xFF2E7D32);
      iconColor = Colors.white;
    } else if (reconnecting) {
      icon = Icons.sync;
      body = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E2E2);
      iconColor = Colors.orange;
    } else {
      icon = Icons.bluetooth;
      body = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFD8D8D8);
      iconColor = isDark ? const Color(0xFFBBBBBB) : const Color(0xFF666666);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: SizedBox(
        width: 52,
        height: 52,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!connected)
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final t = _pulse.value;
                  return Container(
                    width: 44 + 8 * t,
                    height: 44 + 8 * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.5 * (1 - t)),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: body,
                boxShadow: [
                  if (!connected)
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.35),
                      blurRadius: 14,
                      spreadRadius: 1,
                    )
                  else
                    BoxShadow(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.45),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: reconnecting
                  ? RotationTransition(
                      turns: _pulse,
                      child: Icon(icon, size: 20, color: iconColor),
                    )
                  : Icon(icon, size: 20, color: iconColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live transcription strip under the orb: the in-progress words stream
/// here while capturing, the last captured line stays visible when idle.
/// Display only — capture controls live in the chat bar as before.
class _LiveCaptureStrip extends StatelessWidget {
  const _LiveCaptureStrip({required this.conversation});

  final ConversationState conversation;

  @override
  Widget build(BuildContext context) {
    final words = conversation.liveTranscript.trim();
    final active = conversation.active;
    final preview = words.isNotEmpty
        ? words
        : (active != null && active.segments.isNotEmpty
              ? active.segments.last.text.trim()
              : '');
    final idle = preview.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 110),
        child: SingleChildScrollView(
          child: Text(
            idle ? 'Transcription will appear here…' : preview,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 15,
              height: 1.45,
              color: idle
                  ? const Color(0xFF888888)
                  : Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Battery pill from the shared header language. Display only.
class _BatteryPill extends StatelessWidget {
  const _BatteryPill({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.battery_std, size: 18, color: Color(0xFF888888)),
          const SizedBox(width: 6),
          Text(
            '$percent%',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF888888),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureHero extends StatelessWidget {
  const _CaptureHero({
    required this.micLevel,
    required this.isConnected,
    required this.deviceName,
  });

  final double micLevel;
  final bool isConnected;
  final String? deviceName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          isConnected
              ? 'Listening for your thoughts'
              : 'Connect your pendant to begin',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isConnected
              ? 'Tap the control below when you are ready'
              : 'Your conversations stay on this device',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 14),
        ),
        if (isConnected && deviceName != null) ...[
          const SizedBox(height: 8),
          Text(
            deviceName!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF888888),
            ),
          ),
        ],
      ],
    );
  }
}
