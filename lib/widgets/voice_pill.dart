import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum VoicePillState { idle, listening, paused, cancelling }

class VoicePill extends StatefulWidget {
  const VoicePill({
    super.key,
    required this.state,
    required this.micLevel,
    this.liveTranscript = '',
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onCancel,
  });

  final VoicePillState state;
  final double micLevel;
  final String liveTranscript;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  @override
  State<VoicePill> createState() => _VoicePillState();
}

class _VoicePillState extends State<VoicePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  Timer? _timer;
  DateTime? _startedAt;
  String _elapsed = '0:00';
  double _dragDistance = 0;
  bool _cancelHapticSent = false;
  VoicePillState? _lastState;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _lastState = widget.state;
    _syncState(widget.state);
  }

  @override
  void didUpdateWidget(covariant VoicePill oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncState(widget.state);
  }

  void _syncState(VoicePillState state) {
    final previous = _lastState;
    _lastState = state;
    if (state == VoicePillState.idle) {
      _animation.reverse();
      _timer?.cancel();
      _timer = null;
      _startedAt = null;
      _elapsed = '0:00';
      _dragDistance = 0;
      _cancelHapticSent = false;
    } else if (state == VoicePillState.listening &&
        previous != VoicePillState.listening) {
      _animation.forward();
      _startTimer();
    } else if (state == VoicePillState.paused &&
        previous == VoicePillState.listening) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _startedAt ??= DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || _startedAt == null) return;
      final duration = DateTime.now().difference(_startedAt!);
      setState(() {
        _elapsed =
            '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
      });
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isActive) return;
    setState(() {
      _dragDistance = (_dragDistance - details.delta.dx).clamp(0.0, 120.0);
    });
    if (_dragDistance >= 100 && !_cancelHapticSent) {
      _cancelHapticSent = true;
      HapticFeedback.heavyImpact();
      widget.onCancel();
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isActive) return;
    setState(() {
      _dragDistance = 0;
      _cancelHapticSent = false;
    });
  }

  bool get _isActive =>
      widget.state == VoicePillState.listening ||
      widget.state == VoicePillState.paused ||
      widget.state == VoicePillState.cancelling;

  @override
  void dispose() {
    _timer?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final active = _isActive;
    final danger = _dragDistance > 20;

    return GestureDetector(
      onTap: widget.state == VoicePillState.idle
          ? () {
              HapticFeedback.lightImpact();
              widget.onStart();
            }
          : null,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) => Transform.translate(
          offset: Offset(-_dragDistance, 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: active ? 72 : 64,
            decoration: BoxDecoration(
              color: danger
                  ? Colors.red.withValues(alpha: dark ? 0.16 : 0.08)
                  : (dark ? const Color(0xFF151515) : Colors.white),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: danger
                    ? Colors.redAccent
                    : active
                    ? primary.withValues(alpha: 0.7)
                    : (dark
                          ? const Color(0xFF303030)
                          : const Color(0xFFE2E2E2)),
                width: active ? 1.5 : 1,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: child,
          ),
        ),
        child: active
            ? _ActiveControl(
                state: widget.state,
                transcript: widget.liveTranscript,
                elapsed: _elapsed,
                primary: primary,
                dark: dark,
                danger: danger,
                onPause: widget.onPause,
                onResume: widget.onResume,
                onStop: widget.onStop,
              )
            : _IdleControl(dark: dark, primary: primary),
      ),
    );
  }
}

class _IdleControl extends StatelessWidget {
  const _IdleControl({required this.dark, required this.primary});

  final bool dark;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 14),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.mic_rounded, color: primary, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Ready to capture',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: dark ? Colors.white : Colors.black,
            ),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }
}

class _ActiveControl extends StatelessWidget {
  const _ActiveControl({
    required this.state,
    required this.transcript,
    required this.elapsed,
    required this.primary,
    required this.dark,
    required this.danger,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  final VoicePillState state;
  final String transcript;
  final String elapsed;
  final Color primary;
  final bool dark;
  final bool danger;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final paused = state == VoicePillState.paused;
    return Row(
      children: [
        const SizedBox(width: 14),
        _StatusDot(color: danger ? Colors.redAccent : primary, pulse: !paused),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            danger
                ? 'Release to cancel'
                : transcript.trim().isNotEmpty
                ? transcript.trim()
                : (paused ? 'Capture paused' : 'Listening  •  $elapsed'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: danger
                  ? Colors.redAccent
                  : (dark ? Colors.white : Colors.black),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontStyle: transcript.trim().isNotEmpty
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, required this.pulse});

  final Color color;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: pulse
            ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
            : null,
      ),
    );
  }
}
