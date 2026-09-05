import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import '../main.dart';

class CommandService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();

  final Set<String> _processedCommands = {};

  static const platform = MethodChannel('device_protection/admin');

  Future<void> saveFCMToken() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await _firestore.collection('users').doc(user.uid).set({
            'fcmToken': token,
          }, SetOptions(merge: true));
          print('📱 FCM Token saved successfully: $token');
        }
      } else {
        print('⚠️ Notification permissions declined by user');
      }
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  void listenForCommands(BuildContext context) {
    User? user = _auth.currentUser;
    if (user == null) {
      print('❌ No user logged in');
      return;
    }

    print('✅ Listening for commands...');

    saveFCMToken();

    _firestore
        .collection('commands')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen(
          (snapshot) {
            for (var doc in snapshot.docs) {
              String docId = doc.id;

              if (_processedCommands.contains(docId)) continue;

              var data = doc.data();
              print('📩 Command received: ${data['type']}');

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

  Future<void> _enableTheftMode(BuildContext context, String docId) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        await _updateCommandStatus(docId, 'failed');
        return;
      }

      await _firestore.collection('users').doc(user.uid).set({
        'isTheftModeOn': true,
      }, SetOptions(merge: true));

      bool isActive =
          await platform.invokeMethod('isDeviceAdminActive') ?? false;
      if (!isActive) {
        print(
          '⚠️ Admin not active yet. Prompting user to enable it for intruder capture...',
        );
        await platform.invokeMethod('enableAdmin');
      }

      await _updateCommandStatus(docId, 'completed');
      print('🛡️ Theft Mode Enabled Remotely!');

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
        try {
          await platform.invokeMethod('lockDevice');
          print('✅ Physical device locked successfully via Method Channel');
          await _updateCommandStatus(docId, 'completed');
        } catch (platformError) {
          print('❌ Native lock method error: $platformError');
          await _updateCommandStatus(docId, 'failed');
        }
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

  Future<void> _ringPhone(BuildContext context, String docId) async {
    try {
      try {
        if (_audioPlayer.state == PlayerState.playing ||
            _audioPlayer.state == PlayerState.paused) {
          await _audioPlayer.stop();
        }

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
                  try {
                    if (_audioPlayer.state == PlayerState.playing ||
                        _audioPlayer.state == PlayerState.paused) {
                      await _audioPlayer.stop();
                    }
                  } catch (stopError) {
                    print('⚠️ Error stopping audio: $stopError');
                  }
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
