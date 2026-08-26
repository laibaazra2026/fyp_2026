import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sim_reader/sim_reader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String _errorMessage = '';

  // Password Security Rules
  String? _validatePassword(String password) {
    if (password.isEmpty) return 'Password cannot be empty.';
    if (password.length < 8) {
      return 'Password must be at least 8 characters long.';
    }
    if (password.contains(' ')) return 'Password cannot contain spaces.';
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter.';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter.';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number.';
    }
    return null;
  }

  // STEP 1: Start Signup & Trigger Owner Phone Verification
  Future<void> _signup() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _emergencyPhoneController.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill out all input fields.');
      return;
    }

    String? passwordError = _validatePassword(_passwordController.text);
    if (passwordError != null) {
      setState(() => _errorMessage = passwordError);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 1. Create account in Firebase Auth with Email & Password
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      // 2. Send official email verification link
      await userCredential.user?.sendEmailVerification();

      // 3. Begin Owner Phone Verification Flow
      await _startOwnerPhoneVerification(userCredential.user!.uid);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // STEP 2: Verify Owner Phone
  Future<void> _startOwnerPhoneVerification(String uid) async {
    String ownerPhone = _phoneController.text.trim();

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: ownerPhone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-resolution if supported, move straight to emergency verification
        await _startEmergencyPhoneVerification(uid);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Owner Phone Verification Failed: ${e.message}';
        });
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() => _isLoading = false);
        _showOwnerOtpDialog(verificationId, uid);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  void _showOwnerOtpDialog(String verificationId, String uid) {
    _otpController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('📱 Verify Your Phone Number'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter sandbox 6-digit OTP code for YOUR phone (e.g., 123456).',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: '6-digit OTP',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF841EA0),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _verifyOwnerOtpCode(
                verificationId,
                uid,
                _otpController.text.trim(),
              );
            },
            child: const Text(
              'Verify Owner Phone',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyOwnerOtpCode(
    String verificationId,
    String uid,
    String smsCode,
  ) async {
    setState(() => _isLoading = true);
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      // Owner phone successfully verified! Now proceed to Emergency Phone verification.
      await _startEmergencyPhoneVerification(uid);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid Owner OTP Code: $e';
      });
    }
  }

  // STEP 3: Start Emergency Phone Verification
  Future<void> _startEmergencyPhoneVerification(String uid) async {
    String emergencyPhone = _emergencyPhoneController.text.trim();

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: emergencyPhone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _finalizeRegistration(uid);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Emergency Phone Verification Failed: ${e.message}';
        });
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() => _isLoading = false);
        _showEmergencyOtpDialog(verificationId, uid);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  void _showEmergencyOtpDialog(String verificationId, String uid) {
    _otpController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🚨 Verify Emergency Phone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter sandbox 6-digit OTP code for EMERGENCY phone (e.g., 123456).',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: '6-digit OTP',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF841EA0),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _verifyEmergencyOtpCode(
                verificationId,
                uid,
                _otpController.text.trim(),
              );
            },
            child: const Text(
              'Verify & Complete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyEmergencyOtpCode(
    String verificationId,
    String uid,
    String smsCode,
  ) async {
    setState(() => _isLoading = true);
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      // Both phones verified! Finalize account and save to Firestore.
      await _finalizeRegistration(uid);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid Emergency OTP Code: $e';
      });
    }
  }

  // STEP 4: Finalize and save details to Firestore
  Future<void> _finalizeRegistration(String uid) async {
    try {
      await Permission.phone.request();

      String initialCarrier = 'Unknown';
      String initialCountry = 'Unknown';

      try {
        SimInfo? simInfo = await SimReader.getSimInfo();
        if (simInfo != null) {
          initialCarrier = simInfo.carrierName ?? 'Unknown';
          initialCountry = simInfo.countryCode ?? 'Unknown';
        }
      } catch (e) {
        print("Could not fetch initial SIM info: $e");
      }

      // Save user profile with BOTH numbers verified
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'isOwnerPhoneVerified': true,
        'emergencyPhone': _emergencyPhoneController.text.trim(),
        'isEmergencyPhoneVerified': true,
        'baselineCarrier': initialCarrier,
        'baselineCountry': initialCountry,
        'isSimChanged': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ Account created & both phone numbers verified via Sandbox!',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 6),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error saving profile: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF841EA0),
        child: SafeArea(
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
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF841EA0).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_add,
                          size: 60,
                          color: Color(0xFF841EA0),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF841EA0),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Protect your device today',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 30),

                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: const Icon(
                            Icons.person,
                            color: Color(0xFF841EA0),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: const Icon(
                            Icons.email,
                            color: Color(0xFF841EA0),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password (8+ chars, A-Z, 0-9)',
                          prefixIcon: const Icon(
                            Icons.lock,
                            color: Color(0xFF841EA0),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Your Phone (Sandbox OTP Verified)',
                          hintText: '+923001234567',
                          prefixIcon: const Icon(
                            Icons.phone,
                            color: Color(0xFF841EA0),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _emergencyPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Emergency Phone (Sandbox OTP Verified)',
                          hintText: '+923007654321',
                          prefixIcon: const Icon(
                            Icons.phone_android,
                            color: Color(0xFF841EA0),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _errorMessage,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _signup,
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
                                  'Sign up ' ,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
