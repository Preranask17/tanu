import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:tanu_app/screens/conversations_screen.dart';
import 'package:tanu_app/screens/welcome/tanu_wordmark.dart';
import 'package:tanu_app/services/storage_service.dart';

/// Memories redesign contract: shared header (wordmark left, trash action),
/// always-visible RAG search pill, local list below. No backend exercised.
void main() {
  testWidgets('memories page: header, search pill, no overflow',
      (tester) async {
    await tester.runAsync(() async {
      final scratch =
          await Directory.systemTemp.createTemp('tanu_mempage');
      Hive.init(scratch.path);
      await Hive.openBox(Boxes.settings);
      await Hive.openBox(Boxes.commitments);
      await Hive.openBox(Boxes.conversation);
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ConversationsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Shared header: wordmark + headline + trash action.
    expect(find.byType(TanuWordmark), findsOneWidget);
    expect(find.text('Memories'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsWidgets);
    // RAG search pill: magnifier + field only, no mic affordance.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Ask or search memories...'), findsOneWidget);
    expect(find.byIcon(Icons.mic_none), findsNothing);
    // No RAG card before a question is submitted.
    expect(find.textContaining('memories found'), findsNothing);
    expect(find.textContaining('Recalling memories'), findsNothing);
    expect(tester.takeException(), isNull);
    // No Hive.close(): native sqlite/indexer futures in flight can stall
    // teardown in this environment; temp dirs are harmless.
  }, timeout: const Timeout(Duration(minutes: 5)));
}
