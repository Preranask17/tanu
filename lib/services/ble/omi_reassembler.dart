import 'dart:typed_data';

/// Reassembles Omi DevKit BLE audio notifications into complete Opus packets.
///
/// Wire format (see omi/firmware/devkit/src/transport.c):
///   `[packet_index: 2 bytes LE][chunk_index: 1 byte][payload bytes...]`
///
/// A complete Opus packet is the payload across all chunks that share the same
/// [packet_index]; the next [packet_index] starts the next Opus packet.
/// [chunk_index] only splits one packet across notifications when it exceeds
/// `mtu - 3`; at large MTU it is always 0, so a reassembler keyed on it would
/// never flush a frame. Dropped notifications yield a partial packet which is
/// discarded on the next frame boundary (Opus tolerates frame loss).
class OmiReassembler {
  OmiReassembler({required this.onPacket});

  /// Called once per complete, ordered Opus packet.
  final void Function(Uint8List opusPacket) onPacket;

  bool _gotFirst = false;
  int _lastPacketId = -1;
  final List<Uint8List> _pendingChunks = [];

  /// Feed one BLE notification (3-byte header + payload).
  void add(Uint8List notification) {
    if (notification.length < 4) return;

    final packetId = ByteData.sublistView(
      notification,
    ).getUint16(0, Endian.little);
    final payload = Uint8List.sublistView(notification, 3);

    if (!_gotFirst) {
      _gotFirst = true;
      _lastPacketId = packetId;
      _pendingChunks.add(payload);
      return;
    }

    if (packetId != _lastPacketId) {
      flush();
    }
    _lastPacketId = packetId;
    _pendingChunks.add(payload);
  }

  /// Force-complete whatever packet is in flight (e.g. on disconnect).
  void flush() {
    if (_pendingChunks.isEmpty) return;

    int total = 0;
    for (final c in _pendingChunks) {
      total += c.length;
    }
    final packet = Uint8List(total);
    int offset = 0;
    for (final c in _pendingChunks) {
      packet.setRange(offset, offset + c.length, c);
      offset += c.length;
    }
    _pendingChunks.clear();
    onPacket(packet);
  }

  void reset() {
    _gotFirst = false;
    _lastPacketId = -1;
    _pendingChunks.clear();
  }
}
