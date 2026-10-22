import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/transcript.dart';
import '../screens/chat_screen.dart';
import '../theme/tanu_colors.dart';

/// One completed memory card. Library uses [noteLayout] for a Keep-style
/// masonry note; Trash keeps the original list row. Swipe-to-delete when
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
    this.noteLayout = false,
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

  /// Google Keep-style note card for the Library masonry grid.
  final bool noteLayout;

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
    final c = context.tanuColors;

    if (widget.noteLayout) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: c.isDark ? 0.18 : 0.035),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _withMemoryActions(context, _noteBody(context)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.maxFinite,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: c.isDark ? 0.2 : 0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: _withMemoryActions(context, _body(context)),
        ),
      ),
    );
  }

  Widget _withMemoryActions(BuildContext context, Widget child) {
    final session = widget.session;
    final c = context.tanuColors;
    if (widget.onDelete == null && widget.onPin == null) return child;

    return Dismissible(
      key: ValueKey('dismissible_${session.id}'),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: c.primary,
        child: Icon(
          session.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
          color: c.onPrimary,
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: c.danger,
        child: Icon(Icons.delete, color: c.onDanger),
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
        if (direction == DismissDirection.endToStart &&
            widget.onDelete != null) {
          widget.onDelete!();
        }
      },
      child: child,
    );
  }

  Widget _noteBody(BuildContext context) {
    final session = widget.session;
    final c = context.tanuColors;
    final textTheme = Theme.of(context).textTheme;
    final title = session.title.trim();
    final summary = session.summary?.trim() ?? '';
    final preview = summary.isNotEmpty
        ? summary
        : session.segments.isEmpty
        ? 'No transcript recorded yet.'
        : session.transcriptText;
    final revealedAt = session.finishedAt ?? session.startedAt;
    final time =
        '${revealedAt.hour % 12 == 0 ? 12 : revealedAt.hour % 12}:'
        '${revealedAt.minute.toString().padLeft(2, '0')} '
        '${revealedAt.hour < 12 ? 'AM' : 'PM'}';
    final newBadge =
        widget.isNew &&
        revealedAt.isAfter(DateTime.now().subtract(const Duration(minutes: 1)));
    final hasActions = widget.onPin != null || widget.onDelete != null;

    return InkWell(
      onTap: widget.isTrash
          ? null
          : () {
              HapticFeedback.selectionClick();
              Navigator.of(context).push(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => SessionDetailPage(session: session),
                ),
              );
            },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title.isEmpty ? 'Untitled memory' : title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      fontSize: 17,
                      height: 1.25,
                      color: c.heading,
                    ),
                  ),
                ),
                if (session.isPinned) ...[
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.push_pin_rounded,
                      size: 16,
                      color: c.primary,
                    ),
                  ),
                ],
                if (hasActions) ...[
                  const SizedBox(width: 2),
                  _noteActionsMenu(context, c),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              preview,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(
                color: c.textPrimary,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                _aiPill(context, c, hasSummary: summary.isNotEmpty),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (newBadge) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: c.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'New',
                          style: textTheme.labelSmall?.copyWith(
                            color: c.onPrimaryContainer,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      time,
                      style: textTheme.labelSmall?.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _noteActionsMenu(BuildContext context, TanuColors c) {
    return PopupMenuButton<String>(
      tooltip: 'Memory actions',
      padding: EdgeInsets.zero,
      onSelected: (value) {
        HapticFeedback.selectionClick();
        if (value == 'pin') {
          widget.onPin?.call();
        } else if (value == 'delete') {
          widget.onDelete?.call();
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(Icons.more_horiz_rounded, size: 20, color: c.textMuted),
      ),
      itemBuilder: (context) => [
        if (widget.onPin != null)
          PopupMenuItem(
            value: 'pin',
            child: Text(widget.session.isPinned ? 'Unpin' : 'Pin'),
          ),
        if (widget.onDelete != null)
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }

  Widget _aiPill(
    BuildContext context,
    TanuColors c, {
    required bool hasSummary,
  }) {
    final processing = widget.isProcessing;
    final failed = widget.isFailed && widget.onRetry != null;
    final String label;
    if (processing) {
      label = 'Writing…';
    } else if (failed) {
      label = 'Retry AI';
    } else {
      label = hasSummary ? 'Summary' : 'Transcript';
    }

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: c.isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.primary.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (processing)
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: c.primary,
              ),
            )
          else
            Icon(
              failed ? Icons.refresh_rounded : Icons.auto_awesome,
              size: 12,
              color: c.primary,
            ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: c.heading,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );

    if (!failed) return pill;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onRetry!();
      },
      child: pill,
    );
  }

  Widget _body(BuildContext context) {
    final session = widget.session;
    final c = context.tanuColors;
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
      onTap: widget.isTrash
          ? null
          : () {
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
                color: c.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Text(
                title.isEmpty ? 'M' : title.characters.first.toUpperCase(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: c.heading,
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
                        Icon(
                          Icons.push_pin,
                          size: 14,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          title.isEmpty ? 'Untitled memory' : title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: c.heading,
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
                    style: TextStyle(color: c.textMuted, fontSize: 13),
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
                            style: TextStyle(
                              color: c.textMuted,
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
                          const Icon(Icons.refresh_rounded, size: 14),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'AI paused — tap to retry',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.textMuted,
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
                        style: TextStyle(color: c.textMuted, fontSize: 14),
                      ),
                      if (session.segmentCount > 0) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '· ${session.segmentCount} segment${session.segmentCount == 1 ? '' : 's'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: c.textMuted, fontSize: 14),
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
                            color: c.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'New',
                            style: TextStyle(
                              color: c.onPrimaryContainer,
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
                style: IconButton.styleFrom(backgroundColor: c.surfaceMuted),
                icon: Icon(Icons.restore, size: 20, color: c.primary),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: widget.onDeletePermanently,
                style: IconButton.styleFrom(backgroundColor: c.dangerContainer),
                icon: Icon(Icons.delete_forever, size: 20, color: c.danger),
              ),
            ] else ...[
              if (widget.onDelete != null)
                IconButton(
                  onPressed: widget.onDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: c.textMuted,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 20, color: c.textMuted),
            ],
          ],
        ),
      ),
    );
  }
}
