import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import '../../constants.dart';

/// Thin wrapper around the PostHog singleton.
///
/// Tanu records a user's voice, so this service is deny-by-default. Everything
/// funnels through [AnalyticsService.beforeSend], which drops any event outside
/// `allowedEvents` and any property outside `allowedPropertyKeys`. Transcript
/// text, memory titles/summaries and device identifiers must never leave the
/// phone — see `test/analytics_redaction_test.dart`, which is what guards that
/// claim.
///
/// The SDK is inert unless a project token was supplied at build time, and
/// `capture`/`screen` are no-ops before [init] finishes, so instrumentation can
/// be sprinkled through the app without any ordering concerns.
class AnalyticsService {
  /// The complete set of events this app is allowed to emit. Anything else is
  /// dropped by [beforeSend] — add the event here *and* document its
  /// properties when you need it.
  static const Set<String> allowedEvents = {
    'screen viewed',
    'pendant connected',
    'pendant disconnected',
    'session started',
    'session ended',
    'memory processed',
    'stt model downloaded',
    'stt model failed',
    'stt model deleted',
    'setting changed',
    'commitment added',
    'memory retry queued',
    'memory retry succeeded',
    'memory retry gave up',
    'proactive notified',
    'speaker model downloaded',
    'speaker model failed',
  };

  /// The complete set of property keys this app is allowed to send, matched
  /// case-insensitively.
  ///
  /// An allowlist rather than a denylist, because a denylist of "words that
  /// look like user content" is wrong in both directions: it strips legitimate
  /// aggregates (`segment_count`, `has_person`) while still admitting anything
  /// a new event invents (`text_body`, `who`, `macAddress`). Here an unlisted
  /// key cannot leave the phone at all.
  ///
  /// Every value is a shape — a count, a duration, a boolean, or an enum-like
  /// label. The only free-text values are the `close_reason` / `reason` /
  /// `screen` / `setting` / `value` enums, which are literals in this codebase
  /// and never user input.
  static const Set<String> allowedPropertyKeys = {
    // 'screen viewed'
    'screen',
    // 'pendant connected' / 'pendant disconnected' / 'session started'
    'codec', 'battery_pct', 'simulated',
    // 'session started' — the engine's own label, e.g. 'Whisper Small ·
    // 375 MB', never a path or a file name.
    'stt_model',
    // 'session ended'
    'close_reason', 'segment_count', 'duration_s',
    // 'memory processed'
    'commitment_count', 'has_summary',
    // 'memory processed' — structured-pipeline aggregates: turn/speaker
    // counts and whether speakers were measured acoustically. Counts and a
    // boolean only; speaker names and transcript text can never be keys.
    'turn_count', 'speaker_count', 'diarized',
    // 'stt model downloaded' / 'stt model failed'
    'bytes', 'reason',
    // 'setting changed'
    'setting', 'value',
    // 'commitment added'
    'source', 'has_due', 'has_person',
    // 'memory retry queued'
    'error',
    // 'proactive notified'
    'kind',
  };

  /// Non-null while [init] is running or has completed successfully. Captures
  /// chain off this future so an event raised during setup is not lost.
  Future<void>? _ready;
  bool _enabled = false;

  /// True once PostHog is capturing. Exposed for the Settings debug console.
  bool get isActive => _enabled;

  /// Initialises the SDK. Safe to call more than once; later calls are no-ops.
  ///
  /// Bails out (leaving the service inert) when no project token was supplied,
  /// when running under `flutter test` — the SDK forces its method channel open
  /// under `FLUTTER_TEST` and would throw `MissingPluginException`, which it
  /// does not catch — or on Linux/Windows, which have no native PostHog.
  Future<void> init() async {
    if (_ready != null) return _ready;

    if (kPostHogToken.isEmpty) {
      debugPrint('[tanu] analytics: no POSTHOG_TOKEN, staying inert');
      return;
    }
    if (kIsWeb) {
      debugPrint('[tanu] analytics: skipped on web');
      return;
    }
    if (Platform.environment['FLUTTER_TEST'] == 'true') {
      debugPrint('[tanu] analytics: skipped in tests');
      return;
    }
    if (Platform.isLinux || Platform.isWindows) {
      debugPrint('[tanu] analytics: unsupported platform, staying inert');
      return;
    }

    final ready = _setup();
    _ready = ready;
    return ready;
  }

  Future<void> _setup() async {
    final config = PostHogConfig(kPostHogToken)
      ..host = kPostHogHost
      ..debug = kDebugMode
      // Tanu has no sign-in, so stay anonymous: no person profiles are created
      // and no individual is identifiable from the event stream.
      ..personProfiles = PostHogPersonProfiles.identifiedOnly
      // App Opened / Backgrounded / Installed come for free from this. Note
      // these are native-initiated and so bypass `beforeSend` — they carry no
      // user content, only OS metadata.
      ..captureApplicationLifecycleEvents = true
      // Never record the UI: this app is a transcript viewer, and a replay
      // would capture the user's own words on screen.
      ..sessionReplay = false
      ..beforeSend = [beforeSend];

    try {
      await Posthog().setup(config);
      _enabled = true;
      debugPrint('[tanu] analytics: ready ($kPostHogHost)');
    } catch (e) {
      // Analytics must never take the audio pipeline down with it.
      debugPrint('[tanu] analytics: setup failed, staying inert: $e');
    }
  }

  /// Records a custom event. Fire-and-forget; a PostHog failure is logged and
  /// swallowed so it can never interrupt capture.
  void capture(String event, {Map<String, Object?>? properties}) {
    final ready = _ready;
    if (ready == null) return;
    unawaited(
      ready.then((_) => _send(event, properties)).catchError((Object e) {
        debugPrint('[tanu] analytics: $event skipped: $e');
      }),
    );
  }

  Future<void> _send(String event, Map<String, Object?>? properties) async {
    if (!_enabled) return;
    try {
      await Posthog().capture(
        eventName: event,
        properties: _toPostHogProperties(properties),
      );
    } catch (e) {
      debugPrint('[tanu] analytics: $event failed: $e');
    }
  }

  /// PostHog wants a non-nullable value map. Nulls are dropped rather than
  /// coerced, so a conditional property (`if (finishedAt != null) 'duration_s'`)
  /// simply does not appear.
  static Map<String, Object>? _toPostHogProperties(Map<String, Object?>? src) {
    if (src == null || src.isEmpty) return null;
    final out = <String, Object>{};
    src.forEach((key, value) {
      if (value != null) out[key] = value;
    });
    return out;
  }

  /// Records a screen view.
  ///
  /// Tanu navigates with an `IndexedStack` and unnamed `MaterialPageRoute`s, so
  /// PostHog's `PosthogObserver` cannot see any of it. Screens are reported
  /// explicitly instead.
  void screen(String name) {
    capture('screen viewed', properties: {'screen': name});
  }

  /// Flushes anything queued and releases the SDK.
  ///
  /// No-op when [init] bailed out, so this never touches the method channel on
  /// a platform where PostHog was never set up.
  Future<void> close() async {
    if (_ready == null) return;
    _enabled = false;
    _ready = null;
    try {
      await Posthog().close();
    } catch (e) {
      debugPrint('[tanu] analytics: close failed: $e');
    }
  }

  /// The single chokepoint every Dart-side event passes through.
  ///
  /// Drops events not in [allowedEvents], and drops any property whose key is
  /// not in [allowedPropertyKeys]. This is allowlist-first end to end: a future
  /// careless `capture()` cannot leak, it can only be silently dropped.
  ///
  /// Person properties are always cleared — Tanu has no sign-in, so nothing
  /// should ever be attributed to an identified individual.
  ///
  /// Exposed for testing. Does not intercept native lifecycle events.
  static PostHogEvent? beforeSend(PostHogEvent event) {
    if (!allowedEvents.contains(event.event)) {
      debugPrint('[tanu] analytics: dropped "${event.event}" (not allowed)');
      return null;
    }

    event.userProperties = null;
    event.userPropertiesSetOnce = null;

    final properties = event.properties;
    if (properties == null || properties.isEmpty) return event;

    final kept = <String, Object>{};
    properties.forEach((key, value) {
      if (!allowedPropertyKeys.contains(key.toLowerCase())) {
        debugPrint('[tanu] analytics: stripped "$key" from "${event.event}"');
        return;
      }
      kept[key] = value;
    });
    event.properties = kept;
    return event;
  }
}
