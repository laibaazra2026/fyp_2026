import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart' hide PermissionStatus;
import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart';

class BackupRestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. BACKUP LOCAL DATA TO CLOUD
  Future<bool> uploadUserDataBackup() async {
    User? user = _auth.currentUser;
    if (user == null) return false;

    try {
      PermissionStatus contactStatus = await Permission.contacts.request();
      PermissionStatus phoneStatus = await Permission.phone.request();

      if (!contactStatus.isGranted || !phoneStatus.isGranted) {
        return false;
      }

      WriteBatch batch = _firestore.batch();

      // Backup Contacts using modern getAll() and properties syntax
      List<Contact> contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.name, ContactProperty.phone},
      );

      for (var contact in contacts) {
        if (contact.phones.isNotEmpty) {
          DocumentReference contactRef = _firestore
              .collection('users')
              .doc(user.uid)
              .collection('backup_contacts')
              .doc(contact.id);

          batch.set(contactRef, {
            'name': contact.displayName,
            'phone': contact.phones.first.number,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Backup Call Logs (Last 50 calls)
      Iterable<CallLogEntry> callLogs = await CallLog.get();
      int count = 0;
      for (var log in callLogs) {
        if (count >= 50) break;
        DocumentReference logRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('backup_call_logs')
            .doc();

        batch.set(logRef, {
          'name': log.name ?? 'Unknown',
          'number': log.number ?? '',
          'type': log.callType.toString(),
          'duration': log.duration ?? 0,
          'timestamp': log.timestamp ?? DateTime.now().millisecondsSinceEpoch,
        });
        count++;
      }

      await batch.commit();
      return true;
    } catch (e) {
      print("Backup Error: $e");
      return false;
    }
  }

  // 2. RESTORE CONTACTS FROM CLOUD
  Future<List<Map<String, dynamic>>> restoreContactsFromCloud() async {
    User? user = _auth.currentUser;
    if (user == null) return [];

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('backup_contacts')
          .get();

      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      return [];
    }
  }

  // 3. RESTORE CALL LOGS FROM CLOUD
  Future<List<Map<String, dynamic>>> restoreCallLogsFromCloud() async {
    User? user = _auth.currentUser;
    if (user == null) return [];

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('backup_call_logs')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      return [];
    }
  }
}
