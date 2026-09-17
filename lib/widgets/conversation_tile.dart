import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/transcript.dart';
import '../screens/chat_screen.dart';
import '../theme.dart';

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
          color: kTanuSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kTanuLine),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: widget.onDelete == null
              ? _body(context)
              : Dismissible(
                  key: ValueKey('dismissible_${session.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: kTanuRed,
                    child: const Icon(Icons.delete, color: Colors.white),
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
    final tail = session.segments.isEmpty
        ? 'Empty memory'
        : session.segments.last.text.trim();
    final newBadge = widget.isNew &&
        revealedAt.isAfter(
            DateTime.now().subtract(const Duration(minutes: 1)));

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          MaterialPageRoute(
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
                color: kTanuChip,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                title.isEmpty
                    ? 'T'
                    : title.characters.first.toUpperCase(),
                style: const TextStyle(
                  color: kTanuInk,
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
                    style: const TextStyle(
                      color: kTanuInk,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kTanuMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        time,
                        style: const TextStyle(color: kTanuMuted, fontSize: 14),
                      ),
                      if (session.segmentCount > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '· ${session.segmentCount} segment${session.segmentCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: kTanuMuted,
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
                            color: kTanuWarm.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'New',
                            style: TextStyle(
                              color: kTanuWarm,
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
            const Icon(Icons.chevron_right, size: 20, color: kTanuMuted),
          ],
        ),
      ),
    );
  }
}