import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Calm audio waveform for the Capture screen.
///
/// A horizontal row of rounded vertical bars, mirrored around a soft centre
/// line. The bars breathe gently while idle and swell with [level] once a
/// session is [listening] or [transcribing].
///
/// Pure presentation: plain values in, no providers or audio services.
class WaveformVisualizer extends StatefulWidget {
  const WaveformVisualizer({
    super.key,
    this.level = 0,
    this.listening = false,
    this.transcribing = false,
    this.height = 280,
  });

  /// Voice energy 0..1, read from the already-watched conversation state.
  final double level;

  /// Whether a capture session is live.
  final bool listening;

  /// Whether words are actively streaming in.
  final bool transcribing;

  /// Render height; bars stay centred within this space.
  final double height;

  @override
  State<WaveformVisualizer> createState() => _WaveformVisualizerState();
}

class _WaveformVisualizerState extends State<WaveformVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flow;

  @override
  void initState() {
    super.initState();
    // Slow, breathing loop: calm enough to sit behind live transcription.
    _flow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final active = _WaveformColors.terracotta;
    final inactive = dark
        ? _WaveformColors.mutedNeutral
        : _WaveformColors.softBeigeBorder;

    return Semantics(
      label: widget.listening ? 'Live audio waveform' : 'Audio waveform',
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _flow,
            builder: (context, _) => CustomPaint(
              painter: _WaveformPainter(
                phase: _flow.value * 2 * math.pi,
                level: widget.level.clamp(0.0, 1.0).toDouble(),
                listening: widget.listening,
                transcribing: widget.transcribing,
                activeColor: active,
                inactiveColor: inactive,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

abstract final class _WaveformColors {
  /// Muted terracotta beige used for active bars.
  static const Color terracotta = Color(0xFF8C6D58);

  /// Soft beige border used for resting bars in light mode.
  static const Color softBeigeBorder = Color(0xFFE3DCCB);

  /// Muted neutral used for resting bars in dark mode.
  static const Color mutedNeutral = Color(0xFF736B60);
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.phase,
    required this.level,
    required this.listening,
    required this.transcribing,
    required this.activeColor,
    required this.inactiveColor,
  });

  final double phase;
  final double level;
  final bool listening;
  final bool transcribing;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    const barWidth = 6.0;
    const gap = 5.0;
    const horizontalPadding = 24.0;

    final available = math.max(0.0, size.width - horizontalPadding * 2);
    final count = math
        .max(9, (available / (barWidth + gap)).floor())
        .clamp(9, 57)
        .toInt();
    final totalWidth = count * barWidth + (count - 1) * gap;
    final startX = (size.width - totalWidth) / 2 + barWidth / 2;
    final centreY = size.height / 2;

    final minHeight = barWidth + 2;
    final maxHeight = size.height * 0.56;
    final energyGate = listening || transcribing;
    final dynamicEnergy =
        0.28 + level * 0.62 + (transcribing ? 0.08 : 0.0);

    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      final position = count == 1 ? 0.5 : i / (count - 1);
      // Taper the ends so the row reads as a single waveform, not a block.
      final envelope = math
          .pow(math.sin(math.pi * position), 0.7)
          .toDouble();

      final breath = 0.5 + 0.5 * math.sin(phase * 0.9 + i * 0.35);
      final ripple =
          0.5 + 0.5 * math.sin(phase * 1.7 - i * 0.52 + 1.2);

      final energy = (envelope *
              (0.12 +
                  0.08 * breath +
                  (energyGate ? dynamicEnergy : 0.10) *
                      (0.55 * breath + 0.45 * ripple)))
          .clamp(0.0, 1.0)
          .toDouble();

      final barHeight = minHeight + (maxHeight - minHeight) * energy;
      final tint = ((energy - 0.12) / 0.55).clamp(0.0, 1.0).toDouble();
      paint.color = Color.lerp(inactiveColor, activeColor, tint)!;

      final x = startX + i * (barWidth + gap);
      final rect = Rect.fromCenter(
        center: Offset(x, centreY),
        width: barWidth,
        height: barHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(barWidth / 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.phase != phase ||
      old.level != level ||
      old.listening != listening ||
      old.transcribing != transcribing ||
      old.activeColor != activeColor ||
      old.inactiveColor != inactiveColor;
}
