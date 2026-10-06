import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../abstractions/audio_source.dart';
import '../providers/ble_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/stt_model_provider.dart';
import '../widgets/aura_orb.dart';
import '../widgets/home_chat_bar.dart';
import '../widgets/page_layout.dart';

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

  @override
  Widget build(BuildContext context) {
    final status =
        ref.watch(pendantStatusProvider).value ?? const PendantStatus();
    final conversation = ref.watch(conversationProvider);

    // The VoicePill is part of the page now, so only reserve room for the
    // mobile navigation dock at the bottom.
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;
    final bottomPadding =
        MediaQuery.paddingOf(context).bottom + (isDesktop ? 24 : 96);

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
                  expandedHeight: 140,
                  floating: true,
                  pinned: true,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  flexibleSpace: FlexibleSpaceBar(
                    centerTitle: false,
                    title: const TanuPageTitle('Capture'),
                    titlePadding: const EdgeInsets.only(left: 24, bottom: 20),
                  ),
                  actions: const [SizedBox(width: 8)],
                ),
                SliverToBoxAdapter(
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: bottomPadding + 100),
                      child: TanuPageRail(
                        top: 8,
                        bottom: 0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(child: _ConnectionCard(status: status)),
                            const SizedBox(height: 64),
                            _CaptureHero(
                              micLevel: conversation.micLevel,
                              isConnected: status.isConnected,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: bottomPadding,
            left: 0,
            right: 0,
            child: const SafeArea(
              top: false,
              bottom: false,
              child: TanuPageRail(
                top: 0,
                bottom: 0,
                child: HomeChatBar(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.status});

  final PendantStatus status;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final connected = status.isConnected;
    final accent = connected ? Colors.green : const Color(0xFF888888);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF252525) : const Color(0xFFE5E5E5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              size: 17,
              color: accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              switch (status.state) {
                PendantState.connected => status.deviceName ?? 'Connected',
                PendantState.reconnecting => 'Reconnecting...',
                PendantState.scanning => 'Looking for pendant...',
                PendantState.connecting => 'Connecting...',
                PendantState.disconnected => 'Not connected',
              },
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ),
          if (status.batteryPercent != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                '${status.batteryPercent}%',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
        ],
      ),
    );
  }
}

class _CaptureHero extends StatelessWidget {
  const _CaptureHero({required this.micLevel, required this.isConnected});

  final double micLevel;
  final bool isConnected;

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
        const SizedBox(height: 28),
        Center(
          child: AuraOrb(micLevel: micLevel, isConnected: isConnected),
        ),
      ],
    );
  }
}
