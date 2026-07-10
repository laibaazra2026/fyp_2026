import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

class IntruderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  static const MethodChannel _channel = MethodChannel(
    'com.example.device_protection/lock',
  );

  int _wrongAttempts = 0;

  // ========== RESET ATTEMPTS ==========
  void resetAttempts() {
    _wrongAttempts = 0;
  }

  // ========== START LISTENING ==========
  void startListening() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'capturePhoto') {
        await captureIntruderPhoto();
      }
    });
  }

  // ========== RECORD WRONG ATTEMPT ==========
  Future<void> recordWrongAttempt() async {
    _wrongAttempts++;
    print('⚠️ Wrong attempt $_wrongAttempts');

    if (_wrongAttempts >= 3) {
      print('📸 3 wrong attempts! Capturing intruder photo...');
      await captureIntruderPhoto();
      resetAttempts();
    }
  }

  // ========== CAPTURE INTRUDER PHOTO ==========
  Future<void> captureIntruderPhoto() async {
    try {
      // Check camera permission
      PermissionStatus status = await Permission.camera.request();
      if (!status.isGranted) {
        print('❌ Camera permission denied');
        return;
      }

      // Capture image from front camera
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 50,
      );

      if (image == null) {
        print('❌ No image captured');
        return;
      }

      // Convert to Base64
      File imageFile = File(image.path);
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      // Save to Firestore
      await _saveToFirestore(base64Image);

      print('📸 Intruder photo captured and saved!');
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  // ========== SAVE TO FIRESTORE ==========
  Future<void> _saveToFirestore(String base64Image) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('intruder_photos').add({
        'userId': user.uid,
        'userEmail': user.email,
        'imageBase64': base64Image,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      print('✅ Intruder photo saved to Firestore');
    } catch (e) {
      print('❌ Error saving to Firestore: $e');
    }
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
          .limit(20)
          .get();

      return snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('❌ Error getting photos: $e');
      return [];
    }
  }
}
