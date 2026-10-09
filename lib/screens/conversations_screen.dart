import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transcript.dart';
import '../providers/conversation_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/rag_provider.dart';
import '../widgets/conversation_tile.dart';
import '../widgets/pinned_header.dart';
import 'chat_screen.dart';
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
      if (!mounted) return;
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
      if (!mounted) return;
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
    final unpinned =
        visible.where((s) => !s.isPinned).toList().reversed.toList();

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
            PinnedHeader(
              title: 'Memories',
              actions: [
                _HeaderCircleButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Trash',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TrashScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _askRag(),
                  child: Container(
                    padding: const EdgeInsets.only(
                      left: 8,
                      right: 16,
                      top: 8,
                      bottom: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF161618)
                          : const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.35 : 0.06,
                          ),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context)
                                .primaryColor
                                .withValues(alpha: 0.12),
                          ),
                          child: Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _query,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _askRag(),
                            decoration: const InputDecoration(
                              hintText: 'Ask anything about your day…',
                              hintStyle: TextStyle(
                                color: Color(0xFF888888),
                                fontSize: 16,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 16,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        if (query.isNotEmpty)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _clearSearch,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : const Color(0xFFF2F2F7),
                              ),
                              child: const Icon(
                                Icons.clear_rounded,
                                size: 16,
                                color: Color(0xFF888888),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_ragBusy || _ragAnswer != null || _ragError != null)
              SliverToBoxAdapter(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4, left: 20, right: 20),
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
              Expanded(
                child: Text(
                  busy
                      ? 'Recalling memories…'
                      : error != null
                          ? 'Could not recall'
                          : sourceIds.length == 1
                              ? '1 memory found'
                              : '${sourceIds.length} memories found',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF888888),
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
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: Color(0xFF888888),
                    ),
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
                color: Color(0xFF888888),
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
                color: isDark ? Colors.white : Colors.black,
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
                        color: Theme.of(context)
                            .primaryColor
                            .withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 13,
                            color: Theme.of(context).primaryColor,
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
                                color: Theme.of(context).primaryColor,
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
