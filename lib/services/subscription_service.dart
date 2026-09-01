import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
    String paymentMethod,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found. Please log in again.');
      }

      await _firestore.collection('users').doc(user.uid).set({
        'subscriptionPlan': plan.toLowerCase(),
        'planPrice': price,
        'paymentMethod': paymentMethod,
        'subscribedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating subscription: $e');
      rethrow;
    }
  }
}
