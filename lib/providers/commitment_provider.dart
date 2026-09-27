import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/commitment.dart';
import '../services/storage_service.dart';

class CommitmentsNotifier extends Notifier<List<Commitment>> {
  @override
  List<Commitment> build() {
    final box = Hive.box(Boxes.commitments);
    final stored = box.get('items');
    if (stored is List) {
      return stored
          .map((c) => Commitment.fromJson(Map<String, dynamic>.from(c)))
          .toList();
    }
    return const [];
  }

  void _persist() {
    Hive.box(
      Boxes.commitments,
    ).put('items', state.map((c) => c.toJson()).toList());
  }

  /// Add a commitment extracted by the agent.
  void addFromAgent(String action, {String? person, DateTime? due}) {
    state = [
      Commitment(action: action, person: person, due: due, autoExtracted: true),
      ...state,
    ];
    _persist();
  }

  /// Add a commitment manually from the UI.
  void addManual({required String action, String? person, DateTime? due}) {
    state = [Commitment(action: action, person: person, due: due), ...state];
    _persist();
  }

  void toggleDone(String id) {
    state = state.map((c) {
      if (c.id == id) {
        return c.copyWith(done: !c.done);
      }
      return c;
    }).toList();
    _persist();
  }

  void remove(String id) {
    state = state.where((c) => c.id != id).toList();
    _persist();
  }

  void clear() {
    state = const [];
    Hive.box(Boxes.commitments).clear();
  }
}

final commitmentsProvider =
    NotifierProvider<CommitmentsNotifier, List<Commitment>>(
      CommitmentsNotifier.new,
    );
