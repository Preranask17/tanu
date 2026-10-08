import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanu_app/models/transcript.dart';
import 'package:tanu_app/widgets/conversation_tile.dart';

ConversationSession session(String id, String title) => ConversationSession(
  id: id,
  title: title,
  startedAt: DateTime(2026, 1, 1, 10, 0),
  finishedAt: DateTime(2026, 1, 1, 10, 5),
  status: ConversationStatus.completed,
  summary: 'a saved summary',
  segments: [
    TranscriptSegment(
      id: '$id-0',
      text: 'first words',
      timestamp: DateTime(2026, 1, 1, 10, 0),
    ),
  ],
);

Future<void> pumpTile(
  WidgetTester tester,
  Widget tile, {
  double width = 320,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: tile,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('ConversationTile never overflows narrow phones', () {
    testWidgets('processing row at 320px', (tester) async {
      await pumpTile(
        tester,
        ConversationTile(
          session: session('m1', 'Evening planning discussion notes'),
          isProcessing: true,
          onDelete: () {},
          onPin: () {},
        ),
      );
      expect(find.text('Writing summary…'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('retry row at 320px', (tester) async {
      var retried = false;
      await pumpTile(
        tester,
        ConversationTile(
          session: session('m2', 'Evening planning discussion notes'),
          isFailed: true,
          onRetry: () => retried = true,
        ),
      );
      expect(find.text('AI paused — tap to retry'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('AI paused — tap to retry'));
      expect(retried, isTrue);
    });

    testWidgets('plain tile at 320px', (tester) async {
      await pumpTile(
        tester,
        ConversationTile(
          session: session('m3', 'Evening planning discussion notes'),
          onDelete: () {},
          onPin: () {},
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
