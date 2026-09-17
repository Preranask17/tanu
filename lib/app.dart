import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/conversation.dart';
import 'abstractions/audio_source.dart';
import 'providers/ble_provider.dart';
import 'providers/conversation_provider.dart';
import 'providers/navigation_provider.dart';
import 'screens/conversations_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'theme.dart';
import 'widgets/bottom_nav_bar.dart';
import 'widgets/home_chat_bar.dart';

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

  @override
  void initState() {
    super.initState();
    // Start the STT engine warm-up as soon as the UI settles. Skipped in
    // widget tests where the native plugin is unavailable.
    if (Platform.environment['FLUTTER_TEST'] != 'true') {
      Future.microtask(() => ref.read(sttEngineProvider).isAvailable());
      WidgetsBinding.instance.addPostFrameCallback((_) => _initForegroundTask());
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
      final notice = 'Listening…';
      if (notice != _fgNotice) {
        _fgNotice = notice;
        unawaited(
            FlutterForegroundTask.updateService(notificationText: notice));
      }
    }
  }

  Future<void> _startForegroundTask() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Tanu',
          notificationText: 'Listening…',
        );
      } else {
        await FlutterForegroundTask.startService(
          serviceId: 1010,
          serviceTypes: const [
            ForegroundServiceTypes.connectedDevice,
          ],
          notificationTitle: 'Tanu',
          notificationText: 'Listening…',
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
    final status = ref.watch(pendantStatusProvider).value;
    final connected = status?.isConnected ?? false;

    return CupertinoApp(
      title: 'Tanu',
      debugShowCheckedModeBanner: false,
      theme: TanuTheme.light(),
      home: CupertinoTabScaffold(
        controller: CupertinoTabController(initialIndex: index),
        tabBar: CupertinoTabBar(
          onTap: (i) {
            if (i == index) {
              _onTabTap(i, true);
            } else {
              ref.read(navigationTabProvider.notifier).goTo(i);
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.mic),
              activeIcon: Icon(CupertinoIcons.mic_solid),
              label: 'Capture',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.archivebox),
              activeIcon: Icon(CupertinoIcons.archivebox_fill),
              label: 'Memories',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.settings),
              activeIcon: Icon(CupertinoIcons.settings_solid),
              label: 'Settings',
            ),
          ],
        ),
        tabBuilder: (context, i) {
          switch (i) {
            case 0:
              return HomeScreen(key: _homeKey);
            case 1:
              return ConversationsScreen(key: _conversationsKey);
            case 2:
              return const SettingsScreen();
            default:
              return const SizedBox.shrink();
          }
        },
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