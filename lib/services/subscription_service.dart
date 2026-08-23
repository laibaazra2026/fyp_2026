import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Fetch the current subscription plan of the logged-in user
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
        // Returns 'free', 'premium', or 'family' (defaults to 'free')
        return data['subscriptionPlan'] ?? 'free';
      }
      return 'free';
    } catch (e) {
      print('Error fetching subscription plan: $e');
      return 'free';
    }
  }

  // Update subscription, price, payment method, and timestamp for the admin panel
  Future<void> updateSubscriptionWithMethod(
    String plan,
    double price,
    String paymentMethod,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('users').doc(user.uid).update({
        'subscriptionPlan': plan, // e.g., 'premium' or 'family'
        'planPrice': price, // e.g., 99.0 or 199.0
        'paymentMethod':
            paymentMethod, // 'JazzCash', 'EasyPaisa', or 'Sandbox Test'
        'subscribedAt':
            FieldValue.serverTimestamp(), // Exact purchase date & time for admin tracking
      });
    } catch (e) {
      print('Error updating subscription: $e');
      rethrow;
    }
  }
}
