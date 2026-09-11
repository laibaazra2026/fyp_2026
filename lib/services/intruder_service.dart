import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';

class IntruderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> onIncorrectUnlockAttempt() async {
    try {
      print("📸 Starting intruder capture sequence...");
      User? user = _auth.currentUser;

      if (user == null) {
        print("❌ Intruder capture aborted: No active user session found.");
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print("❌ No cameras available on device.");
        return;
      }

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset
            .medium, // Medium resolution helps avoid low-light sensor glitches on some devices
        enableAudio: false,
      );

      await controller.initialize();

      // Fix for black images: Lock exposure and focus to let the sensor process light properly
      try {
        await controller.setExposureMode(ExposureMode.auto);
        await controller.setFocusMode(FocusMode.auto);
      } catch (e) {
        print("⚠️ Could not set auto exposure/focus modes: $e");
      }

      // Give the camera sensor enough warm-up time to calculate lighting
      await Future.delayed(const Duration(milliseconds: 1200));

      XFile image = await controller.takePicture();
      await controller.dispose();

      final appDir = await getApplicationDocumentsDirectory();
      final fileName = "intruder_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final localFile = File('${appDir.path}/$fileName');

      final imageBytes = await image.readAsBytes();
      await localFile.writeAsBytes(imageBytes);
      print("✅ Intruder photo saved locally in app at: ${localFile.path}");

      String base64Image = base64Encode(imageBytes);

      await _firestore.collection('intruder_photos').add({
        'userId': user.uid,
        'localPath': localFile.path,
        'imageBase64': base64Image,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'unresolved',
      });

      print(
        "🚨 Intruder image saved locally and logged to Firestore successfully!",
      );
    } catch (e) {
      print("❌ Error during intruder capture or conversion: $e");
    }
  }
}
