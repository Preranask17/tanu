import 'package:flutter/material.dart';

import '../screens/welcome/tanu_wordmark.dart';

/// Consistent page header used by Capture, Memories and Settings.
///
/// Logo always top-left, optional status actions top-right, page heading
/// below the logo. Spacing (20px sides, safe-area top, 20px logo-to-title
/// gap) is identical on every page. Pure UI: actions are caller-supplied
/// display widgets, no backend here.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.actions = const [],
  });

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 12,
        left: 20,
        right: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const TanuWordmark(height: 28),
              const Spacer(),
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                actions[i],
              ],
            ],
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
