import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/ble_device.dart';

enum PendantState {
  disconnected,
  scanning,
  connecting,
  connected,
  reconnecting,
}

@immutable
class PendantStatus {
  const PendantStatus({
    this.state = PendantState.disconnected,
    this.batteryPercent,
    this.deviceName,
  });

  final PendantState state;
  final int? batteryPercent;
  final String? deviceName;

  bool get isConnected => state == PendantState.connected;

  PendantStatus copyWith({
    PendantState? state,
    int? batteryPercent,
    String? deviceName,
  }) {
    return PendantStatus(
      state: state ?? this.state,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      deviceName: deviceName ?? this.deviceName,
    );
  }
}

/// Live counters for debugging the audio path on a real pendant.
class PendantStats {
  const PendantStats({
    this.codecId,
    this.notifySubscribed = false,
    this.packets = 0,
    this.bytes = 0,
    this.frames = 0,
    this.decodeFailures = 0,
    this.lastError,
  });

  final int? codecId;
  final bool notifySubscribed;
  final int packets;
  final int bytes;
  final int frames;
  final int decodeFailures;
  final String? lastError;

  PendantStats copyWith({
    int? codecId,
    bool? notifySubscribed,
    int? packets,
    int? bytes,
    int? frames,
    int? decodeFailures,
    String? lastError,
  }) {
    return PendantStats(
      codecId: codecId ?? this.codecId,
      notifySubscribed: notifySubscribed ?? this.notifySubscribed,
      packets: packets ?? this.packets,
      bytes: bytes ?? this.bytes,
      frames: frames ?? this.frames,
      decodeFailures: decodeFailures ?? this.decodeFailures,
      lastError: lastError ?? this.lastError,
    );
  }

  String get codecLabel {
    if (codecId == null) return 'unknown';
    if (codecId == 20) return 'opus';
    if (codecId == 21) return 'opus 32k';
    if (codecId == 1) return 'pcm8';
    return 'codec $codecId';
  }
}

/// Source of audio from a physical pendant.
///
/// Only the BLE implementation exists today
/// ([BluetoothPendantSource]); a phone-microphone implementation can be
/// added behind this interface without touching anything else.
abstract class AudioSource {
  /// Stream of decoded PCM16 mono frames (16000 Hz).
  Stream<Uint8List> get audioFrames;

  /// Stream of complete utterances, segmented from the audio by silence.
  Stream<Uint8List> get utterances;

  /// Raw button events: byte value from the button characteristic (0 = short, 1 = long).
  Stream<int> get buttonEvents;

  /// Decoded PCM frames as a playable/recordable stream (all frames, not just utterances).
  Stream<Uint8List> get pcmAudio;

  /// Emits the current connection status and whenever it changes.
  Stream<PendantStatus> get statusStream;

  /// Devices seen while a scan is running, best signal first.
  Stream<List<DiscoveredDevice>> get discoveredDevices;

  /// Starts a Bluetooth scan that surfaces nearby devices on [discoveredDevices].
  /// Safe to call repeatedly; stops itself after a short grace period.
  Future<void> startScanForDevices();

  /// Stops the discovery scan if one is running.
  Future<void> stopScanForDevices();

  PendantStatus get currentStatus;

  /// Mutable current status for consumers that poll (battery etc.).
  ValueNotifier<PendantStatus> get statusNotifier;

  /// Live stats for debugging the audio path.
  ValueNotifier<PendantStats> get stats;

  /// Starts scanning and connecting to the pendant.
  /// [expectedName] is the BLE advertisement name to look for (firmware
  /// advertises "Omi" today; becomes "Tanu" once renamed).
  Future<void> connect({String? expectedName});

  /// Connects to a specific device chosen from the discovered list.
  /// The device id becomes the remembered pendant for next time.
  Future<void> connectToDevice(String remoteId);

  /// Drops the connection and stops listening.
  Future<void> disconnect();

  /// Forget the stored device id so the next connect() re-scans.
  Future<void> forgetDevice();
}