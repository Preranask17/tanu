import 'dart:math' as math;
import 'package:flutter/material.dart';

class AuraOrb extends StatefulWidget {
  final double micLevel;
  final bool isConnected;

  const AuraOrb({super.key, required this.micLevel, required this.isConnected});

  @override
  State<AuraOrb> createState() => _AuraOrbState();
}

class _AuraOrbState extends State<AuraOrb> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final footprint = math.min(300.0, math.max(180.0, available - 24.0));

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value * 2 * math.pi;
            final micLevel = widget.micLevel.clamp(0.0, 1.0);
            final pulse = widget.isConnected
                ? micLevel * 14.0 + math.sin(t * 3) * 3.0
                : math.sin(t * 2) * 2.0;
            final orbSize = footprint * 0.78 + pulse;
            final glowSize = orbSize + 34;

            final cyan = const Color(
              0xFF00E5FF,
            ).withValues(alpha: widget.isConnected ? 0.9 : 0.5);
            final indigo = const Color(
              0xFF651FFF,
            ).withValues(alpha: widget.isConnected ? 0.9 : 0.5);
            final neonPink = const Color(
              0xFFFF007F,
            ).withValues(alpha: widget.isConnected ? 0.8 : 0.4);

            return SizedBox(
              width: footprint,
              height: footprint,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: glowSize,
                    height: glowSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: indigo.withValues(alpha: 0.28),
                          blurRadius: 48 + micLevel * 18,
                          spreadRadius: 8 + micLevel * 8,
                        ),
                      ],
                    ),
                  ),
                  ClipOval(
                    child: Container(
                      width: orbSize,
                      height: orbSize,
                      color: const Color(0xFF111111),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.translate(
                            offset: Offset(
                              math.cos(t) * orbSize * 0.18,
                              math.sin(t) * orbSize * 0.18,
                            ),
                            child: _blob(orbSize * 0.82, cyan),
                          ),
                          Transform.translate(
                            offset: Offset(
                              math.cos(t + math.pi) * orbSize * 0.18,
                              math.sin(t + math.pi) * orbSize * 0.18,
                            ),
                            child: _blob(orbSize * 0.82, indigo),
                          ),
                          Transform.translate(
                            offset: Offset(
                              math.cos(t + math.pi / 2) * orbSize * 0.14,
                              math.sin(t + math.pi * 1.5) * orbSize * 0.14,
                            ),
                            child: _blob(orbSize * 0.65, neonPink),
                          ),
                          _blob(
                            orbSize * 0.4,
                            Colors.white.withValues(
                              alpha: widget.isConnected ? 0.6 : 0.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0.0)]),
      ),
    );
  }
}
