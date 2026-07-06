import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> getCurrentPlan() async {
    User? user = _auth.currentUser;
    if (user == null) return 'free';

    DocumentSnapshot doc = await _firestore
        .collection('subscriptions')
        .doc(user.uid)
        .get();

    if (!doc.exists) return 'free';
    return doc.get('plan') ?? 'free';
  }

  // ========== CHECK IF PREMIUM ==========
  Future<bool> isPremium() async {
    String plan = await getCurrentPlan();
    return plan != 'free';
  }

  // ========== UPDATE SUBSCRIPTION ==========
  Future<void> updateSubscription(String plan, double price) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('subscriptions').doc(user.uid).set({
      'plan': plan,
      'price': price,
      'currency': 'PKR',
      'isActive': true,
      'startDate': FieldValue.serverTimestamp(),
      'expiryDate': DateTime.now().add(Duration(days: 30)),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
