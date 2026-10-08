import 'package:flutter_test/flutter_test.dart';
import 'package:tanu_app/screens/chat_screen.dart'
    show splitSummaryPoints;

void main() {
  group('splitSummaryPoints', () {
    test('splits on sentence boundaries', () {
      expect(
        splitSummaryPoints('Agreed Friday. Ramesh owns the report. Follow up tomorrow.'),
        ['Agreed Friday.', 'Ramesh owns the report.', 'Follow up tomorrow.'],
      );
    });

    test('single sentence stays whole', () {
      expect(splitSummaryPoints('Just one thought'), ['Just one thought']);
    });

    test('trims and drops empties', () {
      expect(splitSummaryPoints('  First.   Second!  '), ['First.', 'Second!']);
    });

    test('question marks split too', () {
      expect(
        splitSummaryPoints('Decided? Yes. Done.'),
        ['Decided?', 'Yes.', 'Done.'],
      );
    });
  });
}
