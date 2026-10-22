import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:tanu_app/models/conversation.dart';
import 'package:tanu_app/models/transcript.dart';
import 'package:tanu_app/providers/conversation_provider.dart';
import 'package:tanu_app/screens/conversations_screen.dart';
import 'package:tanu_app/screens/welcome/tanu_wordmark.dart';
import 'package:tanu_app/services/storage_service.dart';

class _FakeConversationNotifier extends ConversationNotifier {
  _FakeConversationNotifier(this._sessions);

  final List<ConversationSession> _sessions;

  @override
  ConversationState build() => ConversationState(conversations: _sessions);

  @override
  bool isQueuedForRetry(String id) => false;
}

/// Memories redesign contract: shared header (wordmark left, trash action),
/// compact filter row with collapsed search, local list below. No backend
/// exercised.
void main() {
  testWidgets('memories page: header, filters, no overflow', (tester) async {
    await tester.runAsync(() async {
      final scratch = await Directory.systemTemp.createTemp('tanu_mempage');
      Hive.init(scratch.path);
      await Hive.openBox(Boxes.settings);
      await Hive.openBox(Boxes.commitments);
      await Hive.openBox(Boxes.conversation);
    });

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ConversationsScreen())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Shared header: wordmark + headline + trash action.
    expect(find.byType(TanuWordmark), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsWidgets);
    // Compact sort/filter row; the search field stays collapsed until asked.
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Transcripts'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.mic_none), findsNothing);

    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search or ask about your memories…'), findsOneWidget);

    // No RAG card before a question is submitted.
    expect(find.textContaining('memories found'), findsNothing);
    expect(find.textContaining('Recalling memories'), findsNothing);
    expect(tester.takeException(), isNull);
    // No Hive.close(): native sqlite/indexer futures in flight can stall
    // teardown in this environment; temp dirs are harmless.
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('memories filters narrow the local list', (tester) async {
    final now = DateTime.now();
    final pinned = ConversationSession(
      id: 'pinned',
      title: 'Pinned memory',
      startedAt: now.subtract(const Duration(hours: 2)),
      finishedAt: now.subtract(const Duration(hours: 1)),
      status: ConversationStatus.completed,
      summary: 'A pinned note with a summary.',
      isPinned: true,
    );
    final transcriptOnly = ConversationSession(
      id: 'transcript',
      title: 'Transcript only',
      startedAt: now.subtract(const Duration(hours: 4)),
      finishedAt: now.subtract(const Duration(hours: 3)),
      status: ConversationStatus.completed,
      segments: [
        TranscriptSegment(
          id: 'transcript-0',
          text: 'Words captured without a generated note.',
          timestamp: now.subtract(const Duration(hours: 4)),
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationProvider.overrideWith(
            () => _FakeConversationNotifier([pinned, transcriptOnly]),
          ),
        ],
        child: const MaterialApp(home: ConversationsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Pinned memory'), findsOneWidget);
    expect(find.text('Transcript only'), findsOneWidget);

    Future<void> tapFilter(String label) async {
      final chip = find.text(label);
      await tester.ensureVisible(chip);
      await tester.pump();
      await tester.tap(chip);
      await tester.pump();
    }

    await tapFilter('Favorites');
    expect(find.text('Pinned memory'), findsOneWidget);
    expect(find.text('Transcript only'), findsNothing);

    await tapFilter('Transcripts');
    expect(find.text('Pinned memory'), findsNothing);
    expect(find.text('Transcript only'), findsOneWidget);

    await tapFilter('Notes');
    expect(find.text('Pinned memory'), findsOneWidget);
    expect(find.text('Transcript only'), findsNothing);

    await tapFilter('All');
    expect(find.text('Pinned memory'), findsOneWidget);
    expect(find.text('Transcript only'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
