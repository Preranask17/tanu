import 'package:flutter_test/flutter_test.dart';
import 'package:tanu_app/config/stt_config.dart';
import 'package:tanu_app/services/stt/indic_stt_engine.dart';

void main() {
  group('Indic language table', () {
    test('covers the documented South-Indian languages plus Hindi', () {
      final codes = SttConfig.indicLanguages.map((e) => e.code).toSet();
      expect(codes, containsAll({'hi', 'kn', 'ta', 'te', 'ml'}));
    });

    test('codes are unique and labels non-empty', () {
      final codes = SttConfig.indicLanguages.map((e) => e.code).toList();
      expect(codes.toSet().length, codes.length);
      for (final entry in SttConfig.indicLanguages) {
        expect(entry.label, isNotEmpty);
      }
    });

    test('lookup resolves labels and rejects unknown codes', () {
      expect(SttConfig.indicLabelFor('hi'), 'Hindi');
      expect(SttConfig.indicLabelFor('ta'), 'Tamil');
      expect(SttConfig.indicLabelFor(''), isNull);
      expect(SttConfig.indicLabelFor('xx'), isNull);
    });
  });

  group('IndicSttEngine core', () {
    test('constructs warming with a language-specific label', () {
      final engine = IndicSttEngine(
        languageCode: 'hi',
        languageLabel: 'Hindi',
      );
      expect(engine.languageCode, 'hi');
      expect(engine.modelLabel, 'Whisper Small · Hindi');
      expect(engine.warmingUp.value, isTrue);
      expect(engine.hasActiveUtterance, isFalse);
    });

    test('label tracks the requested language', () {
      final engine = IndicSttEngine(
        languageCode: 'kn',
        languageLabel: 'Kannada',
      );
      expect(engine.modelLabel, contains('Kannada'));
    });
  });
}
