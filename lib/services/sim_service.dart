import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';

class SimService {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  // ========== GET ANDROID ID ==========
  Future<String?> getAndroidId() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id; // This changes on factory reset only
      }
      return null;
    } catch (e) {
      print('❌ Error getting Android ID: $e');
      return null;
    }
  }

  // ========== GET DEVICE NAME ==========
  Future<String?> getDeviceName() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return androidInfo.model; // e.g., "vivo 1938"
      }
      return null;
    } catch (e) {
      print('❌ Error getting device name: $e');
      return null;
    }
  }

  // ========== CHECK SIM CHANGE BY COMPARING DEVICE NAME ==========
  Future<bool> checkDeviceChanged() async {
    String? currentName = await getDeviceName();
    if (currentName == null) return false;

    final prefs = await SharedPreferences.getInstance();
    String? savedName = prefs.getString('device_name');

    if (savedName == null || savedName.isEmpty) {
      await prefs.setString('device_name', currentName);
      print('✅ First time device name saved: $currentName');
      return false;
    }

    if (currentName != savedName) {
      print('⚠️ DEVICE NAME CHANGED! $savedName -> $currentName');

      // Save alert to Firebase
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('alerts').add({
          'userId': user.uid,
          'type': 'DEVICE_CHANGE',
          'title': '⚠️ Device Changed!',
          'message': 'Device name changed from $savedName to $currentName',
          'oldDevice': savedName,
          'newDevice': currentName,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
        print('✅ Alert saved to Firebase!');
      }

      // Update saved name
      await prefs.setString('device_name', currentName);
      return true;
    }

    print('✅ Device name is same: $currentName');
    return false;
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
          'A new device was detected. Alert saved to Firebase.',
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
    final prefs = await SharedPreferences.getInstance();
    String? name = prefs.getString('device_name');
    if (name == null || name.isEmpty) {
      return 'No device saved';
    }
    return 'Device: $name';
  }
}
