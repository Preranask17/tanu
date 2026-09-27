import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/analytics/analytics_service.dart';
import 'ble_provider.dart';

final analyticsProvider = Provider<AnalyticsService>((ref) {
  final analytics = AnalyticsService();
  ref.onDispose(() => unawaited(analytics.close()));
  unawaited(analytics.init());

  // Pendant connect/disconnect. This mirrors the one provider-to-provider
  // reactive edge in `conversationProvider`: the status is a stream, not state,
  // so it is observed here rather than watched into this provider's value.
  DateTime? connectedAt;
  ref.listen(pendantStatusProvider, (prev, next) {
    final status = next.value;
    if (status == null) return;
    if (status.isConnected) {
      if (connectedAt != null) return;
      connectedAt = DateTime.now();
      analytics.capture(
        'pendant connected',
        properties: {
          'battery_pct': status.batteryPercent,
          // Codec label only ("opus" / "pcm8") — never a device name or id.
          'codec': ref.read(pendantStatsProvider).value.codecLabel,
        },
      );
    } else if (connectedAt != null) {
      final seconds =
          DateTime.now().difference(connectedAt!).inMilliseconds ~/ 1000;
      connectedAt = null;
      analytics.capture(
        'pendant disconnected',
        properties: {'connected_for_s': seconds, 'state': status.state.name},
      );
    }
  });

  return analytics;
});
