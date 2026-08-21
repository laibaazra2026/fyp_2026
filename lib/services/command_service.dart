import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:device_policy_manager/device_policy_manager.dart';
import 'package:flutter/services.dart';
import '../main.dart'; // ✅ IMPORT MAIN TO ACCESS THE GLOBAL NAVIGATOR KEY

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

  // ========== LOCK PHONE (ONLY REAL PHYSICAL LOCK, NO CUSTOM UI) ==========
  Future<void> _lockPhone(BuildContext context, String docId) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        await _updateCommandStatus(docId, 'failed');
        return;
      }

      await _updateCommandStatus(docId, 'completed');

      // ✅ Trigger ONLY the native physical screen lock via Method Channel
      try {
        const platform = MethodChannel('com.example.device_protection/lock');
        await platform.invokeMethod('lockDevice');
        print('✅ Physical device locked successfully');
      } catch (e) {
        print('⚠️ Admin not active or lock failed: $e');
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

      // ✅ Use global navigator key for the dialog just to be extra safe against background context errors
      if (navigatorKey.currentContext != null) {
        showDialog(
          context: navigatorKey.currentContext!,
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
