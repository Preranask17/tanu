import 'package:flutter/material.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              color: isDark ? const Color(0xFF1a1a1a) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: isConnected
                      ? Colors.green.withValues(alpha: 0.35)
                      : Colors.red.withValues(alpha: 0.35),
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
                color: isConnected
                    ? Colors.green.withValues(alpha: 0.5)
                    : Colors.red.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Icon(
              isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
              color: isConnected ? Colors.green[400] : Colors.red[400],
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
                color: isDark ? const Color(0xFF111111) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
                  width: 1,
                ),
              ),
              child: Text(
                displayText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: hasLive
                      ? Colors.red[400]
                      : (isDark ? Colors.grey[300] : const Color(0xFF4A453F)),
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
