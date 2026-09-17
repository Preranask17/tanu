import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../abstractions/audio_source.dart';
import '../models/ble_device.dart';
import '../services/ble/bluetooth_pendant_source.dart';
import '../services/simulator_pendant_source.dart';

/// Set this to true to use your PC microphone as the pendant source for testing.
/// Be sure to set this back to false before committing!
const bool kUseSimulator = true;

/// Singleton pendant source. Its status is watched via [pendantStatusProvider].
final pendantProvider = Provider<AudioSource>((ref) {
  final source = kUseSimulator ? SimulatorPendantSource() : BluetoothPendantSource();
  ref.onDispose(source.dispose);
  return source;
});

final pendantStatusProvider = StreamProvider<PendantStatus>(
  (ref) => ref.watch(pendantProvider).statusStream,
);

/// Live audio-path stats for debugging on a real pendant.
final pendantStatsProvider = Provider<ValueNotifier<PendantStats>>(
  (ref) => ref.watch(pendantProvider).stats,
);

/// Devices found by an ongoing discovery scan, best signal first.
final discoveredDevicesProvider = StreamProvider<List<DiscoveredDevice>>(
  (ref) => ref.watch(pendantProvider).discoveredDevices,
);

/// Reconnect to the last chosen pendant, ignoring failures (the user can
/// still open the device picker afterwards).
final pendantReconnectProvider = Provider<void Function()>((ref) {
  final source = ref.watch(pendantProvider);
  return () {
    source.connect().catchError(
          (e) => debugPrint('[tanu] auto-reconnect failed: $e'),
        );
  };
});

/// Start a discovery scan. Errors (e.g. Bluetooth off) surface to the caller.
final startScanProvider = Provider<Future<void> Function()>((ref) {
  final source = ref.watch(pendantProvider);
  return source.startScanForDevices;
});

/// Stop the discovery scan.
final stopScanProvider = Provider<Future<void> Function()>((ref) {
  final source = ref.watch(pendantProvider);
  return source.stopScanForDevices;
});

/// Connect to a specific discovered device and remember it as the pendant.
final connectToDeviceProvider = Provider<Future<void> Function(String)>((ref) {
  final source = ref.watch(pendantProvider);
  return (remoteId) => source.connectToDevice(remoteId);
});

/// Forget the stored pendant device.
final pendantForgetProvider = Provider<void Function()>((ref) {
  final source = ref.watch(pendantProvider);
  return () {
    source.forgetDevice().catchError(
          (e) => debugPrint('[tanu] forget failed: $e'),
        );
  };
});