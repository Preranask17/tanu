import 'package:flutter/cupertino.dart';
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
          CupertinoColors.systemGreen.resolveFrom(context),
          CupertinoIcons.bluetooth,
          status.deviceName ?? 'Connected',
        ),
      PendantState.reconnecting => (CupertinoColors.systemOrange.resolveFrom(context), CupertinoIcons.arrow_2_circlepath, 'Reconnecting...'),
      PendantState.scanning => (CupertinoColors.activeBlue.resolveFrom(context), CupertinoIcons.antenna_radiowaves_left_right, 'Looking for pendant...'),
      PendantState.connecting => (CupertinoColors.activeBlue.resolveFrom(context), CupertinoIcons.arrow_2_circlepath, 'Connecting...'),
      PendantState.disconnected => (CupertinoColors.systemGrey.resolveFrom(context), CupertinoIcons.bluetooth, 'Not connected'),
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
            Icon(CupertinoIcons.battery_100, size: 15, color: CupertinoColors.systemGrey.resolveFrom(context)),
            const SizedBox(width: 4),
            Text('${status.batteryPercent}%', style: TextStyle(fontSize: 13, color: CupertinoColors.label.resolveFrom(context))),
          ],
        ],
      ),
    );
  }
}