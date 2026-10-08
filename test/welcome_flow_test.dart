import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanu_app/providers/settings_provider.dart';
import 'package:tanu_app/screens/welcome/onboarding_pages.dart';
import 'package:tanu_app/screens/welcome/orb_enter_transition.dart';
import 'package:tanu_app/screens/welcome/tanu_wordmark.dart';
import 'package:tanu_app/screens/welcome/wave_dot_background.dart';
import 'package:tanu_app/screens/welcome/welcome_flow.dart';

/// Fake settings that records completion instead of persisting it, so this
/// widget test needs no filesystem and no real async work.
class _FakeSettings extends SettingsNotifier {
  bool completed = false;

  @override
  AppSettings build() =>
      const AppSettings(hasCompletedOnboarding: false);

  @override
  void completeOnboarding() {
    completed = true;
    state = state.copyWith(hasCompletedOnboarding: true);
  }
}

/// Proves the first-run experience end to end with the real widgets:
/// onboarding pages first (NO formation movie) -> all six pages ->
/// Get Started plays the orb enter-transition -> existing completion hook
/// fires. No backend is exercised.
void main() {
  testWidgets('welcome flow: pages, orb enter, get started', (tester) async {
    final fake = _FakeSettings();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(() => fake),
        ],
        child: const MaterialApp(home: WelcomeFlow()),
      ),
    );
    await tester.pump();

    // 1. First launch lands DIRECTLY on onboarding — no formation movie.
    expect(find.text('Meet TANU'), findsOneWidget);
    // No wordmark on page 1 (pure text heading); it lives on page 6.
    expect(find.byType(TanuWordmark), findsNothing);
    // Page 1 capability cluster is present.
    expect(find.text('Ambient Capture'), findsOneWidget);
    expect(find.text('Instant Memories'), findsOneWidget);
    expect(find.text('AI Intelligence'), findsOneWidget);
    expect(find.text('Pendant Sync'), findsOneWidget);
    // Dot-wave backdrop is present behind the pages (and stays there: it
    // lives outside the PageView, so swiping below also proves persistence).
    expect(find.byType(WaveDotBackground), findsOneWidget);

    // 2. Swipe through the remaining pages in order.
    const titles = [
      'Meet TANU',
      'Your TANU pendant',
      'Capture moments naturally',
      'Your memories, organized',
      'Ask TANU anything',
      'You’re ready to begin.',
    ];
    for (var i = 1; i < titles.length; i++) {
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 800);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(titles[i]), findsOneWidget);
      if (i == 1) {
        // Pendant placeholder is present with its marked insertion point.
        expect(find.byType(PendantVideoPlaceholder), findsOneWidget);
      }
      if (i == 5) {
        // Brand wordmark sits above the final headline too.
        expect(find.byType(TanuWordmark), findsOneWidget);
      }
    }

    // 3. Get Started swaps to the orb enter-transition (not the app yet).
    expect(fake.completed, isFalse);
    await tester.tap(find.text('Get Started with TANU'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(OrbEnterTransition), findsOneWidget);
    expect(fake.completed, isFalse);

    // 4. Once the zoom ends (black screen), the completion hook fires.
    await tester.pump(const Duration(milliseconds: 2500));
    expect(fake.completed, isTrue);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
