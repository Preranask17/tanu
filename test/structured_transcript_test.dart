import 'package:flutter_test/flutter_test.dart';
import 'package:tanu_app/models/transcript.dart';
import 'package:tanu_app/providers/conversation_provider.dart';

/// Guards the structured memory-processor input: timestamped lines, pause
/// markers, and speaker tags. This is the structure the old flat
/// space-joined blob destroyed — if the format regresses, the LLM goes back
/// to guessing turns from punctuation.
ConversationSession _session(List<TranscriptSegment> segments) {
  return ConversationSession(
    id: 's1',
    title: '',
    startedAt: DateTime(2026, 1, 1),
    segments: segments,
  );
}

TranscriptSegment _seg(String id, String text, int startMs, [int? endMs]) {
  return TranscriptSegment(
    id: id,
    text: text,
    timestamp: DateTime(2026, 1, 1),
    startMs: startMs,
    endMs: endMs,
  );
}

void main() {
  group('ConversationNotifier.buildStructuredInput', () {
    test('renders timestamped lines with unknown-speaker tags', () {
      final out = ConversationNotifier.buildStructuredInput(
        _session([
          _seg('a', 'hello there', 12000, 18000),
          _seg('b', 'hi back', 22000, 31000),
        ]),
      );

      expect(out, contains('[00:12-00:18] [?] hello there'));
      expect(out, contains('[00:22-00:31] [?] hi back'));
    });

    test('inserts pause markers for 2s+ gaps only', () {
      final out = ConversationNotifier.buildStructuredInput(
        _session([
          _seg('a', 'first', 0, 1000),
          _seg('b', 'second', 1500, 2500),
          _seg('c', 'third', 6000, 7000),
        ]),
      );

      expect(out, isNot(contains('[pause 0.5s]')));
      expect(out, contains('[pause 3.5s]'));
    });

    test('trusts acoustic speaker tags from diarization', () {
      final out = ConversationNotifier.buildStructuredInput(
        _session([
          _seg('a', 'i will go', 0, 2000).copyWith(speaker: 'You'),
          _seg('b', 'i will stay', 3000, 5000).copyWith(speaker: 'Other 1'),
        ]),
      );

      expect(out, contains('[You] i will go'));
      expect(out, contains('[Other 1] i will stay'));
      expect(out, isNot(contains('[?]')));
    });

    test('skips empty segments and trims whitespace', () {
      final out = ConversationNotifier.buildStructuredInput(
        _session([
          _seg('a', '   ', 0, 1000),
          _seg('b', '  real words  ', 2000, 3000),
        ]),
      );

      expect(out, '[00:02-00:03] [?] real words');
    });

    test('empty session produces empty input', () {
      expect(
        ConversationNotifier.buildStructuredInput(_session(const [])),
        isEmpty,
      );
    });

    test('open segments use start as end', () {
      final out = ConversationNotifier.buildStructuredInput(
        _session([_seg('a', 'talking', 61000)]),
      );

      expect(out, contains('[01:01-01:01]'));
    });
  });
}
