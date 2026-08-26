import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // v7.2.0 Singleton instance & initialization state
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _isInitialized = false;

  AuthService() {
    _initializeGoogleSignIn();
  }

  Future<void> _initializeGoogleSignIn() async {
    try {
      await _googleSignIn.initialize();
      _isInitialized = true;
    } catch (e) {
      print('Google Sign-In Initialization Error: $e');
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _initializeGoogleSignIn();
    }
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 1. Sign In with Email & Password
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'An error occurred during sign in.');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // 🟢 2. Login Wrapper Method (Fixes the red line under _authService.login)
  Future<UserCredential?> login({
    required String email,
    required String password,
  }) async {
    return await signInWithEmailAndPassword(email: email, password: password);
  }

  // 3. Sign Up with Email & Password
  Future<UserCredential?> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'An error occurred during registration.');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // 4. Sign In with Google (Compatible with v7.2.0)
  Future<UserCredential?> signInWithGoogle() async {
    try {
      await _ensureInitialized();

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      const List<String> scopes = ['email', 'profile'];
      final clientAuth = await googleUser.authorizationClient.authorizeScopes(
        scopes,
      );
      final googleAuth = googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: clientAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'email': userCredential.user!.email,
          'name': userCredential.user!.displayName ?? '',
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Google Sign-In failed.');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  // 5. Reset Password
  Future<void> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found for that email address.';
          break;
        case 'invalid-email':
          message = 'The email address is badly formatted.';
          break;
        default:
          message = e.message ?? 'Failed to send password reset email.';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  // 6. Sign Out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }
}
