import 'dart:math' as math;
import 'dart:typed_data';

import '../../constants.dart';

/// A speech span handed to the voiceprint embedder: one or more STT
/// segments merged to reach a trustworthy audio length.
class SegmentRef {
  const SegmentRef({
    required this.id,
    required this.startMs,
    required this.endMs,
  });

  final String id;
  final int startMs;
  final int? endMs;
}

/// One embeddable window of session audio with the STT segments it covers.
class SpeakerWindow {
  const SpeakerWindow({
    required this.segmentIds,
    required this.startMs,
    required this.endMs,
    this.embedding = const [],
    this.rms = 0,
  });

  /// STT segment ids covered by this window (in time order).
  final List<String> segmentIds;
  final int startMs;
  final int endMs;

  /// Voiceprint from the embedding model (empty until embedded).
  final List<double> embedding;

  /// Mean RMS energy of the window's audio (wearer = loudest cluster).
  final double rms;

  int get durationMs => endMs - startMs;

  SpeakerWindow withEmbedding(List<double> vector, double energy) {
    return SpeakerWindow(
      segmentIds: segmentIds,
      startMs: startMs,
      endMs: endMs,
      embedding: vector,
      rms: energy,
    );
  }
}

/// Segment id -> speaker label (`'You'`, `'Other 1'`, …).
class SpeakerLabels {
  const SpeakerLabels({
    required this.labels,
    required this.speakerCount,
    required this.youConfident,
  });

  final Map<String, String> labels;
  final int speakerCount;

  /// True when the wearer call cleared the energy margin — otherwise the
  /// loudest cluster is still called You (best guess), just not confidently.
  final bool youConfident;
}

/// Pure-Dart speaker clustering: cosine similarity over voiceprints, greedy
/// assignment, energy-based wearer detection.
///
/// No native dependencies, so every rule here is unit-testable with
/// synthetic embeddings. The native embedding model only produces the
/// voiceprints ([SpeakerWindow.embedding]); everything after that is here.
class SpeakerClusterer {
  SpeakerClusterer._();

  /// Cosine similarity in [-1, 1]. Returns 0 for degenerate inputs.
  static double cosine(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) return 0;
    var dot = 0.0;
    var na = 0.0;
    var nb = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na <= 0 || nb <= 0) return 0;
    return dot / (math.sqrt(na) * math.sqrt(nb));
  }

  /// Mean RMS energy of PCM float samples in [-1, 1].
  static double rms(Float32List samples) {
    if (samples.isEmpty) return 0;
    var sum = 0.0;
    for (final v in samples) {
      sum += v * v;
    }
    return math.sqrt(sum / samples.length);
  }

  /// Groups window indices into clusters. Each window joins the cluster it
  /// resembles most (mean cosine to members) when that similarity clears
  /// [threshold], otherwise it seeds a new cluster. Order-stable.
  static List<List<int>> cluster(
    List<List<double>> embeddings, {
    double threshold = kSpeakerClusterThreshold,
  }) {
    final clusters = <List<int>>[];
    for (var i = 0; i < embeddings.length; i++) {
      final emb = embeddings[i];
      var bestCluster = -1;
      var bestSim = -2.0;
      for (var c = 0; c < clusters.length; c++) {
        final members = clusters[c];
        var sim = 0.0;
        for (final m in members) {
          sim += cosine(emb, embeddings[m]);
        }
        sim /= members.length;
        if (sim > bestSim) {
          bestSim = sim;
          bestCluster = c;
        }
      }
      if (bestCluster >= 0 && bestSim >= threshold) {
        clusters[bestCluster].add(i);
      } else {
        clusters.add([i]);
      }
    }
    return clusters;
  }

  /// Merges STT segments into embeddable windows: every window holds at
  /// least [kSpeakerMinWindowSeconds] of audio (short segments merge forward
  /// across small gaps), no window spans a silence gap of 2.5 s+, and spans
  /// longer than [kSpeakerMaxWindowSeconds] are split so one window rarely
  /// straddles two speakers.
  static List<SpeakerWindow> buildWindows(List<SegmentRef> segments) {
    final minMs = (kSpeakerMinWindowSeconds * 1000).round();
    final maxMs = (kSpeakerMaxWindowSeconds * 1000).round();
    const maxGapMs = 2500;

    // Split over-long segments first so windows stay single-speaker-ish.
    final pieces = <_Piece>[];
    for (final s in segments) {
      final end = s.endMs ?? s.startMs;
      if (end <= s.startMs) continue;
      var start = s.startMs;
      while (end - start > maxMs) {
        pieces.add(_Piece(id: s.id, startMs: start, endMs: start + maxMs));
        start += maxMs;
      }
      pieces.add(_Piece(id: s.id, startMs: start, endMs: end));
    }
    pieces.sort((a, b) => a.startMs.compareTo(b.startMs));

    final windows = <SpeakerWindow>[];
    final pending = <_Piece>[];
    var pendingMs = 0;

    void flush() {
      if (pending.isEmpty) return;
      final ids = <String>[];
      for (final p in pending) {
        if (ids.isEmpty || ids.last != p.id) ids.add(p.id);
      }
      windows.add(
        SpeakerWindow(
          segmentIds: ids,
          startMs: pending.first.startMs,
          endMs: pending.last.endMs,
        ),
      );
      pending.clear();
      pendingMs = 0;
    }

    for (final p in pieces) {
      if (pending.isNotEmpty) {
        final gap = p.startMs - pending.last.endMs;
        if (gap >= maxGapMs) flush();
      }
      pending.add(p);
      pendingMs += p.endMs - p.startMs;
      if (pendingMs >= minMs) flush();
    }
    flush();
    return windows;
  }

  /// Labels every covered segment id. The highest-energy cluster is the
  /// wearer (chest-worn mic); remaining clusters become `Other N` ordered by
  /// total speech time. Single-cluster sessions are the wearer talking to
  /// themselves — labeled You, but not confidently.
  static SpeakerLabels assignLabels(List<SpeakerWindow> windows) {
    final embedded = windows.where((w) => w.embedding.isNotEmpty).toList();
    if (embedded.isEmpty) {
      return const SpeakerLabels(
        labels: {},
        speakerCount: 0,
        youConfident: false,
      );
    }
    final clusters = cluster(embedded.map((w) => w.embedding).toList());

    // Cluster stats: speech time + mean energy.
    final stats = <_ClusterStat>[];
    for (final members in clusters) {
      var ms = 0;
      var energy = 0.0;
      for (final m in members) {
        ms += embedded[m].durationMs;
        energy += embedded[m].rms;
      }
      stats.add(
        _ClusterStat(members: members, totalMs: ms, meanRms: energy / members.length),
      );
    }

    // Wearer = loudest cluster. Confidence needs a real rival and a margin.
    var wearer = 0;
    for (var i = 1; i < stats.length; i++) {
      if (stats[i].meanRms > stats[wearer].meanRms) wearer = i;
    }
    var confident = false;
    if (stats.length == 1) {
      confident = false;
    } else {
      var runnerUp = 0.0;
      for (var i = 0; i < stats.length; i++) {
        if (i == wearer) continue;
        if (stats[i].meanRms > runnerUp) runnerUp = stats[i].meanRms;
      }
      confident = runnerUp > 0 &&
          stats[wearer].meanRms / runnerUp >= kWearerEnergyMargin;
    }

    // Non-wearers become Other N ordered by speech time (stable, reviewable).
    final order = List<int>.generate(stats.length, (i) => i)
      ..sort((a, b) {
        if (a == wearer) return -1;
        if (b == wearer) return 1;
        return stats[b].totalMs.compareTo(stats[a].totalMs);
      });

    final names = <int, String>{};
    var other = 0;
    for (final c in order) {
      if (c == wearer) {
        names[c] = kSpeakerYou;
      } else {
        other++;
        names[c] = kSpeakerOther(other);
      }
    }

    final labels = <String, String>{};
    for (var c = 0; c < clusters.length; c++) {
      for (final m in clusters[c]) {
        for (final id in embedded[m].segmentIds) {
          labels[id] = names[c]!;
        }
      }
    }
    return SpeakerLabels(
      labels: labels,
      speakerCount: clusters.length,
      youConfident: confident,
    );
  }
}

class _Piece {
  _Piece({required this.id, required this.startMs, required this.endMs});

  final String id;
  final int startMs;
  final int endMs;
}

class _ClusterStat {
  _ClusterStat({
    required this.members,
    required this.totalMs,
    required this.meanRms,
  });

  final List<int> members;
  final int totalMs;
  final double meanRms;
}
