import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../abstractions/audio_source.dart';

/// Shared pendant status controls for the Capture, Memories and Settings
/// headers: [BatteryPill] + [PendantStatusButton], same look everywhere.
///
/// Presentation only: reads an existing [PendantStatus] and forwards taps to
/// the caller (which opens the existing device picker sheet). All BLE/scan
/// logic lives elsewhere and is untouched.
class DeviceStatusActions extends StatelessWidget {
  const DeviceStatusActions({
    super.key,
    required this.status,
    required this.onBluetoothTap,
  });

  final PendantStatus status;
  final VoidCallback onBluetoothTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status.isConnected && status.batteryPercent != null) ...[
          BatteryPill(percent: status.batteryPercent!),
          const SizedBox(width: 10),
        ],
        PendantStatusButton(
          status: status,
          onTap: onBluetoothTap,
        ),
      ],
    );
  }
}

/// Bluetooth status button with a UNIFORM container in every state: same
/// 44x44 dark circular surface, same subtle neutral border, same height and
/// alignment as the battery pill beside it. Only the status accents change —
/// icon + a soft red glow when disconnected, green connected icon otherwise.
class PendantStatusButton extends StatelessWidget {
  const PendantStatusButton({
    super.key,
    required this.status,
    required this.onTap,
  });

  final PendantStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final connected = status.isConnected;
    final reconnecting = status.state == PendantState.reconnecting;

    final IconData icon;
    final Color iconColor;
    if (connected) {
      icon = Icons.bluetooth_connected;
      iconColor = const Color(0xFF4CAF50);
    } else if (reconnecting) {
      icon = Icons.sync;
      iconColor = Colors.orange;
    } else {
      icon = Icons.bluetooth;
      iconColor = const Color(0xFF888888);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF),
          border: Border.all(
            color: isDark
                ? const Color(0xFF2A2A2A)
                : const Color(0xFFE5E5E5),
            width: 1,
          ),
          boxShadow: [
            // Soft status glow; the container itself never changes.
            if (!connected)
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.30),
                blurRadius: 14,
                spreadRadius: 1,
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
    );
  }
}

/// Compact battery pill. Display only: the value comes straight from the
/// existing pendant status, no battery logic here.
class BatteryPill extends StatelessWidget {
  const BatteryPill({super.key, required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.battery_std, size: 18, color: Color(0xFF888888)),
          const SizedBox(width: 6),
          Text(
            '$percent%',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF888888),
            ),
          ),
        ],
      ),
    );
  }
}
