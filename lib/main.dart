import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Port for the foreground-service task handler to talk to the UI isolate.
  // Native-only: dart:isolate is unsupported on web.
  if (!kIsWeb) {
    FlutterForegroundTask.initCommunicationPort();
  }
  await StorageService.initialize();

  runApp(const ProviderScope(child: TanuApp()));
}
