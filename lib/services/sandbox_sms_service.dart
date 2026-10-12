import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/app_config.dart';

class SandboxSmsService {
  static final SandboxSmsService _instance = SandboxSmsService._internal();
  factory SandboxSmsService() => _instance;
  SandboxSmsService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final List<Map<String, String>> _inboxMessages = [];

  Future<bool> sendOtp({
    required String countryCode,
    required String localNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    String rawNumber = '$countryCode$localNumber';
    String cleanNumber = rawNumber.replaceAll(RegExp(r'\s+'), '');

    final RegExp phoneRegex = RegExp(r'^\+[1-9]\d{7,14}$');
    if (!phoneRegex.hasMatch(cleanNumber)) {
      onError(
        'Please enter a valid phone number format with your country code.',
      );
      return false;
    }

    if (!AppConfig.isLiveProductionMode) {
      String mockPin = '1234';

      _inboxMessages.insert(0, {
        'sender': 'Security App (Sandbox)',
        'body':
            'Your sandbox verification PIN is $mockPin. Do not share this with anyone.',
        'time': DateTime.now().toString().substring(11, 16),
        'phone': cleanNumber,
      });

      await Future.delayed(const Duration(milliseconds: 800));

      onCodeSent('mock_viva_verification_id');
      return true;
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: cleanNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {},
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
