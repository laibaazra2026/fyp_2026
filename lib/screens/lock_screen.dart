import 'package:flutter/material.dart';
import 'package:flutter_screen_lock/flutter_screen_lock.dart';

class LockScreen extends StatelessWidget {
  final String correctPin;

  const LockScreen({super.key, required this.correctPin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.purple.shade900, Colors.purple.shade700],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 80, color: Colors.white),
              const SizedBox(height: 20),
              const Text(
                '🔒 Device Locked',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Enter PIN to unlock',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ScreenLock(
                  correctString: correctPin,
                  title: const Text(
                    'Enter PIN',
                    style: TextStyle(color: Colors.white),
                  ),
                  onUnlocked: () {
                    Navigator.pop(context, true);
                  },
                  onCancelled: () {
                    Navigator.pop(context, false);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
