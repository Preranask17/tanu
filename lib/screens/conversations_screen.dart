import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transcript.dart';
import '../providers/conversation_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/conversation_tile.dart';
import 'trash_screen.dart';
import '../widgets/page_layout.dart';

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      ConversationsScreenState();
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
    final convState = ref.watch(conversationProvider);
    final sessions = convState.conversations;
    final processingIds = convState.processingIds;
    final notifier = ref.read(conversationProvider.notifier);
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
            SliverAppBar(
              expandedHeight: 140,
              floating: true,
              pinned: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: false,
                title: const TanuPageTitle('Memories'),
                titlePadding: const EdgeInsets.only(left: 24, bottom: 20),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      top: -50,
                      right: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -80,
                      left: -50,
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blueAccent.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TrashScreen()),
                      );
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    onPressed: toggleSearch,
                    icon: Icon(_searching ? Icons.close : Icons.search),
                  ),
                ),
              ],
            ),
            if (_searching)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                  child: TextField(
                    controller: _query,
                    autofocus: true,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Search memories...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _query.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF161618)
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(100), // Pill shape
                        borderSide: BorderSide(
                          color: isDark
                              ? const Color(0xFF2A2A2C)
                              : const Color(0xFFE9ECEF),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(100),
                        borderSide: BorderSide(
                          color: isDark
                              ? const Color(0xFF2A2A2C)
                              : const Color(0xFFE9ECEF),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(100),
                        borderSide: BorderSide(
                          color: Theme.of(context).primaryColor,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
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
                  top: _searching ? 4 : 12,
                  left: 24,
                  right: 24,
                  bottom: bottomInset,
                ),
                sliver: visible.isEmpty && query.isNotEmpty
                    ? const SliverToBoxAdapter(child: _NoMatches())
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
                                  isProcessing:
                                      processingIds.contains(session.id),
                                  isFailed: !processingIds.contains(
                                    session.id,
                                  ) &&
                                      notifier.isQueuedForRetry(session.id),
                                  onRetry: () =>
                                      notifier.retrySession(session.id),
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
  const _NoMatches();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Text(
          'No matches for that search.',
          style: TextStyle(color: Color(0xFF888888)),
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
