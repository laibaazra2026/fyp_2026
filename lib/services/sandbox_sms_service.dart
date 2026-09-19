import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/app_config.dart';

class SandboxSmsService {
  // Singleton pattern
  static final SandboxSmsService _instance = SandboxSmsService._internal();
  factory SandboxSmsService() => _instance;
  SandboxSmsService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final List<Map<String, String>> _inboxMessages = [];

  /// Sends an OTP following proper format & country code rules.
  Future<bool> sendOtp({
    required String countryCode, // e.g., '+92' from country code picker/flag
    required String localNumber, // e.g., local phone number entered by user
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    // Combine country code and local number, removing extra whitespaces
    String rawNumber = '$countryCode$localNumber';
    String cleanNumber = rawNumber.replaceAll(RegExp(r'\s+'), '');

    // Professional formatting / regex validation rule for a valid international phone number format
    // Ensures it starts with '+' followed by 8 to 15 digits total.
    final RegExp phoneRegex = RegExp(r'^\+[1-9]\d{7,14}$');
    if (!phoneRegex.hasMatch(cleanNumber)) {
      onError(
        'Please enter a valid phone number format with your country code.',
      );
      return false;
    }

    // ==========================================
    // 1. SANDBOX / MOCK MODE (For University Viva)
    // ==========================================
    if (!AppConfig.isLiveProductionMode) {
      // Mock PIN definition for sandbox environment
      String mockPin = '1234';

      _inboxMessages.insert(0, {
        'sender': 'Security App (Sandbox)',
        'body':
            'Your sandbox verification PIN is $mockPin. Do not share this with anyone.',
        'time': DateTime.now().toString().substring(11, 16),
        'phone': cleanNumber,
      });

      // Simulate network/SMS gateway delay
      await Future.delayed(const Duration(milliseconds: 800));

      // Return a mock verification ID to maintain UI flow symmetry
      onCodeSent('mock_viva_verification_id');
      return true;
    }

    // ==========================================
    // 2. LIVE PRODUCTION MODE (For Real Users)
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

  /// Backward compatibility helper for existing UI screens
  Future<bool> sendMockOtp(String fullPhoneNumber) async {
    return sendOtp(
      countryCode: '',
      localNumber: fullPhoneNumber,
      onCodeSent: (_) {},
      onError: (_) {},
    );
  }

  List<Map<String, String>> getInboxMessages() => _inboxMessages;
}
