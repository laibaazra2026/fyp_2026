import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sim_reader/sim_reader.dart';

class SimService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _baselineCarrierKey = 'baseline_carrier_name';
  static const String _baselineSerialKey = 'baseline_sim_serial';
  static const String _localLogsKey = 'local_sim_swap_logs';

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

      // 3. If no baseline exists, this is the very first run
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

      // 4. Compare current SIM data against the baseline to detect a real physical swap
      if ((currentIdentifier != baselineIdentifier ||
              currentCarrier != baselineCarrier) &&
          currentIdentifier != 'Unknown_ID') {
        print(
          "🚨 REAL PHYSICAL SIM SWAP DETECTED! Old: $baselineCarrier, New: $currentCarrier",
        );

        // Save locally first so logs never disappear from the app UI
        await _saveLogLocally(currentCarrier, currentIdentifier);

        // Log the swap event to Firestore (User + Admin portals)
        await _logSimSwapToFirestore(currentCarrier, currentIdentifier);

        // Trigger simulated emergency alert for trusted numbers (Free - No carrier SMS cost)
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

  /// Save logs locally on the device to prevent them from disappearing
  Future<void> _saveLogLocally(String carrier, String identifier) async {
    try {
      List<Map<String, dynamic>> existingLogs = await getUserSimLogs();

      final newLog = {
        'carrierName': carrier,
        'identifier': identifier,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'Mismatch Alert',
      };

      existingLogs.insert(0, newLog); // Keep latest at top

      // Convert any Timestamp objects back to strings before encoding to JSON storage
      final encodableLogs = existingLogs.map((log) {
        final map = Map<String, dynamic>.from(log);
        if (map['timestamp'] is Timestamp) {
          map['timestamp'] = (map['timestamp'] as Timestamp)
              .toDate()
              .toIso8601String();
        }
        return map;
      }).toList();

      await _secureStorage.write(
        key: _localLogsKey,
        value: jsonEncode(encodableLogs),
      );
      print("💾 SIM log securely cached locally.");
    } catch (e) {
      print("❌ Failed to save log locally: $e");
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

      final logData = {
        'userId': user.uid,
        'userEmail': user.email ?? 'Unknown',
        'carrierName': newCarrier,
        'identifier': newIdentifier,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'Mismatch Alert',
      };

      // Log to user portal collection
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sim_logs')
          .add(logData);

      // Log to global collection for admin portal visibility
      await _firestore.collection('all_sim_swap_logs').add(logData);

      print("☁️ SIM swap successfully logged to Firestore & Admin portal.");
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

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Save the simulated alert with the emergency numbers attached so you can display them in the UI drawer
        final fakeAlertData = {
          'userId': user.uid,
          'carrierName': newCarrier,
          'emergencyNumbers': recipients,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'Simulated Alert',
          'message':
              '🚨 Simulated SMS to ${recipients.join(", ")}: Physical SIM swapped to $newCarrier!',
        };

        // Save to Firestore so your app drawer / alert notification icon can display it seamlessly
        await _firestore.collection('sim_swap_alerts').add(fakeAlertData);
      }

      print(
        "📱 Simulated emergency alert generated for trusted numbers (No carrier SMS cost).",
      );
    } catch (e) {
      print("❌ Failed to create simulated alert: $e");
    }
  }

  /// Fetch logs for the User Portal (reads local storage first so they never vanish)
  Future<List<Map<String, dynamic>>> getUserSimLogs() async {
    try {
      String? localData = await _secureStorage.read(key: _localLogsKey);
      if (localData != null && localData.isNotEmpty) {
        List<dynamic> decoded = jsonDecode(localData);
        return decoded.map((item) {
          final map = item as Map<String, dynamic>;
          if (map['timestamp'] is String) {
            map['timestamp'] = Timestamp.fromDate(
              DateTime.parse(map['timestamp']),
            );
          }
          return map;
        }).toList();
      }
    } catch (e) {
      print("❌ Error reading local logs: $e");
    }

    // Fallback to Firestore if local storage cache is empty
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sim_logs')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print("❌ Error fetching Firestore logs: $e");
      return [];
    }
  }

  /// Fetch all users' logs for the Admin Portal
  Future<List<Map<String, dynamic>>> getAllUsersSimLogsForAdmin() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('all_sim_swap_logs')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print("❌ Error fetching admin logs: $e");
      return [];
    }
  }

  Future<void> saveTrustedNumbers(List<String> numbers) async {
    String joined = numbers.join(',');
    await _secureStorage.write(key: 'trusted_emergency_numbers', value: joined);
  }
}
