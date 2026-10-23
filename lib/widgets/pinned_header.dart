import 'package:flutter/material.dart';

import '../theme/tanu_colors.dart';
import 'tanu_brand_mark.dart';

/// Pinned variant of the shared page header: logo top-left with status
/// actions top-right, page heading below — all pinned so it stays fixed
/// while the page scrolls. Same 20px side rhythm and 44px action language
/// as [PageHeader]; pure UI, actions are caller-supplied display widgets.
class PinnedHeader extends StatelessWidget {
  const PinnedHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      floating: false,
      snap: false,
      automaticallyImplyLeading: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 20,
      centerTitle: false,
      title: const TanuBrandMark(),
      actions: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          actions[i],
        ],
        const SizedBox(width: 20),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(
          subtitle == null || subtitle!.isEmpty ? 68 : 78,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.tanuColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
