import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:tanu_app/screens/settings_screen.dart';
import 'package:tanu_app/services/storage_service.dart';

/// Proves the compact two-card Settings layout and the heavy sections'
/// sub-views: the console lives in a fast sheet instead of expanding inline,
/// its close action dismisses cleanly, and the bottom row clears any nav
/// overlay. Filesystem work runs in runAsync (async dart:io stalls in this
/// environment's FakeAsync test zone). No backend is exercised.
void main() {
  testWidgets('settings: compact groups and sheet console', (tester) async {
    await tester.runAsync(() async {
      final scratch = await Directory.systemTemp.createTemp('tanu_settings');
      Hive.init(scratch.path);
      await Hive.openBox(Boxes.settings);
      await Hive.openBox(Boxes.commitments);
      await Hive.openBox(Boxes.conversation);
    });

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Two compact group cards replace the six separate sections.
    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('System & AI'), findsOneWidget);

    // The complex controls are not dumped on the main settings page.
    expect(find.textContaining('DEV CONSOLE'), findsNothing);
    expect(find.text('Download Offline Model (~375MB)'), findsNothing);
    expect(find.text("WIPE TANU'S MEMORY"), findsNothing);

    // Scroll to the last action row and open its sub-view.
    await tester.scrollUntilVisible(
      find.text('Under the Hood'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Under the Hood'), findsOneWidget);

    await tester.tap(find.text('Under the Hood'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('DEV CONSOLE'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Drag the sheet to its end: completes without layout exceptions and
    // the diagnostics remain reachable.
    await tester.fling(
      find.byType(Scrollable).last,
      const Offset(0, -500),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('DEV CONSOLE'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // The fixed header keeps a clear close action available after scrolling.
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('DEV CONSOLE'), findsNothing);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
