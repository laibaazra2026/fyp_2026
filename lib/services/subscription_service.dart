import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Fetch the current user's active subscription plan
  Future<String> getCurrentPlan() async {
    User? user = _auth.currentUser;
    if (user == null) return 'free';

    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
        return data?['plan'] ?? 'free';
      }
    } catch (e) {
      print('Error fetching subscription plan: $e');
    }
    return 'free';
  }

  // Update or upgrade the user's subscription plan and price
  Future<void> updateSubscription(String planName, double price) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'plan': planName,
        'price': price,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating subscription: $e');
    }
  }
}
