import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../../models/transcript.dart';
import '../../providers/settings_provider.dart';
import '../storage_service.dart';
import 'proactive_service.dart';

/// Background digest delivery: fires the morning digest even when the app
/// is closed, killed, or rebooted (WorkManager persists and reschedules
/// natively). Reuses [ProactiveService.maybeSendDigest] verbatim — no new
/// delivery logic, no backend, no analytics.
const String kDigestTaskName = 'tanu-morning-digest';
const String kDigestUniqueName = 'tanu-morning-digest-periodic';

@pragma('vm:entry-point')
void digestTaskCallback() {
  Workmanager().executeTask((task, inputData) async {
    bool ok = false;
    try {
      await StorageService.initialize();
      final settings = _readSettings();
      final plugin = await ProactiveService.init(onTap: (_) {});
      final sessions = _readSessions();
      await plugin.maybeSendDigest(
        sessions: sessions,
        digestHour: settings.digestHour,
        enabled: settings.notifyEnabled && settings.digestEnabled,
      );
      ok = true;
    } catch (e) {
      debugPrint('[tanu] digest task failed: $e');
    }
    return ok;
  });
}

AppSettings _readSettings() {
  try {
    final stored = Hive.box(Boxes.settings).get('settings');
    if (stored is Map) {
      return AppSettings.fromJson(Map<String, dynamic>.from(stored));
    }
  } catch (_) {}
  return const AppSettings(hasCompletedOnboarding: true);
}

List<ConversationSession> _readSessions() {
  try {
    final stored = Hive.box(Boxes.conversation).get('sessions');
    if (stored is List) {
      return stored
          .whereType<Map>()
          .map(
            (e) => ConversationSession.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    }
  } catch (_) {}
  return [];
}

/// Delay from [now] until the next [digestHour] today (or tomorrow if it
/// already passed). Pure, unit-tested.
Duration nextDigestDelay(DateTime now, int digestHour) {
  var target = DateTime(now.year, now.month, now.day, digestHour);
  if (!target.isAfter(now)) {
    target = target.add(const Duration(days: 1));
  }
  return target.difference(now);
}

/// (Re)registers the daily digest worker. Safe to call on every launch and
/// hour change: unique work + replace policy means exactly one schedule.
/// No-ops on web and on any plugin error — digest stays opportunistic.
Future<void> scheduleDigestWorker({required int digestHour}) async {
  if (kIsWeb) return;
  try {
    await Workmanager().initialize(digestTaskCallback, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(
      kDigestUniqueName,
      kDigestTaskName,
      frequency: const Duration(hours: 24),
      initialDelay: nextDigestDelay(DateTime.now(), digestHour),
      constraints: Constraints(
        networkType: NetworkType.notRequired,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  } catch (e) {
    debugPrint('[tanu] digest schedule failed: $e');
  }
}
