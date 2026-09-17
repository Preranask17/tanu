import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../models/transcript.dart';
import '../screens/chat_screen.dart';

/// One completed memory card: a warm-beige initial tile, the session title,
/// the tail of its transcript and the close time. Swipe-to-delete when
/// [onDelete] is set.
class ConversationTile extends StatefulWidget {
  const ConversationTile({
    super.key,
    required this.session,
    this.onDelete,
    this.isNew = false,
  });

  final ConversationSession session;
  final VoidCallback? onDelete;
  final bool isNew;

  @override
  State<ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<ConversationTile> {
  Timer? _newReset;

  @override
  void initState() {
    super.initState();
    if (widget.isNew) {
      _newReset = Timer(const Duration(seconds: 60), () {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _newReset?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.maxFinite,
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: widget.onDelete == null
              ? _body(context)
              : Dismissible(
                  key: ValueKey('dismissible_${session.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: CupertinoColors.destructiveRed.resolveFrom(context),
                    child: const Icon(CupertinoIcons.delete, color: CupertinoColors.white),
                  ),
                  onDismissed: (_) => widget.onDelete!(),
                  child: _body(context),
                ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final session = widget.session;
    final title = session.title.trim();
    final revealedAt = session.finishedAt ?? session.startedAt;
    final time = '${revealedAt.hour % 12 == 0 ? 12 : revealedAt.hour % 12}:'
        '${revealedAt.minute.toString().padLeft(2, '0')} '
        '${revealedAt.hour < 12 ? 'AM' : 'PM'}';
    final tail = session.summary?.isNotEmpty == true
        ? session.summary!
        : (session.segments.isEmpty ? 'Empty memory' : session.segments.last.text.trim());
    final newBadge = widget.isNew &&
        revealedAt.isAfter(
            DateTime.now().subtract(const Duration(minutes: 1)));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          CupertinoPageRoute(
            fullscreenDialog: true,
            builder: (_) => SessionDetailPage(session: session),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey5.resolveFrom(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                title.isEmpty
                    ? 'T'
                    : title.characters.first.toUpperCase(),
                style: TextStyle(
                  color: CupertinoColors.label.resolveFrom(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? 'Untitled memory' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: CupertinoColors.label.resolveFrom(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: CupertinoColors.secondaryLabel.resolveFrom(context), fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        time,
                        style: TextStyle(color: CupertinoColors.secondaryLabel.resolveFrom(context), fontSize: 14),
                      ),
                      if (session.segmentCount > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '· ${session.segmentCount} segment${session.segmentCount == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (newBadge)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: CupertinoColors.activeBlue.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'New',
                            style: TextStyle(
                              color: CupertinoColors.activeBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 20, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
          ],
        ),
      ),
    );
  }
}