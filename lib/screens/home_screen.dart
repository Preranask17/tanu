import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../abstractions/audio_source.dart';
import '../models/conversation.dart';
import '../providers/ble_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/stt_model_provider.dart';
import 'chat_screen.dart';
import '../widgets/device_picker_sheet.dart';
import '../widgets/pinned_header.dart';
import '../widgets/waveform_visualizer.dart';
import '../theme/tanu_colors.dart';

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

  void _openTranscript() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ChatPage(),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final status =
        ref.watch(pendantStatusProvider).value ?? const PendantStatus();
    final conversation = ref.watch(conversationProvider);

    final isDesktop = MediaQuery.sizeOf(context).width >= 600;
    final live = conversation.isListening || conversation.active != null;
    // Keep the scrollable content clear of the floating dock on mobile.
    final bottomInset =
        MediaQuery.paddingOf(context).bottom + (isDesktop ? 24 : 108);

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
            PinnedHeader(
              title: '${_greeting()},',
              subtitle: 'Let’s capture something worth remembering.',
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 8, bottom: bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HomeStatusStrip(
                      status: status,
                      conversation: conversation,
                      onConnect: _openDevicePicker,
                      onOpenTranscript: _openTranscript,
                    ),
                    WaveformVisualizer(
                      level: conversation.micLevel,
                      listening: conversation.isListening,
                      transcribing: conversation.liveTranscript
                          .trim()
                          .isNotEmpty,
                    ),
                    _LiveCaptureStrip(
                      conversation: conversation,
                      onOpenTranscript: _openTranscript,
                    ),
                    const SizedBox(height: 12),
                    if (!live)
                      _CaptureHero(
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
    );
  }
}

/// Connection + live-session status, placed directly above the waveform.
/// Presentation only: reads the already-watched status/conversation values and
/// forwards taps to the existing device picker / live transcript route.
class _HomeStatusStrip extends StatelessWidget {
  const _HomeStatusStrip({
    required this.status,
    required this.conversation,
    required this.onConnect,
    required this.onOpenTranscript,
  });

  final PendantStatus status;
  final ConversationState conversation;
  final VoidCallback onConnect;
  final VoidCallback onOpenTranscript;

  @override
  Widget build(BuildContext context) {
    final live = conversation.isListening || conversation.active != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ConnectionStrip(status: status, onTap: onConnect),
          if (live) ...[
            const SizedBox(height: 8),
            _LiveConversationBanner(
              listening: conversation.isListening,
              onTap: onOpenTranscript,
            ),
          ],
        ],
      ),
    );
  }
}

class _ConnectionStrip extends StatelessWidget {
  const _ConnectionStrip({required this.status, required this.onTap});

  final PendantStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    final connected = status.isConnected;
    final reconnecting =
        status.state == PendantState.reconnecting ||
        status.state == PendantState.scanning ||
        status.state == PendantState.connecting;

    final IconData icon;
    final Color accent;
    final String label;
    if (connected) {
      icon = Icons.bluetooth_connected;
      accent = c.success;
      label = status.deviceName?.trim().isNotEmpty == true
          ? status.deviceName!.trim()
          : 'Pendant connected';
    } else if (reconnecting) {
      icon = Icons.sync;
      accent = c.warning;
      label = status.state == PendantState.scanning
          ? 'Looking for pendant…'
          : 'Reconnecting…';
    } else {
      icon = Icons.bluetooth_disabled;
      accent = c.danger;
      label = 'Connect Pendant';
    }

    final battery = status.batteryPercent;
    final showBattery = connected && battery != null;

    return Semantics(
      button: true,
      label: '$label. Tap to manage your pendant.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: connected ? c.success.withValues(alpha: 0.28) : c.border,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
              ),
              if (showBattery) ...[
                Icon(Icons.battery_std, size: 16, color: c.textMuted),
                const SizedBox(width: 4),
                Text(
                  '$battery%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(Icons.chevron_right_rounded, size: 18, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveConversationBanner extends StatelessWidget {
  const _LiveConversationBanner({required this.listening, required this.onTap});

  final bool listening;
  final VoidCallback onTap;

  static const _terracotta = Color(0xFF8C6D58);

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    final title = listening ? 'Live Conversation' : 'Conversation paused';

    return Semantics(
      button: true,
      label: '$title. Tap to open the live transcript.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _terracotta.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: _terracotta.withValues(alpha: c.isDark ? 0.10 : 0.07),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: listening ? _terracotta : c.textMuted,
                  boxShadow: listening
                      ? [
                          BoxShadow(
                            color: _terracotta.withValues(alpha: 0.45),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Tap to open the live transcript',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        color: c.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: c.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live transcription strip under the waveform: the in-progress words stream
/// here while capturing, the last captured line stays visible when idle.
/// Tapping opens the live transcript only while a session is active.
class _LiveCaptureStrip extends StatelessWidget {
  const _LiveCaptureStrip({
    required this.conversation,
    required this.onOpenTranscript,
  });

  final ConversationState conversation;
  final VoidCallback onOpenTranscript;

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
    final live = conversation.isListening || active != null;
    return Padding(
      padding: const EdgeInsets.only(top: 2, left: 32, right: 32),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: live
            ? () {
                HapticFeedback.selectionClick();
                onOpenTranscript();
              }
            : null,
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
                    ? context.tanuColors.textMuted
                    : Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptureHero extends StatelessWidget {
  const _CaptureHero({required this.isConnected, required this.deviceName});

  final bool isConnected;
  final String? deviceName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          isConnected ? 'Ready when you are' : 'Connect your pendant to begin',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isConnected
              ? 'Your pendant captures automatically as you speak.'
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
              color: context.tanuColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}
