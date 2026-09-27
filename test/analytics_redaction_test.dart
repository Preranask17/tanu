import 'package:flutter_test/flutter_test.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:tanu_app/services/analytics/analytics_service.dart';

/// These are the tests that make the privacy claim in
/// `lib/services/analytics/analytics_service.dart` true. Tanu transcribes a
/// user's voice, so anything that reaches PostHog goes through
/// [AnalyticsService.beforeSend] first — and that hook is allowlist-first: an
/// event or property that is not explicitly permitted is dropped, not
/// filtered. If one of these fails, user content is leaking.
void main() {
  group('AnalyticsService.beforeSend', () {
    test('passes an allowed event with clean properties through', () {
      final event = PostHogEvent(
        event: 'session ended',
        properties: {'close_reason': 'idle', 'segment_count': 12},
      );

      final result = AnalyticsService.beforeSend(event);

      expect(result, isNotNull);
      expect(result!.event, 'session ended');
      expect(result.properties, {'close_reason': 'idle', 'segment_count': 12});
    });

    test('drops an event that is not on the allowlist', () {
      final event = PostHogEvent(
        event: 'transcript captured',
        properties: {'text': 'my bank password is hunter2'},
      );

      expect(AnalyticsService.beforeSend(event), isNull);
    });

    test('strips transcript-shaped property keys', () {
      final event = PostHogEvent(
        event: 'memory processed',
        properties: {
          'commitment_count': 2,
          'transcript': 'remember to call the dentist',
          'rawText': 'remember to call the dentist',
          'title': 'Dentist',
          'summary': 'The user needs a dentist',
        },
      );

      final result = AnalyticsService.beforeSend(event);

      expect(result, isNotNull);
      // Only the aggregate survives.
      expect(result!.properties, {'commitment_count': 2});
    });

    test('strips device identifier keys', () {
      final event = PostHogEvent(
        event: 'pendant connected',
        properties: {
          'codec': 'opus',
          'mac': 'AA:BB:CC:DD:EE:FF',
          'deviceId': 'remote-1234',
          'deviceName': "Mithil's pendant",
        },
      );

      final result = AnalyticsService.beforeSend(event);

      expect(result!.properties, {'codec': 'opus'});
    });

    test('strips user-property payloads so no person profile is written', () {
      final event = PostHogEvent(
        event: 'session started',
        properties: {'stt_model': 'SenseVoice'},
        userProperties: {'email': 'someone@example.com'},
        userPropertiesSetOnce: {'device_id': 'remote-1234'},
      );

      final result = AnalyticsService.beforeSend(event);

      expect(result!.userProperties, isNull);
      expect(result.userPropertiesSetOnce, isNull);
    });

    test('leaves an event with no properties alone', () {
      final event = PostHogEvent(event: 'stt model deleted');

      final result = AnalyticsService.beforeSend(event);

      expect(result, isNotNull);
      expect(result!.properties, isNull);
    });

    test('keeps the aggregate properties the funnel is made of', () {
      // Regression guard: an earlier substring-based denylist stripped
      // segment_count / has_person / has_summary because they *contained* the
      // words segment / person / summary, which silently gutted the funnel
      // while looking like it was protecting it.
      final ended = AnalyticsService.beforeSend(
        PostHogEvent(
          event: 'session ended',
          properties: {
            'close_reason': 'idle',
            'segment_count': 7,
            'duration_s': 94,
          },
        ),
      );
      expect(ended!.properties, {
        'close_reason': 'idle',
        'segment_count': 7,
        'duration_s': 94,
      });

      final memory = AnalyticsService.beforeSend(
        PostHogEvent(
          event: 'memory processed',
          properties: {'commitment_count': 2, 'has_summary': true},
        ),
      );
      expect(memory!.properties, {'commitment_count': 2, 'has_summary': true});

      final commitment = AnalyticsService.beforeSend(
        PostHogEvent(
          event: 'commitment added',
          properties: {'source': 'agent', 'has_due': true, 'has_person': false},
        ),
      );
      expect(commitment!.properties, {
        'source': 'agent',
        'has_due': true,
        'has_person': false,
      });
    });

    test('every key emitted by the app is on the property allowlist', () {
      // Guards the same way the event test does for names, but the set of
      // emitted keys is the one this suite knows about rather than a
      // hand-written mirror of the allowlist — a mirror just agrees with itself
      // and catches nothing. This is how 'stt_model' was found being silently
      // dropped: it was emitted by 'session started' and not on the list.
      const emitted = {
        'screen',
        'codec',
        'battery_pct',
        'simulated',
        'stt_model',
        'close_reason',
        'segment_count',
        'duration_s',
        'commitment_count',
        'has_summary',
        'bytes',
        'reason',
        'setting',
        'value',
        'source',
        'has_due',
        'has_person',
      };

      final unused = emitted.difference(AnalyticsService.allowedPropertyKeys);
      expect(
        unused,
        isEmpty,
        reason:
            'these keys are emitted but not on the property allowlist, so '
            'they are being silently dropped: $unused',
      );
    });

    test('an emitted key missing from the allowlist is actually dropped', () {
      // Proves the failure mode above is real rather than theoretical: the
      // symptom is a working-looking event with a silent hole in it.
      final event = PostHogEvent(
        event: 'session started',
        properties: {'stt_model': 'SenseVoice', 'not_allowlisted': 'value'},
      );

      final result = AnalyticsService.beforeSend(event);

      expect(result!.properties, {'stt_model': 'SenseVoice'});
    });

    test('every advertised event is on the allowlist', () {
      // Guards against an event being emitted but silently dropped: if you add
      // a capture() call, add the name here and to allowedEvents.
      const emitted = [
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
      ];

      for (final name in emitted) {
        expect(
          AnalyticsService.allowedEvents.contains(name),
          isTrue,
          reason: '"$name" is emitted but not on the allowlist',
        );
      }
    });
  });

  group('AnalyticsService is inert without a token', () {
    test('capture is a no-op and nothing is sent', () async {
      // No --dart-define=POSTHOG_TOKEN in the test environment, so init() bails
      // and _ready stays null. capture() must not throw or touch the SDK.
      final analytics = AnalyticsService();
      await analytics.init();

      expect(analytics.isActive, isFalse);
      // Would throw or hit a missing method channel if this were not guarded.
      analytics.capture('session started', properties: {'segment_count': 1});
      analytics.screen('capture');
      await analytics.close();
    });
  });
}
