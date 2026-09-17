import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tanu_app/services/ble/omi_reassembler.dart';

/// Builds a BLE notification matching the DevKit wire format:
/// `[packet_index: 2 LE][chunk_index: 1][payload]`.
Uint8List _notify(int packetId, int chunkIndex, List<int> payload) {
  return Uint8List.fromList([
    packetId & 0xFF,
    (packetId >> 8) & 0xFF,
    chunkIndex,
    ...payload,
  ]);
}

void main() {
  group('OmiReassembler', () {
    test('flushes one packet per notification when MTU is large', () {
      final packets = <Uint8List>[];
      final r = OmiReassembler(onPacket: packets.add);

      r.add(_notify(0, 0, [1, 2, 3]));
      r.add(_notify(1, 0, [4, 5]));
      r.add(_notify(2, 0, [6]));

      expect(packets.length, 2, reason: 'frame boundaries are packet_index');
      expect(packets[0], [1, 2, 3]);
      expect(packets[1], [4, 5]);
      // chunk_index being constant 0 must NOT prevent flushing.
      r.flush();
      expect(packets.length, 3);
      expect(packets[2], [6]);
    });

    test('reassembles a packet split across multiple chunks', () {
      final packets = <Uint8List>[];
      final r = OmiReassembler(onPacket: packets.add);

      // One 150-byte Opus packet across three notifications (mtu ~ 53).
      for (var i = 0; i < 3; i++) {
        r.add(_notify(10, i, List.filled(50, 10 + i)));
      }
      // Next packet starts.
      r.add(_notify(11, 0, [9, 9]));

      expect(packets.length, 1);
      expect(packets[0].length, 150);
      for (var i = 0; i < 3; i++) {
        expect(packets[0].sublist(i * 50, i * 50 + 50), List.filled(50, 10 + i));
      }
      r.flush();
      expect(packets.length, 2);
      expect(packets[1], [9, 9]);
    });

    test('a partial packet after a gap still gets delivered to the decoder', () {
      final packets = <Uint8List>[];
      final r = OmiReassembler(onPacket: packets.add);

      r.add(_notify(20, 0, [1, 2]));
      // Notification for chunk 1 is lost; next packet arrives instead.
      r.add(_notify(21, 0, [3, 4]));

      // The partial frame 20 is flushed to the decoder (Opus rejects it);
      // then frame 21 completes on its own boundary.
      expect(packets.length, 1);
      expect(packets[0], [1, 2]);
      r.flush();
      expect(packets.length, 2);
      expect(packets[1], [3, 4]);
    });

    test('reassembler id generation is little-endian', () {
      final packets = <Uint8List>[];
      final r = OmiReassembler(onPacket: packets.add);

      // packet_index 0x0201 (=513)
      r.add(Uint8List.fromList([0x01, 0x02, 0x00, 0xAA]));
      r.add(_notify(514, 0, [0xBB]));
      r.flush();
      expect(packets.length, 2);
      expect(packets[0], [0xAA]);
    });
  });
}