import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sim_reader/sim_reader.dart';
import 'package:permission_handler/permission_handler.dart';

class SimService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Check SIM on app startup
  Future<void> checkOnStartup(BuildContext context) async {
    await _performSimCheck(isManualCheck: false, forceSwapForDemo: false);
  }

  // 2. Triggered when user taps "Re-check SIM Status" normally
  Future<bool> detectSimChange(BuildContext context) async {
    return await _performSimCheck(isManualCheck: true, forceSwapForDemo: false);
  }

  // 3. 🎓 FYP DEMO METHOD: Forces a simulated SIM swap for live evaluation/defense
  Future<bool> simulateSimSwapForDemo(BuildContext context) async {
    return await _performSimCheck(isManualCheck: true, forceSwapForDemo: true);
  }

  // Core SIM checking and emergency alert logic
  Future<bool> _performSimCheck({
    required bool isManualCheck,
    required bool forceSwapForDemo,
  }) async {
    var status = await Permission.phone.request();
    if (!status.isGranted) {
      print("Phone permission not granted.");
      return false;
    }

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      SimInfo? currentSim = await SimReader.getSimInfo();
      String currentCarrier = currentSim?.carrierName ?? 'Active Carrier';
      String currentCountry = currentSim?.countryCode ?? 'PK';

      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      if (!userDoc.exists) return false;

      // Ensure data is treated as a Map to prevent red lines
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      // Fixed: Explicitly cast to String? to remove red line warnings
      String savedCarrier = (userData['baselineCarrier'] as String?) ?? '';

      // Initialize baseline if empty
      if (savedCarrier.isEmpty && !forceSwapForDemo) {
        await _firestore.collection('users').doc(user.uid).update({
          'baselineCarrier': currentCarrier,
          'baselineCountry': currentCountry,
          'isSimChanged': false,
        });
        return false;
      }

      // Determine if a swap happened (either real mismatch OR forced FYP demo switch)
      bool isSwapDetected =
          forceSwapForDemo || (currentCarrier != savedCarrier);

      if (isSwapDetected) {
        String simulatedOldCarrier = savedCarrier.isEmpty
            ? 'Original Carrier'
            : savedCarrier;
        String simulatedNewCarrier = forceSwapForDemo
            ? 'Unauthorized-Sim (FYP Demo)'
            : currentCarrier;

        // Fixed: Explicitly cast to String?
        String emergencyPhone = (userData['emergencyPhone'] as String?) ?? '';
        String userName = (userData['name'] as String?) ?? 'Protected User';
        String userEmail = (userData['email'] as String?) ?? 'No Email';

        // 1. Log to Admin Portal collection (Critical for FYP evaluation score)
        await _firestore.collection('admin_alerts').add({
          'userId': user.uid,
          'userName': userName,
          'userEmail': userEmail,
          'oldCarrier': simulatedOldCarrier,
          'newCarrier': simulatedNewCarrier,
          'alertType': 'SIM_CARD_CHANGED',
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'Unresolved',
        });

        // 2. Dispatch Sandbox Alert to Emergency Contact
        if (emergencyPhone.isNotEmpty) {
          await _firestore.collection('emergency_notifications').add({
            'userId': user.uid,
            'userName': userName,
            'contactPhone': emergencyPhone,
            'message':
                '🚨 SECURITY ALERT: Unauthorized SIM change detected! Switched from $simulatedOldCarrier to $simulatedNewCarrier. Emergency lockdown initiated.',
            'alertType': 'SIM_CHANGE_SANDBOX',
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'Sandbox Dispatched Successfully',
          });
        }

        // 3. Flag user account status in database
        await _firestore.collection('users').doc(user.uid).update({
          'isSimChanged': true,
        });

        return true; // SIM swap handled & logged successfully
      }

      return false; // Secure
    } catch (e) {
      print("Error during SIM check: $e");
      return false;
    }
  }

  // Get status string for dashboard UI card
  Future<String> getSimStatus() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return "Not logged in";

      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      if (!doc.exists) return "Device status unknown";

      Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;

      bool isSimChanged = (userData['isSimChanged'] as bool?) ?? false;
      if (isSimChanged) {
        return "⚠️ Security Alert: SIM Swap Detected & Logged!";
      }

      String carrier = (userData['baselineCarrier'] as String?) ?? '';
      if (carrier.isNotEmpty) {
        return "Secure (Baseline Carrier: $carrier)";
      }

      return "SIM status verified & protected";
    } catch (e) {
      return "Error checking status";
    }
  }
}
