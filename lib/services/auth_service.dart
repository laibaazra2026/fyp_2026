import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ========== STRICT PASSWORD VALIDATION HELPER ==========
  String? validatePasswordRules(String password) {
    if (password.isEmpty) return 'Password cannot be empty.';
    if (password.length < 8)
      return 'Password must be at least 8 characters long.';
    if (password.contains(' ')) return 'Password cannot contain spaces.';
    if (!password.contains(RegExp(r'[A-Z]')))
      return 'Must contain at least one uppercase letter.';
    if (!password.contains(RegExp(r'[a-z]')))
      return 'Must contain at least one lowercase letter.';
    if (!password.contains(RegExp(r'[0-9]')))
      return 'Must contain at least one number.';
    return null; // Valid!
  }

  // ========== LOGIN ==========
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    try {
      // Validate password rules before hitting Firebase
      String? validationError = validatePasswordRules(password);
      if (validationError != null) {
        throw Exception(validationError);
      }

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
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ========== SIGN UP ==========
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    try {
      // Validate password rules before creating user
      String? validationError = validatePasswordRules(password);
      if (validationError != null) {
        throw Exception(validationError);
      }

      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      await userCredential.user!.sendEmailVerification();

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'name': name,
        'email': email,
        'phone': phone,
        'isPremium': false,
        'isTheftModeOn': false,
        'emailVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return userCredential;
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ========== FORGOT PASSWORD ==========
  Future<void> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ========== SIGN OUT ==========
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
