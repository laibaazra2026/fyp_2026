import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';

class SimService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<bool> requestSimPermission() async {
    PermissionStatus status = await Permission.phone.request();
    return status.isGranted;
  }

  Future<void> checkPhysicalSimSwap() async {
    bool hasPermission = await requestSimPermission();
    if (!hasPermission) return;

    User? user = _auth.currentUser;
    if (user == null) return;

    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

      String currentSimIdentifier = androidInfo.id;

      String? oldSimToken = await _secureStorage.read(key: 'trusted_sim_token');
      DocumentReference userDoc = _firestore.collection('users').doc(user.uid);

      if (oldSimToken == null) {
        await _secureStorage.write(
          key: 'trusted_sim_token',
          value: currentSimIdentifier,
        );
        await userDoc.set({
          'trustedSimToken': currentSimIdentifier,
          'simRegisteredAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else if (oldSimToken != currentSimIdentifier) {
        await _firestore.collection('sim_logs').add({
          'userId': user.uid,
          'userEmail': user.email ?? 'Unknown User',
          'oldSimIdentifier': oldSimToken,
          'newSimIdentifier': currentSimIdentifier,
          'deviceModel': androidInfo.model,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'Unauthorized Physical SIM Swap',
        });

        await _secureStorage.write(
          key: 'trusted_sim_token',
          value: currentSimIdentifier,
        );

        await userDoc.update({
          'trustedSimToken': currentSimIdentifier,
          'lastSimSwapDetected': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error checking SIM swap: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserSimLogs() async {
    User? user = _auth.currentUser;
    if (user == null) return [];

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('sim_logs')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching user SIM logs: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllUsersSimLogsForAdmin() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('sim_logs')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching admin SIM logs: $e');
      return [];
    }
  }
}
