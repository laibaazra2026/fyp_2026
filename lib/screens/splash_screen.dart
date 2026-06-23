import 'dart:async';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _logoScale = 0.0;
  double _logoOpacity = 0.0;
  double _textOpacity = 0.0;
  double _textOffset = 50.0;

  @override
  void initState() {
    super.initState();

    // Start animations after 100ms
    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() {
        _logoScale = 1.0;
        _logoOpacity = 1.0;
      });
    });

    // Text animation starts after logo
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _textOpacity = 1.0;
        _textOffset = 0.0;
      });
    });

    // Navigate after 3 seconds
    Timer(const Duration(seconds: 3), () {
      // Navigation will be added later
    });
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
              // LOGO with Scale + Fade Animation
              AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutBack,
                width: _logoScale == 0.0 ? 0.0 : 150.0,
                height: _logoScale == 0.0 ? 0.0 : 150.0,
                child: Opacity(
                  opacity: _logoOpacity,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.security,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // APP NAME with Fade + Slide Animation
              Opacity(
                opacity: _textOpacity,
                child: Transform.translate(
                  offset: Offset(0, _textOffset),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
