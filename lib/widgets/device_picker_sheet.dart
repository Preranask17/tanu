import 'dart:async';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! > 300) {
                Navigator.of(context).pop();
              }
            },
            child: Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              clipBehavior: Clip.antiAlias,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Drag handle ──
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12, top: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).dividerTheme.color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),

                      // ── Title ──
                      Text(
                        'Connect your pendant',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),

                      // ── Subtitle ──
                      Text(
                        scanning
                            ? 'Scanning for nearby Bluetooth devices\u2026'
                            : 'Pick your pendant from the list below.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF888888),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Error banner ──
                      if (_error != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 18,
                                color: Colors.redAccent,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // ── Device list ──
                      Flexible(
                        child: SizedBox(
                          height: 200,
                          child: devices.isEmpty
                              ? Center(
                                  child: scanning
                                      ? const Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                            SizedBox(height: 12),
                                            Text(
                                              'Looking\u2026',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF888888),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Text(
                                          _error == null
                                              ? 'No devices found.'
                                              : 'Try again.',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF888888),
                                          ),
                                        ),
                                )
                              : ListView.separated(
                                  itemCount: devices.length,
                                  separatorBuilder: (_, __) => Container(
                                    height: 1,
                                    color: Theme.of(context).dividerTheme.color,
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

                      // ── Action buttons ──
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: _connectingId != null
                                  ? null
                                  : () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: isDark ? Colors.white : Colors.black,
                                backgroundColor: isDark ? const Color(0xFF222222) : const Color(0xFFF0F0F0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _connectingId != null
                                  ? null
                                  : _restartScan,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Scan again'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Device row
// ─────────────────────────────────────────────────────────────────────────────

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          children: [
            const Icon(
              Icons.memory,
              color: Color(0xFF888888),
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.displayName,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${device.id}   \u00b7   ${device.rssi} dBm',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF888888),
                    ),
                  ),
                ],
              ),
            ),
            if (connecting)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                connected
                    ? Icons.check_circle
                    : Icons.chevron_right,
                color: connected
                    ? Theme.of(context).primaryColor
                    : const Color(0xFF888888),
              ),
          ],
        ),
      ),
    );
  }
}
