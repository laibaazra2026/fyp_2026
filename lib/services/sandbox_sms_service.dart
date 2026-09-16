import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/app_config.dart';

class SandboxSmsService {
  // Singleton pattern
  static final SandboxSmsService _instance = SandboxSmsService._internal();
  factory SandboxSmsService() => _instance;
  SandboxSmsService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final List<String> allowedTestNumbers = [
    '+923005171794',
    '+923144964339',
    '+923241923864',
    '+923128719043',
    '+923157633912',
  ];

  final List<Map<String, String>> _inboxMessages = [];

  /// Sends an OTP. Uses local mock inbox if in Sandbox mode,
  /// and switches to real Firebase Phone Auth if in Live mode.
  Future<bool> sendOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    // Normalize format
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'\s+'), '');

    // ==========================================
    // 1. SANDBOX / MOCK MODE (For University Viva)
    // ==========================================
    if (!AppConfig.isLiveProductionMode) {
      if (!allowedTestNumbers.contains(cleanNumber)) {
        onError('Phone number not found in sandbox allowed test numbers.');
        return false;
      }

      // Default mock OTP for easy testing
      String otp = '1234';

      _inboxMessages.insert(0, {
        'sender': 'JazzCash/EasyPaisa (Sandbox)',
        'body':
            'Your secure transaction OTP is $otp. Do not share this PIN with anyone.',
        'time': DateTime.now().toString().substring(11, 16),
        'phone': cleanNumber,
      });

      await Future.delayed(const Duration(milliseconds: 800));

      // Pass a mock verification ID back to keep the flow consistent
      onCodeSent('mock_viva_verification_id');
      return true;
    }

    // ==========================================
    // 2. LIVE PRODUCTION MODE (For your 3 Clients)
    // ==========================================
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: cleanNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution if supported by the device
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? 'Live SMS verification failed.');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
      return true;
    } catch (e) {
      onError(e.toString());
      return false;
    }
  }

  /// Retains the original mock inbox method name for backward compatibility with your UI screens
  Future<bool> sendMockOtp(String phoneNumber) async {
    return sendOtp(
      phoneNumber: phoneNumber,
      onCodeSent: (_) {},
      onError: (_) {},
    );
  }

  List<Map<String, String>> getInboxMessages() => _inboxMessages;
}
