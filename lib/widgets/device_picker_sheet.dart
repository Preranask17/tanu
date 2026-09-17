import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ble_device.dart';
import '../providers/ble_provider.dart';

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
      child: Container(
        color: CupertinoColors.systemBackground,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16, top: 4),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey4,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const Text(
              'Connect your pendant',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              scanning
                  ? 'Scanning for nearby Bluetooth devices…'
                  : 'Pick your pendant from the list below.',
              style: const TextStyle(
                fontSize: 15,
                color: CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(height: 16),

            if (_error != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: CupertinoColors.destructiveRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CupertinoColors.destructiveRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 20, color: CupertinoColors.destructiveRed),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.destructiveRed,
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
                                  const CupertinoActivityIndicator(radius: 14),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Looking…',
                                    style: TextStyle(
                                      color: CupertinoColors.systemGrey,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                _error == null
                                    ? 'No devices found.'
                                    : 'Try again.',
                                style: TextStyle(
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                      )
                    : ListView.separated(
                        itemCount: devices.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          color: CupertinoColors.systemGrey5,
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

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    onPressed: _connectingId != null ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CupertinoButton.filled(
                    onPressed: _connectingId != null ? null : _restartScan,
                    child: const Text('Scan again', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
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
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            const Icon(
              CupertinoIcons.device_laptop,
              color: CupertinoColors.systemGrey,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${device.id}   ·   ${device.rssi} dBm',
                    style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
                  ),
                ],
              ),
            ),
            if (connecting)
              const CupertinoActivityIndicator()
            else
              Icon(
                connected ? CupertinoIcons.checkmark_alt_circle_fill : CupertinoIcons.chevron_right,
                color: connected ? CupertinoColors.activeBlue : CupertinoColors.systemGrey4,
              ),
          ],
        ),
      ),
    );
  }
}