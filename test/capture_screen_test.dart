import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:tanu_app/screens/home_screen.dart';
import 'package:tanu_app/services/storage_service.dart';
import 'package:tanu_app/widgets/waveform_visualizer.dart';

/// Proves the Home wireframe renders with the real widgets, disconnected:
/// [TANU + Home | pendant pill] -> [waveform] -> [Today timeline].
/// Filesystem work runs in runAsync (async dart:io stalls in this
/// environment's FakeAsync test zone). No backend is exercised.
void main() {
  testWidgets('home: header, waveform, today feed', (tester) async {
    await tester.runAsync(() async {
      final scratch = await Directory.systemTemp.createTemp('tanu_capture');
      Hive.init(scratch.path);
      await Hive.openBox(Boxes.settings);
      await Hive.openBox(Boxes.commitments);
      await Hive.openBox(Boxes.conversation);
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 1. Shared header: TANU mark + Home title, compact pendant pill right.
    expect(find.text('TANU'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.byIcon(Icons.bluetooth_rounded), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    // No battery percentage while disconnected.
    expect(find.textContaining('%'), findsNothing);

    // 2. Waveform directly follows the header stack; no live banner when idle.
    expect(find.byType(WaveformVisualizer), findsOneWidget);
    expect(find.text('Live Conversation'), findsNothing);

    // 3. Today timeline section is always present.
    expect(find.text('Today'), findsOneWidget);

    // Home carries zero search bars and no legacy capture controls.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Capture'), findsNothing);
    expect(find.text('Scan'), findsNothing);
    expect(find.text('No pendant yet'), findsNothing);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
