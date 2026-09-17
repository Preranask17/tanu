import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../constants.dart';
import '../services/storage_service.dart';

/// Where continuous speech recognition runs: Deepgram in the cloud or the
/// on-device Moonshine model. The pendant is never blocked on this choice —
/// it only decides which recognizer gets fed the audio stream.
enum SttBackend { cloud, onDevice }

class AppSettings {
  const AppSettings({
    this.apiKey = '',
    this.model = kMistralModel,
    this.deviceName = kPendantName,
    this.sttBackend = SttBackend.cloud,
  });

  final String apiKey;
  final String model;
  final String deviceName;
  final SttBackend sttBackend;

  bool get hasApiKey => apiKey.isNotEmpty;

  AppSettings copyWith({
    String? apiKey,
    String? model,
    String? deviceName,
    SttBackend? sttBackend,
  }) {
    return AppSettings(
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      deviceName: deviceName ?? this.deviceName,
      sttBackend: sttBackend ?? this.sttBackend,
    );
  }

  Map<String, dynamic> toJson() => {
        'apiKey': apiKey,
        'model': model,
        'deviceName': deviceName,
        'sttBackend': sttBackend.name,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        apiKey: json['apiKey'] as String? ?? '',
        model: json['model'] as String? ?? kMistralModel,
        deviceName: json['deviceName'] as String? ?? kPendantName,
        sttBackend: SttBackend.values.asNameMap()[json['sttBackend']] ??
            SttBackend.cloud,
      );
}

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final box = Hive.box(Boxes.settings);
    final stored = box.get('settings');
    if (stored is Map) {
      return AppSettings.fromJson(Map<String, dynamic>.from(stored));
    }
    return AppSettings(apiKey: kMistralApiKeyDefine);
  }

  void setApiKey(String key) {
    state = state.copyWith(apiKey: key.trim());
    _save();
  }

  void setModel(String model) {
    state = state.copyWith(model: model);
    _save();
  }

  void setDeviceName(String name) {
    state = state.copyWith(deviceName: name.trim().isEmpty ? kPendantName : name.trim());
    _save();
  }

  void setSttBackend(SttBackend backend) {
    state = state.copyWith(sttBackend: backend);
    _save();
  }

  void _save() {
    Hive.box(Boxes.settings).put('settings', state.toJson());
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);