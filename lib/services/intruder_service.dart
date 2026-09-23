import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:geolocator/geolocator.dart';
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

      // 1. Fetch current GPS location coordinates
      Position? position;
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always) {
            position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );
            print(
              "📍 Intruder GPS Location captured: Lat ${position.latitude}, Lng ${position.longitude}",
            );
          }
        }
      } catch (e) {
        print("⚠️ Could not fetch GPS location: $e");
      }

      // 2. Camera setup and image capture
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

      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (e) {
        print("⚠️ Could not set focus mode: $e");
      }

      await Future.delayed(const Duration(milliseconds: 800));

      XFile image = await controller.takePicture();
      await controller.dispose();

      final originalBytes = await image.readAsBytes();
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

      // 3. Package all intruder security data together
      final intruderData = {
        'userId': user.uid,
        'userEmail': user.email ?? 'Unknown',
        'localPath': localFile.path,
        'imageBase64': base64Image,
        'latitude': position?.latitude,
        'longitude': position?.longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'unresolved',
      };

      // 4. Log to user's personal intruder collection
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('intruder_logs')
          .add(intruderData);

      // 5. Log to global collection for Admin Portal visibility
      await _firestore.collection('all_intruder_logs').add(intruderData);

      // (Optional legacy collection sync)
      await _firestore.collection('intruder_photos').add(intruderData);

      print(
        "🚨 Intruder photo, GPS coordinates, and logs successfully saved & synced to Firebase!",
      );
    } catch (e) {
      print("❌ Error during intruder capture or location logging: $e");
    }
  }
}
