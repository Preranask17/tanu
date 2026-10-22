import 'package:flutter/material.dart';

import '../theme/tanu_colors.dart';

class TopStatusRow extends StatelessWidget {
  final bool isConnected;
  final VoidCallback onBluetoothTap;
  final VoidCallback onLivePreviewTap;
  final String? liveTranscript;

  const TopStatusRow({
    super.key,
    required this.isConnected,
    required this.onBluetoothTap,
    required this.onLivePreviewTap,
    this.liveTranscript,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.tanuColors;
    final hasLive = liveTranscript != null && liveTranscript!.trim().isNotEmpty;
    final displayText = hasLive 
        ? "● LIVE: $liveTranscript" 
        : (isConnected ? "No conversation currently" : "Pendant not connected");

    return Row(
      children: [
        // Bluetooth Button with subtle glow effect (Top Left)
        GestureDetector(
          onTap: onBluetoothTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.surface,
              boxShadow: [
                BoxShadow(
                  color: (isConnected ? c.success : c.danger).withValues(
                    alpha: 0.35,
                  ),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 0),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(
                color: (isConnected ? c.success : c.danger).withValues(
                  alpha: 0.5,
                ),
                width: 1.5,
              ),
            ),
            child: Icon(
              isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
              color: isConnected ? c.success : c.danger,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Live Stream status / notification rounded rectangle (Top Right)
        Expanded(
          child: GestureDetector(
            onTap: onLivePreviewTap,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(color: c.border, width: 1),
              ),
              child: Text(
                displayText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: hasLive ? c.danger : c.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
