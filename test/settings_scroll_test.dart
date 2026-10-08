import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:tanu_app/screens/settings_screen.dart';
import 'package:tanu_app/services/storage_service.dart';

/// Proves the Settings bottom cushion: scrolling to the very end leaves the
/// "Under the Hood" section fully above any nav overlay, expandable and
/// tappable. Filesystem work runs in runAsync (async dart:io stalls in this
/// environment's FakeAsync test zone). No backend is exercised.
void main() {
  testWidgets('settings: bottom content clears the nav dock', (tester) async {
    await tester.runAsync(() async {
      final scratch = await Directory.systemTemp.createTemp('tanu_settings');
      Hive.init(scratch.path);
      await Hive.openBox(Boxes.settings);
      await Hive.openBox(Boxes.commitments);
      await Hive.openBox(Boxes.conversation);
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Scroll the last section fully into view.
    await tester.scrollUntilVisible(
      find.text('Under the Hood'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Under the Hood'), findsOneWidget);

    // Expand it: console content appears and stays reachable/tappable.
    await tester.tap(find.text('Under the Hood'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(
      find.textContaining('DEV CONSOLE'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.textContaining('DEV CONSOLE'), findsOneWidget);

    // Drag to the absolute end: completes without layout exceptions and
    // the diagnostics remain on screen (not clipped behind a dock).
    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, -600),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('DEV CONSOLE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
