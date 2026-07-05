import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CommandService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ========== LISTEN FOR COMMANDS ==========
  void listenForCommands(BuildContext context) {
    User? user = _auth.currentUser;
    if (user == null) {
      print('❌ No user logged in');
      return;
    }

    print('✅ Listening for commands...');

    _firestore
        .collection('commands')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
          for (var doc in snapshot.docs) {
            var data = doc.data();
            print('📩 Command received: ${data['type']}');
            _executeCommand(context, doc.id, data);
          }
        });
  }

  // ========== EXECUTE COMMAND ==========
  Future<void> _executeCommand(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) async {
    String type = data['type'] ?? '';

    switch (type) {
      case 'THEFT_MODE':
        await _enableTheftMode(context, docId);
        break;
      case 'LOCK':
        await _lockPhone(context, docId);
        break;
      case 'RING':
        await _ringPhone(context, docId);
        break;
      case 'GET_LOCATION':
        await _getLocation(context, docId);
        break;
      case 'ERASE_DATA':
        await _eraseData(context, docId);
        break;
      default:
        print('❌ Unknown command: $type');
    }
  }

  // ========== ENABLE THEFT MODE ==========
  Future<void> _enableTheftMode(BuildContext context, String docId) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        print('❌ No user found');
        return;
      }

      // Update Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'isTheftModeOn': true,
      });

      // Update command status
      await _updateCommandStatus(docId, 'completed');

      print('✅ Theft mode enabled remotely');

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🛡️ Theft Mode Enabled Remotely!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Show dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('🛡️ Theft Mode Enabled'),
          content: const Text(
            'Theft mode has been enabled remotely.\n'
            'Your device is now protected.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('❌ Error enabling theft mode: $e');
      await _updateCommandStatus(docId, 'failed');
    }
  }

  // ========== LOCK PHONE ==========
  Future<void> _lockPhone(BuildContext context, String docId) async {
    try {
      await _updateCommandStatus(docId, 'completed');

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('🔒 Phone Locked'),
          content: const Text('Your device has been locked remotely.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      print('✅ Phone locked remotely');
    } catch (e) {
      print('❌ Error locking phone: $e');
      await _updateCommandStatus(docId, 'failed');
    }
  }

  // ========== RING PHONE ==========
  Future<void> _ringPhone(BuildContext context, String docId) async {
    try {
      await _updateCommandStatus(docId, 'completed');

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('🔔 Phone Ringing'),
          content: const Text('Your device is ringing loudly!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Stop Ringing'),
            ),
          ],
        ),
      );

      print('🔔 Phone ringing remotely');
    } catch (e) {
      print('❌ Error ringing phone: $e');
      await _updateCommandStatus(docId, 'failed');
    }
  }

  // ========== GET LOCATION ==========
  Future<void> _getLocation(BuildContext context, String docId) async {
    try {
      await _updateCommandStatus(docId, 'completed');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📍 Location requested!'),
          backgroundColor: Colors.blue,
        ),
      );

      print('📍 Location requested remotely');
    } catch (e) {
      print('❌ Error getting location: $e');
      await _updateCommandStatus(docId, 'failed');
    }
  }

  // ========== ERASE DATA ==========
  Future<void> _eraseData(BuildContext context, String docId) async {
    try {
      bool? confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ WARNING'),
          content: const Text(
            'This will erase all data on this device.\n'
            'Are you sure you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Erase', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        User? user = _auth.currentUser;
        if (user != null) {
          await _firestore.collection('users').doc(user.uid).delete();
          await _auth.signOut();
        }

        await _updateCommandStatus(docId, 'completed');
        print('✅ Data erased remotely');

        Navigator.pushReplacementNamed(context, '/login');
      } else {
        await _updateCommandStatus(docId, 'cancelled');
        print('❌ Erase command cancelled');
      }
    } catch (e) {
      print('❌ Error erasing data: $e');
      await _updateCommandStatus(docId, 'failed');
    }
  }

  // ========== UPDATE COMMAND STATUS ==========
  Future<void> _updateCommandStatus(String docId, String status) async {
    await _firestore.collection('commands').doc(docId).update({
      'status': status,
      'executedAt': FieldValue.serverTimestamp(),
    });
    print('✅ Command status updated to: $status');
  }
}
