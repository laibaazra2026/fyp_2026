import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math';
import '../screens/lock_screen.dart';
import 'package:flutter/services.dart';

class CommandService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();

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
      if (user == null) return;

      await _firestore.collection('users').doc(user.uid).update({
        'isTheftModeOn': true,
      });

      await _updateCommandStatus(docId, 'completed');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🛡️ Theft Mode Enabled Remotely!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('🛡️ Theft Mode Enabled'),
          content: const Text('Theft mode has been enabled remotely.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('❌ Error: $e');
      await _updateCommandStatus(docId, 'failed');
    }
  }

  // ========== GENERATE RANDOM 6-DIGIT PIN ==========
  String _generateRandomPin() {
    final random = Random();
    String pin = '';
    for (int i = 0; i < 6; i++) {
      pin += random.nextInt(10).toString();
    }
    return pin;
  }

  // ========== LOCK PHONE (REAL LOCK WITH DEVICE ADMIN) ==========
  // ========== LOCK PHONE (USING METHOD CHANNEL) ==========
  Future<void> _lockPhone(BuildContext context, String docId) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        await _updateCommandStatus(docId, 'failed');
        return;
      }

      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      String lockPin = userDoc.get('lockPin') ?? '1234';

      await _updateCommandStatus(docId, 'completed');

      // ✅ LOCK USING METHOD CHANNEL
      try {
        const platform = MethodChannel('com.example.device_protection/lock');
        await platform.invokeMethod('lockDevice');
        print('✅ Device locked via Method Channel');
      } catch (e) {
        print('❌ Lock failed: $e');
      }

      // ✅ Show lock screen overlay
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LockScreen(correctPin: lockPin),
            ),
          );
        }
      });
    } catch (e) {
      print('❌ Error: $e');
      await _updateCommandStatus(docId, 'failed');
    }
  }

  // ========== RING PHONE (REAL RINGTONE!) ==========
  Future<void> _ringPhone(BuildContext context, String docId) async {
    try {
      await _updateCommandStatus(docId, 'completed');

      // ✅ Play ringtone
      await _audioPlayer.play(AssetSource('sounds/ringtone.mp3'));

      // Show dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('🔔 Phone Ringing'),
          content: const Text('Your device is ringing loudly!'),
          actions: [
            TextButton(
              onPressed: () {
                _audioPlayer.stop();
                Navigator.pop(context);
              },
              child: const Text('Stop Ringing'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('❌ Error: $e');
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
    } catch (e) {
      print('❌ Error: $e');
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
            'Are you sure?',
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

        // Try to wipe data using DeviceApps
        try {} catch (e) {
          print('⚠️ Wipe data not available: $e');
        }

        await _updateCommandStatus(docId, 'completed');
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        await _updateCommandStatus(docId, 'cancelled');
      }
    } catch (e) {
      print('❌ Error: $e');
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
