import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../constants.dart';
import '../config/stt_config.dart';
import '../services/storage_service.dart';
import 'analytics_provider.dart';

class AppSettings {
  const AppSettings({
    this.deviceName = kPendantName,
    this.themeMode = ThemeMode.system,
    this.hasCompletedOnboarding = true,
    this.geminiApiKey = '',
    this.sttLanguageCode = '',
  });

  final String deviceName;
  final ThemeMode themeMode;
  final bool hasCompletedOnboarding;
  final String geminiApiKey;

  /// Explicit Indic STT language (`hi`, `kn`, …). `''` = auto-detect via the
  /// default Whisper engine. A non-empty code routes the recognizer through
  /// [IndicSttEngine] with the same on-device bundle.
  final String sttLanguageCode;

  AppSettings copyWith({
    String? deviceName,
    ThemeMode? themeMode,
    bool? hasCompletedOnboarding,
    String? geminiApiKey,
    String? sttLanguageCode,
  }) {
    return AppSettings(
      deviceName: deviceName ?? this.deviceName,
      themeMode: themeMode ?? this.themeMode,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      sttLanguageCode: sttLanguageCode ?? this.sttLanguageCode,
    );
  }

  Map<String, dynamic> toJson() => {
    'deviceName': deviceName,
    'themeMode': themeMode.name,
    'hasCompletedOnboarding': hasCompletedOnboarding,
    'geminiApiKey': geminiApiKey,
    'sttLanguageCode': sttLanguageCode,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    deviceName: json['deviceName'] as String? ?? kPendantName,
    themeMode:
        ThemeMode.values.asNameMap()[json['themeMode']] ?? ThemeMode.system,
    hasCompletedOnboarding: json['hasCompletedOnboarding'] as bool? ?? false,
    geminiApiKey: json['geminiApiKey'] as String? ?? '',
    sttLanguageCode: json['sttLanguageCode'] as String? ?? '',
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

  /// `''` = auto-detect (default Whisper engine). Any supported Indic code
  /// routes the recognizer through [IndicSttEngine]; unknown codes are
  /// ignored so a stale value can never break transcription.
  void setSttLanguageCode(String code) {
    final normalized = code.trim();
    if (normalized.isNotEmpty && SttConfig.indicLabelFor(normalized) == null) {
      return;
    }
    if (normalized == state.sttLanguageCode) return;
    state = state.copyWith(sttLanguageCode: normalized);
    _save();
    ref
        .read(analyticsProvider)
        .capture(
          'setting changed',
          properties: {'setting': 'stt_language', 'value': normalized},
        );
  }

  void _save() {
    Hive.box(Boxes.settings).put('settings', state.toJson());
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
