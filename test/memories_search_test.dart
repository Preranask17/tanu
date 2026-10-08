import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:tanu_app/models/transcript.dart';
import 'package:tanu_app/screens/conversations_screen.dart';
import 'package:tanu_app/services/storage_service.dart';

/// Proves the Memories header stack end to end with real stored sessions:
/// page title + toggled search pill, query filters in real time, clear
/// restores the list, gibberish shows the no-match state. Filesystem work
/// runs in runAsync (async dart:io stalls in this environment's FakeAsync
/// test zone). No backend is exercised.
void main() {
  testWidgets('memories: header, search filters in real time', (
    tester,
  ) async {
    late Directory scratch;
    await tester.runAsync(() async {
      scratch = await Directory.systemTemp.createTemp('tanu_memsearch');
      Hive.init(scratch.path);
      await Hive.openBox(Boxes.settings);
      await Hive.openBox(Boxes.commitments);
      await Hive.openBox(Boxes.conversation);
      // Demo seeding is out of scope here: mark it done so the list holds
      // only the sessions this test writes.
      await Hive.box(Boxes.conversation).put('demoSeeded', true);

      ConversationSession demo(
        String id,
        String title,
        String summary,
        Duration ago,
      ) {
        final start = DateTime.now().subtract(ago);
        return ConversationSession(
          id: id,
          title: title,
          startedAt: start,
          finishedAt: start.add(const Duration(minutes: 5)),
          status: ConversationStatus.completed,
          summary: summary,
          segments: [
            TranscriptSegment(id: '$id-0', text: summary, timestamp: start),
          ],
        );
      }

      await Hive.box(Boxes.conversation).put('sessions', [
        demo(
          'm1',
          'Evening planning',
          'Booked the Friday flights.',
          const Duration(hours: 2),
        ).toJson(),
        demo(
          'm2',
          'Morning standup',
          'Checkout flow ships Friday.',
          const Duration(hours: 5),
        ).toJson(),
      ]);
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ConversationsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Header: page title, both memories listed, search hidden until asked.
    expect(find.text('Memories'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Evening planning'), findsOneWidget);
    expect(find.text('Morning standup'), findsOneWidget);

    // Reveal the search pill and filter in real time.
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search memories...'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'standup');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Morning standup'), findsOneWidget);
    expect(find.text('Evening planning'), findsNothing);

    // Clear pill restores the full list.
    await tester.tap(find.byIcon(Icons.clear_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Evening planning'), findsOneWidget);
    expect(find.text('Morning standup'), findsOneWidget);

    // Empty-results state.
    await tester.enterText(find.byType(TextField), 'zzz-nope');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('No matches for that search.'), findsOneWidget);
    expect(find.text('Evening planning'), findsNothing);
    expect(find.text('Morning standup'), findsNothing);

    await tester.runAsync(() async {
      await Hive.close();
      try {
        await scratch.delete(recursive: true);
      } catch (_) {}
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
