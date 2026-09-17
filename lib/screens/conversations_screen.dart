import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transcript.dart';
import '../providers/conversation_provider.dart';
import '../providers/navigation_provider.dart';
import '../theme.dart';
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
    final bottomInset = MediaQuery.paddingOf(context).bottom + 50 + 16;
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

    return CupertinoPageScaffold(
      child: sessions.isEmpty
          ? const _EmptyConversations()
          : CustomScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                CupertinoSliverNavigationBar(
                  largeTitle: const Text('Memories'),
                  trailing: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: toggleSearch,
                    child: Icon(
                      _searching ? CupertinoIcons.clear_circled_solid : CupertinoIcons.search,
                    ),
                  ),
                ),
                CupertinoSliverRefreshControl(
                  onRefresh: () async =>
                      ref.read(conversationProvider.notifier).reloadFromStorage(),
                ),
                if (_searching)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: CupertinoSearchTextField(
                        controller: _query,
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                        onSuffixTap: () {
                          _query.clear();
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: EdgeInsets.only(
                    top: _searching ? 4 : 12,
                    left: 16,
                    right: 16,
                    bottom: bottomInset,
                  ),
                  sliver: visible.isEmpty && query.isNotEmpty
                      ? const SliverToBoxAdapter(child: _NoMatches())
                      : SliverList(
                          delegate: SliverChildListDelegate([
                            for (final label in order) ...[
                              Padding(
                                padding: const EdgeInsets.only(top: 16, bottom: 4),
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
                                            .isAfter(DateTime.now().subtract(
                                                const Duration(minutes: 1))),
                                    onDelete: () => ref
                                        .read(conversationProvider.notifier)
                                        .removeSession(session.id),
                                  ),
                                ),
                            ],
                          ]),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: CupertinoColors.systemGrey,
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
          style: TextStyle(color: CupertinoColors.systemGrey),
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
            const Icon(CupertinoIcons.archivebox, color: CupertinoColors.systemGrey, size: 48),
            const SizedBox(height: 16),
            const Text(
              'No memories yet.\nConnect your pendant and start talking.',
              textAlign: TextAlign.center,
              style: TextStyle(color: CupertinoColors.systemGrey, height: 1.5, fontSize: 16),
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: () =>
                  ref.read(navigationTabProvider.notifier).goToHome(),
              child: const Text('Go to Home', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}