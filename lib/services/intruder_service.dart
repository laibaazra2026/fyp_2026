import 'dart:io';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class IntruderService {
  static Future<void> captureAndUploadIntruder() async {
    try {
      // 1. Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      // Select the front camera
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      // 2. Initialize the camera controller
      final CameraController controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      // 3. Take the picture silently
      XFile imageFile = await controller.takePicture();
      File file = File(imageFile.path);

      // Dispose controller immediately to free hardware
      await controller.dispose();

      // 4. Get current logged-in user ID
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("No active user session found for intruder upload.");
        return;
      }
      String userId = user.uid;

      // 5. Upload image to Firebase Storage
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

      // 6. Save document in Firestore (Matches your web portal's intruders.html query)
      await FirebaseFirestore.instance.collection('intruder_photos').add({
        'userId': userId,
        'url': downloadUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print("Intruder photo successfully captured and uploaded!");
    } catch (e) {
      print("Error capturing/uploading intruder photo: $e");
    }
  }
}
