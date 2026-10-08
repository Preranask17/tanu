import 'package:flutter/material.dart';

import 'opening_animation.dart';

/// Cold-start gate for RETURNING users (onboarding already complete).
///
/// Plays the short formation movie over the already-built main app, then
/// fades it away. Shown at most once per process launch: it lives above the
/// tab scaffold in [app.dart]'s routing, so tab switches, navigation and
/// background/foreground resume can never retrigger it.
///
/// Pure UI: no providers, no backend.
class ReturningStartupGate extends StatefulWidget {
  const ReturningStartupGate({super.key, required this.child});

  /// The real main app, built immediately underneath so startup work
  /// continues while the movie plays.
  final Widget child;

  @override
  State<ReturningStartupGate> createState() => _ReturningStartupGateState();
}

class _ReturningStartupGateState extends State<ReturningStartupGate> {
  bool _revealed = false;
  bool _gone = false;

  void _reveal() {
    if (_revealed) return;
    setState(() => _revealed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_gone) return widget.child;
    return Stack(
      children: [
        widget.child,
        AnimatedOpacity(
          opacity: _revealed ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          onEnd: () {
            if (mounted && _revealed) setState(() => _gone = true);
          },
          child: TanuOpeningSequence(
            duration: const Duration(milliseconds: 3800),
            onDone: _reveal,
          ),
        ),
      ],
    );
  }
}
