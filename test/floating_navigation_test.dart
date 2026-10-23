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
  VoidCallback? onAskTap,
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
          onAskTap: onAskTap ?? () {},
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
  testWidgets('light bar is icon-only with enlarged active icons', (
    tester,
  ) async {
    _usePhoneSurface(tester);
    var tapped = -1;
    var askTapped = 0;

    await tester.pumpWidget(
      _app(
        brightness: Brightness.light,
        onTabSelected: (i) => tapped = i,
        onAskTap: () => askTapped++,
      ),
    );
    await tester.pump();

    final bar = find.byType(FloatingNavigationBar);
    final barRect = tester.getRect(bar);
    expect(barRect.left, 0);
    expect(barRect.right, 320);
    expect(barRect.bottom, 240);
    expect(barRect.height, 78);
    expect(find.descendant(of: bar, matching: find.byType(Text)), findsNothing);

    final home = tester.widget<Icon>(
      find.descendant(of: bar, matching: find.byIcon(Icons.home_rounded)),
    );
    final recall = tester.widget<Icon>(
      find.descendant(
        of: bar,
        matching: find.byIcon(Icons.auto_awesome_outlined),
      ),
    );
    final ask = tester.widget<Icon>(
      find.descendant(
        of: bar,
        matching: find.byIcon(Icons.auto_awesome_rounded),
      ),
    );

    expect(home.size, 26);
    expect(home.color, TanuColors.light.heading);
    expect(recall.size, 26);
    expect(recall.color, TanuColors.light.textMuted);
    expect(ask.size, 28);
    expect(ask.color, Colors.white);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Material && widget.color == TanuPalette.midnightBlue,
      ),
      findsOneWidget,
    );

    final scales = tester
        .widgetList<AnimatedScale>(
          find.descendant(of: bar, matching: find.byType(AnimatedScale)),
        )
        .toList();
    expect(scales.where((scale) => scale.scale == 1.06), hasLength(1));

    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pump();
    expect(tapped, 3);

    await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
    await tester.pump();
    expect(askTapped, 1);
    expect(tapped, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark bar uses the blue accent and keeps the midnight FAB', (
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

    expect(find.descendant(of: bar, matching: find.byType(Text)), findsNothing);
    expect(home.color, TanuColors.dark.primary);
    expect(recall.color, TanuColors.dark.textMuted);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Material && widget.color == TanuPalette.midnightBlue,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('bar tabs and Ask TANU button emit selection haptics', (
    tester,
  ) async {
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

    await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
    await tester.pump();
    expect(haptics, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
    ]);
    expect(tester.takeException(), isNull);
  });
}
