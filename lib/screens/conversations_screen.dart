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
            // Consistent page header (logo top-left, heading below) plus
            // an always-visible glass search. UI only: filters the
            // already-loaded sessions locally, no backend changes.
            const SliverToBoxAdapter(
              child: PageHeader(title: 'Memories'),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                // Stadium-pill ask/search bar: search left, query middle,
                // clear + mic right. UI only: the mic reuses the existing
                // phone-mic test handler, nothing new is wired.
                child: Container(
                  height: 50,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
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
                      Icon(
                        Icons.search,
                        size: 20,
                        color:
                            Colors.white.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _query,
                          decoration: InputDecoration(
                            hintText: 'Ask or search memories...',
                            hintStyle: TextStyle(
                              color: Colors.white
                                  .withValues(alpha: 0.4),
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
                          child: Padding(
                            padding:
                                const EdgeInsets.all(4),
                            child: Icon(
                              Icons.clear,
                              size: 18,
                              color: Colors.white
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => ref
                            .read(conversationProvider.notifier)
                            .microphoneTest(),
                        child: Padding(
                          padding:
                              const EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.mic_none,
                            size: 20,
                            color:
                                Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // AI reply card: fades in below the pill while a query matches.
            // Built from the real filtered matches — no backend query layer.
            SliverToBoxAdapter(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) =>
                    SizeTransition(
                  sizeFactor: animation,
                  alignment: Alignment.topCenter,
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                ),
                child: query.isNotEmpty && visible.isNotEmpty
                    ? _AiReplyCard(
                        key: const ValueKey('reply'),
                        session: visible.first,
                        matchCount: visible.length,
                      )
                    : const SizedBox.shrink(key: ValueKey('empty')),
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
/// AI reply card under the search pill. Display only: summarizes the real
/// filtered matches (top hit + count) with key details in bold. Hidden
/// whenever the query is cleared or matches nothing.
class _AiReplyCard extends StatelessWidget {
  const _AiReplyCard({
    super.key,
    required this.session,
    required this.matchCount,
  });

  final ConversationSession session;
  final int matchCount;

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
    final summary = session.summary?.isNotEmpty == true
        ? session.summary!
        : (session.segments.isNotEmpty
              ? session.segments.last.text.trim()
              : session.title);
    final title = session.title.trim().isNotEmpty
        ? session.title.trim()
        : 'Untitled memory';
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 16, left: 20, right: 20),
      padding: const EdgeInsets.all(18),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0xFFE5E5E5),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 14,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                matchCount == 1
                    ? '1 memory found'
                    : '$matchCount memories found',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF888888),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: isDark ? Colors.white : Colors.black,
              ),
              children: [
                TextSpan(
                  text: '“$summary”',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: ' — saved in '),
                TextSpan(
                  text: '“$title”.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
