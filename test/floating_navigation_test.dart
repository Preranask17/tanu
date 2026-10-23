import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanu_app/theme/tanu_colors.dart';
import 'package:tanu_app/widgets/floating_navigation.dart';

const _items = [
  FloatingNavItem(
    label: 'Home',
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    pageIndex: 0,
    scrollsToTopOnRepeat: true,
  ),
  FloatingNavItem(
    label: 'Recall',
    icon: Icons.auto_awesome_outlined,
    activeIcon: Icons.auto_awesome_rounded,
    pageIndex: 3,
  ),
  FloatingNavItem(
    label: 'Library',
    icon: Icons.grid_view_outlined,
    activeIcon: Icons.grid_view_rounded,
    pageIndex: 1,
    scrollsToTopOnRepeat: true,
  ),
  FloatingNavItem(
    label: 'Settings',
    icon: Icons.tune_outlined,
    activeIcon: Icons.tune_rounded,
    pageIndex: 2,
  ),
];

Widget _app({
  required Brightness brightness,
  required ValueChanged<int> onTabSelected,
}) {
  final colors = brightness == Brightness.dark
      ? TanuColors.dark
      : TanuColors.light;

  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.primary,
        brightness: brightness,
      ),
      extensions: <ThemeExtension<dynamic>>[colors],
    ),
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: FloatingNavigationBar(
          items: _items,
          selectedIndex: 0,
          onTabSelected: onTabSelected,
        ),
      ),
    ),
  );
}

void _usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 240);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('light bar is a flat four-tab layout with labels', (
    tester,
  ) async {
    _usePhoneSurface(tester);
    var tapped = -1;

    await tester.pumpWidget(
      _app(brightness: Brightness.light, onTabSelected: (i) => tapped = i),
    );
    await tester.pump();

    final bar = find.byType(FloatingNavigationBar);
    final barRect = tester.getRect(bar);
    expect(barRect.left, 0);
    expect(barRect.right, 320);
    expect(barRect.bottom, 240);
    expect(barRect.height, 78);

    for (final label in const ['Home', 'Recall', 'Library', 'Settings']) {
      expect(
        find.descendant(of: bar, matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(find.byIcon(Icons.add_rounded), findsNothing);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);

    final home = tester.widget<Icon>(
      find.descendant(of: bar, matching: find.byIcon(Icons.home_rounded)),
    );
    final recall = tester.widget<Icon>(
      find.descendant(
        of: bar,
        matching: find.byIcon(Icons.auto_awesome_outlined),
      ),
    );
    expect(home.size, 24);
    expect(home.color, TanuColors.light.heading);
    expect(recall.size, 24);
    expect(recall.color, TanuColors.light.textMuted);

    final homeLabel = tester.widget<Text>(
      find.descendant(of: bar, matching: find.text('Home')),
    );
    final recallLabel = tester.widget<Text>(
      find.descendant(of: bar, matching: find.text('Recall')),
    );
    expect(homeLabel.style?.color, TanuColors.light.heading);
    expect(recallLabel.style?.color, TanuColors.light.textMuted);
    expect(
      tester.getCenter(find.text('Home')).dy,
      greaterThan(tester.getCenter(find.byIcon(Icons.home_rounded)).dy),
    );

    final container = tester.widget<Container>(
      find.descendant(of: bar, matching: find.byType(Container)).first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, TanuColors.light.surface);
    expect((decoration.border! as Border).top.color, TanuColors.light.border);

    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pump();
    expect(tapped, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark bar uses sand active and muted inactive states', (
    tester,
  ) async {
    _usePhoneSurface(tester);

    await tester.pumpWidget(
      _app(brightness: Brightness.dark, onTabSelected: (_) {}),
    );
    await tester.pump();

    final bar = find.byType(FloatingNavigationBar);
    final home = tester.widget<Icon>(
      find.descendant(of: bar, matching: find.byIcon(Icons.home_rounded)),
    );
    final recall = tester.widget<Icon>(
      find.descendant(
        of: bar,
        matching: find.byIcon(Icons.auto_awesome_outlined),
      ),
    );
    final homeLabel = tester.widget<Text>(
      find.descendant(of: bar, matching: find.text('Home')),
    );
    final recallLabel = tester.widget<Text>(
      find.descendant(of: bar, matching: find.text('Recall')),
    );

    expect(home.color, TanuColors.dark.heading);
    expect(recall.color, TanuColors.dark.textMuted);
    expect(homeLabel.style?.color, TanuColors.dark.heading);
    expect(recallLabel.style?.color, TanuColors.dark.textMuted);
    expect(find.byIcon(Icons.add_rounded), findsNothing);

    final container = tester.widget<Container>(
      find.descendant(of: bar, matching: find.byType(Container)).first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, TanuColors.dark.surface);
    expect((decoration.border! as Border).top.color, TanuColors.dark.border);
    expect(tester.takeException(), isNull);
  });

  testWidgets('flat bar tabs emit selection haptics', (tester) async {
    _usePhoneSurface(tester);
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add('${call.arguments}');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      _app(brightness: Brightness.light, onTabSelected: (_) {}),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pump();
    expect(haptics, ['HapticFeedbackType.selectionClick']);

    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pump();
    expect(haptics, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
    ]);
    expect(tester.takeException(), isNull);
  });
}
