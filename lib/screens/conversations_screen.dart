import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transcript.dart';
import '../providers/conversation_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/rag_provider.dart';
import '../theme/tanu_colors.dart';
import '../widgets/conversation_tile.dart';
import '../widgets/pinned_header.dart';
import 'chat_screen.dart';
import 'trash_screen.dart';

enum _LibraryFilter {
  all('All'),
  notes('Notes'),
  transcripts('Transcripts'),
  favorites('Favorites');

  const _LibraryFilter(this.label);

  final String label;
}

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      ConversationsScreenState();
}

class ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _query = TextEditingController();
  _LibraryFilter _filter = _LibraryFilter.all;
  bool _searchOpen = false;

  /// Structured RAG reply for the submitted question. Same pipeline calls as
  /// the Ask screen (backfill + rag.answer) — no new backend, new UI only.
  String? _ragAnswer;
  List<String> _ragSourceIds = const [];
  bool _ragBusy = false;
  String? _ragError;
  bool _backfilled = false;

  @override
  void dispose() {
    _scroll.dispose();
    _query.dispose();
    super.dispose();
  }

  Future<void> _askRag() async {
    final question = _query.text.trim();
    if (question.isEmpty || _ragBusy) return;
    setState(() {
      _ragBusy = true;
      _ragError = null;
      _ragAnswer = null;
      _ragSourceIds = const [];
    });
    try {
      final indexer = await ref.read(memoryIndexerProvider.future);
      if (!_backfilled) {
        _backfilled = true;
        // Fire-and-forget: don't block the answer on backfill.
        unawaited(
          indexer.backfill(ref.read(conversationProvider).conversations),
        );
      }
      final rag = await ref.read(ragServiceProvider.future);
      final result = await rag.answer(question);
      if (!mounted || !_searchOpen) return;
      final seen = <String>{};
      final ordered = <String>[];
      for (final source in result.sources) {
        if (seen.add(source.chunk.sessionId)) {
          ordered.add(source.chunk.sessionId);
        }
      }
      setState(() {
        _ragAnswer = result.answer;
        _ragSourceIds = ordered;
        _ragBusy = false;
      });
    } catch (e) {
      if (!mounted || !_searchOpen) return;
      setState(() {
        _ragError = '$e';
        _ragBusy = false;
      });
    }
  }

  void _clearSearch() {
    _query.clear();
    setState(() {
      _ragAnswer = null;
      _ragSourceIds = const [];
      _ragError = null;
      _ragBusy = false;
    });
  }

  void _toggleSearch() {
    if (_searchOpen) {
      _query.clear();
      setState(() {
        _searchOpen = false;
        _ragAnswer = null;
        _ragSourceIds = const [];
        _ragError = null;
        _ragBusy = false;
      });
    } else {
      setState(() => _searchOpen = true);
    }
  }

  bool _matchesFilter(ConversationSession session) {
    return switch (_filter) {
      _LibraryFilter.all => true,
      _LibraryFilter.notes => session.summary?.trim().isNotEmpty ?? false,
      _LibraryFilter.transcripts =>
        session.segments.isNotEmpty ||
            (session.cleanedTranscript?.trim().isNotEmpty ?? false),
      _LibraryFilter.favorites => session.isPinned,
    };
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
      if (s.isDeleted || !_matchesFilter(s)) return false;
      if (query.isEmpty) return true;
      if (s.title.toLowerCase().contains(query)) return true;
      if (s.summary != null && s.summary!.toLowerCase().contains(query)) {
        return true;
      }
      return s.segments.any((seg) => seg.text.toLowerCase().contains(query));
    }).toList();

    // Group by calendar day, newest first. Pinned items get their own group at the top.
    final pinned = visible.where((s) => s.isPinned).toList();
    final unpinned = visible
        .where((s) => !s.isPinned)
        .toList()
        .reversed
        .toList();

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

    final c = context.tanuColors;

    final librarySections = <Widget>[
      for (final label in order) ...[
        _DayHeader(label: label),
        _MasonryGrid(
          children: [
            for (final session in groups[label]!)
              ConversationTile(
                key: ValueKey('library_${session.id}'),
                session: session,
                noteLayout: true,
                isProcessing: processingIds.contains(session.id),
                isFailed:
                    !processingIds.contains(session.id) &&
                    notifier.isQueuedForRetry(session.id),
                onRetry: () => notifier.retrySession(session.id),
                isNew:
                    session.status == ConversationStatus.completed &&
                    (session.finishedAt ?? session.startedAt).isAfter(
                      DateTime.now().subtract(const Duration(minutes: 1)),
                    ),
                onDelete: () => ref
                    .read(conversationProvider.notifier)
                    .removeSession(session.id),
                onPin: () => ref
                    .read(conversationProvider.notifier)
                    .togglePin(session.id),
              ),
          ],
        ),
      ],
    ];

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
              title: 'Library',
              actions: [
                _HeaderCircleButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Trash',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TrashScreen()),
                    );
                  },
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final filter in _LibraryFilter.values) ...[
                                  _LibraryFilterChip(
                                    label: filter.label,
                                    selected: _filter == filter,
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() => _filter = filter);
                                    },
                                  ),
                                  if (filter != _LibraryFilter.values.last)
                                    const SizedBox(width: 6),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _HeaderCircleButton(
                          icon: _searchOpen
                              ? Icons.close_rounded
                              : Icons.search_rounded,
                          tooltip: _searchOpen
                              ? 'Close search'
                              : 'Search memories',
                          onTap: _toggleSearch,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_searchOpen)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: c.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: c.textMuted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _query,
                                autofocus: true,
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) => _askRag(),
                                decoration: InputDecoration(
                                  hintText:
                                      'Search or ask about your memories…',
                                  hintStyle: TextStyle(
                                    color: c.textMuted,
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 14,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            if (query.isNotEmpty)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _clearSearch,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: c.surfaceMuted,
                                  ),
                                  child: Icon(
                                    Icons.clear_rounded,
                                    size: 15,
                                    color: c.textMuted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_ragBusy || _ragAnswer != null || _ragError != null)
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: _RagAnswerCard(
                      busy: _ragBusy,
                      answer: _ragAnswer,
                      error: _ragError,
                      sourceIds: _ragSourceIds,
                      sessions: sessions,
                      onRetry: _askRag,
                      onClear: _clearSearch,
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
                sliver:
                    visible.isEmpty &&
                        (query.isNotEmpty || _filter != _LibraryFilter.all)
                    ? SliverToBoxAdapter(
                        child: _NoMatches(
                          message: query.isNotEmpty
                              ? 'No matches for that search.'
                              : 'No memories in this view yet.',
                        ),
                      )
                    : SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 980),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: librarySections,
                            ),
                          ),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact library view selector. Selected chips use a filled blue surface in
/// light mode and a deep blue container with beige text in dark mode.
class _LibraryFilterChip extends StatelessWidget {
  const _LibraryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    final background = selected
        ? (c.isDark ? c.primaryContainer : c.primary)
        : Colors.transparent;
    final foreground = selected
        ? (c.isDark ? c.heading : c.onPrimary)
        : c.textMuted;
    final borderColor = selected ? c.primary : c.border;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: background,
        shape: StadiumBorder(side: BorderSide(color: borderColor)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Text(
              label,
              maxLines: 1,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 44px circle header action in the pendant-button language.
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
    final c = context.tanuColors;
    final button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.surface,
          border: Border.all(color: c.border, width: 1),
        ),
        child: Icon(icon, size: 20, color: c.textMuted),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Structured RAG reply card: the submitted question answered from saved
/// memories (same pipeline as the Ask screen), with the source memories as
/// tappable chips. Display only: every lookup below reads already-loaded
/// sessions, nothing new is fetched or stored.
class _RagAnswerCard extends StatelessWidget {
  const _RagAnswerCard({
    required this.busy,
    required this.answer,
    required this.error,
    required this.sourceIds,
    required this.sessions,
    required this.onRetry,
    required this.onClear,
  });

  final bool busy;
  final String? answer;
  final String? error;
  final List<String> sourceIds;
  final List<ConversationSession> sessions;
  final VoidCallback onRetry;
  final VoidCallback onClear;

  String _sourceTitle(String id) {
    for (final s in sessions) {
      if (s.id == id) {
        final title = s.title.trim();
        return title.isEmpty ? 'Untitled memory' : title;
      }
    }
    return 'Memory';
  }

  ConversationSession? _sourceSession(String id) {
    for (final s in sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4, left: 20, right: 20),
      padding: const EdgeInsets.all(18),
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 14, color: c.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  busy
                      ? 'Recalling memories…'
                      : error != null
                      ? 'Could not recall'
                      : sourceIds.length == 1
                      ? '1 memory found'
                      : '${sourceIds.length} memories found',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.textMuted,
                  ),
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClear,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 16, color: c.textMuted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (busy)
            const Text(
              'Searching your saved memories for relevant moments…',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 14,
                height: 1.4,
              ),
            )
          else if (error != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The recall failed. Your memories are untouched.',
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Try again'),
                ),
              ],
            )
          else if (answer != null)
            Text(
              answer!,
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: c.textPrimary,
              ),
            ),
          if (!busy && error == null && sourceIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in sourceIds)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      final target = _sourceSession(id);
                      if (target == null) return;
                      HapticFeedback.selectionClick();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => SessionDetailPage(session: target),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: c.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 13,
                            color: c.onPrimaryContainer,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              _sourceTitle(id),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: c.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Two-column Keep-style masonry: cards alternate columns and size to their
/// own content, so each column staggers naturally without a fixed aspect ratio.
class _MasonryGrid extends StatelessWidget {
  const _MasonryGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final left = <Widget>[];
    final right = <Widget>[];

    for (var i = 0; i < children.length; i++) {
      (i.isEven ? left : right).add(children[i]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: left)),
        const SizedBox(width: 12),
        Expanded(child: Column(children: right)),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12, left: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: c.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: c.heading,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Divider(color: c.border, thickness: 1)),
        ],
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: context.tanuColors.textMuted),
        ),
      ),
    );
  }
}

class _EmptyConversations extends ConsumerWidget {
  const _EmptyConversations();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.tanuColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.memory_rounded,
                color: c.primary.withValues(alpha: 0.8),
                size: 64,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'A blank slate',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: c.heading,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Connect your pendant and let it listen to the world.\nYour memories will magically appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted, height: 1.5, fontSize: 15),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () =>
                  ref.read(navigationTabProvider.notifier).goToHome(),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: c.onPrimary,
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
