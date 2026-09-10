import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> getCurrentPlan() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'free';

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return 'free';

      return doc.data()?['subscriptionTier'] ?? 'free';
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

      await _firestore.collection('users').doc(user.uid).set({
        'subscriptionTier': tier,
        'subscriptionPlan': tier,
        'subscriptionStatus': 'active',
        'planPrice': double.tryParse(price) ?? 0.0,
        'paymentMethod': paymentMethod,
        'lastTransactionId': txnId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }
}
