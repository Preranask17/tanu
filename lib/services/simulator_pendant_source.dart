import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../abstractions/audio_source.dart';
import '../models/ble_device.dart';

/// A simulator pendant that routes the PC/phone microphone through the
/// exact same audio path as a real hardware pendant.
class SimulatorPendantSource implements AudioSource {
  final _statusStreamCtrl = StreamController<PendantStatus>.broadcast();
  final _pcmAudioCtrl = StreamController<Uint8List>.broadcast();
  final _buttonEventsCtrl = StreamController<int>.broadcast();
  final _discoveredDevicesCtrl =
      StreamController<List<DiscoveredDevice>>.broadcast();

  final _status = ValueNotifier<PendantStatus>(const PendantStatus());
  final _stats = ValueNotifier<PendantStats>(
    const PendantStats(codecId: 1),
  ); // mock PCM codec

  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _micSub;

  @override
  Stream<Uint8List> get audioFrames => const Stream.empty();

  @override
  Stream<Uint8List> get utterances => const Stream.empty();

  @override
  Stream<int> get buttonEvents => _buttonEventsCtrl.stream;

  @override
  Stream<Uint8List> get pcmAudio => _pcmAudioCtrl.stream;

  @override
  Stream<PendantStatus> get statusStream => _statusStreamCtrl.stream;

  @override
  Stream<List<DiscoveredDevice>> get discoveredDevices =>
      _discoveredDevicesCtrl.stream;

  @override
  PendantStatus get currentStatus => _status.value;

  @override
  ValueNotifier<PendantStatus> get statusNotifier => _status;

  @override
  ValueNotifier<PendantStats> get stats => _stats;

  @override
  Future<void> startScanForDevices() async {
    _discoveredDevicesCtrl.add([
      const DiscoveredDevice(
        id: 'simulator-id',
        name: 'Tanu Simulator (PC Mic)',
        rssi: -40,
        isConnectable: true,
      ),
    ]);
  }

  @override
  Future<void> stopScanForDevices() async {}

  @override
  Future<void> connect({String? expectedName}) async {
    await connectToDevice('simulator-id');
  }

  @override
  Future<void> connectToDevice(String remoteId) async {
    _status.value = const PendantStatus(state: PendantState.connecting);
    _statusStreamCtrl.add(_status.value);

    await Future.delayed(const Duration(seconds: 1));

    _recorder = AudioRecorder();
    if (await _recorder!.hasPermission()) {
      final stream = await _recorder!.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      var remainder = <int>[];
      _micSub = stream.listen((chunk) {
        final allBytes = remainder.isEmpty
            ? chunk
            : Uint8List.fromList(remainder + chunk);
        final emitLength = allBytes.length - (allBytes.length % 2);

        if (emitLength > 0) {
          final emitChunk = Uint8List.sublistView(allBytes, 0, emitLength);
          _pcmAudioCtrl.add(emitChunk);
          _stats.value = _stats.value.copyWith(
            bytes: _stats.value.bytes + emitLength,
            packets: _stats.value.packets + 1,
          );
        }
        remainder = allBytes.sublist(emitLength);
      });

      _status.value = const PendantStatus(
        state: PendantState.connected,
        deviceName: 'Tanu Simulator',
        batteryPercent: 100,
      );
      _statusStreamCtrl.add(_status.value);
    } else {
      _status.value = const PendantStatus(state: PendantState.disconnected);
      _statusStreamCtrl.add(_status.value);
      debugPrint('[tanu_simulator] Mic permission denied.');
    }
  }

  @override
  Future<void> disconnect() async {
    await _micSub?.cancel();
    _micSub = null;
    await _recorder?.stop();
    await _recorder?.dispose();
    _recorder = null;

    _status.value = const PendantStatus(state: PendantState.disconnected);
    _statusStreamCtrl.add(_status.value);
  }

  @override
  Future<void> forgetDevice() async {
    await disconnect();
  }

  @override
  void dispose() {
    disconnect();
    _statusStreamCtrl.close();
    _pcmAudioCtrl.close();
    _buttonEventsCtrl.close();
    _discoveredDevicesCtrl.close();
    _status.dispose();
    _stats.dispose();
  }
}
