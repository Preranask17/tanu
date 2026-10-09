import 'package:flutter_test/flutter_test.dart';
import 'package:tanu_app/services/proactive/digest_task.dart';

void main() {
  group('nextDigestDelay', () {
    test('later today when the hour is ahead', () {
      final delay =
          nextDigestDelay(DateTime(2026, 10, 9, 6, 30), 8);
      expect(delay, const Duration(hours: 1, minutes: 30));
    });

    test('tomorrow when the hour already passed', () {
      final delay = nextDigestDelay(DateTime(2026, 10, 9, 9, 0), 8);
      expect(delay, const Duration(hours: 23));
    });

    test('exactly on the hour rolls to tomorrow', () {
      final delay = nextDigestDelay(DateTime(2026, 10, 9, 8, 0), 8);
      expect(delay, const Duration(hours: 24));
    });

    test('late night to morning hour', () {
      final delay = nextDigestDelay(DateTime(2026, 10, 9, 23, 15), 7);
      expect(delay, const Duration(hours: 7, minutes: 45));
    });

    test('custom hour respected', () {
      final delay = nextDigestDelay(DateTime(2026, 10, 9, 5, 0), 10);
      expect(delay, const Duration(hours: 5));
    });
  });
}
