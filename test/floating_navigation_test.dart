import 'package:flutter/material.dart';
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FloatingNavigationBar(
            items: _items,
            selectedIndex: 0,
            onTabSelected: onTabSelected,
          ),
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
  testWidgets('light dock is icon-only with enlarged active icons', (
    tester,
  ) async {
    _usePhoneSurface(tester);
    var tapped = -1;

    await tester.pumpWidget(
      _app(brightness: Brightness.light, onTabSelected: (i) => tapped = i),
    );
    await tester.pump();

    final dock = find.byType(FloatingNavigationBar);
    expect(
      find.descendant(of: dock, matching: find.byType(Text)),
      findsNothing,
    );

    final home = tester.widget<Icon>(
      find.descendant(of: dock, matching: find.byIcon(Icons.home_rounded)),
    );
    final recall = tester.widget<Icon>(
      find.descendant(
        of: dock,
        matching: find.byIcon(Icons.auto_awesome_outlined),
      ),
    );
    final add = tester.widget<Icon>(
      find.descendant(of: dock, matching: find.byIcon(Icons.add_rounded)),
    );

    expect(home.size, 26);
    expect(home.color, TanuColors.light.heading);
    expect(recall.size, 26);
    expect(recall.color, TanuColors.light.textMuted);
    expect(add.size, 28);
    expect(add.color, Colors.white);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Material && widget.color == TanuPalette.midnightBlue,
      ),
      findsOneWidget,
    );

    final scales = tester
        .widgetList<AnimatedScale>(
          find.descendant(of: dock, matching: find.byType(AnimatedScale)),
        )
        .toList();
    expect(scales.where((scale) => scale.scale == 1.06), hasLength(1));

    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pump();
    expect(tapped, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark dock uses the blue accent and keeps the midnight FAB', (
    tester,
  ) async {
    _usePhoneSurface(tester);

    await tester.pumpWidget(
      _app(brightness: Brightness.dark, onTabSelected: (_) {}),
    );
    await tester.pump();

    final dock = find.byType(FloatingNavigationBar);
    final home = tester.widget<Icon>(
      find.descendant(of: dock, matching: find.byIcon(Icons.home_rounded)),
    );
    final recall = tester.widget<Icon>(
      find.descendant(
        of: dock,
        matching: find.byIcon(Icons.auto_awesome_outlined),
      ),
    );

    expect(
      find.descendant(of: dock, matching: find.byType(Text)),
      findsNothing,
    );
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
}
