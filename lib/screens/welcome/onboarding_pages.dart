import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/ai_presence_orb.dart';
import 'tanu_wordmark.dart';

/// First-run story: a wearable pendant that listens, on-device speech to
/// text, recall anything, absolute privacy. Content-only: navigation chrome
/// (dots, Back / Next / Get Started) lives in the flow. Nothing here reads
/// backend providers or the transcription engine.
List<Widget> buildWelcomePages() => const [
      _HeroOrbPage(),
      _ListenPage(),
      _TranscribePage(),
      _RecallPage(),
      _PrivateReadyPage(),
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

class _EntranceState extends State<_Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _rise;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _rise = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _rise, child: widget.child),
    );
  }
}

/// Small caps kicker above each headline.
class _Kicker extends StatelessWidget {
  const _Kicker(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.0,
        color: Color(0xFF888888),
      ),
    );
  }
}

/// Page headline.
class _Headline extends StatelessWidget {
  const _Headline(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        height: 1.15,
        color: Colors.white,
      ),
    );
  }
}

/// Supporting line under the headline.
class _Subline extends StatelessWidget {
  const _Subline(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Color(0xFFBBBBBB),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 1: hero orb + floating feature bubbles
// ---------------------------------------------------------------------------

class _HeroOrbPage extends StatelessWidget {
  const _HeroOrbPage();

  @override
  Widget build(BuildContext context) {
    final fieldHeight =
        (MediaQuery.sizeOf(context).height * 0.38).clamp(260.0, 360.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Entrance(
          delay: Duration.zero,
          child: const TanuWordmark(
            height: 36,
            alignment: Alignment.center,
          ),
        ),
        const SizedBox(height: 8),
        _Entrance(
          delay: const Duration(milliseconds: 150),
          child: SizedBox(
            height: fieldHeight,
            width: double.infinity,
            child: const _OrbBubbleField(),
          ),
        ),
        _Entrance(
          delay: const Duration(milliseconds: 350),
          child: const _Headline('Your day,\nremembered.'),
        ),
        const SizedBox(height: 12),
        _Entrance(
          delay: const Duration(milliseconds: 500),
          child: const _Subline(
            'A pendant that listens, writes it down,\nand lets you recall anything.',
          ),
        ),
      ],
    );
  }
}

/// The orb ringed by four floating feature bubbles. Each bubble drifts on
/// its own sine phase so the field feels alive but never frantic.
class _OrbBubbleField extends StatefulWidget {
  const _OrbBubbleField();

  @override
  State<_OrbBubbleField> createState() => _OrbBubbleFieldState();
}

class _OrbBubbleFieldState extends State<_OrbBubbleField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift;

  static const _bubbles = [
    (icon: Icons.hearing_rounded, label: 'Listens all day', dx: -0.30, dy: -0.30, phase: 0.0),
    (icon: Icons.graphic_eq_rounded, label: 'Speech to text', dx: 0.30, dy: -0.26, phase: 1.7),
    (icon: Icons.auto_awesome_rounded, label: 'Recall anything', dx: -0.32, dy: 0.30, phase: 3.4),
    (icon: Icons.lock_rounded, label: '100% private', dx: 0.30, dy: 0.32, phase: 4.6),
  ];

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final w = size.width - 64;
    final h = 320.0;
    return AnimatedBuilder(
          animation: _drift,
          builder: (context, _) {
            final t = _drift.value * 2 * math.pi;
            return Stack(
              alignment: Alignment.center,
              children: [
                const AiPresenceOrb(level: 0.35, listening: true, height: 220),
                for (final b in _bubbles)
                  Positioned(
                    left:
                        w / 2 + b.dx * w + 7 * math.sin(t + b.phase) - 70,
                    top:
                        h / 2 + b.dy * h + 9 * math.cos(t * 0.8 + b.phase) - 18,
                    child: _FeatureBubble(
                      icon: b.icon,
                      label: b.label,
                    ),
                  ),
              ],
            );
          },
        );
  }
}

class _FeatureBubble extends StatelessWidget {
  const _FeatureBubble({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFB9A7F2)),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pages 2-5: the pendant story
// ---------------------------------------------------------------------------

class _StoryIcon extends StatelessWidget {
  const _StoryIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.07),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 1,
        ),
      ),
      child: Icon(icon, size: 40, color: const Color(0xFFB9A7F2)),
    );
  }
}

class _ListenPage extends StatelessWidget {
  const _ListenPage();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Entrance(
          delay: Duration.zero,
          child: const _StoryIcon(Icons.bluetooth_connected_rounded),
        ),
        const SizedBox(height: 32),
        _Entrance(
          delay: const Duration(milliseconds: 200),
          child: const _Kicker('The pendant'),
        ),
        const SizedBox(height: 12),
        _Entrance(
          delay: const Duration(milliseconds: 300),
          child: const _Headline('It hears\nyour day.'),
        ),
        const SizedBox(height: 12),
        _Entrance(
          delay: const Duration(milliseconds: 420),
          child: const _Subline(
            'A tiny wearable on you.\nIt streams the moments — meetings,\nideas, promises — to your phone.',
          ),
        ),
      ],
    );
  }
}

class _TranscribePage extends StatelessWidget {
  const _TranscribePage();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Entrance(
          delay: Duration.zero,
          child: const _StoryIcon(Icons.graphic_eq_rounded),
        ),
        const SizedBox(height: 32),
        _Entrance(
          delay: const Duration(milliseconds: 200),
          child: const _Kicker('Speech to text'),
        ),
        const SizedBox(height: 12),
        _Entrance(
          delay: const Duration(milliseconds: 300),
          child: const _Headline('Words, written\ndown live.'),
        ),
        const SizedBox(height: 12),
        _Entrance(
          delay: const Duration(milliseconds: 420),
          child: const _Subline(
            'Conversations become timestamped\ntranscripts as you speak —\nin Hindi, Kannada, Tamil and more.',
          ),
        ),
      ],
    );
  }
}

class _RecallPage extends StatelessWidget {
  const _RecallPage();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Entrance(
          delay: Duration.zero,
          child: const _StoryIcon(Icons.auto_awesome_rounded),
        ),
        const SizedBox(height: 32),
        _Entrance(
          delay: const Duration(milliseconds: 200),
          child: const _Kicker('Recall'),
        ),
        const SizedBox(height: 12),
        _Entrance(
          delay: const Duration(milliseconds: 300),
          child: const _Headline('Ask anything.\nGet answers.'),
        ),
        const SizedBox(height: 12),
        _Entrance(
          delay: const Duration(milliseconds: 420),
          child: const _Subline(
            '“What did we decide on Friday?”\nTanu finds it in your memories\nwith clear, sourced replies.',
          ),
        ),
      ],
    );
  }
}

class _PrivateReadyPage extends StatelessWidget {
  const _PrivateReadyPage();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Entrance(
          delay: Duration.zero,
          child: const _StoryIcon(Icons.lock_rounded),
        ),
        const SizedBox(height: 32),
        _Entrance(
          delay: const Duration(milliseconds: 200),
          child: const _Kicker('Absolute privacy'),
        ),
        const SizedBox(height: 12),
        _Entrance(
          delay: const Duration(milliseconds: 300),
          child: const _Headline('Yours. Only\nyours.'),
        ),
        const SizedBox(height: 12),
        _Entrance(
          delay: const Duration(milliseconds: 420),
          child: const _Subline(
            'Everything lives on this device.\nNo feeds, no strangers,\nno compromises.',
          ),
        ),
      ],
    );
  }
}
