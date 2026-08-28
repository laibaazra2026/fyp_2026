import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import '../main.dart'; // ✅ IMPORT MAIN TO ACCESS THE GLOBAL NAVIGATOR KEY

class CommandService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // 🛡️ Track processed command IDs locally to prevent duplicate executions
  final Set<String> _processedCommands = {};

  // ✅ MATCHED WITH MainActivity.kt CHANNEL NAME
  static const platform = MethodChannel('device_protection/admin');

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
              String docId = doc.id;

              // Skip if already processed in this session
              if (_processedCommands.contains(docId)) continue;

              var data = doc.data();
              print('📩 Command received: ${data['type']}');

              // Mark as processing locally immediately
              _processedCommands.add(docId);

              _executeCommand(context, docId, data);
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

      // 1. Safely create or update Theft Mode in Firestore using set with merge
      await _firestore.collection('users').doc(user.uid).set({
        'isTheftModeOn': true,
      }, SetOptions(merge: true));

      // 2. Check if admin permission is active; if not, prompt for it
      bool isActive =
          await platform.invokeMethod('isDeviceAdminActive') ?? false;
      if (!isActive) {
        print(
          '⚠️ Admin not active yet. Prompting user to enable it for intruder capture...',
        );
        await platform.invokeMethod('enableAdmin');
      }

      // 3. Mark command as completed
      await _updateCommandStatus(docId, 'completed');
      print('🛡️ Theft Mode Enabled Remotely!');

      // Safe UI feedback wrapper using global navigator context fallback
      try {
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
      } catch (uiError) {
        print('⚠️ UI notification skipped: $uiError');
      }
    } catch (e) {
      print('❌ Error enabling theft mode: $e');
      await _updateCommandStatus(docId, 'failed');
    }
  }

  // ========== LOCK PHONE ==========
  Future<void> _lockPhone(BuildContext context, String docId) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        await _updateCommandStatus(docId, 'failed');
        return;
      }

      bool isActive =
          await platform.invokeMethod('isDeviceAdminActive') ?? false;

      if (isActive) {
        await platform.invokeMethod('lockDevice');
        print('✅ Physical device locked successfully via Method Channel');
        await _updateCommandStatus(docId, 'completed');
      } else {
        print('⚠️ Device Admin is not active, prompting user...');
        await platform.invokeMethod('enableAdmin');
        await _updateCommandStatus(docId, 'failed');
      }
    } catch (e) {
      print('❌ Error locking phone: $e');
      await _updateCommandStatus(docId, 'failed');
    }
  }

  // ========== RING PHONE ==========
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
