import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

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
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      // Ensure exposure and focus are set to auto for clear lighting
      try {
        await controller.setFocusMode(FocusMode.auto);
        await controller.setExposureMode(ExposureMode.auto);
      } catch (e) {
        print("⚠️ Could not set camera focus/exposure modes: $e");
      }

      // CRITICAL FIX: Increased stabilization delay to 1200ms
      // to give physical camera hardware enough time to process light and avoid black frames.
      await Future.delayed(const Duration(milliseconds: 1200));

      XFile image = await controller.takePicture();
      await controller.dispose();

      final originalBytes = await image.readAsBytes();

      // Safety check: if bytes are empty or black, retry or fallback
      if (originalBytes.isEmpty) {
        print("❌ Captured image buffer is empty.");
        return;
      }

      img.Image? decodedImage = img.decodeImage(originalBytes);
      late Uint8List imageBytes;

      if (decodedImage != null) {
        int sensorOrientation = frontCamera.sensorOrientation;

        if (sensorOrientation == 90) {
          decodedImage = img.copyRotate(decodedImage, angle: 90);
        } else if (sensorOrientation == 270) {
          decodedImage = img.copyRotate(decodedImage, angle: 270);
        } else if (sensorOrientation == 180) {
          decodedImage = img.copyRotate(decodedImage, angle: 180);
        }

        // Mirror the image horizontally for a natural front-camera selfie view
        decodedImage = img.flipHorizontal(decodedImage);

        imageBytes = Uint8List.fromList(
          img.encodeJpg(decodedImage, quality: 85),
        );
      } else {
        imageBytes = originalBytes;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final fileName = "intruder_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final localFile = File('${appDir.path}/$fileName');

      await localFile.writeAsBytes(imageBytes);
      print("✅ Intruder photo saved locally at: ${localFile.path}");

      String base64Image = base64Encode(imageBytes);

      await _firestore.collection('intruder_photos').add({
        'userId': user.uid,
        'localPath': localFile.path,
        'imageBase64': base64Image,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'unresolved',
      });

      print(
        "🚨 Intruder image captured successfully and uploaded to Firestore!",
      );
    } catch (e) {
      print("❌ Error during intruder capture or conversion: $e");
    }
  }
}
