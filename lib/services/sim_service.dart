import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_sms/flutter_sms.dart';
import 'package:sim_reader/sim_reader.dart';

class SimService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // 1. Request Runtime Permissions for Phone and SMS
  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.phone,
      Permission.sms,
    ].request();

    return statuses[Permission.phone]!.isGranted &&
        statuses[Permission.sms]!.isGranted;
  }

  // 2. Real Physical SIM Change Detection
  Future<void> checkPhysicalSimSwap() async {
    bool hasPermission = await requestPermissions();
    if (!hasPermission) {
      print("SIM Detection Error: Phone or SMS permissions denied by user.");
      return;
    }

    User? user = _auth.currentUser;
    if (user == null) return;

    try {
      // Fetch live physical SIM info from the hardware slot
      SimInfo? simInfo;
      try {
        simInfo = await SimReader.getSimInfo();
      } catch (e) {
        print("SimReader hardware exception: $e");
      }

      // Extract the real physical SIM serial number (ICCID) or subscriber ID
      String currentSimIdentifier =
          simInfo?.simSerialNumber ?? simInfo?.subscriberId ?? '';

      // Fallback to device hardware fingerprint ONLY if the SIM slot is unreadable
      if (currentSimIdentifier.isEmpty || currentSimIdentifier == 'UNKNOWN') {
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        currentSimIdentifier =
            "${androidInfo.board}_${androidInfo.device}_${androidInfo.id}";
      }

      String? oldSimToken = await _secureStorage.read(key: 'trusted_sim_token');
      String? trustedNumbersStr = await _secureStorage.read(
        key: 'trusted_numbers',
      );

      // Default emergency contacts fallback
      if (trustedNumbersStr == null || trustedNumbersStr.isEmpty) {
        trustedNumbersStr =
            "+923144984339,+923128719043,+923157633912,+923005171794,+923241923864";
        await _secureStorage.write(
          key: 'trusted_numbers',
          value: trustedNumbersStr,
        );
      }

      DocumentReference userDoc = _firestore.collection('users').doc(user.uid);

      if (oldSimToken == null) {
        // First-time setup: Save current real SIM signature as trusted
        await _secureStorage.write(
          key: 'trusted_sim_token',
          value: currentSimIdentifier,
        );
        await userDoc.set({
          'trustedSimToken': currentSimIdentifier,
          'simRegisteredAt': FieldValue.serverTimestamp(),
          'trustedNumbers': trustedNumbersStr.split(','),
        }, SetOptions(merge: true));
        print("Baseline SIM registered successfully: $currentSimIdentifier");
      } else if (oldSimToken != currentSimIdentifier) {
        // 🚨 REAL PHYSICAL SIM SWAP DETECTED 🚨
        print(
          "REAL SIM SWAP DETECTED! Old: $oldSimToken, New: $currentSimIdentifier",
        );

        if (trustedNumbersStr.isNotEmpty) {
          List<String> trustedNumbers = trustedNumbersStr.split(',');
          String alertMessage =
              "SECURITY ALERT: Physical SIM card has been changed on user account!";
          await _sendAlertSms(trustedNumbers, alertMessage);
        }

        // Update local secure storage to the new SIM token
        await _secureStorage.write(
          key: 'trusted_sim_token',
          value: currentSimIdentifier,
        );

        // Log the real swap to Firestore
        await _firestore.collection('sim_logs').add({
          'userId': user.uid,
          'userEmail': user.email ?? 'Unknown User',
          'oldIdentifier': oldSimToken,
          'newIdentifier': currentSimIdentifier,
          'carrierName': simInfo?.carrierName ?? 'Unknown Carrier',
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'Real Physical SIM Swap Detected',
        });

        await userDoc.update({
          'trustedSimToken': currentSimIdentifier,
          'lastSimSwapDetected': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Real SIM Swap check critical error: $e');
    }
  }

  // 3. SMS Dispatcher
  Future<void> _sendAlertSms(List<String> recipients, String message) async {
    try {
      String result = await sendSMS(message: message, recipients: recipients)
          .catchError((onError) {
            print("SMS Error: $onError");
            return "Failed";
          });
      print("SMS Dispatch Result: $result");
    } catch (e) {
      print("SMS Dispatch Exception: $e");
    }
  }

  // 4. Save Emergency Contacts
  Future<void> saveTrustedNumbers(List<String> numbers) async {
    String joinedNumbers = numbers.join(',');
    await _secureStorage.write(key: 'trusted_numbers', value: joinedNumbers);

    User? user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'trustedNumbers': numbers,
      }, SetOptions(merge: true));
    }
  }

  // 5. Fetch User Logs
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
      return [];
    }
  }
}
