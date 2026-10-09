import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../models/transcript.dart';
import '../agent/gemini_agent_engine.dart';
import '../storage_service.dart';
import 'importance_scorer.dart';

enum ProactiveKind { commitment, highlight }

/// Fires local notifications for fresh memories that contain commitments or
/// decisions. Always-on, spam-limited (3/day, 1h gap), no extra API calls.
class ProactiveService {
  ProactiveService._(this._plugin, this._onTap);

  final FlutterLocalNotificationsPlugin _plugin;
  final ValueChanged<String> _onTap;

  static const _channelId = 'tanu_insights';
  static const _channelName = 'Tanu insights';
  static const _commitmentsChannelId = 'tanu_commitments';
  static const _commitmentsChannelName = 'Tanu commitments';
  static const _digestChannelId = 'tanu_digest';
  static const _digestChannelName = 'Tanu digest';

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
        ?.requestNotificationsPermission();
    final androidPlugin =
        plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Insights from your memories',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _commitmentsChannelId,
        _commitmentsChannelName,
        description: 'Commitments pulled from your conversations',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _digestChannelId,
        _digestChannelName,
        description: 'Your morning memory digest',
        importance: Importance.defaultImportance,
      ),
    );
    return ProactiveService._(plugin, onTap);
  }

  /// Immediate test notification that bypasses the daily/interval caps and
  /// content gates. Wired to the Settings "Under the Hood" console so a
  /// silent phone can be diagnosed on-device: if this shows, plumbing and
  /// permission are fine and real memories are being gated by caps/content.
  Future<bool> showTestNotification() async {
    try {
      await _plugin.show(
        id: -1,
        title: 'Tanu test notification',
        body: 'Notifications are working.',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: '',
      );
      return true;
    } catch (e) {
      debugPrint('[tanu] test notify failed: $e');
      return false;
    }
  }

  /// Session ids already pinged (Hive, capped). Retries, queue drains
  /// and reprocessing re-run scoring freely — this set is what keeps every
  /// memory to exactly one notification.
  bool _wasNotified(String sessionId) {
    try {
      final box = Hive.box(Boxes.conversation);
      final raw = box.get('proactiveNotified');
      if (raw is List) return raw.whereType<String>().contains(sessionId);
    } catch (_) {}
    return false;
  }

  void _markNotified(String sessionId) {
    try {
      final box = Hive.box(Boxes.conversation);
      final raw = box.get('proactiveNotified');
      final ids = <String>[];
      if (raw is List) ids.addAll(raw.whereType<String>());
      if (!ids.contains(sessionId)) {
        ids.add(sessionId);
        while (ids.length > 100) {
          ids.removeAt(0);
        }
        box.put('proactiveNotified', ids);
      }
    } catch (_) {}
  }

  static final _decisionVerbs = RegExp(
    r'\b(decided|agreed|promised|will|need to|plan to|scheduled|committed)\b',
    caseSensitive: false,
  );

  /// Known people for novelty scoring, learned from past commitment
  /// counterparties. Lowercased names only — never transcript content.
  Set<String> _knownPeople() {
    try {
      final box = Hive.box(Boxes.conversation);
      final raw = box.get('proactiveKnownPeople');
      if (raw is List) {
        return raw.whereType<String>().toSet();
      }
    } catch (_) {}
    return {};
  }

  void _learnPeople(Iterable<AgentCommitment> commitments) {
    try {
      final box = Hive.box(Boxes.conversation);
      final known = _knownPeople();
      var changed = false;
      for (final c in commitments) {
        final person = c.person?.trim().toLowerCase() ?? '';
        if (person.isNotEmpty && known.add(person)) changed = true;
      }
      if (changed) {
        final pruned = known.length > 200
            ? known.skip(known.length - 200).toSet()
            : known;
        box.put('proactiveKnownPeople', pruned.toList());
      }
    } catch (_) {}
  }

  /// Persisted importance per memory (session id -> score), pruned to the
  /// newest 100. Feeds the morning digest without re-reading transcripts.
  void _recordScore(String sessionId, int score) {
    try {
      final box = Hive.box(Boxes.conversation);
      final raw = box.get('proactiveScores');
      final map = Map<String, dynamic>.from(raw is Map ? raw : {});
      map[sessionId] = score;
      while (map.length > 100) {
        map.remove(map.keys.first);
      }
      box.put('proactiveScores', map);
    } catch (_) {}
  }

  void _stashForDigest(String sessionId) {
    try {
      final box = Hive.box(Boxes.conversation);
      final raw = box.get('proactiveDigestPending');
      final pending = <String>[];
      if (raw is List) pending.addAll(raw.whereType<String>());
      if (!pending.contains(sessionId)) {
        pending.add(sessionId);
        while (pending.length > 20) {
          pending.removeAt(0);
        }
        box.put('proactiveDigestPending', pending);
      }
    } catch (_) {}
  }

  /// Whether an already-scored memory pings right now. Every close with
  /// important content notifies — no daily count, no minimum gap. Guards
  /// that remain: master switch, already-notified (retries/drains must
  /// never double-ping), quiet hours (held for digest), threshold.
  static bool shouldNotifyImmediately({
    required int score,
    required bool alreadyNotified,
    required bool quietNow,
    required bool enabled,
  }) {
    if (!enabled) return false;
    if (alreadyNotified) return false;
    if (score < ImportanceThresholds.digest) return false;
    if (quietNow) return false;
    return true;
  }

  /// Whether a closed memory gets the "it ended" ping: speech was
  /// captured, master switch on, outside quiet hours. No AI, no caps.
  static bool shouldNotifyEnded({
    required bool hasSegments,
    required bool quietNow,
    required bool enabled,
  }) {
    if (!enabled) return false;
    if (!hasSegments) return false;
    if (quietNow) return false;
    return true;
  }

  /// "Memory saved" ping at close time: duration + segment count only, no
  /// transcript or summary in the shade. Works with no API key and no
  /// network. Fire-and-forget; all failures are silent by design.
  Future<void> notifySessionEnded({
    required String sessionId,
    required int segmentCount,
    required int durationMin,
    bool enabled = true,
  }) async {
    if (!shouldNotifyEnded(
      hasSegments: segmentCount > 0,
      quietNow: inQuietHours(now: DateTime.now()),
      enabled: enabled,
    )) {
      return;
    }
    try {
      await _plugin.show(
        id: sessionId.hashCode ^ 0x9e37,
        title: 'Memory saved',
        body: '$durationMin min · $segmentCount segment${segmentCount == 1 ? '' : 's'}',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: sessionId,
      );
    } catch (e) {
      debugPrint('[tanu] ended ping failed: $e');
    }
  }

  Future<ProactiveKind?> maybeNotify({
    required ConversationSession session,
    required MemoryResult result,
    bool enabled = true,
  }) async {
    if (!enabled) {
      debugPrint('[tanu] proactive skipped: master switch off');
      return null;
    }
    final scored = scoreMemoryImportance(
      commitments: result.commitments,
      summary: result.summary,
      knownPeople: _knownPeople(),
    );
    _recordScore(session.id, scored.score);
    _learnPeople(result.commitments);
    debugPrint(
      '[tanu] proactive score=${scored.score} reasons=${scored.reasons}',
    );

    if (scored.score < ImportanceThresholds.digest) {
      debugPrint('[tanu] proactive skipped: below digest threshold');
      return null;
    }

    // Every close with important content pings: no daily count, no gap.
    // Retries and drains re-run scoring freely; the notified set below is
    // what keeps each memory to exactly one ping.
    final quietNow = inQuietHours(now: DateTime.now());
    final alreadyNotified = _wasNotified(session.id);
    if (!ProactiveService.shouldNotifyImmediately(
      score: scored.score,
      alreadyNotified: alreadyNotified,
      quietNow: quietNow,
      enabled: enabled,
    )) {
      if (!alreadyNotified && enabled) {
        // Blocked only by quiet hours: held for the digest, never dropped.
        _stashForDigest(session.id);
        debugPrint('[tanu] proactive held for digest: quiet hours');
      } else {
        debugPrint(
          '[tanu] proactive skipped: already notified or master off',
        );
      }
      return null;
    }

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
      debugPrint(
        '[tanu] proactive skipped: no commitments and summary too short/generic',
      );
      return null;
    }

    // Commitments get their own channel so they stand apart from
    // generic insights in the shade and in channel settings.
    final channelId = kind == ProactiveKind.commitment
        ? _commitmentsChannelId
        : _channelId;
    final channelName = kind == ProactiveKind.commitment
        ? _commitmentsChannelName
        : _channelName;
    try {
      await _plugin.show(
        id: session.id.hashCode,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: session.id,
      );
      _markNotified(session.id);
      return kind;
    } catch (e) {
      debugPrint('[tanu] proactive notify failed: $e');
      return null;
    }
  }

  /// Morning digest: up to 3 stashed memories as one summary notification.
  /// Runs opportunistically (first memory processed after [digestHour] when
  /// none was sent today). Returns true when anything showed. Content is the
  /// same title/summary text the cards already carry — never logged.
  Future<bool> maybeSendDigest({
    required List<ConversationSession> sessions,
    DateTime? now,
    int digestHour = 8,
    bool enabled = true,
  }) async {
    if (!enabled) return false;
    final at = now ?? DateTime.now();
    if (at.hour < digestHour) return false;
    try {
      final box = Hive.box(Boxes.conversation);
      final today = DateTime(at.year, at.month, at.day);
      final sentRaw = box.get('proactiveDigestDay') as String?;
      if (sentRaw != null && DateTime.tryParse(sentRaw) == today) {
        return false;
      }
      final raw = box.get('proactiveDigestPending');
      final pending = <String>[];
      if (raw is List) pending.addAll(raw.whereType<String>());
      if (pending.isEmpty) return false;

      final scoresRaw = box.get('proactiveScores');
      final scores = scoresRaw is Map
          ? Map<String, dynamic>.from(scoresRaw)
          : <String, dynamic>{};
      pending.sort((a, b) =>
          ((scores[b] as int?) ?? 0).compareTo((scores[a] as int?) ?? 0));
      final top = pending.take(3).toList();
      final byId = {for (final s in sessions) s.id: s};
      final lines = <String>[];
      for (final id in top) {
        final target = byId[id];
        if (target == null) continue;
        final title = target.title.trim().isEmpty
            ? 'Untitled memory'
            : target.title.trim();
        lines.add('\u2022 $title');
      }
      if (lines.isEmpty) {
        box.put('proactiveDigestDay', today.toIso8601String());
        box.put('proactiveDigestPending', <String>[]);
        return false;
      }
      await _plugin.show(
        id: -2,
        title: 'Your morning memory digest',
        body: lines.join('\n'),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _digestChannelId,
            _digestChannelName,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: top.first,
      );
      box.put('proactiveDigestDay', today.toIso8601String());
      box.put(
        'proactiveDigestPending',
        pending.where((id) => !top.contains(id)).toList(),
      );
      return true;
    } catch (e) {
      debugPrint('[tanu] digest failed: $e');
      return false;
    }
  }
}
