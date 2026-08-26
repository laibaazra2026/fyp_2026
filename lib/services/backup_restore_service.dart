import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:call_log/call_log.dart';

class BackupRestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ☁️ Backup Contacts and Call Logs to Firestore
  Future<bool> backupData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Request permissions using v2.x syntax
      final status = await FlutterContacts.permissions.request(
        PermissionType.readWrite,
      );
      if (status != PermissionStatus.granted) return false;

      // Fetch all contacts using v2.x getAll
      List<Contact> contacts = await FlutterContacts.getAll(
        properties: {
          ContactProperty.name,
          ContactProperty.phone,
          ContactProperty.email,
        },
      );

      List<Map<String, dynamic>> contactListMap = contacts
          .map(
            (c) => {
              'name': c.displayName ?? 'Unknown',
              'phone': c.phones.isNotEmpty ? c.phones.first.number : '',
              'email': c.emails.isNotEmpty ? c.emails.first.address : '',
            },
          )
          .toList();

      // Fetch call logs safely
      Iterable<CallLogEntry> callLogs = await CallLog.get();
      List<Map<String, dynamic>> callLogListMap = callLogs
          .map(
            (log) => {
              'name': log.name ?? 'Unknown',
              'number': log.number ?? '',
              'type': log.callType.toString(),
              'timestamp': log.timestamp ?? 0,
            },
          )
          .toList();

      // Save to Firestore under the authenticated user's UID
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('backup_data')
          .doc('device_backup')
          .set({
            'contacts': contactListMap,
            'callLogs': callLogListMap,
            'backedUpAt': FieldValue.serverTimestamp(),
          });

      return true;
    } catch (e) {
      print('Backup error: $e');
      return false;
    }
  }

  // 🔄 Restore Contacts to Device & Fetch Data for UI Display
  Future<Map<String, dynamic>?> restoreData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final status = await FlutterContacts.permissions.request(
        PermissionType.readWrite,
      );
      if (status != PermissionStatus.granted) return null;

      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('backup_data')
          .doc('device_backup')
          .get();

      if (!doc.exists) return null;

      List<dynamic> contactList = doc.get('contacts');
      List<dynamic> callLogList = doc.get('callLogs');

      // Restore contacts back to the device phonebook using v2.x create API
      for (var c in contactList) {
        final newContact = Contact(
          name: Name(first: c['name'] ?? 'Unknown'),
          phones: [Phone(number: c['phone'] ?? '')],
        );
        await FlutterContacts.create(newContact);
      }

      return {'contacts': contactList, 'callLogs': callLogList};
    } catch (e) {
      print('Restore error: $e');
      return null;
    }
  }
}
