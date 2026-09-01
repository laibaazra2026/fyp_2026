import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:call_log/call_log.dart';

class BackupRestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<bool> _checkSubscription(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        print('❌ User document not found in Firestore.');
        return false;
      }

      var data = userDoc.data() as Map<String, dynamic>?;
      if (data == null) return false;

      String? plan = data['subscriptionPlan'];
      print('🔍 Found subscription plan: $plan');

      bool isValid =
          plan != null && plan.isNotEmpty && plan.toLowerCase() != 'free';
      return isValid;
    } catch (e) {
      print('❌ Error checking subscription: $e');
      return false;
    }
  }

  Future<bool> backupData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ Backup failed: No authenticated user.');
        return false;
      }

      bool hasAccess = await _checkSubscription(user.uid);
      if (!hasAccess) {
        print('❌ Backup blocked: No active subscription plan detected.');
        return false;
      }

      print('✅ Subscription verified! Proceeding with backup...');

      List<Contact> contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.name, ContactProperty.phone},
      );

      List<Map<String, dynamic>> contactsList = contacts.map((c) {
        return {
          'name': c.displayName ?? 'Unknown',
          'phone': c.phones.isNotEmpty ? c.phones.first.number : '',
        };
      }).toList();

      Iterable<CallLogEntry> callLogs = await CallLog.get();
      List<Map<String, dynamic>> callLogsList = callLogs.map((log) {
        return {
          'name': log.name ?? 'Unknown',
          'number': log.number ?? '',
          'type': log.callType.toString().split('.').last.toUpperCase(),
          'timestamp': log.timestamp ?? DateTime.now().millisecondsSinceEpoch,
        };
      }).toList();

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('backups')
          .doc('device_backup')
          .set({
            'contacts': contactsList,
            'callLogs': callLogsList,
            'timestamp': FieldValue.serverTimestamp(),
          });

      print('✅ Cloud Backup successful for user: ${user.uid}');
      return true;
    } catch (e) {
      print('❌ Error backing up data: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> restoreData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ Restore failed: No authenticated user.');
        return null;
      }

      bool hasAccess = await _checkSubscription(user.uid);
      if (!hasAccess) {
        print('❌ Restore blocked: No active subscription plan detected.');
        return null;
      }

      DocumentSnapshot docSnap = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('backups')
          .doc('device_backup')
          .get();

      if (!docSnap.exists) {
        print('⚠️ No backup found in cloud for this user.');
        return null;
      }

      var data = docSnap.data() as Map<String, dynamic>?;
      if (data == null) return null;

      print('✅ Restore successful from cloud.');
      return {
        'contacts': data['contacts'] ?? [],
        'callLogs': data['callLogs'] ?? [],
      };
    } catch (e) {
      print('❌ Error restoring data: $e');
      return null;
    }
  }
}
