import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Calm "AI presence" visual for the Capture screen.
///
/// A slowly morphing organic form in deep indigo / violet / blue with faint
/// cyan/pink accents blended *inside* the shape (everything accent is
/// clipped to the body, so no separate circles ever show). It always breathes
/// on its own and swells gently with [level] (mic energy).
///
/// Pure UI: takes plain values, imports nothing backend-related.
class AiPresenceOrb extends StatefulWidget {
  const AiPresenceOrb({
    super.key,
    this.level = 0,
    this.listening = false,
    this.height = 280,
  });

  /// Voice energy 0..1, read from the already-watched conversation state.
  final double level;

  /// Whether a session is live; only softens the glow, never restyles.
  final bool listening;

  /// Render height; the orb scales to fit while staying round.
  final double height;

  @override
  State<AiPresenceOrb> createState() => _AiPresenceOrbState();
}

class _AiPresenceOrbState extends State<AiPresenceOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flow;

  @override
  void initState() {
    super.initState();
    // One slow loop (~7s): calm and intentional, never frantic.
    _flow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _flow,
        builder: (context, _) => CustomPaint(
          painter: _OrbPainter(
            t: _flow.value * 2 * math.pi,
            level: widget.level.clamp(0.0, 1.0),
            listening: widget.listening,
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({
    required this.t,
    required this.level,
    required this.listening,
  });

  final double t;
  final double level;
  final bool listening;

  /// Edge recipe: a circle first, alive second. Total circumference
  /// deviation stays within ~±5% so the silhouette always reads as round:
  /// global breathing does the visible work, harmonics add only a whisper
  /// of organic motion, and voice energy barely ripples the rim.
  double _radius(double angle, double base) {
    // Slow breathing swell (~7s loop frequency component): ±2.5%.
    final breath = math.sin(t * 0.9) * 0.025;
    // Fixed micro-ripple around the edge: ±2% combined, no points.
    final ripple = 0.012 * math.sin(3 * angle + t * 1.1) +
        0.008 * math.sin(5 * angle - t * 0.7 + 1.3);
    // Voice energy: a ±2% shimmer at most, never a deformation.
    final voice = level * 0.02 * math.sin(2 * angle + t * 2.0);
    return base * (1 + breath + ripple + voice);
  }

  Path _body(Offset center, double radius) {
    final path = Path();
    const steps = 128;
    for (var i = 0; i <= steps; i++) {
      final a = i / steps * 2 * math.pi;
      final r = _radius(a, radius);
      final p = Offset(
        center.dx + r * math.cos(a),
        center.dy + r * math.sin(a),
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  void _accent(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0.0)],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) * 0.30;

    // 1. Soft ambient glow on the dark background.
    final glowAlpha = (listening ? 0.38 : 0.30) + level * 0.10;
    canvas.drawCircle(
      center,
      r * 2.4,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 48)
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF4A3AA8).withValues(alpha: glowAlpha),
            const Color(0xFF4A3AA8).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r * 2.4)),
    );

    final body = _body(center, r);

    // 2. Base form: deep indigo -> violet -> blue, top to bottom.
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2A1E5C),
            Color(0xFF3E2E7E),
            Color(0xFF1E3A6E),
          ],
          stops: [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r * 1.4)),
    );

    // 3. Accents + depth, all clipped to the body so no circle edges show.
    // Drift is deliberately slower than the breathing loop: interior light
    // diffuses rather than orbits.
    canvas.save();
    canvas.clipPath(body);
    final drift = t * 0.35;
    _accent(
      canvas,
      center + Offset(r * 0.38 * math.cos(drift), r * 0.30 * math.sin(drift)),
      r * 0.85,
      const Color(0xFF59D6E6).withValues(alpha: 0.16),
    );
    _accent(
      canvas,
      center + Offset(r * 0.34 * math.cos(drift + 2.4), r * 0.34 * math.sin(drift + 2.4)),
      r * 0.80,
      const Color(0xFFE08BC0).withValues(alpha: 0.13),
    );
    _accent(
      canvas,
      center + Offset(0, -r * 0.42),
      r * 0.90,
      const Color(0xFF8F7BEE).withValues(alpha: 0.20),
    );
    // Inner depth: darker toward the rim, luminous toward the core.
    canvas.drawCircle(
      center,
      r * 1.4,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF000000).withValues(alpha: 0.0),
            const Color(0xFF000000).withValues(alpha: 0.38),
          ],
          stops: const [0.45, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r * 1.4)),
    );
    canvas.restore();

    // 4. Whisper-soft rim so the form reads against black, never a hard edge.
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
        ..color = const Color(0xFF8F7BEE).withValues(alpha: 0.28),
    );
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) =>
      old.t != t || old.level != level || old.listening != listening;
}
