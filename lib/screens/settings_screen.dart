import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:android_intent_plus/android_intent.dart';

import '../abstractions/audio_source.dart';
import '../providers/ble_provider.dart';
import '../providers/commitment_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/dev_capture_provider.dart';
import '../providers/proactive_provider.dart';
import '../providers/settings_provider.dart';
import '../config/stt_config.dart';
import '../constants.dart';
import '../providers/stt_model_provider.dart';
import '../services/storage_service.dart';
import '../theme/tanu_colors.dart';
import '../widgets/device_picker_sheet.dart';
import '../widgets/page_layout.dart';
import '../widgets/pinned_header.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _developerOpen = false;

  @override
  Widget build(BuildContext context) {
    final status =
        ref.watch(pendantStatusProvider).value ?? const PendantStatus();
    final capture = ref.watch(devCaptureProvider);
    final stats = ref.watch(pendantStatsProvider);
    final c = context.tanuColors;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          const PinnedHeader(title: 'Settings'),
          SliverToBoxAdapter(
            child: TanuPageRail(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pendant status
                  _PendantDashboard(status: status),

                  const SizedBox(height: 20),

                  const _SettingsCard(
                    title: 'Appearance',
                    subtitle: 'How Tanu looks',
                    child: _AppearanceSelector(),
                  ),

                  const SizedBox(height: 16),

                  _SettingsCard(
                    title: 'Speech Engine',
                    subtitle: 'Offline AI model for transcription',
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(18, 16, 18, 18),
                          child: _SttModelDashboard(),
                        ),
                        Divider(height: 1, color: c.borderSubtle),
                        const _SttLanguagePicker(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  const _SettingsCard(
                    title: 'Memory',
                    subtitle: 'All your data stays on this device',
                    child: _WipeMemoryButton(),
                  ),

                  const SizedBox(height: 16),

                  const _SettingsCard(
                    title: 'Gemini API Key',
                    subtitle:
                        'Used for memory processing, chat & RAG embeddings',
                    child: _GeminiKeyField(),
                  ),

                  const SizedBox(height: 16),

                  const _SettingsCard(
                    title: 'Notifications',
                    subtitle: 'Important moments, not noise',
                    padding: EdgeInsets.zero,
                    child: _NotificationSettings(),
                  ),

                  const SizedBox(height: 16),

                  _SettingsCard(
                    title: 'Under the Hood',
                    subtitle: 'Diagnostic tools',
                    onHeaderTap: () =>
                        setState(() => _developerOpen = !_developerOpen),
                    trailing: Icon(
                      _developerOpen
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: c.heading.withValues(alpha: 0.72),
                    ),
                    child: _developerOpen
                        ? _DeveloperConsole(capture: capture, stats: stats)
                        : null,
                  ),
                  // Clearance above the floating dock so the last section
                  // scrolls fully into view on every screen size.
                  SizedBox(height: MediaQuery.paddingOf(context).bottom + 112),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Components

/// Grouped settings surface with an Outfit header and Inter tile text.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    this.subtitle,
    this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 18),
    this.trailing,
    this.onHeaderTap,
  });

  final String title;
  final String? subtitle;
  final Widget? child;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;
  final VoidCallback? onHeaderTap;

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    final textTheme = Theme.of(context).textTheme;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _SectionHeader(title: title, subtitle: subtitle),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );

    return Material(
      color: c.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onHeaderTap != null)
            InkWell(onTap: onHeaderTap, child: header)
          else
            header,
          if (child != null) ...[
            Divider(height: 1, color: c.borderSubtle),
            ListTileTheme(
              data: ListTileThemeData(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                iconColor: c.heading,
                textColor: c.heading,
                titleTextStyle: textTheme.bodyLarge?.copyWith(
                  color: c.heading,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                subtitleTextStyle: textTheme.bodySmall?.copyWith(
                  color: c.heading.withValues(alpha: 0.72),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              child: Padding(padding: padding, child: child!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Notification preferences: master switch, morning digest + hour.
/// Display only — the proactive service reads the persisted values.
class _NotificationSettings extends ConsumerWidget {
  const _NotificationSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final c = context.tanuColors;
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Important notifications'),
          subtitle: const Text('Commitments and highlights'),
          value: settings.notifyEnabled,
          onChanged: (v) =>
              ref.read(settingsProvider.notifier).setNotificationsEnabled(v),
        ),
        SwitchListTile(
          title: const Text('Morning digest'),
          subtitle: const Text('Top stashed memories, once daily'),
          value: settings.digestEnabled,
          onChanged: settings.notifyEnabled
              ? (v) => ref.read(settingsProvider.notifier).setDigestEnabled(v)
              : null,
        ),
        ListTile(
          title: const Text('Digest hour'),
          trailing: DropdownButton<int>(
            value: settings.digestHour,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: c.heading,
              fontWeight: FontWeight.w600,
            ),
            dropdownColor: c.surfaceElevated,
            underline: const SizedBox.shrink(),
            onChanged: settings.notifyEnabled && settings.digestEnabled
                ? (v) {
                    if (v != null) {
                      ref.read(settingsProvider.notifier).setDigestHour(v);
                    }
                  }
                : null,
            items: [
              for (var h = 6; h <= 10; h++)
                DropdownMenuItem(value: h, child: Text('$h am')),
            ],
          ),
        ),
        Divider(height: 1, color: c.borderSubtle),
        const _BackgroundProtection(),
      ],
    );
  }
}

/// Background protection: one-tap routes to the system screens that
/// decide whether the digest worker survives app kill on aggressive OEM
/// skins (Oppo/Realme/Vivo/Xiaomi). Fired via plain Android intents — no
/// native plugin, nothing to break the Gradle build. All launches guarded.
class _BackgroundProtection extends StatelessWidget {
  const _BackgroundProtection();

  static const _package = 'com.tanu.tanu_app';

  Future<void> _launch(AndroidIntent intent) async {
    try {
      await intent.launch();
    } catch (e) {
      debugPrint('[tanu] settings intent failed: $e');
    }
  }

  /// Battery exemption request for this exact package (falls back to the
  /// optimization list when the request screen is unavailable).
  Future<void> _requestExemption() async {
    try {
      await const AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
        data: 'package:$_package',
      ).launch();
      return;
    } catch (_) {}
    await _launch(
      const AndroidIntent(
        action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
      ),
    );
  }

  /// OEM autostart managers move between releases: try known ColorOS
  /// entries, then the app-details page as a guaranteed fallback.
  Future<void> _openAutostart() async {
    const candidates = [
      (
        'com.coloros.safecenter',
        'com.coloros.safecenter.startupapp.StartupAppListActivity',
      ),
      (
        'com.oppo.safe',
        'com.oppo.safe.permission.startup.StartupAppListActivity',
      ),
      (
        'com.coloros.safecenter',
        'com.coloros.safecenter.permission.startup.StartupAppListActivity',
      ),
    ];
    for (final c in candidates) {
      try {
        await AndroidIntent(
          action: 'android.intent.action.MAIN',
          package: c.$1,
          componentName: c.$2,
        ).launch();
        return;
      } catch (_) {}
    }
    await _launch(
      const AndroidIntent(
        action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
        data: 'package:$_package',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.shield_outlined, color: c.heading),
          title: const Text('Background protection'),
          subtitle: Text(
            'Aggressive skins kill background apps. Exempt Tanu so the '
            'morning digest arrives with the app closed.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 18, bottom: 12),
          child: Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: _requestExemption,
                  icon: const Icon(Icons.battery_saver_outlined, size: 16),
                  label: const Text('Battery exemption'),
                ),
                TextButton.icon(
                  onPressed: _openAutostart,
                  icon: const Icon(Icons.play_circle_outline, size: 16),
                  label: const Text('Autostart'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GeminiKeyField extends ConsumerStatefulWidget {
  const _GeminiKeyField();

  @override
  ConsumerState<_GeminiKeyField> createState() => _GeminiKeyFieldState();
}

class _GeminiKeyFieldState extends ConsumerState<_GeminiKeyField> {
  final _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _ctrl.text = ref.read(settingsProvider).geminiApiKey;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            obscureText: _obscure,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: c.heading),
            decoration: InputDecoration(
              hintText: 'AIza...',
              filled: true,
              fillColor: c.surfaceMuted,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () {
            ref.read(settingsProvider.notifier).setGeminiApiKey(_ctrl.text);
            FocusScope.of(context).unfocus();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Gemini API key saved')),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.titleLarge?.copyWith(
            color: c.heading,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: textTheme.bodyMedium?.copyWith(
              color: c.heading.withValues(alpha: 0.72),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _PendantDashboard extends StatelessWidget {
  final PendantStatus status;

  const _PendantDashboard({required this.status});

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    final isConnected = status.isConnected;
    final accent = isConnected ? c.success : c.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isConnected ? accent.withValues(alpha: 0.35) : c.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: c.isDark ? 0.2 : 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isConnected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_disabled,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isConnected
                                ? 'Pendant connected'
                                : 'Pendant offline',
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(color: c.heading),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isConnected
                                ? (status.deviceName ?? 'Tanu pendant')
                                : 'Connect a pendant to start capturing',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.heading.withValues(alpha: 0.72),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isConnected && status.batteryPercent != null)
                _BatteryBadge(percent: status.batteryPercent!),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isConnected ? 'Ready to capture' : 'No pendant connected',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isConnected ? c.surfaceMuted : c.primary,
                foregroundColor: isConnected ? c.heading : c.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: () {
                if (isConnected) {
                  ProviderScope.containerOf(
                    context,
                  ).read(pendantDisconnectProvider)();
                } else {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const DevicePickerSheet(),
                  );
                }
              },
              child: Text(
                isConnected ? 'Disconnect' : 'Scan for Pendant',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BatteryBadge extends StatelessWidget {
  const _BatteryBadge({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: c.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.battery_charging_full, color: c.success, size: 16),
          const SizedBox(width: 4),
          Text(
            '$percent%',
            style: TextStyle(
              color: c.success,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceSelector extends ConsumerWidget {
  const _AppearanceSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(settingsProvider).themeMode;
    final c = context.tanuColors;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          _ThemePill(
            label: 'System',
            icon: Icons.brightness_auto,
            isSelected: currentMode == ThemeMode.system,
            onTap: () => ref
                .read(settingsProvider.notifier)
                .setThemeMode(ThemeMode.system),
          ),
          _ThemePill(
            label: 'Light',
            icon: Icons.light_mode,
            isSelected: currentMode == ThemeMode.light,
            onTap: () => ref
                .read(settingsProvider.notifier)
                .setThemeMode(ThemeMode.light),
          ),
          _ThemePill(
            label: 'Dark',
            icon: Icons.dark_mode,
            isSelected: currentMode == ThemeMode.dark,
            onTap: () => ref
                .read(settingsProvider.notifier)
                .setThemeMode(ThemeMode.dark),
          ),
        ],
      ),
    );
  }
}

class _ThemePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemePill({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? c.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected && !c.isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? c.primary : c.textMuted),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: c.heading.withValues(alpha: isSelected ? 1 : 0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Speech-language picker. Auto-detect (default Whisper engine) or one
/// explicit Indic language (same on-device bundle driven through the Indic
/// engine core with a fixed language hint). Pure selection UI: the engine
/// factory rebuilds the recognizer when the persisted code changes.
class _SttLanguagePicker extends ConsumerWidget {
  const _SttLanguagePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(settingsProvider.select((s) => s.sttLanguageCode));
    final c = context.tanuColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        children: [
          Icon(Icons.translate_rounded, size: 20, color: c.heading),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Speech language',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: c.heading,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'Same offline model, fixed hint',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: c.heading.withValues(alpha: 0.72),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          DropdownButton<String>(
            value: code.isEmpty ? '' : code,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: c.heading),
            dropdownColor: c.surfaceElevated,
            underline: const SizedBox.shrink(),
            onChanged: (next) {
              if (next != null) {
                ref.read(settingsProvider.notifier).setSttLanguageCode(next);
              }
            },
            items: [
              const DropdownMenuItem(value: '', child: Text('Auto-detect')),
              for (final lang in SttConfig.indicLanguages)
                DropdownMenuItem(value: lang.code, child: Text(lang.label)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SttModelDashboard extends ConsumerWidget {
  const _SttModelDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sttModelProvider);
    final notifier = ref.read(sttModelProvider.notifier);

    String statusText;
    if (state.phase == SttModelPhase.ready) {
      statusText = 'Installed and Ready';
    } else if (state.phase == SttModelPhase.downloading) {
      if (state.totalBytes > 0) {
        if (state.downloadedBytes >= state.totalBytes) {
          statusText = 'Extracting Model... This might take a minute.';
        } else {
          final pct = (state.downloadedBytes / state.totalBytes * 100)
              .toStringAsFixed(1);
          statusText = 'Downloading... $pct%';
        }
      } else {
        statusText = 'Downloading...';
      }
    } else if (state.error != null) {
      statusText = 'Error: ${state.error}';
    } else {
      statusText = 'Not Installed';
    }

    final c = context.tanuColors;
    // Active recognizer core: identical to the bundle title by default,
    // "Whisper Small · Hindi"-style only when an Indic language is fixed.
    final engineLabel = ref.watch(sttEngineProvider).modelLabel;
    final showEngineLabel = engineLabel != kOfflineModelLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kOfflineModelLabel,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: c.heading,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: c.heading.withValues(alpha: 0.72),
                      fontSize: 12,
                    ),
                  ),
                  if (showEngineLabel)
                    Text(
                      engineLabel,
                      style: TextStyle(
                        color: c.heading.withValues(alpha: 0.72),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (state.phase == SttModelPhase.ready)
              Icon(Icons.check_circle, color: c.success)
            else if (state.busy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        if (state.phase != SttModelPhase.ready && !state.busy) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: c.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: () => notifier.download(),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Download Offline Model (~375MB)',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (state.phase == SttModelPhase.ready && !state.busy) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.delete),
              label: const Text('Delete Model'),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.danger,
                side: BorderSide(color: c.danger),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Model?'),
                    content: const Text(
                      'This will delete the downloaded speech model. You will need to download it again to use offline transcription.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: c.danger),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  notifier.deleteModel();
                }
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _WipeMemoryButton extends ConsumerWidget {
  const _WipeMemoryButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.tanuColors;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.delete_forever),
        label: const Text('WIPE TANU\'S MEMORY'),
        style: OutlinedButton.styleFrom(
          foregroundColor: c.danger,
          side: BorderSide(color: c.danger, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete everything?'),
              content: const Text(
                'This irrevocably destroys your conversation history and all commitments on this device.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(
                    foregroundColor: c.onDanger,
                    backgroundColor: c.danger,
                  ),
                  child: const Text('Destroy'),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            await StorageService.clearAll();
            ref.read(conversationProvider.notifier).clear();
            ref.read(commitmentsProvider.notifier).clear();
          }
        },
      ),
    );
  }
}

class _DeveloperConsole extends ConsumerWidget {
  final dynamic capture;
  final ValueNotifier<PendantStats> stats;

  const _DeveloperConsole({required this.capture, required this.stats});

  static String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const consoleGreen = Color(0xFF62F7B2);
    const consoleBorder = Color(0xFF303030);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: consoleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  '>  DEV CONSOLE',
                  style: TextStyle(
                    color: consoleGreen,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.mic, color: consoleGreen),
                onPressed: () =>
                    ref.read(conversationProvider.notifier).microphoneTest(),
                tooltip: 'Phone Mic Test',
              ),
            ],
          ),
          const Divider(color: consoleBorder, height: 16),

          ValueListenableBuilder<PendantStats>(
            valueListenable: stats,
            builder: (context, s, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ConsoleMetric(
                  label: 'BLE STATE',
                  value: s.notifySubscribed ? 'NOTIFY_ON' : 'NOTIFY_OFF',
                ),
                _ConsoleMetric(label: 'CODEC', value: s.codecLabel),
                _ConsoleMetric(label: 'PACKETS', value: '${s.packets}'),
                _ConsoleMetric(label: 'FRAMES', value: '${s.frames}'),
                _ConsoleMetric(label: 'DATA IN', value: _fmtSize(s.bytes)),
                _ConsoleMetric(
                  label: 'DROPS/ERRORS',
                  value: '${s.decodeFailures}',
                ),
              ],
            ),
          ),

          const Divider(color: consoleBorder, height: 16),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: capture.recording
                  ? Colors.red.shade700
                  : const Color(0xFF353535),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              textStyle: const TextStyle(fontSize: 12),
            ),
            onPressed: () => ref.read(devCaptureProvider.notifier).toggle(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  capture.recording
                      ? Icons.stop_rounded
                      : Icons.fiber_manual_record,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    capture.recording
                        ? 'STOP WAV CAPTURE [${_fmtSize(capture.bytes)}]'
                        : 'START RAW AUDIO DUMP',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          if (capture.path != null && !capture.recording)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Dumped: ${capture.path!.split('/').last}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontFamily: 'Courier',
                  fontSize: 10,
                ),
              ),
            ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF353535),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              textStyle: const TextStyle(fontSize: 12),
            ),
            onPressed: () async {
              final ok = await ref
                  .read(proactiveServiceProvider.future)
                  .then((svc) => svc.showTestNotification())
                  .catchError((_) => false);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? 'Test notification sent — check the shade'
                          : 'Test notification failed — check permission',
                    ),
                  ),
                );
              }
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_outlined, size: 16),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'SEND TEST NOTIFICATION',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsoleMetric extends StatelessWidget {
  const _ConsoleMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white70,
          fontFamily: 'Courier',
          fontSize: 12,
          height: 1.35,
        ),
      ),
    );
  }
}
