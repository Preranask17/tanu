import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanu_app/constants.dart';
import 'package:tanu_app/services/stt/model_download_coordinator.dart';

@Timeout(Duration(minutes: 10))

/// Exercises the real bundled-model install: APK asset bytes in,
/// verified model dir + version marker out. Mocks only the platform
/// boundaries (asset bundle, app-support path) — the coordinator,
/// BZip2 extraction and marker logic run for real.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory scratch;

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('tanu_model_test');

    // App-support path -> scratch dir (no real filesystem writes elsewhere).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        if (call.method == 'getApplicationSupportDirectory') {
          return scratch.path;
        }
        return null;
      },
    );

    // Asset bundle -> the real files from the repo (test cwd is package root).
    // NOTE: the 'flutter/assets' channel carries the raw UTF-8 asset key,
    // not a method-call envelope, and expects the raw bytes back.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
      if (message == null) return null;
      final key = utf8.decode(
        message.buffer.asUint8List(
          message.offsetInBytes,
          message.lengthInBytes,
        ),
      );
      final file = File(key);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        return ByteData.sublistView(bytes);
      }
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    try {
      await scratch.delete(recursive: true);
    } catch (_) {}
  });

  test('bundled model installs once; second call is a fast no-op', () async {
    final events = <String>[];
    final first = await ModelDownloadCoordinator.ensure(
      onEvent: events.add,
    );
    expect(first, isNotNull, reason: 'install should succeed: $events');
    expect(first!.path.endsWith('tokens.txt'), isTrue);

    final stem =
        kOfflineBundleFileName.replaceFirst('.tar.bz2', '');
    final dir = Directory('${scratch.path}/$stem');
    expect(File('${dir.path}/model.int8.onnx').existsSync(), isTrue);
    expect(File('${dir.path}/tokens.txt').existsSync(), isTrue);
    expect(File('${dir.path}/$kSileroVadFileName').existsSync(), isTrue);
    final marker = File('${scratch.path}/$stem.version');
    expect(marker.existsSync(), isTrue);
    expect(marker.readAsStringSync().trim(), kBundledModelVersion);
    // Staging archive is cleaned up to save ~155 MB.
    expect(
      File('${scratch.path}/$kOfflineBundleFileName').existsSync(),
      isFalse,
    );

    // Second call must hit the marker fast path — no re-copy.
    final sw = Stopwatch()..start();
    final second = await ModelDownloadCoordinator.ensure();
    sw.stop();
    expect(second, isNotNull);
    expect(
      sw.elapsedMilliseconds,
      lessThan(10000),
      reason: 'second ensure took ${sw.elapsedMilliseconds}ms (re-copied?)',
    );
  }, timeout: const Timeout(Duration(minutes: 10)));
}
