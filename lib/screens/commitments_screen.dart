import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/commitment.dart';
import '../providers/commitment_provider.dart';
import '../widgets/connection_status_bar.dart';

class CommitmentsScreen extends ConsumerStatefulWidget {
  const CommitmentsScreen({super.key});

  @override
  ConsumerState<CommitmentsScreen> createState() => _CommitmentsScreenState();
}

class _CommitmentsScreenState extends ConsumerState<CommitmentsScreen> {
  final _actionCtrl = TextEditingController();
  final _personCtrl = TextEditingController();
  DateTime? _due;
  bool _submitting = false;

  @override
  void dispose() {
    _actionCtrl.dispose();
    _personCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() => _due = picked);
    }
  }

  void _submit() {
    final action = _actionCtrl.text.trim();
    if (action.isEmpty) return;
    setState(() => _submitting = true);
    ref
        .read(commitmentsProvider.notifier)
        .addManual(
          action: action,
          person: _personCtrl.text.trim().isEmpty
              ? null
              : _personCtrl.text.trim(),
          due: _due,
        );
    _actionCtrl.clear();
    _personCtrl.clear();
    setState(() {
      _due = null;
      _submitting = false;
    });
  }

  // ── Section Card style ────────────────────────────────────────────────────
  Widget _sectionCard({required String header, required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8, top: 16),
          child: Text(
            header.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: Color(0xFF888888),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          child: Material(
            color: isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
                width: 1,
              ),
            ),
            child: Column(
              children: children,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final commitments = ref.watch(commitmentsProvider);

    final overdue = commitments
        .where((c) => c.needsAttention && !c.done)
        .toList();
    final active = commitments
        .where((c) => !c.done && !c.needsAttention)
        .toList();
    final done = commitments.where((c) => c.done).toList();

    final currentDate = Commitment.today();

    final bottomInset =
        MediaQuery.paddingOf(context).bottom +
        50 +
        100; // Keyboard avoiding + Nav bar + bottom bar padding

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 120,
                floating: true,
                pinned: true,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    'Commitments',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ConnectionStatusBar(),
                      if (overdue.isNotEmpty)
                        _sectionCard(
                          header: 'Needs attention',
                          children: overdue
                              .map(
                                (c) => _CommitmentTile(
                                  commitment: c,
                                  dueText: _dueLabel(c, currentDate),
                                  highlight: true,
                                ),
                              )
                              .toList(),
                        ),
                      if (active.isNotEmpty)
                        _sectionCard(
                          header: 'Upcoming',
                          children: active
                              .map(
                                (c) => _CommitmentTile(
                                  commitment: c,
                                  dueText: _dueLabel(c, currentDate),
                                ),
                              )
                              .toList(),
                        ),
                      if (done.isNotEmpty)
                        _sectionCard(
                          header: 'Done',
                          children: done
                              .map(
                                (c) => _CommitmentTile(
                                  commitment: c,
                                  dueText: _dueLabel(c, currentDate),
                                  done: true,
                                ),
                              )
                              .toList(),
                        ),
                      if (commitments.isEmpty)
                        const _EmptyState()
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 32,
                          ),
                          child: Text(
                            'These surface automatically when Tanu hears you commit to something — or add your own below.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: const Color(0xFF888888),
                              height: 1.4,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom + 50,
            child: _ManualAddBar(
              actionCtrl: _actionCtrl,
              personCtrl: _personCtrl,
              due: _due,
              submitting: _submitting,
              onPickDue: _pickDue,
              onSubmit: _submit,
            ),
          ),
        ],
      ),
    );
  }

  String _dueLabel(Commitment c, DateTime today) {
    if (c.done) return 'Done';
    if (c.due == null) return c.person ?? '';
    final due = c.due!;
    final diff = DateTime(
      due.year,
      due.month,
      due.day,
    ).difference(today).inDays;
    if (diff < 0) return 'Overdue · ${_friendly(due)}';
    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    return _friendly(due);
  }

  String _friendly(DateTime d) {
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
    return '${months[d.month - 1]} ${d.day}';
  }
}

class _CommitmentTile extends ConsumerWidget {
  const _CommitmentTile({
    required this.commitment,
    required this.dueText,
    this.highlight = false,
    this.done = false,
  });

  final Commitment commitment;
  final String dueText;
  final bool highlight;
  final bool done;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(commitmentsProvider.notifier);
    final isDone = done || commitment.done;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ListTile(
      tileColor: highlight
          ? Colors.red.withOpacity(0.1)
          : null,
      onTap: () => notifier.toggleDone(commitment.id),
      leading: Icon(
        isDone ? Icons.check_circle : Icons.circle_outlined,
        color: isDone ? Colors.grey : Theme.of(context).primaryColor,
        size: 24,
      ),
      title: Text(
        commitment.action,
        style: TextStyle(
          color: isDone
              ? const Color(0xFF888888)
              : (isDark ? Colors.white : Colors.black),
          decoration: isDone ? TextDecoration.lineThrough : null,
          fontWeight: isDone ? FontWeight.w400 : FontWeight.w600,
        ),
      ),
      subtitle: dueText.isEmpty
          ? null
          : Text(
              dueText,
              style: TextStyle(
                color: highlight
                    ? Colors.red
                    : const Color(0xFF888888),
                fontSize: 12,
              ),
            ),
      trailing: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: () => notifier.remove(commitment.id),
        icon: const Icon(
          Icons.close,
          size: 18,
          color: Colors.grey,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(
            Icons.auto_awesome,
            size: 40,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 12),
          Text(
            'No commitments yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Say “I’ll send the file tomorrow” and Tanu will note it here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF888888),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualAddBar extends StatelessWidget {
  const _ManualAddBar({
    required this.actionCtrl,
    required this.personCtrl,
    required this.due,
    required this.submitting,
    required this.onPickDue,
    required this.onSubmit,
  });

  final TextEditingController actionCtrl;
  final TextEditingController personCtrl;
  final DateTime? due;
  final bool submitting;
  final VoidCallback onPickDue;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: actionCtrl,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onSubmit(),
                  decoration: InputDecoration(
                    hintText: 'New commitment...',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerTheme.color ?? Colors.transparent,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerTheme.color ?? Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: submitting ? null : onSubmit,
                style: IconButton.styleFrom(
                  backgroundColor: submitting
                      ? const Color(0xFF888888)
                      : Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(12),
                ),
                icon: const Icon(
                  Icons.arrow_upward,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: personCtrl,
                  decoration: InputDecoration(
                    hintText: 'For who? (optional)',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerTheme.color ?? Colors.transparent,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).dividerTheme.color ?? Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                  foregroundColor: isDark ? Colors.white : Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: onPickDue,
                child: Text(
                  due == null ? 'Pick date' : _shortDate(due!),
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _shortDate(DateTime d) {
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
    return '${months[d.month - 1]} ${d.day}';
  }
}
