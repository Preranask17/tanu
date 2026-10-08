import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Persistent onboarding backdrop: a full-screen matrix of soft glowing dots
/// warped into slow, organic topographic waves.
///
/// Approach is CustomPainter (not a fragment shader): a few thousand plain
/// circles per frame with precomputed paints is cheaper than a fullscreen
/// shader on low-end phones, and dots stay crisp at any density.
///
/// Page-driven morphing: when [pages] (the onboarding PageController) is
/// supplied, the wave topology interpolates between six keyframe states as
/// the user drags — finger movement morphs the field directly, and the
/// arrow buttons morph in sync for free because they drive the same
/// controller. A slow time drift keeps it breathing when idle. Overscroll
/// values are clamped, so bouncing past either end degrades gracefully.
///
/// - Base: near-black indigo gradient + faint violet bloom (dark enough that
///   foreground text stays legible without any scrim).
/// - Dots: violet-white with sparse cyan/pink accents; brightness, size and
///   a small positional wobble all follow domain-warped sine fields, so the
///   ridges flow organically instead of forming straight geometric bands.
/// - Zero input: wrapped in [IgnorePointer]; foreground stays interactive.
///
/// Pure UI: no providers, no backend.
class WaveDotBackground extends StatefulWidget {
  const WaveDotBackground({super.key, this.pages});

  /// The onboarding PageController. Its scroll offset drives the morph;
  /// when null (or before layout) the backdrop rests on keyframe 0.
  final PageController? pages;

  @override
  State<WaveDotBackground> createState() => _WaveDotBackgroundState();
}

class _WaveDotBackgroundState extends State<WaveDotBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tickers = <Listenable>[_drift];
    final source = widget.pages;
    if (source != null) tickers.add(source);
    return RepaintBoundary(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: Listenable.merge(tickers),
          builder: (context, _) {
            var page = 0.0;
            if (source?.hasClients == true) {
              page = (source?.page ?? 0.0).clamp(0.0, 5.0);
            }
            return CustomPaint(
              painter: _WaveDotPainter(time: _drift.value * 24, page: page),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

/// One keyframe of the morph: the six onboarding pages each rest on one of
/// these, and dragging interpolates between neighbours with smoothstep.
class _WaveKey {
  const _WaveKey({
    required this.amp,
    required this.freq,
    required this.warp,
    required this.angle,
    required this.lift,
    required this.radial,
    required this.presence,
  });

  /// Ridge contrast around the midpoint. Higher = sharper bright bands.
  final double amp;

  /// Spatial frequency multiplier.
  final double freq;

  /// Domain-warp strength. Higher = more organic, less striped.
  final double warp;

  /// Flow rotation in radians.
  final double angle;

  /// Vertical bias of the ridge focus, in screen-half units.
  final double lift;

  /// 0 = horizontal band flow, 1 = concentric radial rings.
  final double radial;

  /// Fraction of dots visible (density feel without popping).
  final double presence;
}

const _waveKeys = [
  // 0 Meet TANU: gentle central crest.
  _WaveKey(
      amp: 0.70,
      freq: 0.90,
      warp: 0.80,
      angle: 0.0,
      lift: 0.05,
      radial: 0.65,
      presence: 0.85),
  // 1 Pendant: dual flowing horizontal ripples.
  _WaveKey(
      amp: 0.90,
      freq: 1.00,
      warp: 1.10,
      angle: 0.12,
      lift: 0.10,
      radial: 0.10,
      presence: 0.90),
  // 2 Capture: focused radial density.
  _WaveKey(
      amp: 1.15,
      freq: 1.05,
      warp: 0.90,
      angle: -0.10,
      lift: 0.0,
      radial: 1.00,
      presence: 1.00),
  // 3 Memories: soft diagonal drift.
  _WaveKey(
      amp: 0.95,
      freq: 0.95,
      warp: 1.25,
      angle: 0.45,
      lift: -0.05,
      radial: 0.25,
      presence: 0.92),
  // 4 Ask: fine ripple detail.
  _WaveKey(
      amp: 0.80,
      freq: 1.25,
      warp: 1.00,
      angle: 0.20,
      lift: 0.0,
      radial: 0.35,
      presence: 0.88),
  // 5 Ready: calm wide glow.
  _WaveKey(
      amp: 0.55,
      freq: 0.85,
      warp: 0.70,
      angle: 0.0,
      lift: 0.08,
      radial: 0.50,
      presence: 0.80),
];

double _smooth(double x) {
  final t = x.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double _mix(double a, double b, double t) => a + (b - a) * t;

class _WaveDotPainter extends CustomPainter {
  _WaveDotPainter({required this.time, required this.page});

  /// Seconds into the ~24s drift loop (idle breathing).
  final double time;

  /// Fractional page position, already clamped to 0..5 by the widget.
  final double page;

  static const double _step = 17.0;

  static const _base = Color(0xFFB9AFF2); // pale violet-white
  static const _cyan = Color(0xFF59D6E6);
  static const _pink = Color(0xFFE08BC0);

  /// Precomputed paint table: 3 hues x 16 alpha steps. Nothing is allocated
  /// per frame or per dot besides the offset itself.
  static final List<List<Paint>> _paints = [
    for (var c = 0; c < 3; c++)
      [
        for (var a = 0; a < 16; a++)
          Paint()
            ..color = [_base, _cyan, _pink][c]
                .withValues(alpha: (a + 1) / 16 * 0.34),
      ],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Interpolated keyframe for the current (possibly fractional) page.
    final p = page.clamp(0.0, 5.0);
    final i0 = p.floor().clamp(0, 4);
    final f = _smooth(p - i0);
    final k0 = _waveKeys[i0];
    final k1 = _waveKeys[i0 + 1];
    final amp = _mix(k0.amp, k1.amp, f);
    final freq = _mix(k0.freq, k1.freq, f);
    final warp = _mix(k0.warp, k1.warp, f);
    final angle = _mix(k0.angle, k1.angle, f);
    final lift = _mix(k0.lift, k1.lift, f);
    final radial = _mix(k0.radial, k1.radial, f);
    final presence = _mix(k0.presence, k1.presence, f);

    // 1. Near-black indigo base.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D0924), Color(0xFF030207)],
        ).createShader(Offset.zero & size),
    );

    // 2. Faint violet bloom, upper third.
    final bloomCenter = Offset(size.width / 2, size.height * 0.30);
    canvas.drawCircle(
      bloomCenter,
      size.width * 0.75,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF4A3AA8).withValues(alpha: 0.10),
            const Color(0xFF4A3AA8).withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(center: bloomCenter, radius: size.width * 0.75),
        ),
    );

    // 3. Warped dot matrix.
    final cx = size.width / 2;
    final cy = size.height * (0.5 - lift * 0.2);
    final ca = math.cos(angle);
    final sa = math.sin(angle);
    final nx = (size.width / _step).ceil();
    final ny = (size.height / _step).ceil();
    for (var jy = 0; jy < ny; jy++) {
      final y = (jy + 0.5) * _step;
      for (var jx = 0; jx < nx; jx++) {
        final x = (jx + 0.5) * _step;

        // Rotate the domain so the flow itself turns as pages change.
        final dx = x - cx;
        final dy = y - cy;
        final u = (dx * ca - dy * sa) * freq;
        final v = (dx * sa + dy * ca) * freq;

        // Band flow (horizontal ripples, domain-warped).
        final bands = math.sin(
              v * 0.014 -
                  time * 0.28 +
                  warp * 1.5 * math.sin(u * 0.008 + time * 0.18),
            ) +
            math.sin(
              u * 0.012 +
                  time * 0.35 +
                  warp * 1.8 * math.sin(v * 0.010 - time * 0.22),
            ) +
            0.6 * math.sin((u + v) * 0.006 + time * 0.15);

        // Radial flow (concentric rings around the lifted focus).
        final dist = math.sqrt(dx * dx + dy * dy) * freq;
        final rings = math.sin(dist * 0.018 - time * 0.45) +
            0.5 * math.sin(dist * 0.043 + time * 0.30);

        final ridge = ((bands / 2.6 * 0.5 + 0.5) * (1 - radial)) +
            ((rings / 3 + 0.5) * radial);
        // Contrast around the midpoint: amp sharpens ridges without
        // changing overall brightness much.
        final bright = ((ridge - 0.5) * amp + 0.5).clamp(0.0, 1.0);
        final b = bright * bright;

        // Density gate with a soft edge: dots fade (not pop) as presence
        // morphs. The hash is stable per cell across frames and pages.
        final hash = (math.sin(jx * 12.9898 + jy * 78.233) * 43758.5453)
            .abs()
            .remainder(1.0);
        final gate = ((presence - hash) * 8).clamp(0.0, 1.0);

        // Vignette: keep edges quiet so content stays the focus.
        final ex = (x / size.width - 0.5) * 2;
        final ey = (y / size.height - 0.5) * 2;
        final vig = (1 - 0.45 * (ex * ex + ey * ey)).clamp(0.15, 1.0);

        final alpha = (0.03 + 0.30 * b) * vig * gate;
        if (alpha < 0.012) continue;

        // Sparse accent tint from two slower fields.
        final m1 = math.sin(x * 0.005 - time * 0.10 + math.sin(y * 0.007));
        final m2 = math.sin(y * 0.006 + time * 0.08 + math.sin(x * 0.006));
        final ci = m1 > 0.75 ? 1 : (m2 > 0.75 ? 2 : 0);

        // Positional wobble, scaled by brightness: ridges shimmer, valleys sit.
        final ox = 2.5 * b * math.sin(y * 0.02 + time * 0.30);
        final oy = 2.5 * b * math.cos(x * 0.02 - time * 0.25);

        final ai = (alpha / 0.34 * 15).clamp(0, 15).toInt();
        canvas.drawCircle(
          Offset(x + ox, y + oy),
          1.0 + 1.4 * b,
          _paints[ci][ai],
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WaveDotPainter old) =>
      old.time != time || old.page != page;
}
