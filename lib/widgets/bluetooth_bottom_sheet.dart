import 'package:flutter/material.dart';

class BluetoothBottomSheet extends StatelessWidget {
  const BluetoothBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const Text('Connect Pendant', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          // List of devices...
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: const Text('Tanu Pendant'),
                  trailing: ElevatedButton(onPressed: () {}, child: const Text('Connect')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
