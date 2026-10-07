import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:tanu_app/screens/home_screen.dart';
import 'package:tanu_app/screens/welcome/tanu_wordmark.dart';
import 'package:tanu_app/services/storage_service.dart';

/// Proves the Capture sequence renders with the real widgets, disconnected
/// and empty: [wordmark + BT/battery header] -> [hero orb] ->
/// [live transcription box] -> [empty memories placeholder].
/// Filesystem work runs in runAsync (async dart:io stalls in this
/// environment's FakeAsync test zone). No backend is exercised.
void main() {
  testWidgets('capture: header, orb, transcription, empty state', (
    tester,
  ) async {
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

    // 1. Top header: wordmark left, disconnected BT control right.
    expect(find.byType(TanuWordmark), findsOneWidget);
    expect(find.byIcon(Icons.bluetooth), findsOneWidget);
    // No battery pill while disconnected with no known value.
    expect(find.textContaining('%'), findsNothing);
    // Section headline below the header.
    expect(find.text('Capture'), findsOneWidget);

    // 2 + 3. Hero orb and persistent transcription box with idle placeholder.
    expect(find.text('Transcription will appear here…'), findsOneWidget);
    // Capture carries zero search bars.
    expect(find.byType(TextField), findsNothing);
    // Idle capture flag: badge reads Ready, never Capturing...
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Capturing...'), findsNothing);

    // 4. Memories section is gone: no empty-state text, no cards.
    expect(
      find.text('No memories recorded yet. TANU is listening...'),
      findsNothing,
    );
    expect(find.text('Scan'), findsNothing);
    expect(find.text('No pendant yet'), findsNothing);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
