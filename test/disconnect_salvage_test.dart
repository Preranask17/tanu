import 'package:flutter_test/flutter_test.dart';
import 'package:tanu_app/models/transcript.dart';
import 'package:tanu_app/providers/conversation_provider.dart';
import 'package:tanu_app/services/stt/stt_worker_utils.dart';

TranscriptSegment seg(String id, String text, {int? endMs}) =>
    TranscriptSegment(
      id: id,
      text: text,
      timestamp: DateTime(2026, 1, 1),
      endMs: endMs,
    );

void main() {
  group('lockLiveTail: disconnect never drops the visible tail', () {
    test('empty live text changes nothing', () {
      final segs = [seg('s-0', 'hello', endMs: 100)];
      expect(
        ConversationNotifier.lockLiveTail(
          segments: segs,
          liveTranscript: '   ',
          sessionId: 's',
          nowMs: 200,
        ),
        same(segs),
      );
    });

    test('open segment gets locked with the tail text', () {
      final out = ConversationNotifier.lockLiveTail(
        segments: [seg('s-0', 'hel')],
        liveTranscript: 'hello world',
        sessionId: 's',
        nowMs: 200,
      );
      expect(out, hasLength(1));
      expect(out.single.text, 'hello world');
      expect(out.single.endMs, 200);
    });

    test('closed list gains exactly one tail segment, never duplicates', () {
      final out = ConversationNotifier.lockLiveTail(
        segments: [seg('s-0', 'first', endMs: 100)],
        liveTranscript: 'second half',
        sessionId: 's',
        nowMs: 200,
      );
      expect(out.map((e) => e.text), ['first', 'second half']);
      expect(out.last.endMs, 200);
    });

    test('no segments + tail creates the first one', () {
      final out = ConversationNotifier.lockLiveTail(
        segments: [],
        liveTranscript: 'only words',
        sessionId: 's',
        nowMs: 50,
      );
      expect(out, hasLength(1));
      expect(out.single.text, 'only words');
    });
  });

  group('splitDecodeWindows: bounded decodes, zero loss', () {
    test('short input passes through untouched', () {
      final out = splitDecodeWindows([1.0, 2.0, 3.0], 10);
      expect(out, hasLength(1));
      expect(out.single, [1.0, 2.0, 3.0]);
    });

    test('long input splits into bounded pieces in order', () {
      final samples = List.generate(25, (i) => i.toDouble());
      final out = splitDecodeWindows(samples, 10);
      expect(out.map((w) => w.length), [10, 10, 5]);
      expect(out.expand((w) => w).toList(), samples);
    });
  });
}
