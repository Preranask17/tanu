import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
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

    return MaterialApp(
      title: 'Tanu',
      debugShowCheckedModeBanner: false,
      theme: TanuTheme.light(),
      home: Scaffold(
        appBar: _AppBar(
          index: index,
          onSearch: () => _conversationsKey.currentState?.toggleSearch(),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  // IndexedStack keeps all tabs alive and prewarmed, so the
                  // pendant reconnect + model warm-up happen once at launch.
                  child: IndexedStack(
                    index: index,
                    children: [
                      HomeScreen(key: _homeKey),
                      ConversationsScreen(key: _conversationsKey),
                      const SettingsScreen(),
                    ],
                  ),
                ),
              ],
            ),
            if (index == 0)
              Positioned(
                left: 16,
                right: 16,
                bottom: kBottomNavBarHeight +
                    kBottomNavChatBarGap +
                    bottomNavBarReservedInset(context),
                child: const HomeChatBar(),
              ),
            BottomNavBar(onTabTap: _onTabTap),
          ],
        ),
      ),
    );
  }
}

/// Transparent app bar Omi keeps over each tab. The device/status pill stays
/// on the left like Omi's battery widget; each tab adds its own action(s).
class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppBar({required this.index, required this.onSearch});

  final int index;
  final VoidCallback onSearch;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: _TabStatusTitle(index: index),
      actions: [
        if (index == 1)
          IconButton(
            tooltip: 'Search conversations',
            onPressed: onSearch,
            icon: const Icon(Icons.search, color: kTanuInk),
          ),
      ],
    );
  }
}

class _TabStatusTitle extends ConsumerWidget {
  const _TabStatusTitle({required this.index});

  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(pendantStatusProvider).value;
    final connected = status?.isConnected ?? false;

    final Widget leading;
    if (!connected) {
      leading = Icon(Icons.bluetooth_disabled, size: 17, color: kTanuMuted);
    } else if (status!.state == PendantState.reconnecting) {
      leading = Icon(Icons.sync, size: 17, color: kTanuWarm);
    } else {
      leading = Icon(Icons.bluetooth_connected, size: 17, color: kTanuGreen);
    }

    final name = switch (status?.state) {
      PendantState.scanning => 'Scanning…',
      PendantState.connecting => 'Connecting…',
      PendantState.reconnecting => 'Reconnecting…',
      PendantState.connected =>
        (status!.deviceName != null && status.deviceName!.isNotEmpty)
            ? status.deviceName!
            : 'Pendant',
      PendantState.disconnected || null => 'Not connected',
    };

    final battery = (connected && status!.batteryPercent != null)
        ? status.batteryPercent!
        : null;

    return Row(
      children: [
        leading,
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: connected ? kTanuInk : kTanuMuted,
            ),
          ),
        ),
        if (battery != null) ...[
          const SizedBox(width: 8),
          Icon(Icons.battery_std, size: 15, color: kTanuMuted),
          const SizedBox(width: 2),
          Text(
            '$battery%',
            style: const TextStyle(fontSize: 13, color: kTanuMuted),
          ),
        ],
      ],
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