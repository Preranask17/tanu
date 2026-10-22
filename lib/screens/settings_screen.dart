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

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status =
        ref.watch(pendantStatusProvider).value ?? const PendantStatus();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          const PinnedHeader(title: 'Settings'),
          SliverToBoxAdapter(
            child: TanuPageRail(
              bottom: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pendant status
                  _PendantDashboard(status: status),

                  const SizedBox(height: 14),

                  _SettingsGroupCard(
                    title: 'Preferences',
                    children: [
                      const _AppearanceTile(),
                      _SettingsActionTile(
                        icon: Icons.graphic_eq_rounded,
                        title: 'Speech Engine',
                        subtitle: 'Offline model & language',
                        onTap: () => _showSettingsSheet(
                          context,
                          title: 'Speech Engine',
                          subtitle:
                              'Offline AI model for transcription on this device',
                          child: const _SpeechEngineControls(),
                        ),
                      ),
                      _SettingsActionTile(
                        icon: Icons.inventory_2_outlined,
                        title: 'Memory',
                        subtitle: 'Review or permanently wipe local data',
                        onTap: () => _showSettingsSheet(
                          context,
                          title: 'Memory',
                          subtitle: 'Stored locally on this device',
                          child: const _MemoryControls(),
                        ),
                      ),
                      const _NotificationSettings(),
                    ],
                  ),

                  const SizedBox(height: 12),

                  _SettingsGroupCard(
                    title: 'System & AI',
                    children: [
                      _SettingsActionTile(
                        icon: Icons.key_outlined,
                        title: 'Gemini API Key',
                        subtitle: 'For memory, chat & RAG embeddings',
                        onTap: () => _showSettingsSheet(
                          context,
                          title: 'Gemini API Key',
                          subtitle:
                              'Used for memory processing, chat & RAG embeddings',
                          child: const _GeminiKeyField(),
                        ),
                      ),
                      _SettingsActionTile(
                        icon: Icons.terminal_rounded,
                        title: 'Under the Hood',
                        subtitle: 'Telemetry, mic tests, and raw capture',
                        onTap: () => _showSettingsSheet(
                          context,
                          title: 'Under the Hood',
                          subtitle: 'Live pendant and capture diagnostics',
                          child: const _UnderTheHoodControls(),
                        ),
                      ),
                    ],
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

/// Shared shell for the settings that need more room than the main page.
Future<void> _showSettingsSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Widget child,
}) async {
  final c = context.tanuColors;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: c.surface,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    showDragHandle: false,
    constraints: const BoxConstraints(maxWidth: 560),
    clipBehavior: Clip.antiAlias,
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 220),
      reverseDuration: Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (_) =>
        _SettingsSheet(title: title, subtitle: subtitle, child: child),
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.textMuted.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: textTheme.titleLarge?.copyWith(
                        color: c.heading,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: 'Close',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 30,
                      height: 30,
                    ),
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      foregroundColor: c.heading,
                      backgroundColor: c.surfaceMuted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size(30, 30),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 3, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    subtitle!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: c.heading.withValues(alpha: 0.68),
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      horizontalTitleGap: 12,
      minLeadingWidth: 32,
      minVerticalPadding: 2,
      leading: _SettingsIcon(icon),
      title: Text(
        title,
        style: textTheme.bodyLarge?.copyWith(
          color: c.heading,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Text(
          subtitle,
          style: textTheme.bodySmall?.copyWith(
            color: c.heading.withValues(alpha: 0.68),
            fontSize: 12.5,
            height: 1.25,
          ),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        size: 20,
        color: c.heading.withValues(alpha: 0.6),
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: c.isDark ? 0.16 : 0.07),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, size: 18, color: c.heading),
    );
  }
}

// Components

/// Compact grouped settings surface with an Outfit header and Inter rows.
class _SettingsGroupCard extends StatelessWidget {
  const _SettingsGroupCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: c.surface,
      elevation: c.isDark ? 0.5 : 1,
      shadowColor: Colors.black.withValues(alpha: c.isDark ? 0.32 : 0.06),
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: c.border),
      ),
      child: ListTileTheme(
        data: ListTileThemeData(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          horizontalTitleGap: 12,
          minLeadingWidth: 32,
          minVerticalPadding: 2,
          iconColor: c.heading,
          textColor: c.heading,
          titleTextStyle: textTheme.bodyLarge?.copyWith(
            color: c.heading,
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
          subtitleTextStyle: textTheme.bodySmall?.copyWith(
            color: c.heading.withValues(alpha: 0.68),
            fontSize: 12.5,
            height: 1.25,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  color: c.heading,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, color: c.borderSubtle),
              children[i],
            ],
            const SizedBox(height: 4),
          ],
        ),
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
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Important notifications'),
          subtitle: const Text('Commitments & highlights'),
          value: settings.notifyEnabled,
          onChanged: (v) =>
              ref.read(settingsProvider.notifier).setNotificationsEnabled(v),
        ),
        SwitchListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Morning digest'),
          subtitle: const Text('Once-daily memory recap'),
          value: settings.digestEnabled,
          onChanged: settings.notifyEnabled
              ? (v) => ref.read(settingsProvider.notifier).setDigestEnabled(v)
              : null,
        ),
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: const Text('Digest hour'),
          trailing: DropdownButton<int>(
            value: settings.digestHour,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: c.heading,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
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
        _SettingsActionTile(
          icon: Icons.shield_outlined,
          title: 'Background protection',
          subtitle: 'Keep digest delivery on aggressive skins',
          onTap: () => _showSettingsSheet(
            context,
            title: 'Background protection',
            subtitle: 'Keep the morning digest alive after the app closes',
            child: const _BackgroundProtection(),
          ),
        ),
      ],
    );
  }
}

/// Background protection sheet content: one-tap routes to the system screens
/// that decide whether the digest worker survives app kill on aggressive OEM
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
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Aggressive skins kill background apps. Exempt Tanu so the '
          'morning digest arrives with the app closed.',
          style: textTheme.bodyMedium?.copyWith(
            color: c.heading.withValues(alpha: 0.78),
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 2,
            runSpacing: 2,
            children: [
              TextButton.icon(
                onPressed: _requestExemption,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                icon: const Icon(Icons.battery_saver_outlined, size: 15),
                label: const Text('Battery exemption'),
              ),
              TextButton.icon(
                onPressed: _openAutostart,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                icon: const Icon(Icons.play_circle_outline, size: 15),
                label: const Text('Autostart'),
              ),
            ],
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
            ).textTheme.bodyMedium?.copyWith(color: c.heading, fontSize: 14.5),
            decoration: InputDecoration(
              hintText: 'AIza...',
              isDense: true,
              filled: true,
              fillColor: c.surfaceMuted,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              suffixIconConstraints: const BoxConstraints.tightFor(
                width: 36,
                height: 36,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            minimumSize: const Size(0, 44),
            textStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: () {
            final messenger = ScaffoldMessenger.of(context);
            final navigator = Navigator.of(context);
            ref.read(settingsProvider.notifier).setGeminiApiKey(_ctrl.text);
            FocusScope.of(context).unfocus();
            if (navigator.canPop()) {
              navigator.pop();
            }
            messenger.showSnackBar(
              const SnackBar(content: Text('Gemini API key saved')),
            );
          },
          child: const Text('Save'),
        ),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isConnected ? accent.withValues(alpha: 0.35) : c.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: c.isDark ? 0.18 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
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
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isConnected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_disabled,
                        color: accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isConnected
                                ? 'Pendant connected'
                                : 'Pendant offline',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: c.heading,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isConnected
                                ? (status.deviceName ?? 'Tanu pendant')
                                : 'Connect a pendant to start capturing',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.heading.withValues(alpha: 0.68),
                              fontSize: 12.5,
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
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isConnected ? 'Ready to capture' : 'No pendant connected',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isConnected ? c.surfaceMuted : c.primary,
                foregroundColor: isConnected ? c.heading : c.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
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
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: c.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.battery_charging_full, color: c.success, size: 14),
          const SizedBox(width: 3),
          Text(
            '$percent%',
            style: TextStyle(
              color: c.success,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceTile extends ConsumerWidget {
  const _AppearanceTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final label = switch (mode) {
      ThemeMode.system => 'System theme',
      ThemeMode.light => 'Light theme',
      ThemeMode.dark => 'Dark theme',
    };

    void setMode(ThemeMode next) =>
        ref.read(settingsProvider.notifier).setThemeMode(next);

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: const _SettingsIcon(Icons.palette_outlined),
      title: const Text('Appearance'),
      subtitle: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ThemeButton(
            icon: Icons.brightness_auto,
            tooltip: 'System theme',
            selected: mode == ThemeMode.system,
            onTap: () => setMode(ThemeMode.system),
          ),
          _ThemeButton(
            icon: Icons.light_mode,
            tooltip: 'Light theme',
            selected: mode == ThemeMode.light,
            onTap: () => setMode(ThemeMode.light),
          ),
          _ThemeButton(
            icon: Icons.dark_mode,
            tooltip: 'Dark theme',
            selected: mode == ThemeMode.dark,
            onTap: () => setMode(ThemeMode.dark),
          ),
        ],
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  const _ThemeButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;

    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: onTap,
          icon: Icon(icon, size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 30, height: 30),
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            foregroundColor: selected ? c.heading : c.textMuted,
            backgroundColor: selected ? c.surfaceMuted : Colors.transparent,
            side: selected ? BorderSide(color: c.border) : BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
            minimumSize: const Size(30, 30),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}

class _SpeechEngineControls extends StatelessWidget {
  const _SpeechEngineControls();

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SttModelDashboard(),
        Divider(height: 1, color: c.borderSubtle),
        const _SttLanguagePicker(),
      ],
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(Icons.translate_rounded, size: 18, color: c.heading),
          const SizedBox(width: 10),
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
                    fontSize: 14.5,
                  ),
                ),
                Text(
                  'Same offline model, fixed hint',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: c.heading.withValues(alpha: 0.68),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          DropdownButton<String>(
            value: code.isEmpty ? '' : code,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: c.heading,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
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
                      fontSize: 14.5,
                    ),
                  ),

                  const SizedBox(height: 3),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: c.heading.withValues(alpha: 0.68),
                      fontSize: 11.5,
                    ),
                  ),
                  if (showEngineLabel)
                    Text(
                      engineLabel,
                      style: TextStyle(
                        color: c.heading.withValues(alpha: 0.68),
                        fontSize: 11.5,
                      ),
                    ),
                ],
              ),
            ),
            if (state.phase == SttModelPhase.ready)
              Icon(Icons.check_circle, color: c.success, size: 20)
            else if (state.busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        if (state.phase != SttModelPhase.ready && !state.busy) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: c.onPrimary,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              onPressed: () => notifier.download(),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download, size: 18),
                  SizedBox(width: 6),
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
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.delete, size: 18),
              label: const Text('Delete Model'),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.danger,
                side: BorderSide(color: c.danger),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
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

class _MemoryControls extends StatelessWidget {
  const _MemoryControls();

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Deleting local memory permanently removes your conversation '
          'history and all commitments stored on this device. This cannot '
          'be undone.',
          style: textTheme.bodyMedium?.copyWith(
            color: c.heading.withValues(alpha: 0.78),
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        const _WipeMemoryButton(),
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
        icon: const Icon(Icons.delete_forever, size: 18),
        label: const Text('WIPE TANU\'S MEMORY'),
        style: OutlinedButton.styleFrom(
          foregroundColor: c.danger,
          side: BorderSide(color: c.danger, width: 1.5),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(vertical: 12),
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

class _UnderTheHoodControls extends ConsumerWidget {
  const _UnderTheHoodControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _DeveloperConsole(
      capture: ref.watch(devCaptureProvider),
      stats: ref.watch(pendantStatsProvider),
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
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
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                iconSize: 18,
                icon: const Icon(Icons.mic, color: consoleGreen),
                onPressed: () =>
                    ref.read(conversationProvider.notifier).microphoneTest(),
                tooltip: 'Phone Mic Test',
              ),
            ],
          ),
          const Divider(color: consoleBorder, height: 12),

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

          const Divider(color: consoleBorder, height: 12),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: capture.recording
                  ? Colors.red.shade700
                  : const Color(0xFF353535),
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: const TextStyle(fontSize: 11.5),
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
                  size: 15,
                ),
                const SizedBox(width: 6),
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
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Dumped: ${capture.path!.split('/').last}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontFamily: 'Courier',
                  fontSize: 9.5,
                ),
              ),
            ),
          const SizedBox(height: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF353535),
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: const TextStyle(fontSize: 11.5),
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
                Icon(Icons.notifications_outlined, size: 15),
                SizedBox(width: 6),
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
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white70,
          fontFamily: 'Courier',
          fontSize: 11.5,
          height: 1.3,
        ),
      ),
    );
  }
}
