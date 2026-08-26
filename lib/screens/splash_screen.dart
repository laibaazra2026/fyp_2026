import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _shimmerController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _footerFadeAnimation;

  @override
  void initState() {
    super.initState();

    // Main entrance animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Continuous crystal color-flowing shimmer animation for the title
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    // Smooth delayed fade animation specifically for the footer
    _footerFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );

    _animationController.forward();

    // Navigate after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryPurple = Color(0xFF841EA0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Animated Logo Shield
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: primaryPurple.withOpacity(0.08),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryPurple.withOpacity(0.15),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      size: 95,
                      color: primaryPurple,
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // Title: "DEVICE PROTECTION" with crystal multi-color gradient traveling across both words
                AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, child) {
                    return ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          colors: const [
                            Color(0xFF00ACC1), // Cyan
                            Color(0xFF841EA0), // Purple
                            Color(0xFFFF6F00), // Amber/Orange
                            Color(0xFF00ACC1), // Cyan loop
                          ],
                          stops: const [0.0, 0.35, 0.7, 1.0],
                          begin: Alignment(_shimmerController.value - 1, 0),
                          end: Alignment(_shimmerController.value, 0),
                        ).createShader(bounds);
                      },
                      child: const Text(
                        'DEVICE PROTECTION',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white, // Required for ShaderMask
                          letterSpacing: 2.0,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 14),

                // Accent Subtitle (Secure • Track • Protect)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Secure',
                      style: TextStyle(
                        color: primaryPurple,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: CircleAvatar(
                        radius: 2.5,
                        backgroundColor: Colors.grey.shade400,
                      ),
                    ),
                    const Text(
                      'Track',
                      style: TextStyle(
                        color: Color(0xFF00838F),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: CircleAvatar(
                        radius: 2.5,
                        backgroundColor: Colors.grey.shade400,
                      ),
                    ),
                    const Text(
                      'Protect',
                      style: TextStyle(
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 45),

                // Sleek Loading Spinner
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      primaryPurple,
                    ),
                    strokeWidth: 2.5,
                  ),
                ),

                const Spacer(),

                // Animated Solid Purple Footer: "Developed by : Laiba & Azra"
                FadeTransition(
                  opacity: _footerFadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Text(
                      'Developed by : Laiba & Azra',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: primaryPurple, // Solid Purple as requested
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
