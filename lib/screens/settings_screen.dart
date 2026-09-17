import 'package:flutter/cupertino.dart';
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

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text('Settings'),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                CupertinoListSection.insetGrouped(
                  header: const Text('PENDANT'),
                  children: [
                    CupertinoListTile(
                      leading: Icon(
                        CupertinoIcons.bluetooth,
                        color: status.isConnected ? CupertinoColors.systemGreen : CupertinoColors.systemGrey,
                      ),
                      title: Text(status.deviceName ?? 'Pendant'),
                      subtitle: Text(_stateLabel(status.state)),
                      trailing: status.isConnected
                          ? CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => ref.read(pendantForgetProvider)(),
                              child: const Text('Forget', style: TextStyle(fontSize: 15)),
                            )
                          : CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _openDevicePicker(context),
                              child: const Text('Scan & connect', style: TextStyle(fontSize: 15)),
                            ),
                    ),
                    if (status.batteryPercent != null)
                      CupertinoListTile(
                        leading: const Icon(CupertinoIcons.battery_100, color: CupertinoColors.systemGreen),
                        title: const Text('Battery'),
                        additionalInfo: Text('${status.batteryPercent}%'),
                      ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('VOICE MODEL'),
                  children: const [
                    _SttBackendToggle(),
                    _VoiceModelGroup(),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('DATA'),
                  children: [
                    CupertinoListTile(
                      leading: const Icon(CupertinoIcons.delete_solid, color: CupertinoColors.destructiveRed),
                      title: const Text('Delete all local data', style: TextStyle(color: CupertinoColors.destructiveRed)),
                      subtitle: const Text('Conversations & commitments'),
                      onTap: () => _confirmDeleteAll(),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('DEVELOPER'),
                  children: [
                    CupertinoListTile(
                      leading: const Icon(CupertinoIcons.chevron_left_slash_chevron_right),
                      title: const Text('Developer tools'),
                      trailing: AnimatedRotation(
                        turns: _developerOpen ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(CupertinoIcons.chevron_down, color: CupertinoColors.systemGrey),
                      ),
                      onTap: () => setState(() => _developerOpen = !_developerOpen),
                    ),
                    if (_developerOpen) ...[
                      CupertinoListTile(
                        leading: const Icon(CupertinoIcons.mic_fill, color: CupertinoColors.activeBlue),
                        title: const Text('Microphone test'),
                        subtitle: const Text('Listen from the phone mic'),
                        onTap: () => ref.read(conversationProvider.notifier).microphoneTest(),
                      ),
                      CupertinoListTile(
                        leading: Icon(
                          capture.recording ? CupertinoIcons.stop_circle_fill : CupertinoIcons.circle_fill,
                          color: capture.recording ? CupertinoColors.destructiveRed : CupertinoColors.activeBlue,
                        ),
                        title: Text(capture.recording ? 'Stop wav capture' : 'Record pendant audio'),
                        subtitle: Text(
                          capture.recording
                              ? '${_fmtSize(capture.bytes)} written so far'
                              : (capture.path == null
                                  ? 'Save decoded stream to .wav'
                                  : 'last: ${capture.path!.split('/').last}'),
                        ),
                        onTap: () => ref.read(devCaptureProvider.notifier).toggle(),
                      ),
                      CupertinoListTile(
                        title: const Text('Live audio stats'),
                        subtitle: ValueListenableBuilder<PendantStats>(
                          valueListenable: stats,
                          builder: (context, s, _) => Text(
                            'notify: ${s.notifySubscribed ? 'on' : 'off'}'
                            ' · ${s.codecLabel}'
                            ' · ${s.packets} pkt / ${s.frames} frames'
                            ' / ${_fmtSize(s.bytes)}'
                            '${s.decodeFailures > 0 ? ' · ${s.decodeFailures} decode fails' : ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Tanu · MVP build\nAll data stays on this device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
                  ),
                ),
                const SizedBox(height: 50), // bottom nav padding
              ],
            ),
          ),
        ],
      ),
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
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete everything?'),
        content: const Text(
            'This removes your conversation history and all commitments locally.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
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
  showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => const DevicePickerSheet(),
  );
}

class _SttBackendToggle extends ConsumerWidget {
  const _SttBackendToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final engine = ref.watch(routingSttEngineProvider);
    final isCloud = settings.sttBackend == SttBackend.cloud;
    final activeLabel = engine.modelLabel;

    return CupertinoListTile(
      leading: const Icon(CupertinoIcons.cloud),
      title: const Text('Cloud STT (Deepgram)'),
      subtitle: Text(isCloud ? 'Streaming to $activeLabel' : 'On-device $activeLabel'),
      trailing: CupertinoSwitch(
        value: isCloud,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CupertinoListTile(
          leading: const Icon(CupertinoIcons.waveform_circle_fill),
          title: const Text('On-device speech'),
          subtitle: Text(_modelSubtitle(model)),
          trailing: _trailing(context, ref, model),
        ),
        if (model.phase == SttModelPhase.downloading) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: model.percent == null ? null : (model.percent! / 100),
                  color: CupertinoColors.activeBlue,
                  backgroundColor: CupertinoColors.systemGrey5,
                ),
                const SizedBox(height: 8),
                Text(
                  '${model.downloadedBytes ~/ (1024 * 1024)} / '
                  '${model.totalBytes ~/ (1024 * 1024)} MB',
                  style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                ),
              ],
            ),
          ),
        ],
        if (model.error != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              model.error!,
              style: const TextStyle(fontSize: 12, color: CupertinoColors.destructiveRed),
            ),
          ),
        ],
      ],
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
      SttModelPhase.ready => CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _confirmDeleteModel(context, ref),
          child: const Text('Delete', style: TextStyle(color: CupertinoColors.destructiveRed, fontSize: 15)),
        ),
      SttModelPhase.missing => CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => ref.read(sttModelProvider.notifier).download(),
          child: const Text('Download', style: TextStyle(fontSize: 15)),
        ),
      _ => null,
    };
  }

  Future<void> _confirmDeleteModel(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete speech model?'),
        content: const Text(
            'It will be re-downloaded the next time you need it.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
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