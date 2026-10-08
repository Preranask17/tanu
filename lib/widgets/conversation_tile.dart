import 'dart:async';

import 'package:flutter/material.dart';
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
    this.onPin,
    this.isNew = false,
    this.isTrash = false,
    this.onRestore,
    this.onDeletePermanently,
    this.isProcessing = false,
    this.isFailed = false,
    this.onRetry,
  });

  final ConversationSession session;
  final VoidCallback? onDelete;
  final VoidCallback? onPin;
  final bool isNew;
  final bool isTrash;
  final VoidCallback? onRestore;
  final VoidCallback? onDeletePermanently;

  /// AI title/summary still generating: shows the shimmer row.
  final bool isProcessing;

  /// Last AI attempt failed or never ran: shows tap-to-retry.
  final bool isFailed;

  /// Single-shot AI retry for [isFailed]. Ignored while processing.
  final VoidCallback? onRetry;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.maxFinite,
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
          borderRadius: BorderRadius.circular(20),
          child: (widget.onDelete == null && widget.onPin == null)
              ? _body(context)
              : Dismissible(
                  key: ValueKey('dismissible_${session.id}'),
                  direction: DismissDirection.horizontal,
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    color: Colors.orange,
                    child: Icon(
                      session.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                      color: Colors.white,
                    ),
                  ),
                  secondaryBackground: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.redAccent,
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.startToEnd) {
                      if (widget.onPin != null) {
                        widget.onPin!();
                      }
                      return false; // Don't actually dismiss the widget
                    }
                    return true; // Let the delete dismiss it
                  },
                  onDismissed: (direction) {
                    if (direction == DismissDirection.endToStart && widget.onDelete != null) {
                      widget.onDelete!();
                    }
                  },
                  child: _body(context),
                ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final session = widget.session;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = session.title.trim();
    final revealedAt = session.finishedAt ?? session.startedAt;
    final time =
        '${revealedAt.hour % 12 == 0 ? 12 : revealedAt.hour % 12}:'
        '${revealedAt.minute.toString().padLeft(2, '0')} '
        '${revealedAt.hour < 12 ? 'AM' : 'PM'}';
    final tail = session.summary?.isNotEmpty == true
        ? session.summary!
        : (session.segments.isEmpty
              ? 'Empty memory'
              : session.segments.last.text.trim());
    final newBadge =
        widget.isNew &&
        revealedAt.isAfter(DateTime.now().subtract(const Duration(minutes: 1)));

    return InkWell(
      onTap: widget.isTrash ? null : () {
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFE5E5E5),
                shape: BoxShape.circle,
              ),
              child: Text(
                title.isEmpty ? 'M' : title.characters.first.toUpperCase(),
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF666666),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (session.isPinned) ...[
                        Icon(Icons.push_pin, size: 14, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          title.isEmpty ? 'Untitled memory' : title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (widget.isProcessing)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Writing summary…',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (widget.isFailed && widget.onRetry != null)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onRetry!();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.refresh_rounded,
                            size: 14,
                            color: Color(0xFF888888),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'AI paused — tap to retry',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF888888),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (widget.isProcessing ||
                      (widget.isFailed && widget.onRetry != null))
                    const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        time,
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 14,
                        ),
                      ),
                      if (session.segmentCount > 0) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '· ${session.segmentCount} segment${session.segmentCount == 1 ? '' : 's'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (newBadge)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withValues(
                              alpha: 0.14,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'New',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
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
            if (widget.isTrash) ...[
              IconButton(
                onPressed: widget.onRestore,
                style: IconButton.styleFrom(backgroundColor: isDark ? const Color(0xFF2A2A2C) : const Color(0xFFE9ECEF)),
                icon: Icon(Icons.restore, size: 20, color: Theme.of(context).primaryColor),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: widget.onDeletePermanently,
                style: IconButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.1)),
                icon: const Icon(Icons.delete_forever, size: 20, color: Colors.red),
              ),
            ] else ...[
              if (widget.onDelete != null)
                IconButton(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFF888888)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: Color(0xFF888888),
              ),
            ],
          ],
        ),
      ),
    );
  }

}
