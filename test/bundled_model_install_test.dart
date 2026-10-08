import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanu_app/constants.dart';
import 'package:tanu_app/services/stt/model_download_coordinator.dart';

/// Exercises the coordinator's verified-bundle fast path: when every file the
/// recognizer needs is already on disk, [ModelDownloadCoordinator.ensure]
/// returns the tokens file without touching the network. Only the platform
/// boundary (app-support path) is mocked.
///
/// NOTE: the download/extract path is intentionally not exercised here — it
/// pulls the real ~375 MB remote bundle. The bundled-asset install described
/// in `assets/models/README.md` is not part of this coordinator.
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
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
    try {
      await scratch.delete(recursive: true);
    } catch (_) {}
  });

  /// Lays down a bundle that satisfies the coordinator's verification
  /// contract: every file in [kWhisperSmallBundleFiles] plus the Silero VAD
  /// model, all non-empty.
  void seedVerifiedBundle() {
    final dir = Directory('${scratch.path}/$kWhisperSmallDirName');
    dir.createSync(recursive: true);
    for (final f in kWhisperSmallBundleFiles) {
      File('${dir.path}/${f.name}').writeAsStringSync('stub');
    }
    File('${dir.path}/$kSileroVadFileName').writeAsStringSync('stub');
  }

  test('verified bundle resolves once; second call is a fast no-op',
      () async {
    seedVerifiedBundle();

    final events = <String>[];
    final first = await ModelDownloadCoordinator.ensure(
      onEvent: events.add,
    );
    expect(first, isNotNull, reason: 'fast-path install should succeed: $events');
    expect(first!.path.endsWith('tokens.txt'), isTrue);

    // Every file the recognizer loads must still be on disk and non-empty.
    for (final f in kWhisperSmallBundleFiles) {
      final file = File('${scratch.path}/$kWhisperSmallDirName/${f.name}');
      expect(file.existsSync(), isTrue, reason: '${f.name} missing');
      expect(file.lengthSync(), greaterThan(0));
    }
    final vad = File(
      '${scratch.path}/$kWhisperSmallDirName/$kSileroVadFileName',
    );
    expect(vad.existsSync(), isTrue);

    // Second call must hit the verified-dir fast path — no download events.
    final sw = Stopwatch()..start();
    final second = await ModelDownloadCoordinator.ensure();
    sw.stop();
    expect(second, isNotNull);
    expect(events, isEmpty, reason: 'fast path must not start a download');
    expect(
      sw.elapsedMilliseconds,
      lessThan(10000),
      reason: 'second ensure took ${sw.elapsedMilliseconds}ms (re-downloaded?)',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
