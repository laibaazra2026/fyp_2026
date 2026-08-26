import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

class IntruderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Request Camera Permission
  static Future<bool> requestCameraPermission() async {
    PermissionStatus status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    return status.isGranted;
  }

  // 2. Monitor & Trigger on Incorrect Unlock Attempts
  Future<void> onIncorrectUnlockAttempt() async {
    try {
      bool hasPermission = await requestCameraPermission();
      if (!hasPermission) {
        print("⚠️ Camera permission denied.");
        return;
      }

      await captureAndProcessIntruder();
    } catch (e) {
      print("❌ Error handling incorrect unlock attempt: $e");
    }
  }

  // 3. Core Capture, Base64 Conversion, and Cloud Sync Logic
  Future<void> captureAndProcessIntruder() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final CameraController controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();
      XFile imageFile = await controller.takePicture();
      File file = File(imageFile.path);
      await controller.dispose();

      // STEP A: Convert image to Base64 so you can display it directly on your mobile card
      List<int> imageBytes = await file.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      print("📱 Intruder photo converted to Base64 successfully!");

      // STEP B: Get user session details
      User? user = _auth.currentUser;
      if (user == null) return;
      String userId = user.uid;

      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      String userName = 'Unknown User';
      String userEmail = user.email ?? 'No Email';

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        userName = data['name'] ?? data['fullName'] ?? 'Unknown User';
      }

      // STEP C: Upload image file to Firebase Storage for Web Portals
      String fileName = 'intruder_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(userId)
          .child('intruder_photos')
          .child(fileName);

      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // STEP D: Save to Firestore (Including Base64 for instant mobile card loading + URL for web portals)
      await _firestore.collection('intruder_photos').add({
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'url': downloadUrl,
        'imageBase64':
            base64Image, // 👈 Directly use this in your mobile UI card
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'Unresolved',
      });

      // Save to Admin Web Portal collection
      await _firestore.collection('admin_alerts').add({
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'alertType': 'INTRUDER_DETECTED',
        'imageUrl': downloadUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'Unresolved',
      });

      print(
        "☁️ Intruder photo processed with Base64 and synced to web portals!",
      );
    } catch (e) {
      print("❌ Error capturing/processing intruder photo: $e");
    }
  }
}
