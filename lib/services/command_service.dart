import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:device_policy_manager/device_policy_manager.dart';
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🛡️ Theft Mode Enabled Remotely!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error: $e');
      await _updateCommandStatus(docId, 'failed');
    }
  }

  // ========== LOCK PHONE (FIXED CRASH ORDER) ==========
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

      String lockPin = '1234';
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('lockPin')) {
          lockPin = data['lockPin'] ?? '1234';
        }
      }

      await _updateCommandStatus(docId, 'completed');

      // ✅ 1. Show the Lock Screen UI overlay FIRST while the app is active
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LockScreen(correctPin: lockPin),
          ),
        );
      }

      // ✅ 2. THEN try to lock the device via Method Channel / Device Admin
      try {
        const platform = MethodChannel('com.example.device_protection/lock');
        await platform.invokeMethod('lockDevice');
        print('✅ Device locked via Method Channel');
      } catch (e) {
        print('⚠️ Admin not active or lock failed. Prompting user...');
        await DevicePolicyManager.requestPermession(
          "Please enable Device Admin to allow remote locking.",
        );
      }
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

      if (context.mounted) {
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
