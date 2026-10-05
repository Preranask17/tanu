import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../abstractions/audio_source.dart';
import '../providers/ble_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/stt_model_provider.dart';
import '../widgets/aura_orb.dart';
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

    // Floating pill sits above the dock: dock = safe + 16 + 64; gap 16 → +96.
    // VoicePill height is 56; leave 16 above it for scroll clearance.
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;
    final bottomPadding =
        MediaQuery.paddingOf(context).bottom + (isDesktop ? 16 : 96);
    final bottomInset = bottomPadding + 56 + 16;

    final recent = conversation.conversations.length > 3
        ? conversation.conversations
              .sublist(conversation.conversations.length - 3)
              .reversed
              .toList()
        : conversation.conversations.reversed.toList();

    final hasMemories = conversation.active != null ||
        conversation.conversations.isNotEmpty;

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
                    const SizedBox(width: 8),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 16, bottom: bottomInset),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: AuraOrb(
                              micLevel: conversation.micLevel,
                              isConnected: status.isConnected,
                            ),
                          ),
                        ),
                        // Voice Pill right beneath the Orb
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: HomeChatBar(),
                        ),
                        if (hasMemories) ...[
                          const SizedBox(height: 16),
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
        ],
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