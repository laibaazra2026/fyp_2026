import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_config.dart'; // Import your configuration file for live/sandbox mode

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> getCurrentPlan() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'free';

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return 'free';

      final data = doc.data();
      if (data == null) return 'free';

      // Check if their subscription plan time period has expired (e.g., 30 days)
      if (data['expiresAt'] != null) {
        Timestamp expiresAt = data['expiresAt'];
        if (DateTime.now().isAfter(expiresAt.toDate())) {
          // Automatically revert to free once time is completed so they can buy a new plan
          await _firestore.collection('users').doc(user.uid).set({
            'subscriptionTier': 'free',
            'subscriptionPlan': 'free',
            'subscriptionStatus': 'expired',
          }, SetOptions(merge: true));
          return 'free';
        }
      }

      return data['subscriptionTier'] ?? 'free';
    } catch (e) {
      return 'free';
    }
  }

  Future<void> updateSubscriptionWithMethod(
    String tier,
    String price,
    String paymentMethod,
    String txnId,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user found');

      final DateTime now = DateTime.now();
      // Set a 30-day validity period for the active plan
      final DateTime expiryDate = now.add(const Duration(days: 30));

      // Enforce single active subscription at a time by overwriting the tier and adding timestamps
      await _firestore.collection('users').doc(user.uid).set({
        'subscriptionTier': tier,
        'subscriptionPlan': tier,
        'subscriptionStatus': 'active',
        'planPrice': double.tryParse(price) ?? 0.0,
        'paymentMethod': paymentMethod,
        'lastTransactionId': txnId,
        'isProduction':
            AppConfig.isLiveProductionMode, // Tracks if bought in live mode
        'purchasedAt': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(expiryDate),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }
}
