import 'package:flutter_test/flutter_test.dart';
import 'package:tanu_app/models/conversation.dart';

void main() {
  group('ConversationState.processingIds', () {
    test('defaults to empty', () {
      expect(const ConversationState().processingIds, isEmpty);
    });

    test('copyWith sets and clears ids independently', () {
      const base = ConversationState();
      final marked = base.copyWith(processingIds: {'a', 'b'});
      expect(marked.processingIds, {'a', 'b'});
      // Other fields untouched, original unmodified.
      expect(base.processingIds, isEmpty);
      expect(marked.liveTranscript, base.liveTranscript);

      final cleared = marked.copyWith(
        processingIds: marked.processingIds.difference({'a'}),
      );
      expect(cleared.processingIds, {'b'});
    });
  });
}
