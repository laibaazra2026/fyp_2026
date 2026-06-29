import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

class IntruderService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  int _wrongAttempts = 0;

  // ========== RESET ATTEMPTS ==========
  void resetAttempts() {
    _wrongAttempts = 0;
  }

  // ========== RECORD WRONG ATTEMPT ==========
  Future<void> recordWrongAttempt(BuildContext context) async {
    _wrongAttempts++;

    if (_wrongAttempts >= 3) {
      // Capture intruder photo
      await captureIntruderPhoto(context);
      resetAttempts();
    }
  }

  // ========== CAPTURE INTRUDER PHOTO ==========
  Future<void> captureIntruderPhoto(BuildContext context) async {
    try {
      // Request camera permission
      PermissionStatus status = await Permission.camera.request();
      if (!status.isGranted) {
        _showMessage(context, '❌ Camera permission denied');
        return;
      }

      // Capture image from front camera
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image == null) {
        _showMessage(context, '❌ No image captured');
        return;
      }

      _showMessage(context, '📸 Photo captured! Uploading...');

      // Upload to Firebase Storage
      String photoUrl = await _uploadToFirebase(image);

      // Save to Firestore
      await _saveToFirestore(photoUrl);

      _showMessage(context, '✅ Intruder photo saved to Firebase!');
    } catch (e) {
      _showMessage(context, '❌ Error: $e');
    }
  }

  // ========== UPLOAD TO FIREBASE STORAGE ==========
  Future<String> _uploadToFirebase(XFile image) async {
    User? user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    String fileName = 'intruder_${DateTime.now().millisecondsSinceEpoch}.jpg';
    String filePath = 'intruder_images/${user.uid}/$fileName';

    Reference ref = _storage.ref().child(filePath);
    UploadTask uploadTask = ref.putFile(File(image.path));
    TaskSnapshot snapshot = await uploadTask;

    return await snapshot.ref.getDownloadURL();
  }

  // ========== SAVE TO FIRESTORE ==========
  Future<void> _saveToFirestore(String photoUrl) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('intruder_photos').add({
      'userId': user.uid,
      'userEmail': user.email,
      'photoUrl': photoUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  // ========== GET INTRUDER PHOTOS ==========
  Future<List<Map<String, dynamic>>> getIntruderPhotos() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return [];

      QuerySnapshot snapshot = await _firestore
          .collection('intruder_photos')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting photos: $e');
      return [];
    }
  }

  // ========== SHOW MESSAGE ==========
  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: Duration(seconds: 2)),
    );
  }
}
