import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ========== LOGIN ==========
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!userCredential.user!.emailVerified) {
        await _auth.signOut();
        throw Exception(
          '⚠️ Please verify your email first.\nCheck your inbox and click the verification link.',
        );
      }

      return userCredential;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // ========== SIGN UP ==========
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    // ✅ NO altPhone
  }) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      await userCredential.user!.sendEmailVerification();

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'name': name,
        'email': email,
        'phone': phone,
        // ✅ NO altPhone
        'isPremium': false,
        'isTheftModeOn': false,
        'emailVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return userCredential;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // ========== FORGOT PASSWORD ==========
  Future<void> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // ========== SIGN OUT ==========
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
