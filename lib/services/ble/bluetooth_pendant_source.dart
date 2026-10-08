import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../abstractions/audio_source.dart';
import '../../models/ble_device.dart';
import '../storage_service.dart';
import 'omi_reassembler.dart';
import 'opus_decoder.dart';

/// The only AudioSource implementation today: a BLE pendant streaming Opus.
///
/// Borrows Omi's DevKit GATT layout and the packet framing
/// `[packet_index:2 LE][frame_id:1][payload]`, but keeps the whole connection
/// lifecycle in Dart (no native split like Omi's — acceptable for the MVP).
class BluetoothPendantSource implements AudioSource {
  BluetoothPendantSource({void Function(String)? log})
    : _log = log ?? debugPrint {
    _storedDeviceId = _readStoredDeviceId();
  }

  final void Function(String) _log;

  // ---- state ----
  final ValueNotifier<PendantStatus> _status = ValueNotifier(
    const PendantStatus(),
  );
  final ValueNotifier<PendantStats> _stats = ValueNotifier(
    const PendantStats(),
  );
  final StreamController<PendantStatus> _statusController =
      StreamController<PendantStatus>.broadcast();
  final StreamController<List<DiscoveredDevice>> _devicesController =
      StreamController<List<DiscoveredDevice>>.broadcast();

  String? _storedDeviceId;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _audioChar;
  BluetoothCharacteristic? _buttonChar;
  BluetoothCharacteristic? _batteryLevelChar;

  StreamSubscription<List<int>>? _audioSub;
  StreamSubscription<List<int>>? _buttonSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  Timer? _batteryTimer;

  // discovery
  final Map<String, DiscoveredDevice> _devices = {};
  StreamSubscription<List<ScanResult>>? _scanResultsSub;
  Timer? _scanAutoStop;
  static const int _maxDiscoveredDevices = 30;

  // audio pipeline
  final StreamController<Uint8List> _audioFrames =
      StreamController<Uint8List>.broadcast(sync: true);
  final StreamController<Uint8List> _utterances =
      StreamController<Uint8List>.broadcast();
  final StreamController<Uint8List> _pcmAudio =
      StreamController<Uint8List>.broadcast(sync: true);
  final StreamController<int> _buttonEvents = StreamController<int>.broadcast();

  OpusDecoder? _decoder;

  // opus framing / reassembly
  // Omi firmware frame boundary = the 2-byte packet_index in the header
  // `[packet_index:2 LE][chunk_index:1][payload]`. chunk_index only splits one
  // packet across notifications when it exceeds `mtu - 3`; at large MTU it is
  // always 0, so grouping by it never flushes. Group by packet_index instead.
  late final OmiReassembler _reassembler = OmiReassembler(
    onPacket: _onReassembled,
  );
  int _framesDecoded = 0;
  int? _codecId;

  // segmentation
  final List<int> _utteranceBuffer = [];
  int _silentFrames = 0;
  static const int _silenceFrameThreshold = 12; // ~0.75s of silence
  static const int _maxUtteranceBytes = 16000 * 2 * 30; // 30s cap

  bool _manualDisconnect = false;
  bool _reconnecting = false;
  Timer? _reconnectTimer;
  bool _connectInProgress = false;

  @override
  Stream<Uint8List> get audioFrames => _audioFrames.stream;

  @override
  Stream<Uint8List> get utterances => _utterances.stream;

  @override
  Stream<Uint8List> get pcmAudio => _pcmAudio.stream;

  @override
  Stream<int> get buttonEvents => _buttonEvents.stream;

  @override
  Stream<PendantStatus> get statusStream => _statusController.stream;

  @override
  Stream<List<DiscoveredDevice>> get discoveredDevices =>
      _devicesController.stream;

  @override
  ValueNotifier<PendantStatus> get statusNotifier => _status;

  @override
  PendantStatus get currentStatus => _status.value;

  @override
  ValueNotifier<PendantStats> get stats => _stats;

  void _setStats(PendantStats Function(PendantStats) update) {
    _stats.value = update(_stats.value);
  }

  // ---------------------------------------------------------------------------

  /// Reconnects to the last chosen pendant. Throws if none was picked yet —
  /// the UI should then offer the device picker instead.
  @override
  Future<void> connect({String? expectedName}) async {
    if (_device != null && _device!.isConnected) {
      _log('[tanu] already connected');
      return;
    }
    final stored = _storedDeviceId;
    if (stored == null) {
      throw StateError('No pendant chosen yet — scan and pick one');
    }
    _manualDisconnect = false;
    _reconnecting = false;
    await _connectKnown(stored);
  }

  /// Connects to a device the user picked from the discovery list and
  /// remembers it as the pendant for next time.
  @override
  Future<void> connectToDevice(String remoteId) async {
    await stopScanForDevices();

    _manualDisconnect = false;
    _reconnecting = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    final current = _device;
    if (current != null && current.isConnected) {
      try {
        await current.disconnect();
      } catch (e) {
        _log('[tanu] dropping old connection: $e');
      }
    }
    await _teardownSubscriptions();
    _device = null;

    _rememberDevice(remoteId);
    try {
      await _connectKnown(remoteId);
    } catch (e) {
      _log('[tanu] connect to $remoteId failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _teardownSubscriptions();
    final device = _device;
    _device = null;
    if (device != null) {
      try {
        await device.disconnect();
      } catch (e) {
        _log('[tanu] disconnect error: $e');
      }
    }
    _setState(PendantState.disconnected, clearBattery: true, clearName: true);
    _stats.value = const PendantStats();
  }

  @override
  Future<void> forgetDevice() async {
    await disconnect();
    _forgetStoredDevice();
  }

  Future<void> _connectKnown(String remoteId) async {
    final adapter = FlutterBluePlus.adapterStateNow;
    if (adapter == BluetoothAdapterState.off) {
      _setState(
        PendantState.disconnected,
        clearBattery: true,
        clearName: true,
      );
      throw StateError('Bluetooth is off');
    }

    if (_connectInProgress) {
      _log('[tanu] connection attempt already in progress');
      return;
    }

    _connectInProgress = true;
    final device = BluetoothDevice(remoteId: DeviceIdentifier(remoteId));
    _device = device;
    _watchConnection(device);
    _setState(PendantState.connecting);

    try {
      try {
        if (device.isConnected) {
          _log('[tanu] device is already connected; configuring it');
        } else {
          await device.connect(
            license: License.nonprofit,
            timeout: const Duration(seconds: 35),
          );
        }
      } catch (e) {
        // Some platforms report an "already connected" error even though the
        // device is usable. Continue setup when the native connection is alive.
        if (!device.isConnected) {
          _setState(
            PendantState.disconnected,
            clearBattery: true,
            clearName: true,
          );
          rethrow;
        }
        _log('[tanu] connect reported an error but the device is connected: $e');
      }

      try {
        await _setupPendant(device);
      } catch (e) {
        _log('[tanu] setup failed, disconnecting: $e');
        try {
          await device.disconnect();
        } catch (_) {}
        _setState(
          PendantState.disconnected,
          clearBattery: true,
          clearName: true,
        );
        rethrow;
      }

      _startBatteryPolling();
      _setState(PendantState.connected, name: device.platformName);
      _log('[tanu] connected to ${device.platformName}');
    } finally {
      _connectInProgress = false;
    }
  }

  // ---- discovery ----

  /// Scans for nearby BLE devices of any kind. Results land on
  /// [discoveredDevices], best signal first, deduped by MAC.
  @override
  Future<void> startScanForDevices() async {
    if (FlutterBluePlus.isScanningNow) {
      await stopScanForDevices();
    }

    // Ensure the Bluetooth adapter is on and permissions are granted.
    // On Android 9 (Oppo A9, etc.) this is required before scanning.
    try {
      if (await FlutterBluePlus.isSupported == false) {
        throw Exception('Bluetooth is not supported on this device');
      }

      // Wait for adapter to be on (up to 5 seconds)
      final adapterState = await FlutterBluePlus.adapterState
          .where((s) => s == BluetoothAdapterState.on)
          .first
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw Exception(
                'Bluetooth is off. Please turn on Bluetooth in Settings.',
              );
            },
          );
      _log('[tanu] adapter state: $adapterState');
    } catch (e) {
      _log('[tanu] adapter/permission check failed: $e');
      rethrow;
    }

    _scanAutoStop?.cancel();
    _scanAutoStop = Timer(const Duration(seconds: 20), stopScanForDevices);

    _scanResultsSub?.cancel();
    _scanResultsSub = FlutterBluePlus.onScanResults.listen(_onScanResults);

    _devices.clear();

    // Include already-connected system devices (e.g. if paired in Windows settings)
    try {
      final systemDevices = await FlutterBluePlus.systemDevices([]);
      for (final d in systemDevices) {
        _devices[d.remoteId.str] = DiscoveredDevice(
          id: d.remoteId.str,
          name: d.platformName,
          rssi: 0,
          isConnectable: true,
        );
      }
    } catch (e) {
      _log('[tanu] systemDevices error: $e');
    }

    _emitDevices();
    await FlutterBluePlus.startScan(
      continuousUpdates: true,
      continuousDivisor: 2, // emit every 2nd update to balance speed/perf
    );
    _log('[tanu] device scan started');
  }

  @override
  Future<void> stopScanForDevices() async {
    _scanAutoStop?.cancel();
    _scanAutoStop = null;
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
    await _scanResultsSub?.cancel();
    _scanResultsSub = null;
    _log('[tanu] device scan stopped');
  }

  void _onScanResults(List<ScanResult> results) {
    for (final r in results) {
      final id = r.device.remoteId.str;
      final existing = _devices[id];
      final name = r.device.advName;
      final candidate = DiscoveredDevice(
        id: id,
        name: name,
        rssi: r.rssi,
        isConnectable: r.advertisementData.connectable,
      );
      final shouldReplace =
          existing == null ||
          candidate.rssi > existing.rssi ||
          (name.isNotEmpty && existing.name.isEmpty) ||
          candidate.isConnectable != existing.isConnectable;
      if (shouldReplace) {
        _devices[id] = candidate;
      }
    }
    _emitDevices();
  }

  void _emitDevices() {
    if (_devicesController.isClosed) return;
    final sorted = _devices.values.toList()
      ..removeWhere((d) => !d.isConnectable);
    sorted.sort((a, b) {
      final byRssi = b.rssi.compareTo(a.rssi);
      if (byRssi != 0) return byRssi;
      return a.displayName.compareTo(b.displayName);
    });
    _devicesController.add(sorted.take(_maxDiscoveredDevices).toList());
  }

  // ---- stored device (remember the pendant across launches) ----

  String? _readStoredDeviceId() {
    try {
      return Hive.box(Boxes.settings).get('storedDeviceId') as String?;
    } catch (e) {
      _log('[tanu] could not read stored device id: $e');
      return null;
    }
  }

  void _rememberDevice(String id) {
    _storedDeviceId = id;
    try {
      Hive.box(Boxes.settings).put('storedDeviceId', id);
    } catch (e) {
      _log('[tanu] could not persist device id: $e');
    }
  }

  void _forgetStoredDevice() {
    _storedDeviceId = null;
    try {
      Hive.box(Boxes.settings).delete('storedDeviceId');
    } catch (e) {
      _log('[tanu] could not clear stored device id: $e');
    }
  }

  Future<void> _setupPendant(BluetoothDevice device) async {
    final services = await device.discoverServices();

    BluetoothCharacteristic? findChar(String serviceUuid, String charUuid) {
      for (final s in services) {
        if (s.uuid.str128.toLowerCase() == serviceUuid.toLowerCase()) {
          for (final c in s.characteristics) {
            if (c.uuid.str128.toLowerCase() == charUuid.toLowerCase()) {
              return c;
            }
          }
        }
      }
      return null;
    }

    final audioChar = findChar(
      '19B10000-E8F2-537E-4F6C-D104768A1214',
      '19B10001-E8F2-537E-4F6C-D104768A1214',
    );
    final buttonChar = findChar(
      '19B10000-E8F2-537E-4F6C-D104768A1214',
      '19B10003-E8F2-537E-4F6C-D104768A1214',
    );
    final codecChar = findChar(
      '19B10000-E8F2-537E-4F6C-D104768A1214',
      '19B10002-E8F2-537E-4F6C-D104768A1214',
    );
    final batteryLevelChar = findChar(
      '0000180F-0000-1000-8000-00805F9B34FB',
      '00002A19-0000-1000-8000-00805F9B34FB',
    );

    if (audioChar == null) {
      throw StateError('Pendant did not expose the audio characteristic');
    }

    _audioChar = audioChar;
    _buttonChar = buttonChar;
    _batteryLevelChar = batteryLevelChar;

    // Read the negotiated codec. DevKit firmware exposes it read-only and it is
    // always 20 (Opus, 10 ms CELT). 21 = opusFS320, 1 = pcm8 (fallbacks).
    if (codecChar != null) {
      try {
        final value = await codecChar.read();
        _codecId = value.isEmpty ? null : value.first;
        _log('[tanu] codec char read: $_codecId');
      } catch (e) {
        _codecId = 20;
        _log('[tanu] codec read failed, assuming opus(20): $e');
      }
    } else {
      _codecId = 20;
      _log('[tanu] no codec characteristic, assuming opus(20)');
    }
    _log('[tanu] final codec id: $_codecId');
    _setStats((s) => s.copyWith(codecId: _codecId));

    _decoder ??= await OpusDecoder.instance;

    await _subscribeCharacteristics();
  }

  Future<void> _subscribeCharacteristics() async {
    await _audioSub?.cancel();
    await _buttonSub?.cancel();

    final audioChar = _audioChar;
    final buttonChar = _buttonChar;

    if (audioChar != null) {
      try {
        await audioChar.setNotifyValue(true);
        _audioSub = audioChar.onValueReceived.listen(_onAudioPacket);
        _setStats((s) => s.copyWith(notifySubscribed: true));
        _log('[tanu] subscribed to audio (${audioChar.properties})');
      } catch (e) {
        _setStats((s) => s.copyWith(lastError: 'notify: $e'));
        _log('[tanu] audio notify failure: $e');
        rethrow;
      }
    }

    if (buttonChar != null) {
      try {
        await buttonChar.setNotifyValue(true);
        _buttonSub = buttonChar.onValueReceived.listen(_onButtonPacket);
        _log('[tanu] subscribed to button events');
      } catch (e) {
        _log('[tanu] button characteristic not notifiable/busy, skipping: $e');
      }
    }
  }

  void _onButtonPacket(List<int> value) {
    if (value.isEmpty) return;
    final byte = value.first;
    _buttonEvents.add(byte);
    _log('[tanu] button event: $byte');
  }

  void _onAudioPacket(List<int> value) {
    try {
      final bytes = Uint8List.fromList(value);
      _diagnose(bytes);
      _reassembleAndDecode(bytes);
    } catch (e) {
      _log('[tanu] audio packet error: $e');
    }
  }

  // Debug helpers for the packet path (writes a few samples so we can see what
  // the firmware actually sends).
  int _packetCount = 0;
  int _receivedBytes = 0;
  final Stopwatch _lastStatsEmit = Stopwatch()..start();

  void _diagnose(Uint8List packet) {
    _packetCount++;
    _receivedBytes += packet.length;
    // Accumulate counters but notify listeners at most ~4x/sec; per-packet
    // notifies were rebuilding widgets on the main isolate ~40x/sec.
    if (_lastStatsEmit.elapsedMilliseconds >= 250) {
      _lastStatsEmit.reset();
      _setStats(
        (s) => s.copyWith(packets: _packetCount, bytes: _receivedBytes),
      );
    }
    if (_packetCount <= 3) {
      final head = packet
          .take(16)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      _log('[tanu] pkt#$_packetCount len=${packet.length} head=[$head]');
    }
    if (_packetCount % 2000 == 0) {
      _log('[tanu] rx bytes=$_receivedBytes packets=$_packetCount');
    }
  }

  void _reassembleAndDecode(Uint8List packet) {
    _reassembler.add(packet);
  }

  /// A complete Opus packet was reassembled from BLE notifications.
  void _onReassembled(Uint8List frame) {
    _framesDecoded++;
    _setStats((s) => s.copyWith(frames: _framesDecoded));
    _onOpusFrame(frame);
  }

  void _onOpusFrame(Uint8List opusFrame) {
    // Codec 1 = pcm8: raw 8-bit samples, no Opus. Expand to 16-bit 16 kHz PCM.
    if (_codecId == 1) {
      final pcm = _expandPcm8(opusFrame);
      _audioFrames.add(pcm);
      _pcmAudio.add(pcm);
      _segment(pcm);
      return;
    }

    final decoder = _decoder;
    if (decoder == null) return;

    Uint8List pcm;
    try {
      pcm = decoder.decode(opusFrame);
    } catch (e) {
      _setStats(
        (s) => s.copyWith(
          decodeFailures: s.decodeFailures + 1,
          lastError: 'decode: $e',
        ),
      );
      if (_packetCount <= 8) {
        _log('[tanu] opus decode failed (${opusFrame.length} bytes): $e');
      }
      return;
    }
    _audioFrames.add(pcm);
    _pcmAudio.add(pcm);
    _segment(pcm);
  }

  /// pcm8 -> PCM16 mono at 16 kHz (doubles the sample rate, keeps timing).
  Uint8List _expandPcm8(Uint8List raw) {
    final out = Uint8List(raw.length * 4);
    final bd = ByteData.view(out.buffer);
    for (int i = 0; i < raw.length; i++) {
      final s = (raw[i] - 128) << 8; // unsigned 8-bit -> signed 16-bit
      bd.setInt16(i * 4, s, Endian.little); // original sample
      bd.setInt16(i * 4 + 2, s, Endian.little); // duplicated at 2x rate
    }
    return out;
  }

  // ---- silence-based segmentation ----

  void _segment(Uint8List pcmBytes) {
    final amplitude = _frameAmplitude(pcmBytes);

    if (amplitude < 500) {
      _silentFrames++;
    } else {
      _silentFrames = 0;
    }

    _utteranceBuffer.addAll(pcmBytes);

    // Cap utterance length even with continuous speech.
    if (_utteranceBuffer.length >= _maxUtteranceBytes) {
      _emitUtterance();
    }

    // Emit after a sustained run of silence frames.
    if (_silenceReached() && _utteranceBuffer.isNotEmpty) {
      _emitUtterance();
    }

    // Speech onset (after silence) — the interesting point to watch.
    if (amplitude >= 500 && _silentFrames > 0) {
      _log('[tanu] speech onset amp=$amplitude');
    }
  }

  bool _silenceReached() => _silentFrames >= _silenceFrameThreshold;

  int _frameAmplitude(Uint8List bytes) {
    int maxAmp = 0;
    final bd = ByteData.sublistView(bytes);
    for (int i = 0; i < bytes.length; i += 2) {
      final sample = bd.getInt16(i, Endian.little);
      final abs = sample < 0 ? -sample : sample;
      if (abs > maxAmp) maxAmp = abs;
    }
    return maxAmp;
  }

  void _emitUtterance() {
    if (_utteranceBuffer.isEmpty) {
      _silentFrames = 0;
      return;
    }
    final utterance = Uint8List.fromList(_utteranceBuffer);
    _utteranceBuffer.clear();
    _silentFrames = 0;
    _log(
      '[tanu] utterance emitted: ${(utterance.length / 2 / 16000).toStringAsFixed(2)}s',
    );
    if (!_utterances.isClosed) {
      _utterances.add(utterance);
    }
  }

  // ---- battery ----

  void _startBatteryPolling() {
    _readBattery();
    _batteryTimer ??= Timer.periodic(
      const Duration(seconds: 60),
      (_) => _readBattery(),
    );
  }

  Future<void> _readBattery() async {
    final char = _batteryLevelChar;
    if (char == null) return;
    try {
      final value = await char.read();
      if (value.isNotEmpty) {
        _setState(PendantState.connected, battery: value.first);
      }
    } catch (e) {
      _log('[tanu] battery read failed: $e');
    }
  }

  // ---- reconnect ----

  void _watchConnection(BluetoothDevice device) {
    _connSub?.cancel();
    _connSub = device.connectionState.listen((state) {
      _log('[tanu] connection state: $state');
      // flutter_blue_plus emits the current state immediately when the
      // subscription starts. Ignore that initial disconnected value while
      // connect()/service discovery is still in progress.
      if (_connectInProgress) return;

      if (state == BluetoothConnectionState.disconnected) {
        _reassembler.reset();
        _utteranceBuffer.clear();
        _silentFrames = 0;

        if (_manualDisconnect) {
          _setState(
            PendantState.disconnected,
            clearBattery: true,
            clearName: true,
          );
          return;
        }

        _setState(PendantState.reconnecting);
        _reconnecting = true;
        _reconnectTimer?.cancel();
        _reconnectTimer = Timer(const Duration(seconds: 2), () async {
          _reconnectTimer = null;
          if (_reconnecting && !_manualDisconnect) {
            if (FlutterBluePlus.adapterStateNow == BluetoothAdapterState.off) {
              _log('[tanu] Bluetooth is off; waiting for the user to enable it');
              _reconnecting = false;
              _setState(
                PendantState.disconnected,
                clearBattery: true,
                clearName: true,
              );
              return;
            }
            _log('[tanu] attempting reconnect...');
            try {
              await connect();
            } catch (e) {
              _log('[tanu] reconnect failed: $e');
              _setState(
                PendantState.disconnected,
                clearBattery: true,
                clearName: true,
              );
            }
          }
        });
      }
    });
  }

  // ---- helpers ----

  void _setState(
    PendantState state, {
    int? battery,
    String? name,
    bool clearBattery = false,
    bool clearName = false,
  }) {
    _status.value = _status.value.copyWith(
      state: state,
      batteryPercent: battery,
      deviceName: name,
      clearBatteryPercent: clearBattery,
      clearDeviceName: clearName,
    );
    if (!_statusController.isClosed) {
      _statusController.add(_status.value);
    }
  }

  Future<void> _teardownSubscriptions() async {
    _reconnecting = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _audioSub?.cancel();
    await _buttonSub?.cancel();
    await _connSub?.cancel();
    _batteryTimer?.cancel();
    _batteryTimer = null;
    _audioSub = null;
    _buttonSub = null;
    _connSub = null;
    // Flush whichever Opus packet was in flight so we don't lose its tail.
    _reassembler.flush();
    _reassembler.reset();
  }

  @override
  void dispose() {
    _teardownSubscriptions();
    _scanAutoStop?.cancel();
    _scanResultsSub?.cancel();
    _audioFrames.close();
    _utterances.close();
    _pcmAudio.close();
    _buttonEvents.close();
    _statusController.close();
    _devicesController.close();
    _decoder?.dispose();
    _status.dispose();
    _stats.dispose();
  }
}
