import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SecurityGuardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
        return data['isTheftModeOn'] ?? data['theftMode'] ?? false;
      }
      return false;
    } catch (e) {
      print('❌ Error checking theft mode: $e');
      return false;
    }
  }

  Future<void> runModuleIfTheftModeOn({
    required Function moduleTask,
    required BuildContext context,
    required String moduleName,
  }) async {
    bool theftModeOn = await isTheftModeActive();

    if (!theftModeOn) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ Cannot run $moduleName. Please turn ON Theft Mode first!',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    print('✅ Theft Mode is ON. Executing $moduleName...');
    try {
      final result = moduleTask();
      if (result is Future) {
        await result;
      }
    } catch (e) {
      print('❌ Error executing module $moduleName: $e');
    }
  }
}
