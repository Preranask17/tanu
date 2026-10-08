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
  });

  final String deviceName;
  final ThemeMode themeMode;
  final bool hasCompletedOnboarding;
  final String geminiApiKey;

  AppSettings copyWith({
    String? deviceName,
    ThemeMode? themeMode,
    bool? hasCompletedOnboarding,
    String? geminiApiKey,
  }) {
    return AppSettings(
      deviceName: deviceName ?? this.deviceName,
      themeMode: themeMode ?? this.themeMode,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
    );
  }

  Map<String, dynamic> toJson() => {
    'deviceName': deviceName,
    'themeMode': themeMode.name,
    'hasCompletedOnboarding': hasCompletedOnboarding,
    'geminiApiKey': geminiApiKey,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    deviceName: json['deviceName'] as String? ?? kPendantName,
    themeMode:
        ThemeMode.values.asNameMap()[json['themeMode']] ?? ThemeMode.system,
    hasCompletedOnboarding: json['hasCompletedOnboarding'] as bool? ?? false,
    geminiApiKey: json['geminiApiKey'] as String? ?? '',
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

  void _save() {
    Hive.box(Boxes.settings).put('settings', state.toJson());
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
