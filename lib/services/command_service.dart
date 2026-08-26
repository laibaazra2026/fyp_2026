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
        .listen(
          (snapshot) {
            for (var doc in snapshot.docs) {
              var data = doc.data();
              print('📩 Command received: ${data['type']}');
              _executeCommand(context, doc.id, data);
            }
          },
          onError: (e) {
            print('❌ Command listener error: $e');
          },
        );
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
        await _updateCommandStatus(docId, 'failed');
    }
  }

  // ========== ENABLE THEFT MODE ==========
  Future<void> _enableTheftMode(BuildContext context, String docId) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        await _updateCommandStatus(docId, 'failed');
        return;
      }

      await _firestore.collection('users').doc(user.uid).update({
        'isTheftModeOn': true,
      });

      await _updateCommandStatus(docId, 'completed');

      BuildContext? activeContext = context.mounted
          ? context
          : navigatorKey.currentContext;

      if (activeContext != null) {
        ScaffoldMessenger.of(activeContext).showSnackBar(
          const SnackBar(
            content: Text('🛡️ Theft Mode Enabled Remotely!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error enabling theft mode: $e');
      await _updateCommandStatus(docId, 'failed');
    }
  }

  // ========== LOCK PHONE (FIXED TO lockNow()) ==========
  Future<void> _lockPhone(BuildContext context, String docId) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        await _updateCommandStatus(docId, 'failed');
        return;
      }

      // ✅ Trigger native physical screen lock via Method Channel or DevicePolicyManager
      try {
        const platform = MethodChannel('com.example.device_protection/lock');
        await platform.invokeMethod('lockDevice');
        print('✅ Physical device locked successfully via Method Channel');
      } catch (channelError) {
        print(
          '⚠️ Method channel lock failed, attempting DevicePolicyManager: $channelError',
        );
        try {
          // Fixed from .showLockScreen() to .lockNow()
          await DevicePolicyManager.lockNow();
        } catch (adminError) {
          print('⚠️ Admin lock failed: $adminError');
          await DevicePolicyManager.requestPermession(
            "Please enable Device Admin to allow remote locking.",
          );
          throw Exception('Device Admin permission required');
        }
      }

      await _updateCommandStatus(docId, 'completed');
    } catch (e) {
      print('❌ Error locking phone: $e');
      await _updateCommandStatus(docId, 'failed');
    }
  }

  // ========== RING PHONE (REAL RINGTONE) ==========
  Future<void> _ringPhone(BuildContext context, String docId) async {
    try {
      try {
        await _audioPlayer.setReleaseMode(ReleaseMode.loop);
        await _audioPlayer.play(AssetSource('sounds/ringtone.mp3'));
      } catch (audioError) {
        print('⚠️ Error playing asset audio: $audioError');
      }

      await _updateCommandStatus(docId, 'completed');

      BuildContext? dialogContext =
          navigatorKey.currentContext ?? (context.mounted ? context : null);

      if (dialogContext != null) {
        showDialog(
          context: dialogContext,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('🔔 Phone Ringing'),
            content: const Text(
              'Your device is ringing loudly from a remote command!',
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await _audioPlayer.stop();
                  if (Navigator.canPop(dialogCtx)) {
                    Navigator.pop(dialogCtx);
                  }
                },
                child: const Text('Stop Ringing'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('❌ Error ringing phone: $e');
      await _updateCommandStatus(docId, 'failed');
    }
  }

  // ========== UPDATE COMMAND STATUS ==========
  Future<void> _updateCommandStatus(String docId, String status) async {
    try {
      await _firestore.collection('commands').doc(docId).update({
        'status': status,
        'executedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Command status updated to: $status');
    } catch (e) {
      print('❌ Failed to update command status ($status): $e');
    }
  }
}
