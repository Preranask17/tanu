import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../abstractions/audio_source.dart';
import '../providers/ble_provider.dart';
import '../theme.dart';

/// Compact strip showing pendant connection + battery across screens.
class ConnectionStatusBar extends ConsumerWidget {
  const ConnectionStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(pendantStatusProvider).value ?? PendantStatus();

    final (color, icon, text) = switch (status.state) {
      PendantState.connected => (
          kTanuGreen,
          Icons.bluetooth_connected,
          status.deviceName ?? 'Connected',
        ),
      PendantState.reconnecting => (kTanuWarm, Icons.sync, 'Reconnecting...'),
      PendantState.scanning => (kTanuWarm, Icons.radar, 'Looking for pendant...'),
      PendantState.connecting => (kTanuWarm, Icons.sync, 'Connecting...'),
      PendantState.disconnected => (kTanuRed, Icons.bluetooth_disabled, 'Not connected'),
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
              style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600),
            ),
          ),
          if (status.batteryPercent != null) ...[
            Icon(Icons.battery_full, size: 15, color: kTanuWarm),
            const SizedBox(width: 4),
            Text('${status.batteryPercent}%', style: const TextStyle(fontSize: 13)),
          ],
        ],
      ),
    );
  }
}