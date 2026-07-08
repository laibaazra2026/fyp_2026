import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';

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

  // ========== GET DEVICE MODEL ==========
  Future<String?> getDeviceModel() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.model;
      }
      return null;
    } catch (e) {
      print('❌ Error getting device model: $e');
      return null;
    }
  }

  // ========== GET DEVICE NAME ==========
  Future<String?> getDeviceName() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.device;
      }
      return null;
    } catch (e) {
      print('❌ Error getting device name: $e');
      return null;
    }
  }

  // ========== SAVE DEVICE INFO ==========
  Future<void> saveDeviceInfo(
    String? deviceId,
    String? deviceModel,
    String? deviceName,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_id', deviceId ?? '');
    await prefs.setString('device_model', deviceModel ?? '');
    await prefs.setString('device_name', deviceName ?? '');
    print('✅ Device info saved');
  }

  // ========== GET SAVED DEVICE INFO ==========
  Future<Map<String, String>?> getSavedDeviceInfo() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');
    if (deviceId == null || deviceId.isEmpty) {
      return null;
    }
    return {
      'deviceId': deviceId,
      'deviceModel': prefs.getString('device_model') ?? 'Unknown',
      'deviceName': prefs.getString('device_name') ?? 'Unknown',
    };
  }

  // ========== DETECT SIM/DEVICE CHANGE ==========
  Future<bool> detectSimChange() async {
    String? currentDeviceId = await getDeviceId();
    String? currentDeviceModel = await getDeviceModel();
    String? currentDeviceName = await getDeviceName();

    if (currentDeviceId == null || currentDeviceModel == null) {
      print('❌ Could not get device info');
      return false;
    }

    Map<String, String>? savedInfo = await getSavedDeviceInfo();

    // First time - save device info
    if (savedInfo == null) {
      await saveDeviceInfo(
        currentDeviceId,
        currentDeviceModel,
        currentDeviceName,
      );
      print('✅ First time device info saved');
      return false;
    }

    String savedDeviceId = savedInfo['deviceId'] ?? '';
    String savedModel = savedInfo['deviceModel'] ?? '';

    // Check if device changed
    if (currentDeviceId != savedDeviceId || currentDeviceModel != savedModel) {
      print('⚠️ DEVICE/SIM CHANGE DETECTED!');
      await _handleDeviceChange(
        currentDeviceId,
        savedDeviceId,
        currentDeviceModel,
        savedModel,
        currentDeviceName,
      );
      await saveDeviceInfo(
        currentDeviceId,
        currentDeviceModel,
        currentDeviceName,
      );
      return true;
    }

    print('✅ Device is same');
    return false;
  }

  // ========== HANDLE DEVICE CHANGE ==========
  Future<void> _handleDeviceChange(
    String newId,
    String oldId,
    String newModel,
    String oldModel,
    String? deviceName,
  ) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      String userEmail = userDoc.get('email') ?? 'Unknown';
      String userName = userDoc.get('name') ?? 'User';

      await _firestore.collection('sim_alerts').add({
        'userId': user.uid,
        'userEmail': userEmail,
        'userName': userName,
        'type': 'DEVICE_CHANGE',
        'title': '⚠️ SIM/Device Changed',
        'message': 'A new SIM or device was detected on $deviceName.',
        'oldDeviceId': oldId,
        'newDeviceId': newId,
        'oldModel': oldModel,
        'newModel': newModel,
        'deviceName': deviceName ?? 'Unknown',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      print('✅ SIM/Device change alert saved to sim_alerts!');
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  // ========== CHECK ON STARTUP ==========
  Future<void> checkOnStartup(BuildContext context) async {
    bool changed = await detectSimChange();
    if (changed) {
      _showAlertDialog(context);
    }
  }

  // ========== SHOW ALERT ==========
  void _showAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ SIM/Device Changed'),
        content: const Text(
          'A new SIM or device has been detected.\n'
          'Alert saved to admin panel.',
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

  // ========== GET STATUS ==========
  Future<String> getSimStatus() async {
    Map<String, String>? savedInfo = await getSavedDeviceInfo();
    if (savedInfo == null) {
      return 'No device saved';
    }
    return 'Device: ${savedInfo['deviceModel'] ?? 'Unknown'} (${savedInfo['deviceName'] ?? ''})';
  }
}
