import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:tanu_app/providers/settings_provider.dart';
import 'package:tanu_app/screens/welcome/welcome_flow.dart';
import 'package:tanu_app/services/storage_service.dart';
import 'package:tanu_app/widgets/ai_presence_orb.dart';

/// Onboarding contract: pendant story pages with the hero orb + floating
/// feature bubbles first, Get Started on the last page, and completing it
/// flips hasCompletedOnboarding exactly once (never shows again).
void main() {
  testWidgets('onboarding: hero bubbles, story, get started once',
      (tester) async {
    late Directory scratch;
    late ProviderContainer container;
    await tester.runAsync(() async {
      scratch = await Directory.systemTemp.createTemp('tanu_onboarding');
      Hive.init(scratch.path);
      await Hive.openBox(Boxes.settings);
      await Hive.openBox(Boxes.commitments);
      await Hive.openBox(Boxes.conversation);
    });
    addTearDown(() async {
      container.dispose();
    });

    container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WelcomeFlow()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    // Page 1: hero orb + four floating feature bubbles.
    expect(find.byType(AiPresenceOrb), findsWidgets);
    for (final label in [
      'Listens all day',
      'Speech to text',
      'Recall anything',
      '100% private',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Your day,\nremembered.'), findsOneWidget);

    // Advance through the story to the last page via the flow's arrows.
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('Yours. Only\nyours.'), findsOneWidget);
    expect(find.text('Get Started with TANU'), findsOneWidget);

    // Get Started: orb transition, then the flag flips exactly once.
    expect(
      container.read(settingsProvider).hasCompletedOnboarding,
      isFalse,
    );
    await tester.tap(find.text('Get Started with TANU'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 800));
    expect(
      container.read(settingsProvider).hasCompletedOnboarding,
      isTrue,
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}
