import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _auth = AuthService();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = '📧 Please enter your email address.';
        _isLoading = false;
      });
      return;
    }

    if (_passwordController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = '🔒 Please enter your password.';
        _isLoading = false;
      });
      return;
    }

    try {
      await _auth.login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Login Successful! Welcome back.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (e) {
      String error = e.toString().replaceAll('Exception: ', '');

      if (error.contains('email') && error.contains('verified')) {
        setState(() {
          _errorMessage =
              '⚠️ Please verify your email first.\nCheck your inbox and click the verification link.';
        });
      } else if (error.contains('user-not-found')) {
        setState(() {
          _errorMessage =
              '❌ No account found with this email.\nPlease Sign Up first.';
        });
      } else if (error.contains('wrong-password')) {
        setState(() {
          _errorMessage =
              '❌ Incorrect password.\nPlease try again or reset your password.';
        });
      } else if (error.contains('too-many-requests')) {
        setState(() {
          _errorMessage =
              '⏳ Too many failed attempts.\nPlease try again later.';
        });
      } else if (error.contains('invalid-email')) {
        setState(() {
          _errorMessage = '📧 Please enter a valid email address.';
        });
      } else if (error.contains('network')) {
        setState(() {
          _errorMessage =
              '📡 No internet connection.\nPlease check your network and try again.';
        });
      } else {
        setState(() {
          _errorMessage = '⚠️ $error';
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ForgotPasswordScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(color: const Color(0xFF841EA0)),
                        ),
                      ),
                    ),

                    // Error Message
                    if (_errorMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _errorMessage.contains('✅')
                              ? Colors.green.shade50
                              : _errorMessage.contains('⚠️')
                              ? Colors.orange.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _errorMessage.contains('✅')
                                ? Colors.green.shade200
                                : _errorMessage.contains('⚠️')
                                ? Colors.orange.shade200
                                : Colors.red.shade200,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _errorMessage,
                          style: TextStyle(
                            color: _errorMessage.contains('✅')
                                ? Colors.green.shade700
                                : _errorMessage.contains('⚠️')
                                ? Colors.orange.shade700
                                : Colors.red.shade700,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Login Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF841EA0),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SignupScreen(),
                              ),
                            );
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
