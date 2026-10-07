import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transcript.dart';
import '../providers/ble_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/navigation_provider.dart';
import '../abstractions/audio_source.dart';
import '../widgets/conversation_tile.dart';
import '../widgets/device_picker_sheet.dart';
import '../widgets/device_status_controls.dart';
import '../widgets/page_header.dart';

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

  void _openDevicePicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DevicePickerSheet(),
    );
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
    final status =
        ref.watch(pendantStatusProvider).value ?? const PendantStatus();
    final bottomInset = MediaQuery.paddingOf(context).bottom + 50 + 16;
    final query = _query.text.trim().toLowerCase();

    final visible = sessions.where((s) {
      if (query.isEmpty) return true;
      if (s.title.toLowerCase().contains(query)) return true;
      if (s.summary != null && s.summary!.toLowerCase().contains(query))
        return true;
      return s.segments.any((seg) => seg.text.toLowerCase().contains(query));
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
            // Consistent page header (logo top-left, status top-right,
            // heading below) plus an always-visible glass search. UI only.
            SliverToBoxAdapter(
              child: PageHeader(
                title: 'Memories',
                actions: [
                  DeviceStatusActions(
                    status: status,
                    onBluetoothTap: _openDevicePicker,
                  ),
                ],
              ),
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
                            // Fully transparent input: no border, no fill, no
                            // underline — the pill container is the only
                            // visible surface.
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            filled: false,
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
                                          .isAfter(
                                            DateTime.now().subtract(
                                              const Duration(minutes: 1),
                                            ),
                                          ),
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
      ),
    );
  }
}

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
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Color(0xFF888888),
        ),
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
            const Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFF888888),
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'No memories yet.\nConnect your pendant and start talking.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF888888),
                height: 1.5,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () =>
                  ref.read(navigationTabProvider.notifier).goToHome(),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Go to Home',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
