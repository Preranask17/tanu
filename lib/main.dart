import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'app.dart';
import 'providers/settings_provider.dart';
import 'services/proactive/digest_task.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Port for the foreground-service task handler to talk to the UI isolate.
  // Native-only: dart:isolate is unsupported on web.
  if (!kIsWeb) {
    FlutterForegroundTask.initCommunicationPort();
  }
  try {
    await StorageService.initialize();
  } catch (e) {
    debugPrint('[tanu] storage init failed: $e');
    runApp(const _StartupErrorApp());
    return;
  }

  // Morning digest worker (closed-app/killed/reboot-safe). Best effort:
  // failures keep the digest opportunistic instead of breaking launch.
  // Hour changes re-register via the settings setter.
  try {
    final stored = await _readDigestHour();
    unawaited(scheduleDigestWorker(digestHour: stored));
  } catch (e) {
    debugPrint('[tanu] digest schedule skipped: $e');
  }

  runApp(const ProviderScope(child: TanuApp()));
}

/// Digest hour persisted in settings (default 8am). Read raw so the worker
/// schedule never depends on providers at launch.
Future<int> _readDigestHour() async {
  try {
    final stored = Hive.box(Boxes.settings).get('settings');
    if (stored is Map) {
      return AppSettings.fromJson(Map<String, dynamic>.from(stored))
          .digestHour;
    }
  } catch (_) {}
  return 8;
}

/// Minimal fallback when local storage cannot start: a plain message
/// instead of a red screen. No backend involved.
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Tanu could not start its local storage.\nPlease restart the app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF888888), fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
