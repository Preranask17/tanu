import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanu_app/screens/welcome/opening_animation.dart';
import 'package:tanu_app/screens/welcome/returning_startup_gate.dart';

/// Proves the returning-user gate: formation movie first, main app revealed
/// after, movie shown once and never replayed. Pure widgets, no backend.
void main() {
  testWidgets('returning gate: movie first, then app, shown once',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReturningStartupGate(child: Text('MAIN APP')),
      ),
    );
    await tester.pump();

    // Formation movie is up.
    expect(find.byType(TanuOpeningSequence), findsOneWidget);

    // Skip it: movie fades and is dropped, app remains.
    await tester.tap(find.byType(TanuOpeningSequence));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(TanuOpeningSequence), findsNothing);
    expect(find.text('MAIN APP'), findsOneWidget);

    // Still there after more frames: no replay, no resurrection.
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(TanuOpeningSequence), findsNothing);
    expect(find.text('MAIN APP'), findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
