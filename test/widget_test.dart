import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tanu_app/abstractions/audio_source.dart';
import 'package:tanu_app/abstractions/stt_engine.dart';
import 'package:tanu_app/app.dart';
import 'package:tanu_app/models/ble_device.dart';
import 'package:tanu_app/providers/ble_provider.dart';
import 'package:tanu_app/providers/conversation_provider.dart';
import 'package:tanu_app/services/storage_service.dart';

void main() {
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('tanu_test');
    await StorageService.initialize(overridePath: dir.path);
  });

  tearDownAll(() async {
    await StorageService.clearAll();
  });

  testWidgets('Tanu app renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pendantProvider.overrideWithValue(FakeAudioSource()),
          // Stub the recognizer so the smoke test never opens a real Deepgram
          // websocket (a pending 10s connect timer that would trip the "no
          // pending timers" assertion at teardown). A no-op engine keeps the
          // tree timer-free and the test fully hermetic.
          sttEngineProvider.overrideWithValue(FakeSttEngine()),
        ],
        child: const TanuApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Not connected'), findsWidgets);
    expect(find.text('Conversations'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });
}

class FakeSttEngine implements ContinuousSttEngine {
  final _warmingUp = ValueNotifier<bool>(false);

  @override
  ValueListenable<bool> get warmingUp => _warmingUp;

  @override
  bool get hasActiveUtterance => false;

  @override
  String get modelLabel => 'Fake';

  @override
  Future<bool> startContinuous(
    Stream<Uint8List> chunks, {
    required void Function(String) onUtterance,
    void Function(String partial)? onPartial,
    void Function(double level)? onMicLevel,
    void Function(String event)? onEvent,
  }) async => true;

  @override
  Future<void> stopContinuous() async {}

  @override
  Future<String> transcribe(
    Uint8List pcmUtterance, {
    SttCallbacks? callbacks,
  }) async => '';

  @override
  Future<String> transcribeMic({SttCallbacks? callbacks}) async => '';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> stop() async {}
}

class FakeAudioSource implements AudioSource {
  final _status = ValueNotifier(
    const PendantStatus(
      state: PendantState.connected,
      batteryPercent: 90,
      deviceName: 'Omi',
    ),
  );
  final _button = StreamController<int>.broadcast();
  final _utterances = StreamController<Uint8List>.broadcast();
  final _frames = StreamController<Uint8List>.broadcast();
  final _pcm = StreamController<Uint8List>.broadcast();
  final _statusStream = StreamController<PendantStatus>.broadcast();
  final _devices = StreamController<List<DiscoveredDevice>>.broadcast();
  final _stats = ValueNotifier(
    const PendantStats(codecId: 20, notifySubscribed: true),
  );

  @override
  Stream<Uint8List> get audioFrames => _frames.stream;

  @override
  Stream<int> get buttonEvents => _button.stream;

  @override
  Future<void> connect({String? expectedName}) async {}

  @override
  Future<void> connectToDevice(String remoteId) async {}

  @override
  PendantStatus get currentStatus => _status.value;

  @override
  Future<void> disconnect() async {}

  @override
  Stream<List<DiscoveredDevice>> get discoveredDevices => _devices.stream;

  @override
  Future<void> forgetDevice() async {}

  @override
  Stream<Uint8List> get pcmAudio => _pcm.stream;

  @override
  Future<void> startScanForDevices() async {}

  @override
  Future<void> stopScanForDevices() async {}

  @override
  ValueNotifier<PendantStatus> get statusNotifier => _status;

  @override
  ValueNotifier<PendantStats> get stats => _stats;

  @override
  Stream<PendantStatus> get statusStream => _statusStream.stream;

  @override
  Stream<Uint8List> get utterances => _utterances.stream;

  @override
  void dispose() {}
}
