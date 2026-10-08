import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../models/transcript.dart';
import '../agent/gemini_agent_engine.dart';
import '../storage_service.dart';

enum ProactiveKind { commitment, highlight }

/// Fires local notifications for fresh memories that contain commitments or
/// decisions. Always-on, spam-limited (3/day, 1h gap), no extra API calls.
class ProactiveService {
  ProactiveService._(this._plugin, this._onTap);

  final FlutterLocalNotificationsPlugin _plugin;
  final ValueChanged<String> _onTap;

  static const _channelId = 'tanu_insights';
  static const _channelName = 'Tanu insights';

  static Future<ProactiveService> init({
    required ValueChanged<String> onTap,
  }) async {
    final plugin = FlutterLocalNotificationsPlugin();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios, macOS: ios),
      onDidReceiveNotificationResponse: (r) {
        final payload = r.payload;
        if (payload != null && payload.isNotEmpty) onTap(payload);
      },
    );
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: 'Insights from your memories',
            importance: Importance.high,
          ),
        );
    return ProactiveService._(plugin, onTap);
  }

  static const _maxPerDay = 3;
  static const _minGap = Duration(hours: 1);

  bool _allowedNow() {
    final box = Hive.box(Boxes.conversation);
    final today = DateTime.now();
    final storedDay = DateTime.tryParse(box.get('proactiveDay') as String? ?? '');
    final count = storedDay != null &&
            storedDay.year == today.year &&
            storedDay.month == today.month &&
            storedDay.day == today.day
        ? (box.get('proactiveCount') as int? ?? 0)
        : 0;
    if (count >= _maxPerDay) return false;
    final lastMs = box.get('proactiveLastAt') as int?;
    if (lastMs != null) {
      final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
      if (today.difference(last) < _minGap) return false;
    }
    return true;
  }

  void _recordFired() {
    final box = Hive.box(Boxes.conversation);
    final today = DateTime.now();
    final storedDay =
        DateTime.tryParse(box.get('proactiveDay') as String? ?? '');
    final sameDay = storedDay != null &&
        storedDay.year == today.year &&
        storedDay.month == today.month &&
        storedDay.day == today.day;
    final count = sameDay ? (box.get('proactiveCount') as int? ?? 0) : 0;
    box.put('proactiveDay', today.toIso8601String());
    box.put('proactiveCount', count + 1);
    box.put('proactiveLastAt', today.millisecondsSinceEpoch);
  }

  static final _decisionVerbs = RegExp(
    r'\b(decided|agreed|promised|will|need to|plan to|scheduled|committed)\b',
    caseSensitive: false,
  );

  Future<ProactiveKind?> maybeNotify({
    required ConversationSession session,
    required MemoryResult result,
  }) async {
    if (!_allowedNow()) return null;

    final hasCommitments = result.commitments.isNotEmpty &&
        result.commitments.any((c) => c.isCommitment && (c.action?.isNotEmpty ?? false));

    String title;
    String body;
    ProactiveKind kind;

    if (hasCommitments) {
      final first = result.commitments.firstWhere(
        (c) => c.isCommitment && (c.action?.isNotEmpty ?? false),
      );
      kind = ProactiveKind.commitment;
      title = 'You committed';
      final extra = result.commitments.length > 1
          ? ' (+${result.commitments.length - 1} more)'
          : '';
      body = '"${first.action}"$extra · from "${result.title}"';
    } else if (result.summary.length >= 60 &&
        _decisionVerbs.hasMatch(result.summary)) {
      kind = ProactiveKind.highlight;
      title = result.title.isEmpty ? 'Memory highlight' : result.title;
      body = result.summary.length > 80
          ? '${result.summary.substring(0, 80)}…'
          : result.summary;
    } else {
      return null;
    }

    try {
      await _plugin.show(
        id: session.id.hashCode,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: session.id,
      );
      _recordFired();
      return kind;
    } catch (e) {
      debugPrint('[tanu] proactive notify failed: $e');
      return null;
    }
  }
}
