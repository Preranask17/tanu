import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../abstractions/audio_source.dart';
import '../providers/ble_provider.dart';
import '../providers/commitment_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/dev_capture_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/stt_model_provider.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/device_picker_sheet.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _developerOpen = false;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(pendantStatusProvider).value ?? const PendantStatus();
    final capture = ref.watch(devCaptureProvider);
    final stats = ref.watch(pendantStatsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _Section('Pendant'),
        _Tile(
          leading: Icon(
            Icons.bluetooth,
            color: status.isConnected ? kTanuGreen : kTanuMuted,
          ),
          title: status.deviceName ?? 'Pendant',
          subtitle: _stateLabel(status.state),
          onTap: status.isConnected
              ? null
              : () => _openDevicePicker(context),
          trailing: status.isConnected
              ? TextButton(
                  onPressed: () => ref.read(pendantForgetProvider)(),
                  child: const Text('Forget'),
                )
              : _InlineButton(label: 'Scan & connect', onTap: () => _openDevicePicker(context)),
        ),
        if (status.batteryPercent != null)
          _Tile(
            leading: const Icon(Icons.battery_charging_full, color: kTanuWarm),
            title: 'Battery',
            subtitle: '${status.batteryPercent}%',
        ),
        const SizedBox(height: 12),

        _Section('Voice model'),
        const _SttBackendToggle(),
        const SizedBox(height: 12),
        const _VoiceModelGroup(),
        const SizedBox(height: 12),

        _Section('Data'),
        Card(
          child: _Tile(
            leading: const Icon(Icons.delete_forever_outlined, color: kTanuRed),
            title: 'Delete all local data',
            subtitle: 'Conversations & commitments',
            titleColor: kTanuRed,
            onTap: () => _confirmDeleteAll(),
          ),
        ),
        const SizedBox(height: 24),

        _Section('Developer'),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: ExpansionTile(
              onExpansionChanged: (open) =>
                  setState(() => _developerOpen = open),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.only(bottom: 10),
              leading: const Icon(Icons.developer_mode, color: kTanuWarm),
              title: const Text('Developer tools'),
              trailing: AnimatedRotation(
                turns: _developerOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.expand_more, color: kTanuMuted),
              ),
              children: [
                const Divider(height: 1, indent: 56),
                _Tile(
                  leading: const Icon(Icons.mic, color: kTanuWarm),
                  title: 'Microphone test',
                  subtitle: 'Listen from the phone mic and see the words land',
                  trailing: null,
                  onTap: () =>
                      ref.read(conversationProvider.notifier).microphoneTest(),
                ),
                const Divider(height: 1, indent: 56),
                _Tile(
                  leading: Icon(
                    capture.recording
                        ? Icons.stop_circle_outlined
                        : Icons.fiber_manual_record,
                    color: capture.recording ? kTanuRed : kTanuWarm,
                  ),
                  title: capture.recording ? 'Stop wav capture' : 'Record pendant audio',
                  subtitle: capture.recording
                      ? '${_fmtSize(capture.bytes)} written so far'
                      : (capture.path == null
                          ? 'Save the decoded pendant stream to a .wav file'
                          : 'last: ${capture.path!.split('/').last}'),
                  trailing: null,
                  onTap: () =>
                      ref.read(devCaptureProvider.notifier).toggle(),
                ),
                const Divider(height: 1, indent: 56),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: ValueListenableBuilder<PendantStats>(
                    valueListenable: stats,
                    builder: (context, s, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.show_chart, color: kTanuWarm, size: 20),
                            const SizedBox(width: 12),
                            const Text(
                              'Live audio stats',
                              style: TextStyle(
                                color: kTanuInk,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'notify: ${s.notifySubscribed ? 'on' : 'off'}'
                          ' · ${s.codecLabel}'
                          ' · ${s.packets} pkt / ${s.frames} frames'
                          ' / ${_fmtSize(s.bytes)}'
                          '${s.decodeFailures > 0 ? ' · ${s.decodeFailures} decode fails' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: kTanuMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        const Center(
          child: Text(
            'Tanu · MVP build\nAll data stays on this device.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: kTanuMuted),
          ),
        ),
      ],
    );
  }

  String _stateLabel(PendantState state) => switch (state) {
        PendantState.connected => 'Connected',
        PendantState.scanning => 'Scanning…',
        PendantState.connecting => 'Connecting…',
        PendantState.reconnecting => 'Reconnecting…',
        PendantState.disconnected => 'Not connected',
      };

  static String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete everything?'),
        content: const Text(
            'This removes your conversation history and all commitments locally.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kTanuRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await StorageService.clearAll();
      ref.read(conversationProvider.notifier).clear();
      ref.read(commitmentsProvider.notifier).clear();
    }
  }
}

void _openDevicePicker(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const DevicePickerSheet(),
  );
}

class _Section extends StatelessWidget {
  const _Section(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 10),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: kTanuInk.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

/// Omi-style settings row: circle icon, title, subtitle, chevron/control.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor = kTanuInk,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kTanuChip,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconTheme.merge(
                data: const IconThemeData(size: 20),
                child: leading,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: kTanuMuted),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              const Icon(Icons.chevron_right, size: 20, color: kTanuMuted),
          ],
        ),
      ),
    );
  }
}

class _InlineButton extends StatelessWidget {
  const _InlineButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(onPressed: onTap, child: Text(label));
  }
}

/// Cloud/on-device STT preference. Flipping it persists to settings and, when a
/// conversation is live, hot-swaps the recognizer mid-session.
class _SttBackendToggle extends ConsumerWidget {
  const _SttBackendToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final engine = ref.watch(routingSttEngineProvider);
    final isCloud = settings.sttBackend == SttBackend.cloud;
    final activeLabel = engine.modelLabel;

    return Card(
      child: SwitchListTile(
        value: isCloud,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        secondary: const Icon(Icons.cloud_outlined, color: kTanuWarm),
        title: const Text(
          'Cloud STT (Deepgram)',
          style: TextStyle(fontWeight: FontWeight.w600, color: kTanuInk),
        ),
        subtitle: Text(
          isCloud
              ? 'Streaming to $activeLabel'
              : 'On-device $activeLabel · works offline',
          style: const TextStyle(fontSize: 13, color: kTanuMuted),
        ),
        onChanged: (useCloud) {
          final next = useCloud ? SttBackend.cloud : SttBackend.onDevice;
          ref.read(settingsProvider.notifier).setSttBackend(next);
          ref.read(routingSttEngineProvider).switchBackend(next);
        },
      ),
    );
  }
}

class _VoiceModelGroup extends ConsumerWidget {
  const _VoiceModelGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(sttModelProvider);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Tile(
            leading: const Icon(Icons.record_voice_over, color: kTanuWarm),
            title: 'On-device speech',
            subtitle: _modelSubtitle(model),
            trailing: _trailing(context, ref, model),
          ),
          if (model.phase == SttModelPhase.downloading) ...[
            const Divider(height: 1, indent: 56),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: LinearProgressIndicator(
                value: model.percent == null ? null : (model.percent! / 100),
                color: kTanuWarm,
                backgroundColor: kTanuChip,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                '${model.downloadedBytes ~/ (1024 * 1024)} / '
                '${model.totalBytes ~/ (1024 * 1024)} MB',
                style: const TextStyle(fontSize: 12, color: kTanuMuted),
              ),
            ),
          ],
          if (model.error != null) ...[
            const Divider(height: 1, indent: 56),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                model.error!,
                style: const TextStyle(fontSize: 12, color: kTanuRed),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _modelSubtitle(SttModelState model) {
    final size = (model.totalBytes > 0 ? model.totalBytes : 0) ~/ (1024 * 1024);
    return switch (model.phase) {
      SttModelPhase.checking => 'Checking…',
      SttModelPhase.missing => '${model.modelName} · not downloaded',
      SttModelPhase.downloading =>
        'Downloading ${model.modelName}… ${model.percent ?? 0}%',
      SttModelPhase.ready =>
        '${model.modelName} · $size MB · works offline',
    };
  }

  Widget? _trailing(BuildContext context, WidgetRef ref, SttModelState model) {
    if (model.busy) return const SizedBox.shrink();
    return switch (model.phase) {
      SttModelPhase.ready => TextButton(
          onPressed: () => _confirmDeleteModel(context, ref),
          child: const Text('Delete'),
        ),
      SttModelPhase.missing => FilledButton(
          onPressed: () => ref.read(sttModelProvider.notifier).download(),
          child: const Text('Download'),
        ),
      _ => null,
    };
  }

  Future<void> _confirmDeleteModel(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete speech model?'),
        content: const Text(
            'It will be re-downloaded the next time you need it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kTanuRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(sttModelProvider.notifier).deleteModel();
    }
  }
}