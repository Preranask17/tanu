import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../abstractions/audio_source.dart';
import '../models/transcript.dart';
import '../providers/ble_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/stt_model_provider.dart';
import '../theme/tanu_colors.dart';
import '../widgets/device_picker_sheet.dart';
import '../widgets/waveform_visualizer.dart';
import 'chat_screen.dart';

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

  /// Auto-downloads the Whisper Small STT model on first launch, or upgrades
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
                HapticFeedback.lightImpact();
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

  void _openDevicePicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DevicePickerSheet(),
    );
  }

  void _openTranscript() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ChatPage(),
      ),
    );
  }

  String _greeting(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _dateLabel(DateTime now) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
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
    return '${weekdays[now.weekday - 1]}, '
        '${months[now.month - 1]} ${now.day}';
  }

  bool _isToday(DateTime time, DateTime now) {
    final local = time.toLocal();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final status =
        ref.watch(pendantStatusProvider).value ?? const PendantStatus();
    final conversation = ref.watch(conversationProvider);

    final now = DateTime.now();
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;
    final live = conversation.isListening || conversation.active != null;
    final bottomInset =
        MediaQuery.paddingOf(context).bottom + (isDesktop ? 24 : 108);

    final todaySessions =
        conversation.conversations
            .where(
              (session) =>
                  !session.isDeleted &&
                  session.status == ConversationStatus.completed &&
                  _isToday(session.finishedAt ?? session.startedAt, now),
            )
            .toList()
          ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async =>
              ref.read(conversationProvider.notifier).reloadFromStorage(),
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HomeHeader(
                        greeting: _greeting(now),
                        dateLabel: _dateLabel(now),
                        status: status,
                        onPendantTap: _openDevicePicker,
                      ),
                      const SizedBox(height: 16),
                      if (live) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _LiveConversationBanner(
                            listening: conversation.isListening,
                            onTap: _openTranscript,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      WaveformVisualizer(
                        level: conversation.micLevel,
                        listening: conversation.isListening,
                        transcribing: conversation.liveTranscript
                            .trim()
                            .isNotEmpty,
                      ),
                      const SizedBox(height: 8),
                      _TodayFeed(
                        sessions: todaySessions,
                        processingIds: conversation.processingIds,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header row: time-based salutation and date on the left, compact pendant
/// connection/battery pill on the right.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.greeting,
    required this.dateLabel,
    required this.status,
    required this.onPendantTap,
  });

  final String greeting;
  final String dateLabel;
  final PendantStatus status;
  final VoidCallback onPendantTap;

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(greeting, style: textTheme.displayMedium),
                ),
                const SizedBox(height: 3),
                Text(
                  dateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: c.textMuted,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _PendantPill(status: status, onTap: onPendantTap),
        ],
      ),
    );
  }
}

class _PendantPill extends StatelessWidget {
  const _PendantPill({required this.status, required this.onTap});

  final PendantStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    final connected = status.isConnected;
    final reconnecting =
        status.state == PendantState.reconnecting ||
        status.state == PendantState.scanning ||
        status.state == PendantState.connecting;

    final dotColor = connected
        ? c.success
        : reconnecting
        ? c.primary
        : c.danger;
    final label = connected
        ? 'Pendant'
        : reconnecting
        ? 'Syncing'
        : 'Connect';
    final battery = connected ? status.batteryPercent : null;

    return Semantics(
      button: true,
      label: connected
          ? 'Pendant connected${battery == null ? '' : ', $battery percent battery'}. Tap to manage.'
          : 'Connect pendant. Tap to manage.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  boxShadow: connected
                      ? [
                          BoxShadow(
                            color: dotColor.withValues(alpha: 0.35),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
              if (battery != null) ...[
                const SizedBox(width: 6),
                Text(
                  '$battery%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.textMuted,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Icon(
                Icons.bluetooth_rounded,
                size: 14,
                color: connected ? c.primary : c.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: connected ? c.primary : c.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Active-session banner directly below the header. Tapping it opens the live
/// transcript while a capture session is running.
class _LiveConversationBanner extends StatelessWidget {
  const _LiveConversationBanner({required this.listening, required this.onTap});

  final bool listening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    final title = listening ? 'Live Conversation' : 'Conversation paused';

    return Semantics(
      button: true,
      label: '$title. Tap to open the live transcript.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.primary.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: c.primary.withValues(alpha: c.isDark ? 0.16 : 0.09),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: listening ? c.primary : c.textMuted,
                  boxShadow: listening
                      ? [
                          BoxShadow(
                            color: c.primary.withValues(alpha: 0.45),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: c.heading,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Tap to open the live transcript',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        color: c.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: c.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Today" timeline: completed memories captured since midnight, ordered from
/// morning to evening. Reads already-loaded sessions only.
class _TodayFeed extends StatelessWidget {
  const _TodayFeed({required this.sessions, required this.processingIds});

  final List<ConversationSession> sessions;
  final Set<String> processingIds;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Today',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (sessions.isEmpty)
            const _EmptyToday()
          else
            for (final session in sessions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TodayCard(
                  session: session,
                  processing: processingIds.contains(session.id),
                ),
              ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.session, required this.processing});

  final ConversationSession session;
  final bool processing;

  String get _title {
    final title = session.title.trim();
    return title.isEmpty ? 'Untitled memory' : title;
  }

  String get _summary {
    if (processing) return 'Writing summary…';
    final summary = session.summary?.trim();
    if (summary != null && summary.isNotEmpty) return summary;
    if (session.segments.isNotEmpty) {
      final tail = session.segments.last.text.trim();
      if (tail.isNotEmpty) return tail;
    }
    return 'No transcript yet';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    final time = _formatClock(session.startedAt.toLocal());

    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => SessionDetailPage(session: session),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 50,
                child: Text(
                  time,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textMuted,
                  ),
                ),
              ),
              Container(width: 1, height: 34, color: c.borderSubtle),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.heading,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontStyle: processing
                            ? FontStyle.italic
                            : FontStyle.normal,
                        color: c.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 20, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyToday extends StatelessWidget {
  const _EmptyToday();

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.primary.withValues(alpha: 0.12),
            ),
            child: Icon(Icons.graphic_eq_rounded, size: 19, color: c.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No conversations yet today',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.heading,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your pendant will capture them automatically.',
                  style: TextStyle(fontSize: 12.5, color: c.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatClock(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  return '$hour:${time.minute.toString().padLeft(2, '0')}';
}
