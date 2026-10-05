import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Voice Pill States
enum VoicePillState {
  idle, // Not listening, shows mic icon
  listening, // Active recording, shows pause + waveform + transcript/timer
  paused, // Recording paused, shows resume + waveform frozen
  cancelling, // User sliding to cancel
}

/// A modern Material 3 voice input pill with clear states and smooth animations.
class VoicePill extends StatefulWidget {
  final VoicePillState state;
  final double micLevel;
  final String liveTranscript;
  final VoidCallback onStart; // Idle -> Listening
  final VoidCallback onPause; // Listening -> Paused
  final VoidCallback onResume; // Paused -> Listening
  final VoidCallback onStop; // Paused -> Idle (save)
  final VoidCallback onCancel; // Listening/Paused -> Idle (discard)

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

  @override
  State<VoicePill> createState() => _VoicePillState();
}

class _VoicePillState extends State<VoicePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  DateTime? _startTime;
  Timer? _timer;
  String _timeString = '0:00';

  // Waveform history for visualization
  final List<double> _waveHistory = [];
  static const int _maxHistory = 50;

  // Drag-to-cancel
  double _dragOffset = 0;
  static const double _cancelThreshold = 100;
  bool _hapticTriggered = false;

  VoicePillState? _previousState;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _syncState(widget.state);
    _previousState = widget.state;
  }

  @override
  void didUpdateWidget(covariant VoicePill oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncState(widget.state);

    // Update waveform when listening
    if (widget.state == VoicePillState.listening) {
      final level = widget.micLevel > 0.01
          ? widget.micLevel
          : (0.15 + math.Random().nextDouble() * 0.35);
      setState(() {
        if (_waveHistory.length >= _maxHistory) _waveHistory.removeAt(0);
        _waveHistory.add(level.clamp(0.0, 1.0));
      });
    }
  }

  void _syncState(VoicePillState newState) {
    final wasListening = _previousState == VoicePillState.listening;
    final wasPaused = _previousState == VoicePillState.paused;

    switch (newState) {
      case VoicePillState.idle:
        _controller.reverse();
        _stopTimer();
        _waveHistory.clear();
        _dragOffset = 0;
        _hapticTriggered = false;
        break;
      case VoicePillState.listening:
        if (!wasListening) {
          _controller.forward();
          _startTimer();
        }
        break;
      case VoicePillState.paused:
        if (!wasPaused) {
          _stopTimer();
        }
        break;
      case VoicePillState.cancelling:
        break;
    }
    _previousState = newState;
  }

  void _startTimer() {
    _timer?.cancel();
    _startTime = DateTime.now();
    _timeString = '0:00';
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || _startTime == null) return;
      final elapsed = DateTime.now().difference(_startTime!);
      final m = elapsed.inMinutes;
      final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
      setState(() => _timeString = '$m:$s');
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _startTime = null;
  }

  @override
  void dispose() {
    _controller.dispose();
    _stopTimer();
    super.dispose();
  }

  // ─── Drag Handling ───

  void _onPanUpdate(DragUpdateDetails details) {
    if (widget.state != VoicePillState.listening &&
        widget.state != VoicePillState.paused) {
      return;
    }

    setState(() {
      _dragOffset += details.delta.dx;
      if (_dragOffset > 0) _dragOffset = 0;

      final progress = (_dragOffset / -_cancelThreshold).clamp(0.0, 1.0);

      if (progress >= 1.0 && !_hapticTriggered) {
        HapticFeedback.heavyImpact();
        _hapticTriggered = true;
        widget.onCancel();
      }
    });
  }

  void _onPanEnd(DragEndDetails _) {
    if (widget.state != VoicePillState.listening &&
        widget.state != VoicePillState.paused) {
      return;
    }
    setState(() {
      _dragOffset = 0;
      _hapticTriggered = false;
    });
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // The pill expands from a pill shape (e.g., 200) to full width
    const height = 56.0;
    const baseWidth = 220.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 32;

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final progress = CurvedAnimation(
              parent: _controller,
              curve: Curves.easeOutCubic,
            ).value;

            final currentWidth = baseWidth + (maxWidth - baseWidth) * progress;
            final cancelProgress = (_dragOffset / -_cancelThreshold).clamp(
              0.0,
              1.0,
            );

            return GestureDetector(
              onTap: widget.state == VoicePillState.idle
                  ? _handleIdleTap
                  : null,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: Transform.translate(
                offset: Offset(_dragOffset, 0),
                child: Opacity(
                  opacity: 1.0 - (cancelProgress * 0.4),
                  child: Align(
                    alignment: Alignment.center,
                    child: _PillContainer(
                      width: currentWidth,
                      height: height,
                      progress: progress,
                      cancelProgress: cancelProgress,
                      state: widget.state,
                      micLevel: widget.micLevel,
                      liveTranscript: widget.liveTranscript,
                      timeString: _timeString,
                      waveHistory: _waveHistory,
                      onPauseTap: widget.onPause,
                      onResumeTap: widget.onResume,
                      onStopTap: widget.onStop,
                      colorScheme: colorScheme,
                      isDark: isDark,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handleIdleTap() {
    HapticFeedback.lightImpact();
    widget.onStart();
  }
}

// ─── Pill Container ───

class _PillContainer extends StatelessWidget {
  final double width;
  final double height;
  final double progress;
  final double cancelProgress;
  final VoicePillState state;
  final double micLevel;
  final String liveTranscript;
  final String timeString;
  final List<double> waveHistory;
  final VoidCallback onPauseTap;
  final VoidCallback onResumeTap;
  final VoidCallback onStopTap;
  final ColorScheme colorScheme;
  final bool isDark;

  const _PillContainer({
    required this.width,
    required this.height,
    required this.progress,
    required this.cancelProgress,
    required this.state,
    required this.micLevel,
    required this.liveTranscript,
    required this.timeString,
    required this.waveHistory,
    required this.onPauseTap,
    required this.onResumeTap,
    required this.onStopTap,
    required this.colorScheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isListening = state == VoicePillState.listening;
    final isPaused = state == VoicePillState.paused;
    final isActive = isListening || isPaused;

    // Background color based on state
    Color containerColor;
    Color borderColor;
    List<BoxShadow> shadows;

    if (cancelProgress > 0) {
      containerColor = Colors.redAccent.withValues(alpha: 0.1 * cancelProgress);
      borderColor = Colors.redAccent.withValues(alpha: 0.5 * cancelProgress);
      shadows = [];
    } else if (isActive) {
      containerColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
      borderColor = colorScheme.primary;
      shadows = [
        BoxShadow(
          color: colorScheme.primary.withValues(alpha: 0.25),
          blurRadius: 16,
          spreadRadius: 2,
        ),
      ];
    } else {
      containerColor = isDark ? const Color(0xFF27272A) : Colors.white;
      borderColor = isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E5E5);
      shadows = [];
    }

    // The idle control is the whole pill. Active states reserve the trailing
    // action area for pause/resume/stop controls.
    final actionWidth = state == VoicePillState.idle
        ? width
        : (state == VoicePillState.paused ? height * 2.0 : height);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: borderColor, width: isActive ? 2 : 1),
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Stack(
          alignment: Alignment.centerRight,
          children: [
            // Expanded content area
            if (progress > 0 && state != VoicePillState.idle)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                left: 20,
                right: actionWidth + 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Opacity(
                    opacity: (progress * (1 - cancelProgress)).clamp(0.0, 1.0),
                    child: _ContentArea(
                      state: state,
                      liveTranscript: liveTranscript,
                      timeString: timeString,
                      cancelProgress: cancelProgress,
                      colorScheme: colorScheme,
                      isDark: isDark,
                    ),
                  ),
                ),
              ),

            // Waveform (only when listening)
            if (progress > 0 && isListening && cancelProgress == 0)
              Positioned(
                right: height,
                child: Opacity(
                  opacity: progress.clamp(0.0, 1.0),
                  child: SizedBox(
                    width: 60,
                    height: 32,
                    child: _WaveformWidget(
                      history: waveHistory,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ),

            // Action button area (right side)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: actionWidth,
              height: height,
              child: _ActionButton(
                state: state,
                progress: progress,
                colorScheme: colorScheme,
                isDark: isDark,
                onPauseTap: onPauseTap,
                onResumeTap: onResumeTap,
                onStopTap: onStopTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Content Area (Transcript / Timer / Cancel Hint) ───

class _ContentArea extends StatelessWidget {
  final VoicePillState state;
  final String liveTranscript;
  final String timeString;
  final double cancelProgress;
  final ColorScheme colorScheme;
  final bool isDark;

  const _ContentArea({
    required this.state,
    required this.liveTranscript,
    required this.timeString,
    required this.cancelProgress,
    required this.colorScheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isCancelling = cancelProgress > 0.5;
    final hasTranscript = liveTranscript.trim().isNotEmpty;

    String text;
    TextStyle style;

    if (isCancelling) {
      text = 'Slide to cancel';
      style = TextStyle(
        color: Colors.redAccent,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
    } else if (hasTranscript) {
      text = liveTranscript;
      style = TextStyle(
        color: isDark ? Colors.white : Colors.black,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        height: 1.3,
      );
    } else {
      text = timeString;
      style = TextStyle(
        color: colorScheme.primary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
    }

    return Text(
      text,
      style: style,
      overflow: TextOverflow.fade,
      maxLines: 1,
      softWrap: false,
    );
  }
}

// ─── Action Button (Mic / Pause / Stop) ───

class _ActionButton extends StatelessWidget {
  final VoicePillState state;
  final double progress;
  final ColorScheme colorScheme;
  final bool isDark;
  final VoidCallback onPauseTap;
  final VoidCallback onResumeTap;
  final VoidCallback onStopTap;

  const _ActionButton({
    required this.state,
    required this.progress,
    required this.colorScheme,
    required this.isDark,
    required this.onPauseTap,
    required this.onResumeTap,
    required this.onStopTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIdle = state == VoicePillState.idle;

    // Only show action button when expanded enough
    if (progress < 0.3 && !isIdle) {
      return const SizedBox.shrink();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: _buildButtonForState(isIdle),
    );
  }

  Widget _buildButtonForState(bool isIdle) {
    if (isIdle) {
      return Row(
        key: const ValueKey('idle'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mic_none_rounded,
            color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            'Tap to capture',
            style: TextStyle(
              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    if (state == VoicePillState.listening) {
      return IconButton(
        key: const ValueKey('listening'),
        onPressed: onPauseTap,
        icon: Icon(Icons.pause_rounded, color: colorScheme.primary, size: 26),
        tooltip: 'Pause',
        style: IconButton.styleFrom(
          backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
        ),
      );
    }

    if (state == VoicePillState.paused) {
      return Row(
        key: const ValueKey('paused'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: onResumeTap,
            icon: Icon(Icons.mic_rounded, color: colorScheme.primary, size: 24),
            tooltip: 'Resume',
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onStopTap,
            icon: Icon(Icons.stop_rounded, color: Colors.redAccent, size: 24),
            tooltip: 'Stop & Save',
            style: IconButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

// ─── Waveform Widget ───

class _WaveformWidget extends StatelessWidget {
  final List<double> history;
  final Color color;

  const _WaveformWidget({required this.history, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WaveformPainter(history: history, color: color),
      size: const Size(60, 32),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> history;
  final Color color;

  _WaveformPainter({required this.history, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;

    final maxBars = (size.width / 3.5).floor();
    final displayHistory = history.length > maxBars
        ? history.sublist(history.length - maxBars)
        : history;

    final barWidth = size.width / displayHistory.length;

    for (int i = 0; i < displayHistory.length; i++) {
      final value = displayHistory[i].clamp(0.0, 1.0);
      final height = math.max(2.0, value * size.height * 0.8);
      final x = i * barWidth + barWidth / 2;

      canvas.drawLine(
        Offset(x, size.height / 2 - height / 2),
        Offset(x, size.height / 2 + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.history != history || oldDelegate.color != color;
  }
}
