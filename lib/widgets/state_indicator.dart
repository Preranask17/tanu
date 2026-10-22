import 'package:flutter/material.dart';

import '../abstractions/audio_source.dart';
import '../theme/tanu_colors.dart';

/// Mirrors the pendant state in the UI: idle / listening / thinking / error.
class StateIndicator extends StatelessWidget {
  const StateIndicator({
    super.key,
    required this.state,
    this.isListening = false,
    this.isThinking = false,
    this.error,
  });

  final PendantState state;
  final bool isListening;
  final bool isThinking;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    if (error != null) {
      return _Pill(
        color: c.danger,
        icon: Icons.warning_amber_rounded,
        label: error!,
      );
    }
    if (isThinking) {
      return _Pill(
        color: c.primary,
        icon: Icons.auto_awesome,
        label: 'Tanu is thinking...',
        progress: true,
      );
    }
    if (isListening) {
      return _Pill(
        color: c.primary,
        icon: Icons.graphic_eq,
        label: 'Listening...',
        pulse: true,
      );
    }
    switch (state) {
      case PendantState.connected:
        return _Pill(
          color: c.success,
          icon: Icons.check_circle_outline,
          label: 'Ready',
        );
      case PendantState.scanning:
        return _Pill(
          color: c.primary,
          icon: Icons.settings_bluetooth,
          label: 'Scanning for your pendant...',
          progress: true,
        );
      case PendantState.connecting:
        return _Pill(
          color: c.primary,
          icon: Icons.sync,
          label: 'Connecting...',
          progress: true,
        );
      case PendantState.reconnecting:
        return _Pill(
          color: c.primary,
          icon: Icons.sync,
          label: 'Reconnecting...',
          progress: true,
        );
      case PendantState.disconnected:
        return _Pill(
          color: c.textMuted,
          icon: Icons.bluetooth_disabled,
          label: 'Pendant not connected',
        );
    }
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.color,
    required this.icon,
    required this.label,
    this.progress = false,
    this.pulse = false,
  });

  final Color color;
  final IconData icon;
  final String label;
  final bool progress;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          progress
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: color,
                  ),
                )
              : Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
