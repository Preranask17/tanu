import 'package:flutter/material.dart';

import '../../widgets/ai_presence_orb.dart';

/// "Entering TANU": shown right after "Get Started with TANU", never as a
/// loading movie anywhere else.
///
/// The round orb fades/scales in, breathes briefly on its own animation,
/// then zooms smoothly until it fills the screen and fades to black.
/// [onDone] fires once the screen is black, so whatever comes next appears
/// without any visible cut. Tap skips ahead.
///
/// Pure UI: no providers, no backend.
class OrbEnterTransition extends StatefulWidget {
  const OrbEnterTransition({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OrbEnterTransition> createState() => _OrbEnterTransitionState();
}

class _OrbEnterTransitionState extends State<OrbEnterTransition>
    with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 2800);
  late final AnimationController _c;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _total)..forward();
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final v = _c.value;
            // 0.00–0.22 appear · 0.22–0.52 breathe · 0.52–0.90 dive ·
            // 0.90–1.00 hold black.
            final appear = Curves.easeOutCubic.transform(
              (v / 0.22).clamp(0.0, 1.0),
            );
            final zoomP = ((v - 0.52) / 0.38).clamp(0.0, 1.0);
            final zoomEase = Curves.easeInOutCubic.transform(zoomP);
            final zoom = 1 + 6 * zoomEase;
            // Gentle upward drift while diving: entering, not just enlarging.
            final driftY = -26 * zoomEase;
            // Light blooms as we approach; the orb itself wakes up too.
            final bloom = Curves.easeInCubic.transform(zoomP);
            final level = 0.18 + 0.50 * bloom;
            final scrim = ((v - 0.90) / 0.10).clamp(0.0, 1.0);
            return Stack(
              fit: StackFit.expand,
              children: [
                // Ambient bloom swelling behind the orb.
                Opacity(
                  opacity: 0.15 + 0.45 * bloom,
                  child: Center(
                    child: Container(
                      width: 340,
                      height: 340,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF6D5AE0)
                                .withValues(alpha: 0.55),
                            const Color(0xFF6D5AE0)
                                .withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Opacity(
                  opacity: appear,
                  child: Transform.translate(
                    offset: Offset(0, driftY),
                    child: Transform.scale(
                      scale: (0.55 + 0.45 * appear) * zoom,
                      child: Center(
                        child: AiPresenceOrb(
                          height: 260,
                          level: level,
                          listening: true,
                        ),
                      ),
                    ),
                  ),
                ),
                // Hot core: diving into light just before black.
                if (bloom > 0)
                  Opacity(
                    opacity: 0.30 * bloom * (1 - scrim),
                    child: Center(
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [Color(0xFFE8E4FF), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (scrim > 0)
                  Container(color: Colors.black.withValues(alpha: scrim)),
              ],
            );
          },
        ),
      ),
    );
  }
}
