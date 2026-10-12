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

  Future<bool> checkPhysicalSimSwap() async {
    try {
      SimInfo? simInfo = await SimReader.getSimInfo();
      if (simInfo == null) {
        print("⚠️ SimReader returned null. No active SIM info found.");
        return false;
      }

      String currentCarrier = simInfo.carrierName ?? 'Unknown';

      String rawIdentifier =
          simInfo.simSerialNumber ??
          simInfo.subscriberId ??
          simInfo.countryCode ??
          'Unknown_ID';

      String currentIdentifier = "${currentCarrier}_$rawIdentifier";

      print(
        "🔍 Live SIM Check -> Carrier: $currentCarrier, Identifier: $currentIdentifier",
      );

      String? baselineCarrier = await _secureStorage.read(
        key: _baselineCarrierKey,
      );
      String? baselineIdentifier = await _secureStorage.read(
        key: _baselineSerialKey,
      );

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
        return false;
      }

      if ((currentIdentifier != baselineIdentifier ||
              currentCarrier != baselineCarrier) &&
          currentIdentifier != 'Unknown_ID') {
        print(
          "🚨 REAL PHYSICAL SIM SWAP DETECTED! Old: $baselineCarrier, New: $currentCarrier",
        );

        await _saveLogLocally(currentCarrier, currentIdentifier);

        await _logSimSwapToFirestore(currentCarrier, currentIdentifier);

        await _secureStorage.write(
          key: _baselineCarrierKey,
          value: currentCarrier,
        );
        await _secureStorage.write(
          key: _baselineSerialKey,
          value: currentIdentifier,
        );

        return true;
      }

      print("✅ SIM status secure: No mismatch found.");
      return false;
    } catch (e) {
      print("❌ Error checking physical SIM swap: $e");
      return false;
    }
  }

  Future<void> _saveLogLocally(String carrier, String identifier) async {
    try {
      List<Map<String, dynamic>> existingLogs = await getUserSimLogs();

      final newLog = {
        'carrierName': carrier,
        'identifier': identifier,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'Mismatch Alert',
      };

      existingLogs.insert(0, newLog);

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

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sim_logs')
          .add(logData);

      await _firestore.collection('all_sim_swap_logs').add(logData);

      print("☁️ SIM swap successfully logged to Firestore & Admin portal.");
    } catch (e) {
      print("❌ Failed to log SIM swap to Firestore: $e");
    }
  }

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
}
