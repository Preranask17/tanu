import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanu_app/abstractions/audio_source.dart';
import 'package:tanu_app/providers/ble_provider.dart';
import 'package:tanu_app/screens/ask_screen.dart';
import 'package:tanu_app/theme/tanu_colors.dart';

/// Proves the Recall probing chips populate the existing query field without
/// sending a request. No retrieval backend is exercised.
void main() {
  testWidgets('probing chip fills the Recall query field', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final recallKey = GlobalKey<AskScreenState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pendantStatusProvider.overrideWith(
            (ref) => Stream<PendantStatus>.value(const PendantStatus()),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(
            brightness: Brightness.light,
            useMaterial3: true,
            extensions: <ThemeExtension<dynamic>>[TanuColors.light],
          ),
          home: AskScreen(key: recallKey),
        ),
      ),
    );
    await tester.pump();

    final fieldFinder = find.byType(TextField);
    expect(tester.widget<TextField>(fieldFinder).focusNode?.hasFocus, isFalse);
    recallKey.currentState?.focusInput();
    await tester.pump();
    expect(tester.widget<TextField>(fieldFinder).focusNode?.hasFocus, isTrue);

    const question = 'What were my main takeaways today?';
    expect(find.text(question), findsOneWidget);

    await tester.tap(find.text(question));
    await tester.pump();

    final field = tester.widget<TextField>(fieldFinder);
    expect(field.controller?.text, question);
    expect(tester.takeException(), isNull);
  });
}
