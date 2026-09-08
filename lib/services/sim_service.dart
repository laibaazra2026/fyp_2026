import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sim_reader/sim_reader.dart';
import 'package:flutter_sms/flutter_sms.dart';

class SimService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _baselineCarrierKey = 'baseline_carrier_name';
  static const String _baselineSerialKey = 'baseline_sim_serial';

  /// Step 1: Real physical SIM check method called on app boot or manual screen refresh
  Future<bool> checkPhysicalSimSwap() async {
    try {
      // 1. Fetch real SIM info using the package
      SimInfo? simInfo = await SimReader.getSimInfo();
      if (simInfo == null) {
        print("⚠️ SimReader returned null. No active SIM info found.");
        return false;
      }

      String currentCarrier = simInfo.carrierName ?? 'Unknown';

      // Combine carrier name with identifier/country code to guarantee uniqueness on Android
      String rawIdentifier =
          simInfo.simSerialNumber ??
          simInfo.subscriberId ??
          simInfo.countryCode ??
          'Unknown_ID';

      String currentIdentifier = "${currentCarrier}_$rawIdentifier";

      print(
        "🔍 Live SIM Check -> Carrier: $currentCarrier, Identifier: $currentIdentifier",
      );

      // 2. Read stored baseline values from local secure storage
      String? baselineCarrier = await _secureStorage.read(
        key: _baselineCarrierKey,
      );
      String? baselineIdentifier = await _secureStorage.read(
        key: _baselineSerialKey,
      );

      // 3. If no baseline exists, this is the very first run (e.g., Jazz SIM inserted)
      if (baselineCarrier == null || baselineIdentifier == null) {
        await _secureStorage.write(
          key: _baselineCarrierKey,
          value: currentCarrier,
        );
        await _secureStorage.write(
          key: _baselineSerialKey,
          value: currentIdentifier,
        );
        print(
          "📌 Baseline SIM successfully registered: $currentCarrier ($currentIdentifier)",
        );
        return false; // No swap yet, baseline established
      }

      // 4. Compare current SIM data against the baseline to detect a real physical swap (e.g., Zong inserted)
      if (currentIdentifier != baselineIdentifier ||
          currentCarrier != baselineCarrier) {
        print(
          "🚨 REAL PHYSICAL SIM SWAP DETECTED! Old: $baselineCarrier, New: $currentCarrier",
        );

        // Log the swap event to Firestore
        await _logSimSwapToFirestore(currentCarrier, currentIdentifier);

        // Trigger automated SMS alert to trusted numbers
        await _sendEmergencySmsAlert(currentCarrier);

        // Update baseline to the new SIM so it stops spamming alerts
        await _secureStorage.write(
          key: _baselineCarrierKey,
          value: currentCarrier,
        );
        await _secureStorage.write(
          key: _baselineSerialKey,
          value: currentIdentifier,
        );

        return true; // Swap detected
      }

      print("✅ SIM status secure: No mismatch found.");
      return false;
    } catch (e) {
      print("❌ Error checking physical SIM swap: $e");
      return false;
    }
  }

  Future<void> _logSimSwapToFirestore(
    String newCarrier,
    String newIdentifier,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("❌ Cannot log to Firestore: No authenticated user found.");
        return;
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sim_logs')
          .add({
            'carrierName': newCarrier,
            'identifier': newIdentifier,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'Mismatch Alert',
          });
      print("☁️ SIM swap successfully logged to Firestore.");
    } catch (e) {
      print("❌ Failed to log SIM swap to Firestore: $e");
    }
  }

  Future<void> _sendEmergencySmsAlert(String newCarrier) async {
    try {
      String? trustedStr = await _secureStorage.read(
        key: 'trusted_emergency_numbers',
      );
      if (trustedStr == null || trustedStr.isEmpty) return;

      List<String> recipients = trustedStr
          .split(',')
          .map((n) => n.trim())
          .toList();
      String message =
          "🚨 Security Alert: Physical SIM card was swapped! New Carrier: $newCarrier. Device is protected.";

      await sendSMS(message: message, recipients: recipients);
      print("📩 Emergency SMS alert sent successfully.");
    } catch (e) {
      print("❌ Failed to send emergency SMS: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getUserSimLogs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    QuerySnapshot snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('sim_logs')
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();
  }

  Future<void> saveTrustedNumbers(List<String> numbers) async {
    String joined = numbers.join(',');
    await _secureStorage.write(key: 'trusted_emergency_numbers', value: joined);
  }
}
