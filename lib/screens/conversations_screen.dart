import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transcript.dart';
import '../providers/conversation_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/conversation_tile.dart';
import '../widgets/page_header.dart';
import 'trash_screen.dart';

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      ConversationsScreenState();
}

class ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _scroll.dispose();
    _query.dispose();
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

  String _dayLabel(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(time.year, time.month, time.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final label = '${months[time.month - 1]} ${time.day}';
    if (time.year != now.year) return '$label ${time.year}';
    return label;
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(conversationProvider).conversations;
    final bottomInset = MediaQuery.paddingOf(context).bottom + 50 + 16;
    final query = _query.text.trim().toLowerCase();

    final visible = sessions.where((s) {
      if (s.isDeleted) return false;
      if (query.isEmpty) return true;
      if (s.title.toLowerCase().contains(query)) return true;
      if (s.summary != null && s.summary!.toLowerCase().contains(query)) {
        return true;
      }
      return s.segments.any((seg) => seg.text.toLowerCase().contains(query));
    }).toList();

    // Group by calendar day, newest first. Pinned items get their own group at the top.
    final pinned = visible.where((s) => s.isPinned).toList();
    final unpinned = visible.where((s) => !s.isPinned).toList();

    final groups = <String, List<ConversationSession>>{};
    final order = <String>[];

    if (pinned.isNotEmpty) {
      groups['Pinned'] = pinned;
      order.add('Pinned');
    }

    for (final session in unpinned) {
      final label = _dayLabel(session.finishedAt ?? session.startedAt);
      if (!groups.containsKey(label)) {
        groups[label] = [];
        order.add(label);
      }
      groups[label]!.add(session);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            SliverToBoxAdapter(
              child: PageHeader(
                title: 'Memories',
                actions: [
                  _HeaderCircleButton(
                    icon: Icons.delete_outline,
                    tooltip: 'Trash',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TrashScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : const Color(0xFFE5E5E5),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        size: 20,
                        color: Color(0xFF888888),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _query,
                          decoration: const InputDecoration(
                            hintText: 'Ask or search memories...',
                            hintStyle: TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          style: TextStyle(
                            color:
                                isDark ? Colors.white : Colors.black,
                            fontSize: 15,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      if (query.isNotEmpty)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _query.clear();
                            setState(() {});
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.clear,
                              size: 18,
                              color: Color(0xFF888888),
                            ),
                          ),
                        ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => ref
                            .read(conversationProvider.notifier)
                            .microphoneTest(),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.mic_none,
                            size: 20,
                            color: Color(0xFF888888),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (sessions.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyConversations(),
              )
            else
              SliverPadding(
                padding: EdgeInsets.only(
                  top: 12,
                  left: 20,
                  right: 20,
                  bottom: bottomInset,
                ),
                sliver: visible.isEmpty && query.isNotEmpty
                    ? SliverToBoxAdapter(
                        child: _NoMatches(query: query.trim()),
                      )
                    : SliverList(
                        delegate: SliverChildListDelegate([
                          for (final label in order) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 16,
                                bottom: 4,
                              ),
                              child: _DayHeader(label: label),
                            ),
                            for (final session in groups[label]!)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: ConversationTile(
                                  session: session,
                                  isNew:
                                      session.status ==
                                          ConversationStatus.completed &&
                                      (session.finishedAt ?? session.startedAt)
                                          .isAfter(
                                            DateTime.now().subtract(
                                              const Duration(minutes: 1),
                                            ),
                                          ),
                                  onDelete: () => ref
                                      .read(conversationProvider.notifier)
                                      .removeSession(session.id),
                                  onPin: () => ref
                                      .read(conversationProvider.notifier)
                                      .togglePin(session.id),
                                ),
                              ),
                          ],
                        ]),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 44px circle header action matching the Capture pendant-button language.
class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
            width: 1,
          ),
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF888888)),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12, left: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF222222) : const Color(0xFFE5E5E5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: isDark
                    ? const Color(0xFFCCCCCC)
                    : const Color(0xFF666666),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(
              color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Text(
          'No memories found matching "$query".',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF888888)),
        ),
      ),
    );
  }
}

class _EmptyConversations extends ConsumerWidget {
  const _EmptyConversations();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.memory_rounded,
                color: Theme.of(context).primaryColor.withValues(alpha: 0.8),
                size: 64,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'A blank slate',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'Connect your pendant and let it listen to the world.\nYour memories will magically appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF888888),
                height: 1.5,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () =>
                  ref.read(navigationTabProvider.notifier).goToHome(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: const Text(
                'Start capturing',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
