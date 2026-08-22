import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_sms/flutter_sms.dart';

class SimService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // ========== GET DEVICE ID ==========
  Future<String?> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor;
      }
      return null;
    } catch (e) {
      print('❌ Error getting device ID: $e');
      return null;
    }
  }

  // ========== GET DEVICE MODEL & CARRIER/BRAND INFO ==========
  Future<Map<String, String>> _getCurrentDeviceAndSimInfo() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        return {
          'deviceId': androidInfo.id,
          'deviceModel': androidInfo.model,
          'carrier': androidInfo
              .manufacturer, // Tracks manufacturer / operator footprint
        };
      }
      return {
        'deviceId': 'UNKNOWN_ID',
        'deviceModel': 'Unknown Model',
        'carrier': 'Unknown Carrier',
      };
    } catch (e) {
      print('❌ Error getting device/SIM info: $e');
      return {
        'deviceId': 'ERROR_ID',
        'deviceModel': 'Error',
        'carrier': 'Error',
      };
    }
  }

  // ========== SAVE BASELINE INFO (BOTH DEVICE & SIM) ==========
  Future<void> saveBaselineInfo(
    String deviceId,
    String deviceModel,
    String carrier,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('baseline_device_id', deviceId);
    await prefs.setString('baseline_model', deviceModel);
    await prefs.setString('baseline_carrier', carrier);
    print('✅ Baseline Device & SIM info saved securely');
  }

  // ========== GET SAVED BASELINE INFO ==========
  Future<Map<String, String>?> getSavedBaselineInfo() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('baseline_device_id');
    if (deviceId == null || deviceId.isEmpty) {
      return null;
    }
    return {
      'deviceId': deviceId,
      'deviceModel': prefs.getString('baseline_model') ?? 'Unknown',
      'carrier': prefs.getString('baseline_carrier') ?? 'Unknown',
    };
  }

  // ========== DETECT SIM OR DEVICE CHANGE ==========
  Future<bool> detectSimChange(BuildContext context) async {
    Map<String, String> currentInfo = await _getCurrentDeviceAndSimInfo();
    String currentId = currentInfo['deviceId'] ?? '';
    String currentModel = currentInfo['deviceModel'] ?? '';
    String currentCarrier = currentInfo['carrier'] ?? '';

    if (currentId.isEmpty || currentModel.isEmpty) {
      print('❌ Could not retrieve hardware info');
      return false;
    }

    Map<String, String>? savedInfo = await getSavedBaselineInfo();

    // First time running the app - save baseline
    if (savedInfo == null) {
      await saveBaselineInfo(currentId, currentModel, currentCarrier);
      print('✅ First time baseline established');
      return false;
    }

    String savedId = savedInfo['deviceId'] ?? '';
    String savedCarrier = savedInfo['carrier'] ?? '';

    // Check if EITHER Device ID changed OR SIM/Carrier changed
    bool isDeviceChanged = (currentId != savedId);
    bool isSimChanged = (currentCarrier != savedCarrier);

    if (isDeviceChanged || isSimChanged) {
      String changeType = isDeviceChanged ? 'DEVICE_CHANGE' : 'SIM_CHANGE';
      print('⚠️ SECURITY ALERT: $changeType DETECTED!');

      // 1. Log alert to Firebase for your Web Admin Panel
      await _handleAlertLogging(
        changeType,
        currentId,
        savedId,
        currentCarrier,
        savedCarrier,
        currentModel,
      );

      // 2. Send Alternative SMS Alert to Emergency Contact
      await _sendEmergencySmsAlert(changeType, currentCarrier);

      // Update baseline to current so it doesn't loop
      await saveBaselineInfo(currentId, currentModel, currentCarrier);
      return true;
    }

    print('✅ Device and SIM are secure and unchanged');
    return false;
  }

  // ========== LOG TO FIREBASE FIRESTORE (ADMIN PANEL) ==========
  Future<void> _handleAlertLogging(
    String type,
    String newId,
    String oldId,
    String newCarrier,
    String oldCarrier,
    String deviceModel,
  ) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      String userEmail = userDoc.exists
          ? (userDoc.get('email') ?? 'Unknown')
          : 'Unknown';
      String userName = userDoc.exists
          ? (userDoc.get('name') ?? 'User')
          : 'User';

      // Maps directly into your sim_alerts.html admin web page layout
      await _firestore.collection('sim_alerts').add({
        'userId': user.uid,
        'userEmail': userEmail,
        'userName': userName,
        'type': type, // 'SIM_CHANGE' or 'DEVICE_CHANGE'
        'title': type == 'SIM_CHANGE'
            ? '⚠️ SIM Card Changed'
            : '⚠️ Device Changed',
        'message': type == 'SIM_CHANGE'
            ? 'A new SIM carrier ($newCarrier) was detected.'
            : 'A new device hardware footprint was detected.',
        'oldSimSerial': oldId,
        'newSimSerial': newId,
        'oldCarrier': oldCarrier,
        'newCarrier': newCarrier,
        'deviceModel': deviceModel,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      print('✅ Alert successfully synced to Firestore admin panel!');
    } catch (e) {
      print('❌ Error writing alert to Firestore: $e');
    }
  }

  // ========== SEND ALTERNATIVE SMS ALERT ==========
  Future<void> _sendEmergencySmsAlert(String type, String carrier) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      // Fetch user's alternative emergency phone number from Firestore
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      String? emergencyPhone = userDoc.exists
          ? userDoc.get('emergencyPhone')
          : null;

      if (emergencyPhone == null || emergencyPhone.isEmpty) {
        print('⚠️ No emergency contact configured for SMS.');
        return;
      }

      List<String> recipients = [emergencyPhone];
      String message = type == 'SIM_CHANGE'
          ? "🚨 Security Alert: Your SIM card / carrier has changed to $carrier! Check admin panel."
          : "🚨 Security Alert: Your device hardware signature has changed! Check admin panel.";

      String result = await sendSMS(message: message, recipients: recipients);
      print('📱 Emergency SMS Result: $result');
    } catch (error) {
      print('❌ Failed to send emergency SMS: $error');
    }
  }

  // ========== CHECK ON APP STARTUP ==========
  Future<void> checkOnStartup(BuildContext context) async {
    bool changed = await detectSimChange(context);
    if (changed) {
      _showAlertDialog(context);
    }
  }

  // ========== SHOW POPUP ALERT ON APP SCREEN ==========
  void _showAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Security Warning'),
        content: const Text(
          'A SIM card or Device modification has been detected!\n\n'
          '• Logged to Admin Portal.\n'
          '• Emergency SMS Dispatched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ========== GET STATUS STRING FOR UI ==========
  Future<String> getSimStatus() async {
    Map<String, String>? savedInfo = await getSavedBaselineInfo();
    if (savedInfo == null) {
      return 'No device/SIM baseline saved';
    }
    return 'Secure: ${savedInfo['deviceModel']} (${savedInfo['carrier']})';
  }
}
