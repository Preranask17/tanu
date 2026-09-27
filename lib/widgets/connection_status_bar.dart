import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../abstractions/audio_source.dart';
import '../providers/ble_provider.dart';

/// Compact strip showing pendant connection + battery across screens.
class ConnectionStatusBar extends ConsumerWidget {
  const ConnectionStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(pendantStatusProvider).value ?? PendantStatus();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (color, icon, text) = switch (status.state) {
      PendantState.connected => (
        Colors.green,
        Icons.bluetooth_connected,
        status.deviceName ?? 'Connected',
      ),
      PendantState.reconnecting => (
        Colors.orange,
        Icons.sync,
        'Reconnecting...',
      ),
      PendantState.scanning => (
        Theme.of(context).primaryColor,
        Icons.settings_bluetooth,
        'Looking for pendant...',
      ),
      PendantState.connecting => (
        Theme.of(context).primaryColor,
        Icons.sync,
        'Connecting...',
      ),
      PendantState.disconnected => (
        const Color(0xFF888888),
        Icons.bluetooth_disabled,
        'Not connected',
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (status.batteryPercent != null) ...[
            const Icon(
              Icons.battery_full,
              size: 15,
              color: Color(0xFF888888),
            ),
            const SizedBox(width: 4),
            Text(
              '${status.batteryPercent}%',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
