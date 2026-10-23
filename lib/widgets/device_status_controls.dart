import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../abstractions/audio_source.dart';
import '../theme/tanu_colors.dart';

/// Compact pendant status pill used in every primary tab header.
///
/// Presentation only: reads an existing [PendantStatus] and forwards taps to
/// the caller. The caller opens the existing device picker sheet; scanning and
/// connection logic remain outside this widget.
class PendantStatusPill extends StatelessWidget {
  const PendantStatusPill({
    super.key,
    required this.status,
    required this.onTap,
  });

  final PendantStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    final connected = status.isConnected;
    final reconnecting =
        status.state == PendantState.reconnecting ||
        status.state == PendantState.scanning ||
        status.state == PendantState.connecting;

    final dotColor = connected
        ? c.success
        : reconnecting
        ? c.primary
        : c.danger;
    final battery = connected ? status.batteryPercent : null;
    final label = connected
        ? (battery == null ? 'Pendant' : null)
        : reconnecting
        ? 'Syncing'
        : 'Connect';
    final icon = reconnecting ? Icons.sync_rounded : Icons.bluetooth_rounded;
    final accent = connected ? c.primary : c.textMuted;
    final semantics = connected
        ? 'Pendant connected${battery == null ? '' : ', $battery percent battery'}. Tap to manage.'
        : reconnecting
        ? 'Pendant syncing. Tap to manage.'
        : 'Connect pendant. Tap to manage.';

    return Semantics(
      button: true,
      label: semantics,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  boxShadow: connected
                      ? [
                          BoxShadow(
                            color: dotColor.withValues(alpha: 0.35),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
              if (battery != null) ...[
                const SizedBox(width: 7),
                Text(
                  '$battery%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textMuted,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Icon(icon, size: 16, color: accent),
              if (label != null) ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
