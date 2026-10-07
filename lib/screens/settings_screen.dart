import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../abstractions/audio_source.dart';
import '../providers/ble_provider.dart';
import '../providers/commitment_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/dev_capture_provider.dart';
import '../providers/settings_provider.dart';
import '../constants.dart';
import '../providers/stt_model_provider.dart';
import '../services/storage_service.dart';
import '../widgets/device_picker_sheet.dart';
import '../widgets/device_status_controls.dart';
import '../widgets/page_header.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _developerOpen = false;

  void _openDevicePicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DevicePickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status =
        ref.watch(pendantStatusProvider).value ?? const PendantStatus();
    final capture = ref.watch(devCaptureProvider);
    final stats = ref.watch(pendantStatsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Consistent page header (logo top-left, status top-right,
          // heading below). Sections below are untouched and functional.
          SliverToBoxAdapter(
            child: PageHeader(
              title: 'Settings',
              actions: [
                DeviceStatusActions(
                  status: status,
                  onBluetoothTap: _openDevicePicker,
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ã¢â€â‚¬Ã¢â€â‚¬ Hero: Pendant Status Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
                  _PendantDashboard(status: status),

                  const SizedBox(height: 36),
                  // Ã¢â€â‚¬Ã¢â€â‚¬ Appearance Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
                  const _SectionHeader(
                    title: 'Appearance',
                    subtitle: 'How Tanu looks',
                  ),
                  const SizedBox(height: 16),
                  const _AppearanceSelector(),

                  const SizedBox(height: 36),

                  // Ã¢â€â‚¬Ã¢â€â‚¬ Speech Engine Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
                  const _SectionHeader(
                    title: 'Speech Engine',
                    subtitle: 'Offline AI Model for Transcription',
                  ),
                  const SizedBox(height: 16),
                  const _SttModelDashboard(),

                  const SizedBox(height: 36),

                  // Ã¢â€â‚¬Ã¢â€â‚¬ Memory & Privacy Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
                  const _SectionHeader(
                    title: 'Memory',
                    subtitle: 'All your data stays on this device',
                  ),
                  const SizedBox(height: 16),
                  const _WipeMemoryButton(),

                  const SizedBox(height: 36),

                  // Ã¢â€â‚¬Ã¢â€â‚¬ Developer / Under the Hood Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
                  GestureDetector(
                    onTap: () =>
                        setState(() => _developerOpen = !_developerOpen),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const _SectionHeader(
                          title: 'Under the Hood',
                          subtitle: 'Diagnostic tools',
                        ),
                        Icon(
                          _developerOpen
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: const Color(0xFF888888),
                        ),
                      ],
                    ),
                  ),
                  if (_developerOpen) ...[
                    const SizedBox(height: 16),
                    _DeveloperConsole(capture: capture, stats: stats),
                  ],

                  // Bottom cushion: clears the floating nav dock (64 tall,
                  // offset safeArea + 16) on every screen size, so the last
                  // card scrolls fully into view and stays tappable.
                  SizedBox(
                    height: MediaQuery.paddingOf(context).bottom + 112,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
// Components
// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: TextStyle(color: muted, fontSize: 14)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isConnected = status.isConnected;
    final accent = isConnected ? Colors.green : Theme.of(context).primaryColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isConnected
              ? accent.withValues(alpha: 0.35)
              : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5)),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
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
                  child: Text(
                    isConnected ? 'Tanu is\nConnected' : 'Tanu is\nOffline',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      height: 1.1,
                      fontSize: 32,
                    ),
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
                Text(
                  isConnected ? 'Ready to capture' : 'No pendant connected',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
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
                backgroundColor: isConnected
                    ? (isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFE5E5E5))
                    : Theme.of(context).primaryColor,
                foregroundColor: isConnected
                    ? (isDark ? Colors.white : Colors.black)
                    : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.battery_charging_full,
            color: Colors.green,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            '$percent%',
            style: const TextStyle(
              color: Colors.green,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF2A2A2A) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected && !isDark
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
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black)
                    : const Color(0xFF888888),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black)
                      : const Color(0xFF888888),
                ),
              ),
            ],
          ),
        ),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      kOfflineModelLabel,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (state.phase == SttModelPhase.ready)
                const Icon(Icons.check_circle, color: Colors.green)
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
              child: ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Download Offline Model (~375MB)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () => notifier.download(),
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
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                          ),
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
      ),
    );
  }
}

class _WipeMemoryButton extends ConsumerWidget {
  const _WipeMemoryButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.delete_forever),
        label: const Text('WIPE TANU\'S MEMORY'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.redAccent,
          side: const BorderSide(color: Colors.redAccent, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.redAccent,
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: consoleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '>  DEV CONSOLE',
                style: TextStyle(
                  color: consoleGreen,
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
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

          ElevatedButton.icon(
            icon: Icon(
              capture.recording
                  ? Icons.stop_rounded
                  : Icons.fiber_manual_record,
              size: 16,
            ),
            label: Text(
              capture.recording
                  ? 'STOP WAV CAPTURE [${_fmtSize(capture.bytes)}]'
                  : 'START RAW AUDIO DUMP',
            ),
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
