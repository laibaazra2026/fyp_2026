import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';

class SimService {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  // ========== GET DEVICE ID ==========
  Future<String?> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor;
      }
      return null;
    } catch (e) {
      print('❌ Error: $e');
      return null;
    }
  }

  // ========== SAVE DEVICE ID ==========
  Future<void> saveDeviceId(String? deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_id', deviceId ?? '');
    print('✅ Device ID saved');
  }

  // ========== GET SAVED DEVICE ID ==========
  Future<String?> getSavedDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('device_id');
  }

  // ========== CHECK DEVICE CHANGE ==========
  Future<bool> checkDeviceChanged() async {
    String? currentDeviceId = await getDeviceId();
    if (currentDeviceId == null) return false;

    String? savedDeviceId = await getSavedDeviceId();

    if (savedDeviceId == null || savedDeviceId.isEmpty) {
      await saveDeviceId(currentDeviceId);
      print('✅ First time saved');
      return false;
    }

    if (currentDeviceId != savedDeviceId) {
      print('⚠️ DEVICE CHANGED!');
      await _saveAlertToFirebase(currentDeviceId, savedDeviceId);
      await saveDeviceId(currentDeviceId);
      return true;
    }

    print('✅ Device is same');
    return false;
  }

  // ========== SAVE ALERT ==========
  Future<void> _saveAlertToFirebase(
    String newDeviceId,
    String oldDeviceId,
  ) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('alerts').add({
        'userId': user.uid,
        'type': 'DEVICE_CHANGE',
        'title': '⚠️ Device Changed!',
        'message': 'A new device was detected.',
        'oldDeviceId': oldDeviceId,
        'newDeviceId': newDeviceId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      print('✅ Alert saved');
    } catch (e) {
      print('❌ Firebase error: $e');
    }
  }

  // ========== CHECK ON STARTUP ==========
  Future<void> checkOnStartup(BuildContext context) async {
    bool changed = await checkDeviceChanged();
    if (changed) {
      _showDialog(context);
    }
  }

  // ========== SHOW DIALOG ==========
  void _showDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Device Changed'),
        content: const Text(
          'A new device was detected. Please secure your account.',
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
    String? deviceId = await getSavedDeviceId();
    if (deviceId == null || deviceId.isEmpty) {
      return 'No device saved';
    }
    return 'Device: ${deviceId.substring(0, 4)}...****';
  }
}
