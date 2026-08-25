import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SecurityGuardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Check if Theft Mode is active
  Future<bool> isTheftModeActive() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['theftMode'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error checking theft mode: $e');
      return false;
    }
  }

  // UNIVERSAL WRAPPER: Runs ANY module only if Theft Mode is ON
  Future<void> runModuleIfTheftModeOn({
    required Function() moduleTask,
    required BuildContext context,
    required String moduleName,
  }) async {
    bool theftModeOn = await isTheftModeActive();

    if (!theftModeOn) {
      // Theft Mode is OFF -> Block the module and show a warning
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ Cannot run $moduleName. Please turn ON Theft Mode first!',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return; // Stop completely! Module will not run.
    }

    // Theft Mode is ON -> Safely execute the module
    print('✅ Theft Mode is ON. Executing $moduleName...');
    moduleTask();
  }
}
