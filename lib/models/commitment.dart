import 'package:uuid/uuid.dart';

/// A commitment / to-do surfaced from conversation or added manually.
class Commitment {
  Commitment({
    String? id,
    required this.action,
    this.person,
    this.due,
    this.done = false,
    this.autoExtracted = false,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final String action;
  final String? person;
  final DateTime? due;
  bool done;
  final bool autoExtracted;
  final DateTime createdAt;

  bool get isDue =>
      due != null && due!.isBefore(DateTime.now().normalizedDate());

  /// Overdue or due today.
  bool get needsAttention => due != null && !done && !due!.isAfter(today());

  static DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Commitment copyWith({String? action, String? person, DateTime? due, bool? done}) {
    return Commitment(
      id: id,
      action: action ?? this.action,
      person: person ?? this.person,
      due: due ?? this.due,
      done: done ?? this.done,
      autoExtracted: autoExtracted,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'action': action,
        'person': person,
        'due': due?.toIso8601String(),
        'done': done,
        'autoExtracted': autoExtracted,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Commitment.fromJson(Map<String, dynamic> json) {
    return Commitment(
      id: json['id'] as String,
      action: json['action'] as String,
      person: json['person'] as String?,
      due: json['due'] != null ? DateTime.parse(json['due'] as String) : null,
      done: json['done'] as bool? ?? false,
      autoExtracted: json['autoExtracted'] as bool? ?? false,
      createdAt: DateTime.parse(
        json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

extension on DateTime {
  DateTime normalizedDate() => DateTime(year, month, day);
}