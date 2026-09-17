import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/commitment.dart';
import '../providers/commitment_provider.dart';
import '../theme.dart';
import '../widgets/connection_status_bar.dart';

class CommitmentsScreen extends ConsumerStatefulWidget {
  const CommitmentsScreen({super.key});

  @override
  ConsumerState<CommitmentsScreen> createState() => _CommitmentsScreenState();
}

class _CommitmentsScreenState extends ConsumerState<CommitmentsScreen> {
  final _formKey = GlobalKey<FormState>();
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
    final selected = await showDatePicker(
      context: context,
      initialDate: _due ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (selected != null) {
      setState(() => _due = selected);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
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

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'To-do & commitments',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kTanuInk),
            ),
          ),
          const ConnectionStatusBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (overdue.isNotEmpty) ...[
                  _SectionHeader('Needs attention', icon: Icons.schedule, color: kTanuRed),
                  ...overdue.map((c) => _CommitmentTile(
                        commitment: c,
                        dueText: _dueLabel(c, currentDate),
                        highlight: true,
                      )),
                  const SizedBox(height: 8),
                ],
                if (active.isNotEmpty) ...[
                  if (overdue.isNotEmpty) _SectionHeader('Upcoming'),
                  ...active.map((c) => _CommitmentTile(
                        commitment: c,
                        dueText: _dueLabel(c, currentDate),
                      )),
                  const SizedBox(height: 8),
                ],
                if (done.isNotEmpty) ...[
                  _SectionHeader('Done'),
                  ...done.map((c) => _CommitmentTile(
                        commitment: c,
                        dueText: _dueLabel(c, currentDate),
                        done: true,
                      )),
                  const SizedBox(height: 8),
                ],
                if (commitments.isEmpty)
                  const _EmptyState()
                else ...[
                  const SizedBox(height: 12),
                  Text(
                    'These surface automatically when Tanu hears you commit to something — or add your own below.',
                    style: TextStyle(fontSize: 13, color: kTanuInk.withValues(alpha: 0.6), height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          _ManualAddBar(
            formKey: _formKey,
            actionCtrl: _actionCtrl,
            personCtrl: _personCtrl,
            due: _due,
            submitting: _submitting,
            onPickDue: _pickDue,
            onSubmit: _submit,
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label, {this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: color ?? kTanuInk.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
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
    final color = kTanuInk;
    final notifier = ref.read(commitmentsProvider.notifier);
    return Card(
      color: highlight ? kTanuInk.withValues(alpha: 0.06) : null,
      child: ListTile(
        onTap: () => notifier.toggleDone(commitment.id),
        leading: Checkbox(
          value: done || commitment.done,
          onChanged: (_) => notifier.toggleDone(commitment.id),
          activeColor: color,
        ),
        title: Text(
          commitment.action,
          style: TextStyle(
            color: done ? kTanuInk.withValues(alpha: 0.45) : kTanuInk,
            decoration: done ? TextDecoration.lineThrough : null,
            fontWeight: done ? FontWeight.w400 : FontWeight.w600,
          ),
        ),
        subtitle: dueText.isEmpty
            ? null
            : Text(
                dueText,
                style: TextStyle(
                  color: highlight ? kTanuRed : kTanuInk.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
        trailing: IconButton(
          icon: const Icon(Icons.close, size: 18),
          onPressed: () => notifier.remove(commitment.id),
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
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.celebration_outlined, size: 40, color: kTanuWarm),
          const SizedBox(height: 12),
          const Text(
            'No commitments yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kTanuInk),
          ),
          const SizedBox(height: 4),
          Text(
            'Say “I’ll send the file tomorrow” and Tanu will note it here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: kTanuInk.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

class _ManualAddBar extends StatelessWidget {
  const _ManualAddBar({
    required this.formKey,
    required this.actionCtrl,
    required this.personCtrl,
    required this.due,
    required this.submitting,
    required this.onPickDue,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
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
      color: kTanuSurface,
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: actionCtrl,
              decoration: InputDecoration(
                labelText: 'New commitment',
                hintText: 'e.g. Send Rahul the deck',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check, color: kTanuWarm),
                  onPressed: submitting ? null : onSubmit,
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Say what you’ll do' : null,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onSubmit(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: personCtrl,
                    decoration: const InputDecoration(labelText: 'For who? (optional)'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onPickDue,
                  child: Text(due == null ? 'Pick date' : _shortDate(due!)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _shortDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }
}