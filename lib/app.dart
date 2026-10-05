import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/conversation.dart';
import 'abstractions/audio_source.dart';
import 'providers/analytics_provider.dart';
import 'providers/conversation_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/conversations_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'theme.dart';

import 'widgets/responsive_scaffold.dart';

class TanuApp extends ConsumerStatefulWidget {
  const TanuApp({super.key});

  @override
  ConsumerState<TanuApp> createState() => _TanuAppState();
}

class _TanuAppState extends ConsumerState<TanuApp> {
  bool _fgStarted = false;
  String _fgNotice = '';
  final _homeKey = GlobalKey<HomeScreenState>();
  final _conversationsKey = GlobalKey<ConversationsScreenState>();

  /// Tab index -> screen name. Indexed in step with the `BottomNavigationBarItem`
  /// list in [build] and with the `items` passed to `ResponsiveScaffold`.
  static const _tabScreens = ['capture', 'memories', 'settings'];

  @override
  void initState() {
    super.initState();
    // Tab navigation is an IndexedStack, not a Navigator, so PostHog's
    // `PosthogObserver` sees none of it — report screens explicitly instead.
    // `fireImmediately` covers the landing tab.
    ref.listenManual<int>(navigationTabProvider, (prev, next) {
      if (next == prev) return;
      if (next >= 0 && next < _tabScreens.length) {
        ref.read(analyticsProvider).screen(_tabScreens[next]);
      }
    }, fireImmediately: true);
    // Start the STT engine warm-up as soon as the UI settles. Skipped in
    // widget tests where the native plugin is unavailable.
    if (Platform.environment['FLUTTER_TEST'] != 'true') {
      Future.microtask(() => ref.read(sttEngineProvider).isAvailable());
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _initForegroundTask(),
      );
    }
  }

  @override
  void dispose() {
    if (Platform.isAndroid && _fgStarted) FlutterForegroundTask.stopService();
    super.dispose();
  }

  void _initForegroundTask() {
    if (!Platform.isAndroid) return;
    try {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          // Distinct channel: Android locks channel importance on first use,
          // so a fresh id guarantees the chosen importance even on existing
          // installs. DEFAULT (not MAX) so it stays quietly in the shade
          // without heads-up spam; showWhen off so text updates don't re-push.
          channelId: 'tanu_voice',
          channelName: 'Tanu is listening',
          channelDescription: 'Shows while Tanu listens for your voice.',
          channelImportance: NotificationChannelImportance.DEFAULT,
          priority: NotificationPriority.HIGH,
          showWhen: false,
          onlyAlertOnce: true,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: false,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.nothing(),
          allowWakeLock: true,
        ),
      );
      FlutterForegroundTask.requestNotificationPermission();
    } catch (e) {
      debugPrint('[tanu] fg task init failed: $e');
    }
  }

  void _syncForegroundTask(ConversationState next) {
    if (!Platform.isAndroid) return;
    final active = next.isListening;
    if (active && !_fgStarted) {
      _fgStarted = true;
      unawaited(_startForegroundTask());
    } else if (!active && _fgStarted) {
      _fgStarted = false;
      _fgNotice = '';
      unawaited(FlutterForegroundTask.stopService());
    } else if (active) {
      final notice = 'Listening...';
      if (notice != _fgNotice) {
        _fgNotice = notice;
        unawaited(
          FlutterForegroundTask.updateService(notificationText: notice),
        );
      }
    }
  }

  Future<void> _startForegroundTask() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Tanu',
          notificationText: 'Listening...',
        );
      } else {
        await FlutterForegroundTask.startService(
          serviceId: 1010,
          serviceTypes: const [ForegroundServiceTypes.connectedDevice],
          notificationTitle: 'Tanu',
          notificationText: 'Listening...',
          callback: _fgTaskCallback,
        );
      }
    } catch (e) {
      debugPrint('[tanu] fg start failed: $e');
      _fgStarted = false;
    }
  }

  void _onTabTap(int index, bool isRepeat) {
    final notifier = ref.read(navigationTabProvider.notifier);
    if (!isRepeat) {
      notifier.goTo(index);
      return;
    }
    // A repeat tap scrolls the chosen tab back to its top, like Omi.
    switch (index) {
      case 0:
        _homeKey.currentState?.scrollToTop();
        return;
      case 1:
        _conversationsKey.currentState?.scrollToTop();
        return;
      default:
        notifier.goTo(2);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep the foreground service running while an active session lives in
    // the background (BLE → STT → Tanu replies).
    ref.listen<ConversationState>(
      conversationProvider,
      (prev, next) => _syncForegroundTask(next),
    );
    final index = ref.watch(navigationTabProvider);
    final settings = ref.watch(settingsProvider);
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final brightness = settings.themeMode == ThemeMode.dark
        ? Brightness.dark
        : (settings.themeMode == ThemeMode.light
              ? Brightness.light
              : platformBrightness);

    return MaterialApp(
      title: 'Tanu',
      debugShowCheckedModeBanner: false,
      theme: TanuTheme.getTheme(brightness),
      home: !settings.hasCompletedOnboarding
          ? const OnboardingScreen()
          : ResponsiveScaffold(
              currentIndex: index,
              onTabTapped: (i) {
                if (i == index) {
                  _onTabTap(i, true);
                } else {
                  ref.read(navigationTabProvider.notifier).goTo(i);
                }
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.mic_none),
                  activeIcon: Icon(Icons.mic),
                  label: 'Capture',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.inventory_2_outlined),
                  activeIcon: Icon(Icons.inventory_2),
                  label: 'Memories',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
              pages: [
                HomeScreen(key: _homeKey),
                ConversationsScreen(key: _conversationsKey),
                const SettingsScreen(),
              ],
            ),
    );
  }
}

/// Entry point the foreground service uses to install an (idle) task handler.
/// Keeps the process alive so BLE + STT keep running in the background.
@pragma('vm:entry-point')
void _fgTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_IdleTaskHandler());
}

class _IdleTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
