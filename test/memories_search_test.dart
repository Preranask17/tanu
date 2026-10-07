import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:tanu_app/models/transcript.dart';
import 'package:tanu_app/screens/conversations_screen.dart';
import 'package:tanu_app/screens/welcome/tanu_wordmark.dart';
import 'package:tanu_app/services/storage_service.dart';

/// Proves the Memories header stack end to end with real stored sessions:
/// wordmark header + headline + always-visible search, query filters in
/// real time, X clears, gibberish shows the empty state. Filesystem work
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

    // Universal header: wordmark + headline below it.
    expect(find.byType(TanuWordmark), findsOneWidget);
    expect(find.text('Memories'), findsOneWidget);
    // Pill search with mic affordance, both memories listed, no reply yet.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Ask or search memories...'), findsOneWidget);
    expect(find.byIcon(Icons.mic_none), findsOneWidget);
    expect(find.text('Evening planning'), findsOneWidget);
    expect(find.text('Morning standup'), findsOneWidget);
    expect(find.textContaining('memories found'), findsNothing);

    // Real-time filtering + reply card on query.
    await tester.enterText(find.byType(TextField), 'standup');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Morning standup'), findsOneWidget);
    expect(find.text('Evening planning'), findsNothing);
    expect(find.text('1 memory found'), findsOneWidget);

    // X clears, reply hides, list restores.
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Evening planning'), findsOneWidget);
    expect(find.text('Morning standup'), findsOneWidget);
    expect(find.text('1 memory found'), findsNothing);
    expect(find.text('2 memories found'), findsNothing);

    // Empty-results state, still no reply card.
    await tester.enterText(find.byType(TextField), 'zzz-nope');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('No memories found matching'), findsOneWidget);
    expect(find.text('1 memory found'), findsNothing);
    expect(find.text('2 memories found'), findsNothing);

    await tester.runAsync(() async {
      await Hive.close();
      try {
        await scratch.delete(recursive: true);
      } catch (_) {}
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
