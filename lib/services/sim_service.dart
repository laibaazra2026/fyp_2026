import 'package:flutter/material.dart';
import 'package:sim_card_info/sim_card_info.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SimService {
  final SimCardInfo simCardInfo = SimCardInfo();

  // ========== GET SIM CARD INFO ==========
  Future<String?> getSimSerialNumber() async {
    try {
      List<SimCard>? sims = await simCardInfo.getSimCardInfo();
      if (sims != null && sims.isNotEmpty) {
        return sims.first.serialNumber;
      }
      return null;
    } catch (e) {
      print('❌ Error getting SIM: $e');
      return null;
    }
  }

  // ========== SAVE SIM ==========
  Future<void> saveSim(String? simSerial) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sim_serial', simSerial ?? '');
    print('✅ SIM saved');
  }

  // ========== GET SAVED SIM ==========
  Future<String?> getSavedSim() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('sim_serial');
  }

  // ========== CHECK SIM CHANGE ==========
  Future<bool> checkSimChanged() async {
    String? currentSim = await getSimSerialNumber();
    if (currentSim == null) {
      print('❌ Could not get SIM');
      return false;
    }

    String? savedSim = await getSavedSim();

    if (savedSim == null || savedSim.isEmpty) {
      await saveSim(currentSim);
      print('✅ First time SIM saved');
      return false;
    }

    if (currentSim != savedSim) {
      print('⚠️ SIM CHANGED!');
      await _saveAlertToFirebase(currentSim, savedSim);
      await saveSim(currentSim);
      return true;
    }

    print('✅ SIM is same');
    return false;
  }

  // ========== SAVE ALERT TO FIREBASE ==========
  Future<void> _saveAlertToFirebase(String newSim, String oldSim) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('alerts').add({
        'userId': user.uid,
        'type': 'SIM_CHANGE',
        'title': '⚠️ SIM Card Changed!',
        'message': 'A new SIM card was detected in your device.',
        'oldSim': oldSim,
        'newSim': newSim,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      print('✅ Alert saved to Firebase');
    } catch (e) {
      print('❌ Firebase error: $e');
    }
  }

  // ========== CHECK ON STARTUP ==========
  Future<void> checkOnStartup(BuildContext context) async {
    bool changed = await checkSimChanged();
    if (changed) {
      _showDialog(context);
    }
  }

  // ========== SHOW DIALOG ==========
  void _showDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ SIM Changed'),
        content: const Text('A new SIM card was detected in your device.'),
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
    String? sim = await getSavedSim();
    if (sim == null || sim.isEmpty) {
      return 'No SIM saved';
    }
    return 'SIM: ${sim.substring(0, 4)}...****';
  }
}
