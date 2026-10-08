import 'package:flutter_test/flutter_test.dart';
import 'package:tanu_app/providers/conversation_provider.dart';

void main() {
  group('isBusinessCloseUtterance', () {
    test('end-anchored closers match with enough segments', () {
      expect(
        ConversationNotifier.isBusinessCloseUtterance(
          "let's continue this next time",
          3,
        ),
        isTrue,
      );
      expect(
        ConversationNotifier.isBusinessCloseUtterance(
          'we will pick up this tomorrow',
          2,
        ),
        isTrue,
      );
    });

    test('mid-sentence mentions do not match', () {
      expect(
        ConversationNotifier.isBusinessCloseUtterance(
          "let's continue this next time we meet about budgets",
          5,
        ),
        isFalse,
      );
      expect(
        ConversationNotifier.isBusinessCloseUtterance(
          'we will pick up this tomorrow after the demo, then review',
          5,
        ),
        isFalse,
      );
    });

    test('needs at least two segments', () {
      expect(
        ConversationNotifier.isBusinessCloseUtterance(
          "let's continue this next time",
          1,
        ),
        isFalse,
      );
    });
  });
}
