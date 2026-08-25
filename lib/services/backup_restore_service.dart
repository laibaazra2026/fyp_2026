import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class BackupRestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // 1. BACKUP ALL CONTACTS TO FIRESTORE
  Future<bool> backupContacts() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final status = await FlutterContacts.permissions.request(
        PermissionType.readWrite,
      );
      if (status == PermissionStatus.granted) {
        List<Contact> contacts = await FlutterContacts.getAll(
          properties: {ContactProperty.name, ContactProperty.phone},
        );

        List<Map<String, dynamic>> contactListMap = contacts.map((c) {
          return {
            'name': c.displayName,
            'phone': c.phones.isNotEmpty ? c.phones.first.number : '',
          };
        }).toList();

        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('backup_contacts')
            .doc('my_contacts')
            .set({
              'contacts': contactListMap,
              'backedUpAt': FieldValue.serverTimestamp(),
            });

        return true;
      }
      return false;
    } catch (e) {
      print('Error backing up contacts: $e');
      return false;
    }
  }

  // 2. RESTORE CONTACTS BACK TO PHONE
  Future<bool> restoreContacts() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final status = await FlutterContacts.permissions.request(
        PermissionType.readWrite,
      );
      if (status == PermissionStatus.granted) {
        DocumentSnapshot doc = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('backup_contacts')
            .doc('my_contacts')
            .get();

        if (!doc.exists) return false;

        List<dynamic> contactList = doc.get('contacts');

        for (var c in contactList) {
          final newContact = Contact(
            name: Name(first: c['name'] ?? 'Unknown'),
            phones: [
              Phone(number: c['phone'] ?? ''),
            ], // Fixed with named parameter 'number:'
          );

          await FlutterContacts.create(newContact);
        }
        return true;
      }
      return false;
    } catch (e) {
      print('Error restoring contacts: $e');
      return false;
    }
  }

  // 3. BACKUP MEDIA/PHOTOS TO FIREBASE STORAGE
  Future<bool> backupMedia(File imageFile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = _storage.ref().child(
        'users/${user.uid}/media_backups/$fileName.jpg',
      );

      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('media_backups')
          .add({'url': downloadUrl, 'createdAt': FieldValue.serverTimestamp()});

      return true;
    } catch (e) {
      print('Error backing up media: $e');
      return false;
    }
  }
}
