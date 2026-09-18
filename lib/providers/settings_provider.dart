import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../constants.dart';
import '../services/storage_service.dart';

class AppSettings {
  const AppSettings({
    this.deviceName = kPendantName,
    this.themeMode = ThemeMode.system,
    this.hasCompletedOnboarding = true,
  });

  final String deviceName;
  final ThemeMode themeMode;
  final bool hasCompletedOnboarding;

  AppSettings copyWith({
    String? deviceName,
    ThemeMode? themeMode,
    bool? hasCompletedOnboarding,
  }) {
    return AppSettings(
      deviceName: deviceName ?? this.deviceName,
      themeMode: themeMode ?? this.themeMode,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    );
  }

  Map<String, dynamic> toJson() => {
    'deviceName': deviceName,
    'themeMode': themeMode.name,
    'hasCompletedOnboarding': hasCompletedOnboarding,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    deviceName: json['deviceName'] as String? ?? kPendantName,
    themeMode:
        ThemeMode.values.asNameMap()[json['themeMode']] ?? ThemeMode.system,
    hasCompletedOnboarding: false, // Hardcoded for testing the new UI
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
    state = state.copyWith(themeMode: mode);
    _save();
  }

  void completeOnboarding() {
    state = state.copyWith(hasCompletedOnboarding: true);
    _save();
  }

  void _save() {
    Hive.box(Boxes.settings).put('settings', state.toJson());
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
