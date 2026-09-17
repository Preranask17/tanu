/// A BLE device the app saw during a scan, made phone-friendly.
///
/// The pendant can advertise under any name (it ships as "Omi" but may be
/// renamed), so we never filter on the name — the user picks from this list.
class DiscoveredDevice {
  const DiscoveredDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.isConnectable,
  });

  /// Stable BLE address (MAC / remote id).
  final String id;

  /// Local name from the advertisement, or '' if the device doesn't broadcast one.
  final String name;

  /// Signal strength in dBm (higher/closer = better).
  final int rssi;

  /// Whether the device advertised itself as connectable.
  final bool isConnectable;

  String get displayName => name.isEmpty ? 'Unknown device' : name;

  @override
  bool operator ==(Object other) => other is DiscoveredDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;
}