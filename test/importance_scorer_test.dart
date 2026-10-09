import 'package:flutter_test/flutter_test.dart';
import 'package:tanu_app/services/agent/gemini_agent_engine.dart';
import 'package:tanu_app/services/proactive/importance_scorer.dart';
import 'package:tanu_app/services/proactive/proactive_service.dart';

AgentCommitment commitment(
  String action, {
  String? person,
  String? due,
}) =>
    AgentCommitment(
      isCommitment: true,
      action: action,
      person: person,
      due: due,
    );

void main() {
  immediateDecisionTests();
  endedPingTests();

  group('scoreMemoryImportance', () {
    test('dated commitment to a new person scores immediate', () {
      final scored = scoreMemoryImportance(
        commitments: [
          commitment('Send the report to Ramesh by Friday',
              person: 'Ramesh', due: '2026-10-10'),
        ],
        summary: 'Team agreed the launch deadline is Friday.',
      );
      expect(scored.score, greaterThanOrEqualTo(80));
      expect(scored.reasons, contains('dated'));
    });

    test('chitchat stays silent', () {
      final scored = scoreMemoryImportance(
        commitments: [],
        summary: 'Talked about lunch and the weather for a while.',
      );
      expect(scored.score, lessThan(40));
      expect(scored.reasons, contains('routine'));
    });

    test('decision language without commitments reaches digest', () {
      final scored = scoreMemoryImportance(
        commitments: [],
        summary:
            'We decided the launch deadline is Friday and Ramesh will own the final report going forward.',
      );
      expect(scored.score, greaterThanOrEqualTo(40));
      expect(scored.score, lessThan(80));
      expect(scored.reasons, contains('decision-language'));
    });

    test('repeat topics with known people score lower', () {
      List<AgentCommitment> one(String person) => [
            commitment('Sync up', person: person),
          ];
      final first = scoreMemoryImportance(
        commitments: one('Ramesh'),
        summary: 'Quick sync about the timeline.',
      );
      final repeat = scoreMemoryImportance(
        commitments: one('Ramesh'),
        summary: 'Quick sync about the timeline.',
        knownPeople: {'ramesh'},
      );
      expect(repeat.score, lessThan(first.score));
    });

    test('empty input scores zero', () {
      final scored = scoreMemoryImportance(
        commitments: [],
        summary: '',
      );
      expect(scored.score, 0);
    });
  });

  group('inQuietHours', () {
    DateTime at(int hour) => DateTime(2026, 10, 9, hour);

    test('night window holds', () {
      expect(inQuietHours(now: at(23)), isTrue);
      expect(inQuietHours(now: at(3)), isTrue);
      expect(inQuietHours(now: at(6)), isTrue);
    });

    test('daytime passes', () {
      expect(inQuietHours(now: at(7)), isFalse);
      expect(inQuietHours(now: at(12)), isFalse);
      expect(inQuietHours(now: at(21)), isFalse);
    });

    test('boundary hours', () {
      expect(inQuietHours(now: at(22)), isTrue);
    });
  });
}

void immediateDecisionTests() {
  group('shouldNotifyImmediately: every close pings', () {
    test('consecutive important memories both notify (no caps)', () {
      for (final id in ['m1', 'm2']) {
        expect(
          ProactiveService.shouldNotifyImmediately(
            score: 85,
            alreadyNotified: false,
            quietNow: false,
            enabled: true,
          ),
          isTrue,
          reason: id,
        );
      }
    });

    test('reprocess never double-pings', () {
      expect(
        ProactiveService.shouldNotifyImmediately(
          score: 100,
          alreadyNotified: true,
          quietNow: false,
          enabled: true,
        ),
        isFalse,
      );
    });

    test('quiet hours hold, master off and low scores stay silent', () {
      expect(
        ProactiveService.shouldNotifyImmediately(
          score: 90,
          alreadyNotified: false,
          quietNow: true,
          enabled: true,
        ),
        isFalse,
      );
      expect(
        ProactiveService.shouldNotifyImmediately(
          score: 90,
          alreadyNotified: false,
          quietNow: false,
          enabled: false,
        ),
        isFalse,
      );
      expect(
        ProactiveService.shouldNotifyImmediately(
          score: 20,
          alreadyNotified: false,
          quietNow: false,
          enabled: true,
        ),
        isFalse,
      );
    });
  });
}

void endedPingTests() {
  group('shouldNotifyEnded: every close pings', () {
    test('captured session outside quiet hours pings', () {
      expect(
        ProactiveService.shouldNotifyEnded(
          hasSegments: true,
          quietNow: false,
          enabled: true,
        ),
        isTrue,
      );
    });

    test('empty, quiet, or disabled stays silent', () {
      expect(
        ProactiveService.shouldNotifyEnded(
          hasSegments: false,
          quietNow: false,
          enabled: true,
        ),
        isFalse,
      );
      expect(
        ProactiveService.shouldNotifyEnded(
          hasSegments: true,
          quietNow: true,
          enabled: true,
        ),
        isFalse,
      );
      expect(
        ProactiveService.shouldNotifyEnded(
          hasSegments: true,
          quietNow: false,
          enabled: false,
        ),
        isFalse,
      );
    });
  });
}
