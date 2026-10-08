import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../constants.dart';
import '../services/storage_service.dart';
import 'analytics_provider.dart';

class AppSettings {
  const AppSettings({
    this.deviceName = kPendantName,
    this.themeMode = ThemeMode.system,
    this.hasCompletedOnboarding = true,
    this.geminiApiKey = '',
    this.speakerDiarization = true,
    this.keepSessionAudio = false,
  });

  final String deviceName;
  final ThemeMode themeMode;
  final bool hasCompletedOnboarding;
  final String geminiApiKey;

  /// Post-session on-device speaker labeling (You vs Others). Runs fully
  /// offline; disable to skip the diarization pass entirely.
  final bool speakerDiarization;

  /// Keep per-session WAVs after processing instead of deleting them.
  /// Audio never leaves the phone either way.
  final bool keepSessionAudio;

  AppSettings copyWith({
    String? deviceName,
    ThemeMode? themeMode,
    bool? hasCompletedOnboarding,
    String? geminiApiKey,
    bool? speakerDiarization,
    bool? keepSessionAudio,
  }) {
    return AppSettings(
      deviceName: deviceName ?? this.deviceName,
      themeMode: themeMode ?? this.themeMode,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      speakerDiarization: speakerDiarization ?? this.speakerDiarization,
      keepSessionAudio: keepSessionAudio ?? this.keepSessionAudio,
    );
  }

  Map<String, dynamic> toJson() => {
    'deviceName': deviceName,
    'themeMode': themeMode.name,
    'hasCompletedOnboarding': hasCompletedOnboarding,
    'geminiApiKey': geminiApiKey,
    'speakerDiarization': speakerDiarization,
    'keepSessionAudio': keepSessionAudio,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    deviceName: json['deviceName'] as String? ?? kPendantName,
    themeMode:
        ThemeMode.values.asNameMap()[json['themeMode']] ?? ThemeMode.system,
    hasCompletedOnboarding: json['hasCompletedOnboarding'] as bool? ?? false,
    geminiApiKey: json['geminiApiKey'] as String? ?? '',
    speakerDiarization: json['speakerDiarization'] as bool? ?? true,
    keepSessionAudio: json['keepSessionAudio'] as bool? ?? false,
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
    return const AppSettings(
      hasCompletedOnboarding: false, // Force onboarding on fresh install
    );
  }

  void setDeviceName(String name) {
    state = state.copyWith(
      deviceName: name.trim().isEmpty ? kPendantName : name.trim(),
    );
    _save();
  }

  void setThemeMode(ThemeMode mode) {
    if (mode == state.themeMode) return;
    state = state.copyWith(themeMode: mode);
    _save();
    ref
        .read(analyticsProvider)
        .capture(
          'setting changed',
          properties: {'setting': 'theme_mode', 'value': mode.name},
        );
  }

  void completeOnboarding() {
    state = state.copyWith(hasCompletedOnboarding: true);
    _save();
  }

  void setGeminiApiKey(String key) {
    state = state.copyWith(geminiApiKey: key.trim());
    _save();
  }

  void setSpeakerDiarization(bool enabled) {
    if (enabled == state.speakerDiarization) return;
    state = state.copyWith(speakerDiarization: enabled);
    _save();
    ref
        .read(analyticsProvider)
        .capture(
          'setting changed',
          properties: {'setting': 'speaker_diarization', 'value': '$enabled'},
        );
  }

  void setKeepSessionAudio(bool keep) {
    if (keep == state.keepSessionAudio) return;
    state = state.copyWith(keepSessionAudio: keep);
    _save();
    ref
        .read(analyticsProvider)
        .capture(
          'setting changed',
          properties: {'setting': 'keep_session_audio', 'value': '$keep'},
        );
  }

  void _save() {
    Hive.box(Boxes.settings).put('settings', state.toJson());
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
