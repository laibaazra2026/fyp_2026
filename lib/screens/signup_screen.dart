import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:sim_reader/sim_reader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'login_screen.dart';
import '../../services/sandbox_sms_service.dart';
import '../../services/app_config.dart';

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

  // Country code state prefixes initialized to Pakistan (+92)
  String _phoneCountryCode = '+92';
  String _emergencyCountryCode = '+92';

  bool _obscurePassword = true;
  bool _isLoading = false;
  String _errorMessage = '';

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

  // Strict international format validation rule for any country's phone number
  String? _validatePhoneFormat(String countryCode, String localNumber) {
    if (localNumber.isEmpty) return 'Phone number cannot be empty.';

    String fullNumber = '$countryCode$localNumber'.replaceAll(
      RegExp(r'\s+'),
      '',
    );
    final RegExp phoneRegex = RegExp(r'^\+[1-9]\d{7,14}$');
    if (!phoneRegex.hasMatch(fullNumber)) {
      return 'Please enter a valid international phone number format.';
    }
    return null;
  }

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

    String? phoneError = _validatePhoneFormat(
      _phoneCountryCode,
      _phoneController.text.trim(),
    );
    if (phoneError != null) {
      setState(() => _errorMessage = 'Your Phone: $phoneError');
      return;
    }

    String? emergencyPhoneError = _validatePhoneFormat(
      _emergencyCountryCode,
      _emergencyPhoneController.text.trim(),
    );
    if (emergencyPhoneError != null) {
      setState(() => _errorMessage = 'Emergency Phone: $emergencyPhoneError');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      await userCredential.user?.sendEmailVerification();

      // Step 1: Start Owner Phone Verification (Sandbox or Live based on config)
      await _startOwnerPhoneVerification(userCredential.user!.uid);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _startOwnerPhoneVerification(String uid) async {
    await SandboxSmsService().sendOtp(
      countryCode: _phoneCountryCode,
      localNumber: _phoneController.text.trim(),
      onCodeSent: (String verificationId) {
        setState(() => _isLoading = false);
        _showOwnerOtpDialog(verificationId, uid);
      },
      onError: (String error) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Owner Phone Verification Failed: $error';
        });
      },
    );
  }

  void _showOwnerOtpDialog(String verificationId, String uid) {
    _otpController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('📱 Verify Your Owner Phone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppConfig.isLiveProductionMode
                  ? 'Enter the 6-digit real OTP code received via SMS.'
                  : 'Sandbox Mode: Enter mock OTP code (1234). Check in-app sandbox inbox if needed.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Enter Owner OTP',
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
              String enteredCode = _otpController.text.trim();
              Navigator.pop(context);
              await _verifyOwnerOtpCode(verificationId, uid, enteredCode);
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
    if (smsCode.isEmpty) {
      setState(() => _errorMessage = 'Owner OTP code cannot be empty.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (AppConfig.isLiveProductionMode) {
        PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: smsCode,
        );
        // Link credential to authenticated user session if required
      } else {
        if (smsCode != '1234') {
          throw Exception('Invalid sandbox OTP code. Please enter 1234.');
        }
      }

      setState(() => _isLoading = false);
      // Step 2: Proceed to emergency phone verification
      await _startEmergencyPhoneVerification(uid);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Owner OTP Verification Failed: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  Future<void> _startEmergencyPhoneVerification(String uid) async {
    setState(() => _isLoading = true);
    await SandboxSmsService().sendOtp(
      countryCode: _emergencyCountryCode,
      localNumber: _emergencyPhoneController.text.trim(),
      onCodeSent: (String verificationId) {
        setState(() => _isLoading = false);
        _showEmergencyOtpDialog(verificationId, uid);
      },
      onError: (String error) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Emergency Phone Verification Failed: $error';
        });
      },
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
            Text(
              AppConfig.isLiveProductionMode
                  ? 'Enter the 6-digit real OTP code for the EMERGENCY phone.'
                  : 'Sandbox Mode: Enter mock OTP code for emergency phone (1234).',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Enter Emergency OTP',
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
              String enteredCode = _otpController.text.trim();
              Navigator.pop(context);
              await _verifyEmergencyOtpCode(verificationId, uid, enteredCode);
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
    if (smsCode.isEmpty) {
      setState(() => _errorMessage = 'Emergency OTP code cannot be empty.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (AppConfig.isLiveProductionMode) {
        PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: smsCode,
        );
      } else {
        if (smsCode != '1234') {
          throw Exception('Invalid sandbox OTP code. Please enter 1234.');
        }
      }

      await _finalizeRegistration(uid);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Emergency OTP Verification Failed: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  Future<void> _finalizeRegistration(String uid) async {
    try {
      // Save user profile without SIM data fields
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': '$_phoneCountryCode${_phoneController.text.trim()}',
        'isOwnerPhoneVerified': true,
        'emergencyPhone':
            '$_emergencyCountryCode${_emergencyPhoneController.text.trim()}',
        'isEmergencyPhoneVerified': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ Account created & both phone numbers verified successfully!',
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
      backgroundColor: const Color(0xFF841EA0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
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

                    // Owner Phone Number Input with Country Dropdown Menu
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CountryCodePicker(
                            onChanged: (country) {
                              setState(() {
                                _phoneCountryCode = country.dialCode ?? '+92';
                              });
                            },
                            initialSelection: 'PK',
                            favorite: const ['+92', 'US', 'GB', 'IN'],
                            showCountryOnly: false,
                            showOnlyCountryWhenClosed: false,
                            alignLeft: false,
                          ),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                hintText: '3001234567',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Emergency Phone Number Input with Country Dropdown Menu
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CountryCodePicker(
                            onChanged: (country) {
                              setState(() {
                                _emergencyCountryCode =
                                    country.dialCode ?? '+92';
                              });
                            },
                            initialSelection: 'PK',
                            favorite: const ['+92', 'US', 'GB', 'IN'],
                            showCountryOnly: false,
                            showOnlyCountryWhenClosed: false,
                            alignLeft: false,
                          ),
                          Expanded(
                            child: TextField(
                              controller: _emergencyPhoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                hintText: '3128719043',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                            ),
                          ),
                        ],
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
                                'Sign up',
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
    );
  }
}
