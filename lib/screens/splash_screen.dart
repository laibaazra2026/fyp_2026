import 'dart:async';
import 'package:flutter/material.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();

    // Navigate to Login after 3 seconds
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()), // ← NO const
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF841EA0);

    return Scaffold(
      body: Container(
        color: primaryColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.security,
                      size: 100,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // App Name
              FadeTransition(
                opacity: _fadeAnimation,
                child: const Text(
                  'DEVICE PROTECTION',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 3,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
