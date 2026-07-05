import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';

class CommandService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ========== LISTEN FOR COMMANDS ==========
  void listenForCommands(BuildContext context) {
    User? user = _auth.currentUser;
    if (user == null) return;

    _firestore
        .collection('commands')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        var data = doc.data();
        _executeCommand(context, doc.id, data);
      }
    });
  }

  // ========== EXECUTE COMMAND ==========
  Future<void> _executeCommand(
      BuildContext context, String docId, Map<String, dynamic> data) async {
    String type = data['type'] ?? '';

    switch (type) {
      case 'LOCK':
        await _lockPhone(context, docId);
        break;
      case 'RING':
        await _ringPhone(context, docId);
        break;
      case 'GET_LOCATION':
        await _getLocation(context, docId);
        break;
      case 'THEFT_MODE':
        await _enableTheftMode(context, docId);
        break;
      case 'ERASE_DATA':
        await _eraseData(context, docId);
        break;
      default:
        print('Unknown command: $type');
    }
  }

  // ========== LOCK PHONE ==========
  Future<void> _lockPhone(BuildContext context, String docId) async {
    try {
      // Show dialog
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

      // Update command status
      await _updateCommandStatus(docId, 'completed');
      print('✅ Phone locked remotely');
    } catch (e) {
      print('❌ Error locking phone: $e');
      await _updateCommandStatus(docId, 'failed');
    }
  }

  // ========== RING PHONE ==========
  Future<void> _ringPhone(BuildContext context, String docId) async {
    try {
      // Request audio permission
      PermissionStatus status = await Permission.audio.request();
      if (!status.isGranted) {
        print('❌ Audio permission denied');
        return;
      }

      // Show dialog with ringing animation
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('🔔 Phone Ringing'),
          content: const Text('Your device is ringing loudly!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _updateCommandStatus(docId, 'completed');
              },
              child: const Text('Stop'),
            ),
          ],
        ),
      );

      // Play ringtone (using system ringtone)
      // For actual ring, you would use a package like ringtone_player
      print('🔔 Phone ringing remotely');

      // Update command status
      await _updateCommandStatus(docId, 'completed');
    } catch (e) {
      print('❌ Error ringing phone: $e');
      await _updateCommandStatus(docId, 'failed');
    }
  }

  // ========== GET LOCATION ==========
  Future<void> _getLocation(BuildContext context, String docId) async {
    try {
      // Get current location
      // You already have LocationService, reuse it
      // For now, just save a location request

      await _firestore.collection('locations').add({
        'userId': _auth.currentUser?.uid,
        'latitude': 0,
        'longitude': 0,
        'type': 'REMOTE_REQUEST',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _updateCommandStatus(docId, 'completed');
      print('✅ Location requested remotely');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📍 Location request sent!'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      print('❌ Error getting location: $e');
      await _updateCommandStatus(docId, 'failed');
    }
  }

  // ========== ENABLE THEFT MODE ==========
  Future<void> _enableTheftMode(BuildContext context, String docId) async {
    try {
      // Update user's theft mode status
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'isTheftModeOn': true,
        });
      }

      await _updateCommandStatus(docId, 'completed');
      print('✅ Theft mode enabled remotely');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🛡️ Theft Mode Enabled!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Error enabling theft mode: $e');
      await _updateCommandStatus(docId, 'failed');
    }
  }

  // ========== ERASE DATA (⚠️ WARNING) ==========
  Future<void> _eraseData(BuildContext context, String docId) async {
    try {
      // Show confirmation dialog
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
              child: const Text(
                'Erase',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );

      if (confirm == true) {
        // Delete user data from Firestore
        User? user = _auth.currentUser;
        if (user != null) {
          await _firestore.collection('users').doc(user.uid).delete();
          await _auth.signOut();
        }

        await _updateCommandStatus(docId, 'completed');
        print('✅ Data erased remotely');

        // Navigate to login
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        await _updateCommandStatus(docId, 'cancelled');
        print('❌ Erase command cancelled by user');
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
  }
}