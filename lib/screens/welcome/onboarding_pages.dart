import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/ai_presence_orb.dart';
import 'tanu_wordmark.dart';

/// The six first-run pages. Content-only: navigation chrome (dots, Back /
/// Next / Get Started) lives in the flow. All sample content is local mock
/// data — nothing here reads backend providers or the transcription engine.
List<Widget> buildWelcomePages() => const [
      _MeetTanuPage(),
      _PendantPage(),
      _CapturePage(),
      _MemoriesPage(),
      _AskPage(),
      _ReadyPage(),
    ];

// ---------------------------------------------------------------------------
// Shared pieces
// ---------------------------------------------------------------------------

/// Fades + rises its child once, with a per-item [delay] for a sequential,
// calm entrance on each page.
class _Entrance extends StatefulWidget {
  const _Entrance({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _shown ? Offset.zero : const Offset(0, 0.06),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Top-left anchored title + short supporting text.
///
/// Display type is Inter bold (the serif display face has no bold cut, so a
/// weight flag on it would silently do nothing) at high-impact sizes.
class _PageHeading extends StatelessWidget {
  const _PageHeading({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: TextAlign.left,
          style: GoogleFonts.inter(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            height: 1.15,
            letterSpacing: -0.5,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          body,
          textAlign: TextAlign.left,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            height: 1.35,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

/// Shared page skeleton: optional brand eyebrow, heading anchored top-left
/// with generous top spacing, visual content centered in the remaining
/// space. Keeps all six pages structurally identical; dots/arrows stay
/// pinned in the flow chrome below.
class _PageLayout extends StatelessWidget {
  const _PageLayout({
    required this.title,
    required this.body,
    required this.visual,
    this.eyebrow,
  });

  final String title;
  final String body;
  final Widget visual;

  /// Optional brand mark rendered left-aligned above the heading (used for
  /// the TANU wordmark on pages 1 and 6).
  final Widget? eyebrow;

  @override
  Widget build(BuildContext context) {
    final brand = eyebrow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Generous breathing room below the SafeArea before the text block.
        SizedBox(height: brand == null ? 108 : 64),
        if (brand != null) ...[
          _Entrance(delay: Duration.zero, child: brand),
          const SizedBox(height: 20),
        ],
        _Entrance(
          delay: brand == null
              ? Duration.zero
              : const Duration(milliseconds: 120),
          child: _PageHeading(title: title, body: body),
        ),
        Expanded(
          child: Center(child: visual),
        ),
      ],
    );
  }
}

/// Card shell matching the app's surfaces (no gradients).
Widget _mockCard(BuildContext context, {required Widget child}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
        width: 1,
      ),
    ),
    child: child,
  );
}

// ---------------------------------------------------------------------------
// Page 1 — Meet TANU
// ---------------------------------------------------------------------------

class _MeetTanuPage extends StatelessWidget {
  const _MeetTanuPage();

  @override
  Widget build(BuildContext context) {
    return const _PageLayout(
      title: 'Meet TANU',
      body:
          'Capture the moments that matter. TANU helps you remember the rest.',
      visual: _Entrance(
        delay: Duration(milliseconds: 250),
        child: _PillConstellation(),
      ),
    );
  }
}

/// Asymmetric scattered constellation of capability pills drifting around a
/// small ambient orb. Each pill has its own anchor, tilt and phase on a
/// shared breathing cycle — nothing lines up, nothing moves in unison.
///
/// Fully non-blocking: the whole layer is pointer-transparent, so page
/// swipes pass through untouched. Display only — no backend behind any pill.
class _PillConstellation extends StatefulWidget {
  const _PillConstellation();

  @override
  State<_PillConstellation> createState() => _PillConstellationState();
}

class _PillConstellationState extends State<_PillConstellation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift;

  @override
  void initState() {
    super.initState();
    // Shared 4s time base; per-pill speed multipliers give 3.2–4.8s cycles.
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  // icon, label, anchor, tilt (rad), phase, float amplitude (x, y).
  // All motion shares one breathing 4s cycle; phases keep pills independent.
  static const _pills = [
    (
      Icons.mic,
      'Ambient Capture',
      Alignment(-0.85, -0.35),
      -0.052,
      0.0,
      Offset(4, 8),
    ),
    (
      Icons.psychology,
      'Instant Memories',
      Alignment(0.90, -0.75),
      0.035,
      1.7,
      Offset(3, 6),
    ),
    (
      Icons.auto_awesome,
      'AI Intelligence',
      Alignment(0.35, 0.55),
      0.0,
      3.4,
      Offset(4, 8),
    ),
    (
      Icons.bluetooth,
      'Pendant Sync',
      Alignment(-0.80, 0.85),
      -0.035,
      5.1,
      Offset(3, 7),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _drift,
        builder: (context, _) {
          final t = _drift.value * 2 * math.pi;
          return SizedBox(
            height: 340,
            width: double.infinity,
            child: Stack(
              children: [
                // Small ambient core in the negative space; pills scatter
                // around it.
                const Center(
                  child: AiPresenceOrb(height: 120, level: 0.15),
                ),
                for (var i = 0; i < 4; i++)
                  Builder(
                    builder: (context) {
                      final p = _pills[i];
                      // Elliptical float: cosine horizontally, sine
                      // vertically, each pill on its own phase.
                      final tau = t + p.$5;
                      final offset = Offset(
                        p.$6.dx * math.cos(tau),
                        p.$6.dy * math.sin(tau),
                      );
                      return Align(
                        alignment: p.$3,
                        child: Transform.translate(
                          offset: offset,
                          child: Transform.rotate(
                            angle: p.$4,
                            child: _ScatterPill(
                              icon: p.$1,
                              label: p.$2,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Monochromatic dark-glass capability pill: identical quiet treatment for
/// all four (slate icon + off-white text, soft dark diffusion, no color
/// halos). Stateless display piece; motion comes from the parent.
class _ScatterPill extends StatelessWidget {
  const _ScatterPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.white.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 2 — Pendant placeholder
// ---------------------------------------------------------------------------

/// Clean placeholder for the future pendant video/animation.
///
/// TODO(pendant-video): replace the inner content of [PendantVideoPlaceholder]
/// with the real video player widget when the asset arrives. The box keeps
/// its size (full width, 16/10) so the swap needs no layout changes.
class PendantVideoPlaceholder extends StatelessWidget {
  const PendantVideoPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF4F4F4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
            width: 1,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth, size: 32, color: Color(0xFF888888)),
            SizedBox(height: 12),
            Text(
              'Pendant video goes here',
              style: TextStyle(color: Color(0xFF888888), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendantPage extends StatelessWidget {
  const _PendantPage();

  @override
  Widget build(BuildContext context) {
    return const _PageLayout(
      title: 'Your TANU pendant',
      body:
          'Wear it, talk naturally, and let TANU help capture the moments '
          'that matter.',
      visual: _Entrance(
        delay: Duration(milliseconds: 250),
        child: PendantVideoPlaceholder(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 3 — Capture miniature (mock transcription)
// ---------------------------------------------------------------------------

class _CapturePage extends StatelessWidget {
  const _CapturePage();

  @override
  Widget build(BuildContext context) {
    return _PageLayout(
      title: 'Capture moments naturally',
      body: 'TANU listens with you and turns conversations into memories.',
      visual: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Entrance(
            delay: Duration.zero,
            child: AiPresenceOrb(height: 170, level: 0.35, listening: true),
          ),
          const SizedBox(height: 12),
          _Entrance(
            delay: const Duration(milliseconds: 200),
            child: _mockCard(
              context,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.fiber_manual_record,
                          size: 10, color: Color(0xFFE5484D)),
                      SizedBox(width: 8),
                      Text(
                        'Listening…',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    '“…and then we finally booked the flights for Friday.”',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 15,
                      height: 1.4,
                      color: Color(0xFFBBBBBB),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 4 — Memories miniature (mock cards)
// ---------------------------------------------------------------------------

class _MockMemoryCard extends StatelessWidget {
  const _MockMemoryCard({
    required this.initial,
    required this.title,
    required this.summary,
    required this.time,
  });

  final String initial;
  final String title;
  final String summary;
  final String time;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _mockCard(
      context,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF222222)
                  : const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              initial,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
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
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  time,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoriesPage extends StatelessWidget {
  const _MemoriesPage();

  @override
  Widget build(BuildContext context) {
    return const _PageLayout(
      title: 'Your memories, organized',
      body: 'Revisit anything you have captured, anytime.',
      visual: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Entrance(
            delay: Duration(milliseconds: 200),
            child: _MockMemoryCard(
              initial: 'E',
              title: 'Evening planning',
              summary: 'Booked the Friday flights, hotel still open.',
              time: 'Today · 8:42 PM',
            ),
          ),
          SizedBox(height: 12),
          _Entrance(
            delay: Duration(milliseconds: 320),
            child: _MockMemoryCard(
              initial: 'M',
              title: 'Morning standup',
              summary: 'Checkout flow ships Friday.',
              time: 'Today · 9:30 AM',
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 5 — Ask miniature (mock Q&A)
// ---------------------------------------------------------------------------

class _AskPage extends StatelessWidget {
  const _AskPage();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _PageLayout(
      title: 'Ask TANU anything',
      body:
          'Find a conversation, recall a moment, or ask about something you '
          'have captured.',
      visual: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Entrance(
            delay: const Duration(milliseconds: 200),
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFE5E5E5),
                  width: 1,
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search, size: 20, color: Color(0xFF888888)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'When did we book the flights?',
                      style:
                          TextStyle(color: Color(0xFF888888), fontSize: 15),
                    ),
                  ),
                  Icon(Icons.mic, size: 20, color: Color(0xFF888888)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _Entrance(
            delay: const Duration(milliseconds: 320),
            child: _mockCard(
              context,
              child: const Text(
                'Tuesday evening, while planning — saved in “Evening planning”.',
                style: TextStyle(fontSize: 15, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 6 — Ready
// ---------------------------------------------------------------------------

class _ReadyPage extends StatelessWidget {
  const _ReadyPage();

  @override
  Widget build(BuildContext context) {
    return const _PageLayout(
      title: 'You’re ready to begin.',
      body: 'Your everyday companion is waiting for you.',
      eyebrow: TanuWordmark(),
      visual: _Entrance(
        delay: Duration(milliseconds: 250),
        child: AiPresenceOrb(height: 170, level: 0.12),
      ),
    );
  }
}
