import 'package:flutter/cupertino.dart';
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

  void _pickDue() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 250,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: CupertinoDatePicker(
            initialDateTime: _due ?? DateTime.now(),
            minimumDate: DateTime.now().subtract(const Duration(days: 1)),
            maximumDate: DateTime.now().add(const Duration(days: 365 * 3)),
            mode: CupertinoDatePickerMode.date,
            onDateTimeChanged: (DateTime newDate) {
              setState(() => _due = newDate);
            },
          ),
        ),
      ),
    );
  }

  void _submit() {
    final action = _actionCtrl.text.trim();
    if (action.isEmpty) return;
    setState(() => _submitting = true);
    ref.read(commitmentsProvider.notifier).addManual(
          action: action,
          person: _personCtrl.text.trim().isEmpty ? null : _personCtrl.text.trim(),
          due: _due,
        );
    _actionCtrl.clear();
    _personCtrl.clear();
    setState(() {
      _due = null;
      _submitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final commitments = ref.watch(commitmentsProvider);

    final overdue = commitments.where((c) => c.needsAttention && !c.done).toList();
    final active = commitments.where((c) => !c.done && !c.needsAttention).toList();
    final done = commitments.where((c) => c.done).toList();

    final currentDate = Commitment.today();

    final bottomInset = MediaQuery.paddingOf(context).bottom + 50 + 100; // Keyboard avoiding + Nav bar + bottom bar padding

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              const CupertinoSliverNavigationBar(
                largeTitle: Text('Commitments'),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ConnectionStatusBar(),
                      if (overdue.isNotEmpty)
                        CupertinoListSection.insetGrouped(
                          header: const Text('NEEDS ATTENTION'),
                          children: overdue.map((c) => _CommitmentTile(
                            commitment: c,
                            dueText: _dueLabel(c, currentDate),
                            highlight: true,
                          )).toList(),
                        ),
                      if (active.isNotEmpty)
                        CupertinoListSection.insetGrouped(
                          header: const Text('UPCOMING'),
                          children: active.map((c) => _CommitmentTile(
                            commitment: c,
                            dueText: _dueLabel(c, currentDate),
                          )).toList(),
                        ),
                      if (done.isNotEmpty)
                        CupertinoListSection.insetGrouped(
                          header: const Text('DONE'),
                          children: done.map((c) => _CommitmentTile(
                            commitment: c,
                            dueText: _dueLabel(c, currentDate),
                            done: true,
                          )).toList(),
                        ),
                      if (commitments.isEmpty)
                        const _EmptyState()
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          child: Text(
                            'These surface automatically when Tanu hears you commit to something — or add your own below.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey.resolveFrom(context), height: 1.4),
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
    final diff = DateTime(due.year, due.month, due.day).difference(today).inDays;
    if (diff < 0) return 'Overdue · ${_friendly(due)}';
    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    return _friendly(due);
  }

  String _friendly(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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
    return CupertinoListTile(
      backgroundColor: highlight ? CupertinoColors.destructiveRed.resolveFrom(context).withValues(alpha: 0.1) : null,
      onTap: () => notifier.toggleDone(commitment.id),
      leading: Icon(
        isDone ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
        color: isDone ? CupertinoColors.systemGrey : CupertinoColors.activeBlue,
        size: 24,
      ),
      title: Text(
        commitment.action,
        style: TextStyle(
          color: isDone ? CupertinoColors.secondaryLabel.resolveFrom(context) : CupertinoColors.label.resolveFrom(context),
          decoration: isDone ? TextDecoration.lineThrough : null,
          fontWeight: isDone ? FontWeight.w400 : FontWeight.w600,
        ),
      ),
      subtitle: dueText.isEmpty
          ? null
          : Text(
              dueText,
              style: TextStyle(
                color: highlight ? CupertinoColors.destructiveRed.resolveFrom(context) : CupertinoColors.secondaryLabel.resolveFrom(context),
                fontSize: 12,
              ),
            ),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        minSize: 0,
        onPressed: () => notifier.remove(commitment.id),
        child: const Icon(CupertinoIcons.clear_thick, size: 18, color: CupertinoColors.systemGrey),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          const Icon(CupertinoIcons.sparkles, size: 40, color: CupertinoColors.activeBlue),
          const SizedBox(height: 12),
          Text(
            'No commitments yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: CupertinoColors.label.resolveFrom(context)),
          ),
          const SizedBox(height: 4),
          Text(
            'Say “I’ll send the file tomorrow” and Tanu will note it here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
        border: Border(top: BorderSide(color: CupertinoColors.separator.resolveFrom(context))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: actionCtrl,
                  placeholder: 'New commitment...',
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground.resolveFrom(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: CupertinoColors.systemGrey4.resolveFrom(context)),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onSubmit(),
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: submitting ? null : onSubmit,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: submitting ? CupertinoColors.systemGrey.resolveFrom(context) : CupertinoColors.activeBlue.resolveFrom(context),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.arrow_up, color: CupertinoColors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: personCtrl,
                  placeholder: 'For who? (optional)',
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground.resolveFrom(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: CupertinoColors.systemGrey4.resolveFrom(context)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: CupertinoColors.systemBackground.resolveFrom(context),
                borderRadius: BorderRadius.circular(16),
                onPressed: onPickDue,
                child: Text(
                  due == null ? 'Pick date' : _shortDate(due!),
                  style: TextStyle(color: CupertinoColors.label.resolveFrom(context), fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _shortDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }
}