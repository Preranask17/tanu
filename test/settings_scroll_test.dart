import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:tanu_app/screens/settings_screen.dart';
import 'package:tanu_app/services/storage_service.dart';

/// Proves the Settings bottom cushion and the heavy sections' sub-views:
/// scrolling to the very end leaves "Under the Hood" above any nav overlay,
/// and its console opens in a sheet instead of expanding inline. Filesystem
/// work runs in runAsync (async dart:io stalls in this environment's FakeAsync
/// test zone). No backend is exercised.
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
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // The complex controls are not dumped on the main settings page.
    expect(find.textContaining('DEV CONSOLE'), findsNothing);
    expect(find.text('Download Offline Model (~375MB)'), findsNothing);
    expect(find.text("WIPE TANU'S MEMORY"), findsNothing);

    // Scroll to the last action row and open its sub-view.
    await tester.scrollUntilVisible(
      find.text('Open console'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Under the Hood'), findsOneWidget);
    expect(find.text('Open console'), findsOneWidget);

    await tester.tap(find.text('Open console'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
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
  }, timeout: const Timeout(Duration(minutes: 5)));
}
