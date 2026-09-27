import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-level navigation state so any screen can trigger a tab change.
class NavigationTab extends Notifier<int> {
  @override
  int build() => 0;

  void goTo(int index) => state = index;

  void goToHome() => state = 0;

  void goToConversations() => state = 1;

  void goToSettings() => state = 2;
}

final navigationTabProvider = NotifierProvider<NavigationTab, int>(
  NavigationTab.new,
);
