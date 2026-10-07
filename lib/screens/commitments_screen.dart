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
          padding: const EdgeInsets.only(left: 24, bottom: 8, top: 24),
          child: Text(
            header.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: isDark ? const Color(0xFFCCCCCC) : const Color(0xFF666666),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161618) : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? const Color(0xFF2A2A2C).withOpacity(0.5) : const Color(0xFFE9ECEF).withOpacity(0.8),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.03),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
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
                expandedHeight: 140,
                floating: true,
                pinned: true,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    'Commitments',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 20),
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
                            color: Theme.of(context).primaryColor.withOpacity(0.15),
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
                            color: Colors.redAccent.withOpacity(0.08),
                          ),
                        ),
                      ),
                    ],
                  ),
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
    
    return InkWell(
      onTap: () => notifier.toggleDone(commitment.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => notifier.toggleDone(commitment.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone 
                      ? Theme.of(context).primaryColor 
                      : (highlight ? Colors.red.withOpacity(0.1) : Colors.transparent),
                  border: Border.all(
                    color: isDone 
                        ? Theme.of(context).primaryColor 
                        : (highlight ? Colors.red : const Color(0xFF888888)),
                    width: 2,
                  ),
                ),
                child: isDone
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    commitment.action,
                    style: TextStyle(
                      color: isDone
                          ? const Color(0xFF888888)
                          : (isDark ? Colors.white : Colors.black),
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      fontSize: 16,
                      fontWeight: isDone ? FontWeight.w500 : FontWeight.w600,
                    ),
                  ),
                  if (dueText.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: highlight 
                            ? Colors.red.withOpacity(0.1) 
                            : (isDark ? const Color(0xFF2A2A2C) : const Color(0xFFE9ECEF)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        dueText,
                        style: TextStyle(
                          color: highlight ? Colors.red : (isDark ? const Color(0xFFCCCCCC) : const Color(0xFF666666)),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ]
                ],
              ),
            ),
            IconButton(
              onPressed: () => notifier.remove(commitment.id),
              style: IconButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF222222) : const Color(0xFFF0F0F0),
                shape: const CircleBorder(),
              ),
              icon: const Icon(
                Icons.close,
                size: 16,
                color: Color(0xFF888888),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.task_alt_rounded,
              size: 64,
              color: Theme.of(context).primaryColor.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'All caught up!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Say "Remind me to..." during your day and Tanu will automatically add it here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
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

  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161618) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2C) : const Color(0xFFE9ECEF),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
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
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Add a new commitment...',
                    hintStyle: const TextStyle(fontWeight: FontWeight.w400),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF222222) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                ),
                icon: const Icon(Icons.arrow_upward_rounded, size: 24),
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
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF222222) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: due != null 
                      ? Theme.of(context).primaryColor.withOpacity(0.1)
                      : (isDark ? const Color(0xFF222222) : Colors.white),
                  foregroundColor: due != null 
                      ? Theme.of(context).primaryColor
                      : (isDark ? Colors.white : Colors.black),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: onPickDue,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(
                  due == null ? 'Date' : _shortDate(due!),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _shortDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }
}
