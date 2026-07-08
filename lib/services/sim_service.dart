import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sim_card_info/sim_card_info.dart';

class SimService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ========== GET SIM INFO ==========
  Future<Map<String, String>?> getSimInfo() async {
    try {
      List<SimCard>? sims = await SimCardInfo().getSimCardInfo();
      if (sims != null && sims.isNotEmpty) {
        return {
          'carrierName': sims.first.carrierName ?? 'Unknown',
          'simSerialNumber': sims.first.serialNumber ?? 'Unknown',
          'phoneNumber': sims.first.number ?? 'Unknown',
          'countryCode': sims.first.countryCode ?? 'Unknown',
        };
      }
      return null;
    } catch (e) {
      print('❌ Error getting SIM info: $e');
      return null;
    }
  }

  // ========== SAVE SIM INFO ==========
  Future<void> saveSimInfo(Map<String, String> simInfo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sim_serial', simInfo['simSerialNumber'] ?? '');
    await prefs.setString('sim_carrier', simInfo['carrierName'] ?? '');
  }

  // ========== GET SAVED SIM ==========
  Future<Map<String, String>?> getSavedSimInfo() async {
    final prefs = await SharedPreferences.getInstance();
    String? serial = prefs.getString('sim_serial');
    if (serial == null || serial.isEmpty) {
      return null;
    }
    return {
      'simSerialNumber': serial,
      'carrierName': prefs.getString('sim_carrier') ?? '',
    };
  }

  // ========== DETECT SIM CHANGE ==========
  Future<bool> detectSimChange() async {
    // Get current SIM
    Map<String, String>? currentSim = await getSimInfo();
    if (currentSim == null) {
      print('❌ Could not read SIM');
      return false;
    }

    // Get saved SIM
    Map<String, String>? savedSim = await getSavedSimInfo();

    // First time - save SIM
    if (savedSim == null) {
      await saveSimInfo(currentSim);
      print('✅ First time SIM saved: ${currentSim['carrierName']}');
      return false;
    }

    // Compare SIM serial numbers
    String currentSerial = currentSim['simSerialNumber'] ?? '';
    String savedSerial = savedSim['simSerialNumber'] ?? '';

    if (currentSerial != savedSerial &&
        currentSerial.isNotEmpty &&
        savedSerial.isNotEmpty) {
      // ✅ SIM CHANGED!
      print('⚠️ SIM CHANGE DETECTED!');
      print('   Old SIM: $savedSerial');
      print('   New SIM: $currentSerial');

      await _handleSimChange(currentSim, savedSim);
      await saveSimInfo(currentSim);
      return true;
    }

    print('✅ SIM is same: ${currentSim['carrierName']}');
    return false;
  }

  // ========== HANDLE SIM CHANGE (SEND ALERT) ==========
  Future<void> _handleSimChange(
    Map<String, String> newSim,
    Map<String, String> oldSim,
  ) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      // Get user data
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      String userEmail = userDoc.get('email') ?? 'Unknown';
      String userName = userDoc.get('name') ?? 'User';

      // ✅ SAVE SIM CHANGE ALERT TO FIRESTORE
      await _firestore.collection('sim_alerts').add({
        'userId': user.uid,
        'userEmail': userEmail,
        'userName': userName,
        'type': 'SIM_CHANGE',
        'title': '⚠️ SIM Card Changed',
        'message': 'A new SIM card was detected in the device.',
        'oldSimSerial': oldSim['simSerialNumber'],
        'newSimSerial': newSim['simSerialNumber'],
        'oldCarrier': oldSim['carrierName'],
        'newCarrier': newSim['carrierName'],
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      print('✅ SIM change alert saved to Firebase!');
    } catch (e) {
      print('❌ Error saving SIM alert: $e');
    }
  }

  // ========== CHECK ON APP START ==========
  Future<void> checkOnStartup(BuildContext context) async {
    bool changed = await detectSimChange();
    if (changed) {
      _showAlertDialog(context);
    }
  }

  // ========== SHOW ALERT DIALOG ==========
  void _showAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ SIM Card Changed'),
        content: const Text(
          'A new SIM card has been detected in your device.\n'
          'This alert has been logged in the admin panel.',
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

  // ========== GET SIM STATUS ==========
  Future<String> getSimStatus() async {
    Map<String, String>? savedSim = await getSavedSimInfo();
    if (savedSim == null) {
      return 'No SIM saved';
    }
    return 'SIM: ${savedSim['carrierName']} (${savedSim['simSerialNumber']?.substring(0, 4)}...****)';
  }

  // ========== GET ALL SIM ALERTS ==========
  Future<List<Map<String, dynamic>>> getSimAlerts() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return [];

      QuerySnapshot snapshot = await _firestore
          .collection('sim_alerts')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('❌ Error getting SIM alerts: $e');
      return [];
    }
  }
}
