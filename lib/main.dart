import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Port for the foreground-service task handler to talk to the UI isolate.
  FlutterForegroundTask.initCommunicationPort();
  await StorageService.initialize();

  runApp(
    const ProviderScope(
      child: TanuApp(),
    ),
  );
}