import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Scan Button
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black),
                    ),
                    child: const Text('Scan / Connected'),
                  ),
                  const SizedBox(height: 20),
                  // Live Stream Area
                  Container(
                    width: double.infinity,
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text('LIVE STREAM', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Search
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search to recall...',
                      prefixIcon: const Icon(Icons.search, color: Colors.black),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Recent Memories', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: 4,
                      itemBuilder: (context, index) => Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(child: Text('Memory ${index + 1}')),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Floating Navigation Bar
          Positioned(
            bottom: 30,
            left: 40,
            right: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const Icon(Icons.book, color: Colors.white),
                  const Icon(Icons.chat_bubble_outline, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
