import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF841EA0),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF841EA0).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.security,
                        size: 60,
                        color: const Color(0xFF841EA0),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF841EA0),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Login to continue',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Email Field
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(
                          Icons.email,
                          color: const Color(0xFF841EA0),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(
                          Icons.lock,
                          color: const Color(0xFF841EA0),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey.shade600,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          // TODO: Navigate to Forgot Password
                        },
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(color: const Color(0xFF841EA0)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Login Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: Add login logic
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Login feature coming soon!'),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF841EA0),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'LOGIN',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Sign Up
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account?",
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        TextButton(
                          onPressed: () {
                            // TODO: Navigate to Signup
                          },
                          child: Text(
                            'Sign Up',
                            style: TextStyle(
                              color: const Color(0xFF841EA0),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
