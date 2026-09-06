import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Exact 5 test numbers configured in your Firebase Auth Console
  static final List<String> authorizedTestNumbers = [
    '03005171794',
    '03144964339',
    '03241923864',
    '03128719043',
    '03157633912',
  ];

  // Helper to centralize phone number normalization
  String normalizeNumber(String value) {
    String cleaned = value.trim();
    if (cleaned.startsWith('+92')) {
      cleaned = '0${cleaned.substring(3)}';
    } else if (cleaned.startsWith('92') && cleaned.length == 12) {
      cleaned = '0${cleaned.substring(2)}';
    }
    return cleaned;
  }

  // Validation supporting both 03XX and +92 formats
  String? validateAndNormalizeNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a mobile number';
    }

    String cleaned = normalizeNumber(value);

    if (!cleaned.startsWith('03') ||
        cleaned.length != 11 ||
        int.tryParse(cleaned) == null) {
      return 'Invalid format. Use +923XXXXXXXXX or 03XXXXXXXXX';
    }

    if (!authorizedTestNumbers.contains(cleaned)) {
      return 'Number not authorized. Use one of your Firebase test numbers.';
    }

    return null;
  }

  // Sandbox SMS Simulation Engine logging to Firestore
  Future<bool> sendSandboxSms({
    required String recipientNumber,
    required String planName,
    required double price,
    required String gateway,
  }) async {
    String? validationError = validateAndNormalizeNumber(recipientNumber);
    if (validationError != null) {
      throw Exception(validationError);
    }

    String cleaned = normalizeNumber(recipientNumber);

    await Future.delayed(const Duration(seconds: 1));

    String messageBody =
        "DEAR CUSTOMER, YOUR PAYMENT OF PKR ${price.toStringAsFixed(0)} FOR $planName VIA $gateway IS SUCCESSFUL. REF: SBX-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";

    await _firestore.collection('sms_logs').add({
      'recipient': cleaned,
      'message': messageBody,
      'gateway': gateway,
      'status': 'DELIVERED_SANDBOX',
      'timestamp': FieldValue.serverTimestamp(),
    });

    return true;
  }

  Future<String> getCurrentPlan() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'free';

      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return (data['subscriptionPlan'] ?? 'free').toString().toLowerCase();
      }
      return 'free';
    } catch (e) {
      print('Error fetching subscription plan: $e');
      return 'free';
    }
  }

  Future<void> updateSubscriptionWithMethod(
    String plan,
    double price,
    String paymentMethod, {
    String? verifiedPhoneNumber,
    String? transactionId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found. Please log in again.');
      }

      Map<String, dynamic> updateData = {
        'subscriptionPlan': plan.toLowerCase(),
        'planPrice': price,
        'paymentMethod': paymentMethod,
        'subscriptionStatus': 'active',
        'subscribedAt': FieldValue.serverTimestamp(),
      };

      if (verifiedPhoneNumber != null) {
        updateData['verifiedPhoneNumber'] = normalizeNumber(
          verifiedPhoneNumber,
        );
      }
      if (transactionId != null) {
        updateData['lastTransactionId'] = transactionId;
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(updateData, SetOptions(merge: true));
    } catch (e) {
      print('Error updating subscription: $e');
      rethrow;
    }
  }
}
