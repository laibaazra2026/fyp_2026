import 'package:cloud_firestore/cloud_firestore.dart';

class SandboxSmsService {
  static const List<String> whitelistNumbers = [
    '+923005171794',
    '+923144964339',
    '+923241923864',
    '+923128719043',
    '+923157633912',
  ];

  String? validateNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Mobile number is required';
    }
    String cleaned = value.trim();
    if (!cleaned.startsWith('+92') && !cleaned.startsWith('03')) {
      return 'Must start with +92 or 03';
    }
    if (cleaned.startsWith('03')) {
      cleaned = '+92${cleaned.substring(1)}';
    }
    if (!whitelistNumbers.contains(cleaned)) {
      return 'Number not whitelisted for Sandbox test';
    }
    return null;
  }

  Future<void> sendSandboxSms({
    required String recipientNumber,
    required String planName,
    required double price,
    required String gateway,
  }) async {
    String normalized = recipientNumber.trim();
    if (normalized.startsWith('03')) {
      normalized = '+92${normalized.substring(1)}';
    }

    if (!whitelistNumbers.contains(normalized)) {
      throw Exception('Unauthorized sandbox number.');
    }

    String gatewayPrefix = gateway.toLowerCase().contains('jazz')
        ? 'JazzCash'
        : 'EasyPaisa';
    String txnId =
        'TXN-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    String messageBody =
        'ALERT: Paid PKR ${price.toStringAsFixed(0)} for $planName via $gatewayPrefix. Ref: $txnId.';

    await FirebaseFirestore.instance.collection('sms_logs').add({
      'recipient': normalized,
      'gateway': gatewayPrefix,
      'plan': planName,
      'amount': price,
      'message': messageBody,
      'transactionId': txnId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
