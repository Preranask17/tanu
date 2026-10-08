import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tanu_app/services/speakers/speaker_cluster.dart';

/// Guards the pure-Dart half of diarization: similarity math, window
/// building, greedy clustering, and the energy-based wearer call. The native
/// embedding model only produces voiceprints — every decision after that is
/// here, so it is all pinned by synthetic vectors.
List<double> _vec(List<double> values) => values;

void main() {
  group('SpeakerClusterer.cosine', () {
    test('identical vectors score 1', () {
      expect(SpeakerClusterer.cosine(_vec([1, 0, 0]), _vec([1, 0, 0])), 1.0);
    });

    test('orthogonal vectors score 0', () {
      expect(
        SpeakerClusterer.cosine(_vec([1, 0]), _vec([0, 1])),
        closeTo(0, 1e-9),
      );
    });

    test('opposite vectors score -1', () {
      expect(
        SpeakerClusterer.cosine(_vec([1, 2]), _vec([-1, -2])),
        closeTo(-1, 1e-9),
      );
    });

    test('scale-invariant', () {
      expect(
        SpeakerClusterer.cosine(_vec([1, 1]), _vec([5, 5])),
        closeTo(1, 1e-9),
      );
    });

    test('degenerate inputs score 0, never NaN', () {
      expect(SpeakerClusterer.cosine(const [], const []), 0);
      expect(SpeakerClusterer.cosine(_vec([0, 0]), _vec([0, 0])), 0);
      expect(SpeakerClusterer.cosine(_vec([1]), _vec([1, 2])), 0);
    });
  });

  group('SpeakerClusterer.rms', () {
    test('silence is zero, full-scale is ~1', () {
      expect(SpeakerClusterer.rms(Float32List(160)), 0);
      final loud = Float32List.fromList(List.filled(160, 1.0));
      expect(SpeakerClusterer.rms(loud), closeTo(1, 1e-9));
    });

    test('half amplitude halves the energy', () {
      final full = Float32List.fromList(List.filled(100, 1.0));
      final half = Float32List.fromList(List.filled(100, 0.5));
      expect(
        SpeakerClusterer.rms(full),
        closeTo(2 * SpeakerClusterer.rms(half), 1e-9),
      );
    });
  });

  group('SpeakerClusterer.cluster', () {
    test('groups near-duplicates, splits strangers', () {
      final clusters = SpeakerClusterer.cluster([
        _vec([1.0, 0.0, 0.0]),
        _vec([0.98, 0.02, 0.0]),
        _vec([0.0, 1.0, 0.0]),
      ], threshold: 0.45);

      expect(clusters.length, 2);
      expect(clusters[0], containsAll([0, 1]));
      expect(clusters[1], [2]);
    });

    test('empty input yields no clusters', () {
      expect(SpeakerClusterer.cluster(const []), isEmpty);
    });
  });

  group('SpeakerClusterer.buildWindows', () {
    test('merges short segments forward across small gaps', () {
      final windows = SpeakerClusterer.buildWindows([
        const SegmentRef(id: 'a', startMs: 0, endMs: 400),
        const SegmentRef(id: 'b', startMs: 600, endMs: 1200),
      ]);

      expect(windows.length, 1);
      expect(windows.first.segmentIds, ['a', 'b']);
      expect(windows.first.startMs, 0);
      expect(windows.first.endMs, 1200);
    });

    test('never merges across a 2.5s+ silence gap', () {
      final windows = SpeakerClusterer.buildWindows([
        const SegmentRef(id: 'a', startMs: 0, endMs: 1500),
        const SegmentRef(id: 'b', startMs: 5000, endMs: 6500),
      ]);

      expect(windows.length, 2);
      expect(windows.first.segmentIds, ['a']);
      expect(windows.last.segmentIds, ['b']);
    });

    test('splits over-long spans into capped windows', () {
      final windows = SpeakerClusterer.buildWindows([
        const SegmentRef(id: 'a', startMs: 0, endMs: 25000),
      ]);

      expect(windows.length, greaterThan(1));
      for (final w in windows) {
        expect(w.durationMs, lessThanOrEqualTo(10000));
      }
      expect(windows.first.startMs, 0);
      expect(windows.last.endMs, 25000);
    });

    test('drops zero-length segments', () {
      final windows = SpeakerClusterer.buildWindows([
        const SegmentRef(id: 'a', startMs: 1000, endMs: 1000),
      ]);

      expect(windows, isEmpty);
    });
  });

  group('SpeakerClusterer.assignLabels', () {
    SpeakerWindow window(
      List<String> ids,
      List<double> emb,
      double energy, {
      int start = 0,
      int end = 2000,
    }) {
      return SpeakerWindow(
        segmentIds: ids,
        startMs: start,
        endMs: end,
        embedding: emb,
        rms: energy,
      );
    }

    test('loudest cluster is You, confidently with a margin', () {
      final result = SpeakerClusterer.assignLabels([
        window(['a'], _vec([1.0, 0.0]), 0.9),
        window(['b'], _vec([0.99, 0.01]), 0.85),
        window(['c'], _vec([0.0, 1.0]), 0.2),
      ]);

      expect(result.labels, {'a': 'You', 'b': 'You', 'c': 'Other 1'});
      expect(result.speakerCount, 2);
      expect(result.youConfident, isTrue);
    });

    test('no margin means You without confidence', () {
      final result = SpeakerClusterer.assignLabels([
        window(['a'], _vec([1.0, 0.0]), 0.5),
        window(['c'], _vec([0.0, 1.0]), 0.45),
      ]);

      expect(result.labels['a'], 'You');
      expect(result.labels['c'], 'Other 1');
      expect(result.youConfident, isFalse);
    });

    test('single cluster is a solo wearer, not confidently', () {
      final result = SpeakerClusterer.assignLabels([
        window(['a'], _vec([1.0, 0.0]), 0.7),
        window(['b'], _vec([0.99, 0.01]), 0.6),
      ]);

      expect(result.labels, {'a': 'You', 'b': 'You'});
      expect(result.speakerCount, 1);
      expect(result.youConfident, isFalse);
    });

    test('others are numbered by speech time', () {
      final result = SpeakerClusterer.assignLabels([
        window(['you'], _vec([1.0, 0.0]), 0.9),
        // Long quiet voice vs short quieter one: duration decides numbering.
        window(['long'], _vec([0.0, 1.0]), 0.2, start: 0, end: 9000),
        window(['short'], _vec([0.0, 0.0, 1.0]), 0.15,
            start: 9000, end: 10000),
      ]);

      expect(result.labels['you'], 'You');
      expect(result.labels['long'], 'Other 1');
      expect(result.labels['short'], 'Other 2');
    });

    test('windows without embeddings are skipped, not crashed on', () {
      final result = SpeakerClusterer.assignLabels([
        const SpeakerWindow(segmentIds: ['x'], startMs: 0, endMs: 500),
      ]);

      expect(result.labels, isEmpty);
      expect(result.speakerCount, 0);
    });
  });
}
