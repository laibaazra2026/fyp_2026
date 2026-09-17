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
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      // Fix for dark/black images: Maximize exposure offset in low light
      try {
        double maxExposure = await controller.getMaxExposureOffset();
        await controller.setExposureOffset(maxExposure);
        await controller.setFocusMode(FocusMode.auto);
      } catch (e) {
        print("⚠️ Could not set exposure/focus modes: $e");
      }

      // Give the camera sensor enough warm-up time to calculate lighting
      await Future.delayed(const Duration(milliseconds: 1200));

      XFile image = await controller.takePicture();
      await controller.dispose();

      final originalBytes = await image.readAsBytes();
      img.Image? decodedImage = img.decodeImage(originalBytes);

      late Uint8List imageBytes;

      if (decodedImage != null) {
        // Fix rotation and mirror the front camera selfie properly
        int sensorOrientation = frontCamera.sensorOrientation;
        if (sensorOrientation != 0) {
          decodedImage = img.copyRotate(decodedImage, angle: sensorOrientation);
        }

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
        "🚨 Intruder image saved, straightened, brightened, and logged successfully!",
      );
    } catch (e) {
      print("❌ Error during intruder capture or conversion: $e");
    }
  }
}
