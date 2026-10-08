import '../agent/gemini_agent_engine.dart';

/// Importance thresholds for notification decisions.
class ImportanceThresholds {
  ImportanceThresholds._();

  /// Score at or above this notifies immediately (caps/quiet hours still win).
  static const int immediate = 80;

  /// Scores here and above are digest candidates; below is silent.
  static const int digest = 40;

  /// Quiet hours (local time): immediate pushes are held for the digest.
  static const int quietStartHour = 22;
  static const int quietEndHour = 7;
}

/// Scored importance of one processed memory. Pure data, safe to log:
/// reasons are fixed enum strings, never memory content.
typedef ImportanceScore = ({int score, List<String> reasons});

/// Scores a processed memory 0-100 for notification worthiness. Pure:
/// same inputs always give the same score, no I/O, no network.
ImportanceScore scoreMemoryImportance({
  required List<AgentCommitment> commitments,
  required String summary,
  String transcript = '',
  Set<String> knownPeople = const {},
}) {
  var score = 0;
  final reasons = <String>[];

  var commitmentPoints = 0;
  for (final c in commitments) {
    if (!c.isCommitment || (c.action?.isEmpty ?? true)) continue;
    commitmentPoints += 40;
    final person = c.person?.trim() ?? '';
    if (person.isNotEmpty) {
      commitmentPoints += 10;
      if (!knownPeople.contains(person.toLowerCase())) {
        commitmentPoints += 10;
        reasons.add('new-person');
      } else {
        reasons.add('commitment');
      }
    }
    if ((c.due?.trim().isNotEmpty ?? false)) {
      commitmentPoints += 10;
      reasons.add('dated');
    }
    if (commitmentPoints >= 80) break;
  }
  if (commitmentPoints > 0) {
    score += commitmentPoints > 80 ? 80 : commitmentPoints;
    if (!reasons.contains('commitment') && !reasons.contains('new-person')) {
      reasons.add('commitment');
    }
  }

  final haystack = '$summary\n$transcript'.toLowerCase();
  if (_decisionVerbs.hasMatch(haystack)) {
    score += 30;
    reasons.add('decision-language');
  }

  if (summary.trim().length >= 60) {
    score += 10;
    reasons.add('substantive');
  }

  // Repeat topics decay: a memory echoing only already-known people with
  // no new commitment and no decision language stays quiet.
  if (reasons.isEmpty) {
    return (score: 0, reasons: const ['routine']);
  }
  if (score > 100) score = 100;
  return (score: score, reasons: List.unmodifiable(reasons));
}

final _decisionVerbs = RegExp(
  r'\b(decided|agreed|promised|will|need to|plan to|scheduled|committed|'
  r'deadline|launch|meeting|follow up|action item)\b',
  caseSensitive: false,
);

/// True inside local quiet hours (default 10pm-7am). Pure in [now] so it is
/// unit-testable; production passes the current time.
bool inQuietHours({
  required DateTime now,
  int startHour = ImportanceThresholds.quietStartHour,
  int endHour = ImportanceThresholds.quietEndHour,
}) {
  final hour = now.hour;
  if (startHour <= endHour) {
    return hour >= startHour && hour < endHour;
  }
  return hour >= startHour || hour < endHour;
}
