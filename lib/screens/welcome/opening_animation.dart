import 'dart:math' as math;

import 'package:flutter/material.dart';

/// TANU startup movie: formation of the orb.
///
/// A small central blob appears, satellite blobs drift in from the edges and
/// merge into it, the result settles into a round breathing orb, we pause,
/// then zoom into the orb. Tap skips straight ahead.
///
/// Shown ONLY on cold starts after onboarding is already complete (see
/// `ReturningStartupGate`) — never on first launch, never on navigation.
///
/// Pure UI: no providers, no backend. Same indigo/violet/blue language as
/// the Capture-screen orb.
class TanuOpeningSequence extends StatefulWidget {
  const TanuOpeningSequence({
    super.key,
    required this.onDone,
    this.duration = const Duration(milliseconds: 6200),
  });

  final VoidCallback onDone;

  /// Total run time; the internal timeline is fractional so any duration
  /// keeps the same rhythm. Keep short (~4s) for the returning-user gate.
  final Duration duration;

  @override
  State<TanuOpeningSequence> createState() => _TanuOpeningSequenceState();
}

class _TanuOpeningSequenceState extends State<TanuOpeningSequence>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..forward();
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
          builder: (context, _) => CustomPaint(
            painter: _FormingPainter(value: _c.value),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// Timeline (fractions of the total run):
/// 0.00–0.30 central blob appears · 0.20–0.76 satellites merge ·
/// 0.76–0.86 settle/pause · 0.86–1.00 zoom into the orb.
class _FormingPainter extends CustomPainter {
  _FormingPainter({required this.value});

  final double value;

  static const _satelliteTints = [
    Color(0xFF5A48C8),
    Color(0xFF8F7BEE),
    Color(0xFF3E6ED8),
    Color(0xFF59D6E6),
    Color(0xFFE08BC0),
  ];

  double _smooth(double a, double b, double x) {
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  void _softDisc(Canvas canvas, Offset c, double r, Color color) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  Path _roundBlob(Offset c, double r, double wobble, double t) {
    final path = Path();
    const steps = 96;
    for (var i = 0; i <= steps; i++) {
      final a = i / steps * 2 * math.pi;
      final rr = r *
          (1 +
              wobble * math.sin(3 * a + t * 1.1) +
              wobble * 0.6 * math.sin(5 * a - t * 0.7));
      final p = Offset(c.dx + rr * math.cos(a), c.dy + rr * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = value * 2 * math.pi;
    final center = Offset(size.width / 2, size.height * 0.44);
    final baseR = math.min(size.width, size.height) * 0.16;

    // Central orb scale: appears small, grows as satellites merge.
    final appear = _smooth(0.0, 0.30, value);
    final grow = _smooth(0.20, 0.76, value);
    var scale =
        (0.35 + 0.65 * Curves.easeOutCubic.transform(appear)) * (1 + 0.10 * grow);
    // Gentle breathing once formed.
    scale *= 1 + 0.022 * math.sin(t * 0.9) * _smooth(0.25, 0.5, value);

    final zoomP = _smooth(0.86, 1.0, value);
    final zoom = 1 + 6 * Curves.easeInCubic.transform(zoomP);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(zoom);
    canvas.translate(-center.dx, -center.dy);

    final r = baseR * scale;

    // Ambient glow.
    _softDisc(
      canvas,
      center,
      r * 2.6,
      const Color(0xFF4A3AA8).withValues(alpha: 0.32 * appear),
    );

    // Round body: deep indigo -> violet -> blue.
    final body = _roundBlob(center, r, 0.018, t);
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A1E5C), Color(0xFF3E2E7E), Color(0xFF1E3A6E)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r * 1.4)),
    );

    // Interior accents, clipped inside so no separate discs ever show.
    canvas.save();
    canvas.clipPath(body);
    final drift = t * 0.35;
    _softDisc(
      canvas,
      center + Offset(r * 0.36 * math.cos(drift), r * 0.28 * math.sin(drift)),
      r * 0.85,
      const Color(0xFF59D6E6).withValues(alpha: 0.15 * appear),
    );
    _softDisc(
      canvas,
      center +
          Offset(r * 0.32 * math.cos(drift + 2.4), r * 0.32 * math.sin(drift + 2.4)),
      r * 0.80,
      const Color(0xFFE08BC0).withValues(alpha: 0.12 * appear),
    );
    _softDisc(
      canvas,
      center + Offset(0, -r * 0.40),
      r * 0.90,
      const Color(0xFF8F7BEE).withValues(alpha: 0.20 * appear),
    );
    canvas.restore();

    // Whisper-soft rim.
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
        ..color = const Color(0xFF8F7BEE).withValues(alpha: 0.28 * appear),
    );

    // Merging satellites.
    for (var i = 0; i < _satelliteTints.length; i++) {
      final start = 0.20 + i * 0.06;
      final p = ((value - start) / 0.32).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      final angle = -math.pi / 2 + i * (2 * math.pi / 5) + 0.35;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final travel = math.min(size.width, size.height) * 0.44;
      final bow = Offset(-dir.dy, dir.dx) * math.sin(p * math.pi) * 26;
      final pos = center + dir * travel * (1 - Curves.easeInOut.transform(p)) + bow;
      final satR = 22 * (1 - p) + 8 * p;
      final alpha = _smooth(0.0, 0.22, p) * (1 - _smooth(0.72, 1.0, p));
      if (alpha <= 0) continue;
      _softDisc(
        canvas,
        pos,
        satR * 2.2,
        _satelliteTints[i].withValues(alpha: 0.35 * alpha),
      );
      canvas.drawCircle(
        pos,
        satR,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _satelliteTints[i].withValues(alpha: 0.85 * alpha),
              _satelliteTints[i].withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: pos, radius: satR)),
      );
    }
    canvas.restore();

    // Wordmark fades in once formed, out as we zoom.
    final wordAlpha = _smooth(0.66, 0.78, value) * (1 - _smooth(0.86, 0.92, value));
    if (wordAlpha > 0) {
      final span = TextSpan(
        text: 'T A N U',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.75 * wordAlpha),
          fontSize: 15,
          letterSpacing: 4,
          fontWeight: FontWeight.w500,
        ),
      );
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
      tp.paint(
        canvas,
        Offset(center.dx - tp.width / 2, center.dy + baseR * 2.1),
      );
    }

    // Fade to black through the zoom: entering TANU.
    final scrim = _smooth(0.90, 1.0, value);
    if (scrim > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.black.withValues(alpha: scrim),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FormingPainter old) => old.value != value;
}
