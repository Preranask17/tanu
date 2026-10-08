import 'package:flutter/material.dart';

class BluetoothStatusButton extends StatelessWidget {
  final bool isConnected;
  final VoidCallback onTap;

  const BluetoothStatusButton({
    super.key,
    required this.isConnected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isConnected ? Colors.green[400] : Colors.red[400],
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(Icons.bluetooth, color: Colors.white, size: 20),
      ),
    );
  }
}
