import 'dart:math' as math;
import 'package:flutter/material.dart';

class AudioWaveform extends StatefulWidget {
  const AudioWaveform({super.key, required this.level});
  
  final double level;

  @override
  State<AudioWaveform> createState() => _AudioWaveformState();
}

class _AudioWaveformState extends State<AudioWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  
  // We'll store a history of levels to draw the wave
  final List<double> _levels = List.filled(30, 0.0, growable: true);
  
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 50))..repeat();
    _ctrl.addListener(_tick);
  }
  
  @override
  void didUpdateWidget(AudioWaveform old) {
    super.didUpdateWidget(old);
    // Smooth out level drops, let them decay
  }
  
  double _targetLevel = 0.0;
  double _currentLevel = 0.0;

  void _tick() {
    _targetLevel = widget.level;
    // Smooth interpolation
    _currentLevel += (_targetLevel - _currentLevel) * 0.3;
    
    // Shift left and append
    _levels.removeAt(0);
    _levels.add(_currentLevel * (0.5 + 0.5 * math.sin(DateTime.now().millisecondsSinceEpoch / 100)));
    
    setState(() {});
  }
  
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      width: double.infinity,
      child: CustomPaint(
        painter: _WavePainter(levels: _levels, color: Theme.of(context).primaryColor),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.levels, required this.color});
  
  final List<double> levels;
  final Color color;
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
      
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final maxAmp = size.height / 2;
    final w = size.width;
    final count = levels.length;
    final dx = w / count;
    
    for (int i = 0; i < count; i++) {
      final x = i * dx + dx/2;
      // Boost small values to make them visible
      final amp = maxAmp * (levels[i] * 2).clamp(0.1, 1.0); 
      
      final p1 = Offset(x, size.height/2 - amp);
      final p2 = Offset(x, size.height/2 + amp);
      
      canvas.drawLine(p1, p2, glowPaint);
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => true;
}