import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transcript.dart';
import '../providers/conversation_provider.dart';
import '../providers/navigation_provider.dart';
import '../theme.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/conversation_tile.dart';

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() => ConversationsScreenState();
}

class ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _query = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _scroll.dispose();
    _query.dispose();
    super.dispose();
  }

  void toggleSearch() {
    setState(() => _searching = !_searching);
    if (!_searching) _query.clear();
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
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final label = '${months[time.month - 1]} ${time.day}';
    if (time.year != now.year) return '$label ${time.year}';
    return label;
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(conversationProvider).conversations;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final query = _query.text.trim().toLowerCase();

    final visible = sessions.where((s) {
      if (query.isEmpty) return true;
      if (s.title.toLowerCase().contains(query)) return true;
      return s.segments.any(
        (seg) => seg.text.toLowerCase().contains(query),
      );
    }).toList();

    // Group by calendar day, newest first.
    final groups = <String, List<ConversationSession>>{};
    final order = <String>[];
    for (final session in visible) {
      final label = _dayLabel(session.finishedAt ?? session.startedAt);
      if (!groups.containsKey(label)) {
        groups[label] = [];
        order.add(label);
      }
      groups[label]!.add(session);
    }

    return Column(
      children: [
        if (_searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextField(
              controller: _query,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search memories',
                prefixIcon: const Icon(Icons.search, color: kTanuMuted),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, color: kTanuMuted),
                        onPressed: () {
                          _query.clear();
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
        Expanded(
          child: sessions.isEmpty
              ? _EmptyConversations()
              : RefreshIndicator(
                  onRefresh: () async =>
                      ref.read(conversationProvider.notifier).reloadFromStorage(),
                  color: kTanuWarm,
                  child: CustomScrollView(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.only(
                          top: _searching ? 12 : 4,
                          left: 8,
                          right: 8,
                          bottom: kBottomNavBarHeight + bottomInset + 16,
                        ),
                        sliver: visible.isEmpty
                            ? const SliverToBoxAdapter(child: _NoMatches())
                            : SliverList(
                                delegate: SliverChildListDelegate([
                                  for (final label in order) ...[
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          8, 16, 8, 0),
                                      child: _DayHeader(label: label),
                                    ),
                                    for (final session in groups[label]!)
                                      ConversationTile(
                                        session: session,
                                        isNew:
                                            session.status ==
                                                ConversationStatus.completed &&
                                            (session.finishedAt ?? session.startedAt)
                                                .isAfter(DateTime.now().subtract(
                                                    const Duration(minutes: 1))),
                                        onDelete: () => ref
                                            .read(conversationProvider.notifier)
                                            .removeSession(session.id),
                                      ),
                                  ],
                                ]),
                              ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: kTanuInk.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Text(
          'No matches for that search.',
          style: TextStyle(color: kTanuMuted),
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
            Icon(Icons.forum_outlined, color: kTanuMuted, size: 36),
            const SizedBox(height: 12),
            const Text(
              'No memories yet.\nConnect your pendant and start talking.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kTanuMuted, height: 1.5),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  ref.read(navigationTabProvider.notifier).goToHome(),
              child: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    );
  }
}