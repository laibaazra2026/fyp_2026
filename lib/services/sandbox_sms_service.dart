import 'dart:math';

class SandboxSmsService {
  // Singleton pattern
  static final SandboxSmsService _instance = SandboxSmsService._internal();
  factory SandboxSmsService() => _instance;
  SandboxSmsService._internal();

  final List<String> allowedTestNumbers = [
    '+923005171794',
    '+923144964339',
    '+923241923864',
    '+923128719043',
    '+923157633912',
  ];

  final List<Map<String, String>> _inboxMessages = [];

  // Send simulated SMS/OTP to the mock inbox
  Future<bool> sendMockOtp(String phoneNumber) async {
    // Normalize format
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    if (!allowedTestNumbers.contains(cleanNumber)) {
      return false;
    }

    // Generate random 4-digit code (or default to 1234 for easy testing)
    String otp = '1234';

    _inboxMessages.insert(0, {
      'sender': 'JazzCash/EasyPaisa',
      'body':
          'Your secure transaction OTP is $otp. Do not share this PIN with anyone.',
      'time': DateTime.now().toString().substring(11, 16),
      'phone': cleanNumber,
    });

    await Future.delayed(const Duration(milliseconds: 800));
    return true;
  }

  List<Map<String, String>> getInboxMessages() => _inboxMessages;
}
