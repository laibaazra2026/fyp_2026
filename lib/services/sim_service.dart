import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sim_reader/sim_reader.dart';
import 'package:permission_handler/permission_handler.dart';

class SimService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Check SIM on app startup / login
  Future<void> checkOnStartup(BuildContext context) async {
    await _performSimCheck(isManualCheck: false);
  }

  // 2. Triggered when user taps "Check Device" or "SIM/Device Alert" button
  Future<bool> detectSimChange(BuildContext context) async {
    return await _performSimCheck(isManualCheck: true);
  }

  // Core SIM checking logic
  Future<bool> _performSimCheck({required bool isManualCheck}) async {
    var status = await Permission.phone.request();
    if (!status.isGranted) {
      print("Phone permission not granted.");
      return false;
    }

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      SimInfo? currentSim = await SimReader.getSimInfo();
      if (currentSim == null) return false;

      String currentCarrier = currentSim.carrierName ?? 'Unknown';
      String currentCountry = currentSim.countryCode ?? 'Unknown';

      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      if (!userDoc.exists) return false;

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String savedCarrier = userData['baselineCarrier'] ?? '';

      // If baseline wasn't saved yet, save it now
      if (savedCarrier.isEmpty) {
        await _firestore.collection('users').doc(user.uid).update({
          'baselineCarrier': currentCarrier,
          'baselineCountry': currentCountry,
          'isSimChanged': false,
        });
        return false;
      }

      // Check if carrier has changed
      if (currentCarrier != savedCarrier) {
        // Log security alert directly to Admin Portal collection
        await _firestore.collection('admin_alerts').add({
          'userId': user.uid,
          'userName': userData['name'] ?? 'Unknown User',
          'userEmail': userData['email'] ?? 'No Email',
          'oldCarrier': savedCarrier,
          'newCarrier': currentCarrier,
          'alertType': 'SIM_CARD_CHANGED',
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'Unresolved',
        });

        // Flag user account as compromised
        await _firestore.collection('users').doc(user.uid).update({
          'isSimChanged': true,
        });

        return true; // SIM changed!
      }

      return false; // SIM is secure
    } catch (e) {
      print("Error during SIM check: $e");
      return false;
    }
  }

  // 3. Get text status to display on the dashboard card
  Future<String> getSimStatus() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return "Not logged in";

      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      if (!doc.exists) return "Device status unknown";

      bool isSimChanged = doc.get('isSimChanged') ?? false;
      if (isSimChanged) {
        return "⚠️ Security Alert: SIM Changed!";
      }

      // Fixed syntax here using proper parentheses
      String carrier = doc.get('baselineCarrier') ?? '';
      if (carrier.isNotEmpty) {
        return "Secure (Carrier: $carrier)";
      }

      return "SIM status verified & saved";
    } catch (e) {
      return "Error checking status";
    }
  }
}
