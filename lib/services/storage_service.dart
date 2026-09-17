import 'package:hive_ce_flutter/hive_flutter.dart';

/// Box names used across the app.
class Boxes {
  static const String settings = 'settings';
  static const String commitments = 'commitments';
  static const String conversation = 'conversation';
}

class StorageService {
  /// [overridePath] lets tests point Hive at a temp dir instead of path_provider.
  static Future<void> initialize({String? overridePath}) async {
    if (overridePath != null) {
      Hive.init(overridePath);
    } else {
      await Hive.initFlutter();
    }
    await Future.wait([
      Hive.openBox(Boxes.settings),
      Hive.openBox(Boxes.commitments),
      Hive.openBox(Boxes.conversation),
    ]);
  }

  static Future<void> clearAll() async {
    for (final name in [Boxes.settings, Boxes.commitments, Boxes.conversation]) {
      final box = Hive.box(name);
      await box.clear();
    }
  }
}