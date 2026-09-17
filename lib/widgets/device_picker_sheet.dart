import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ble_device.dart';
import '../providers/ble_provider.dart';
import '../theme.dart';

/// Bottom sheet that scans for nearby BLE devices and lets the user pick the
/// pendant. The device name is never assumed — anything connectable shows up.
class DevicePickerSheet extends ConsumerStatefulWidget {
  const DevicePickerSheet({super.key});

  @override
  ConsumerState<DevicePickerSheet> createState() => _DevicePickerSheetState();
}

class _DevicePickerSheetState extends ConsumerState<DevicePickerSheet> {
  bool _scanning = false;
  bool _started = false;
  String? _connectingId;
  String? _error;
  Timer? _scanLock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  @override
  void dispose() {
    _scanLock?.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (_started) return;
    _started = true;
    setState(() {
      _scanning = true;
      _error = null;
    });
    _scanLock?.cancel();
    _scanLock = Timer(const Duration(seconds: 20), () {
      if (mounted) setState(() => _scanning = false);
    });
    try {
      await ref.read(startScanProvider)();
    } catch (e) {
      if (!mounted) return;
      _scanLock?.cancel();
      setState(() {
        _scanning = false;
        _error = _friendlyError(e);
      });
    }
  }

  Future<void> _restartScan() async {
    _started = false;
    await _startScan();
  }

  Future<void> _connect(String remoteId) async {
    setState(() {
      _connectingId = remoteId;
      _error = null;
    });
    try {
      await ref.read(connectToDeviceProvider)(remoteId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connectingId = null;
        _error = _friendlyError(e);
      });
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.toLowerCase().contains('bluetooth is off')) {
      return 'Bluetooth is off. Turn it on and scan again.';
    }
    if (s.toLowerCase().contains('could not start')) {
      return 'Could not start scanning. Location access may be required.';
    }
    if (s.toLowerCase().contains('connection')) {
      return 'Could not connect to that device. Make sure it\'s on and try again.';
    }
    return 'Something went wrong: $e';
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(discoveredDevicesProvider);
    final devices = devicesAsync.value ?? const <DiscoveredDevice>[];

    final scanning = _scanning || devicesAsync.isLoading;

    return SafeArea(
      child: Material(
        color: kTanuBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: kTanuInk.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Connect your pendant',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: kTanuInk,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              scanning
                  ? 'Scanning for nearby Bluetooth devices…'
                  : 'Pick your pendant from the list below.',
              style: TextStyle(
                fontSize: 13,
                color: kTanuInk.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),

            if (_error != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: kTanuInk.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kTanuInk.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 18, color: kTanuInk),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          fontSize: 13,
                          color: kTanuInk.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Flexible(
              child: SizedBox(
                height: 340,
                child: devices.isEmpty
                    ? Center(
                        child: scanning
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 26,
                                    height: 26,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: kTanuInk,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Looking…',
                                    style: TextStyle(
                                      color: kTanuInk.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                _error == null
                                    ? 'No devices found.'
                                    : 'Try again.',
                                style: TextStyle(
                                  color: kTanuInk.withValues(alpha: 0.7),
                                ),
                              ),
                      )
                    : ListView.separated(
                        itemCount: devices.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: kTanuInk.withValues(alpha: 0.08),
                        ),
                        itemBuilder: (context, index) {
                          final d = devices[index];
                          return _DeviceRow(
                            device: d,
                            connected: false,
                            connecting: _connectingId == d.id,
                            enabled: _connectingId == null,
                            onTap: () => _connect(d.id),
                          );
                        },
                      ),
              ),
            ),

            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: scanning ? null : _restartScan,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Scan again'),
                ),
                FilledButton(
                  onPressed:
                      _connectingId != null ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.connected,
    required this.connecting,
    required this.enabled,
    required this.onTap,
  });

  final DiscoveredDevice device;
  final bool connected;
  final bool connecting;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: enabled ? onTap : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(
        Icons.watch_outlined,
        color: kTanuInk.withValues(alpha: 0.7),
      ),
      title: Text(
        device.displayName,
        style: const TextStyle(fontWeight: FontWeight.w600, color: kTanuInk),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${device.id}   ·   ${device.rssi} dBm',
        style: TextStyle(fontSize: 12, color: kTanuInk.withValues(alpha: 0.55)),
      ),
      trailing: connecting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: kTanuInk),
            )
          : Icon(
              connected ? Icons.check_circle : Icons.chevron_right,
              color: kTanuInk.withValues(alpha: 0.7),
            ),
    );
  }
}