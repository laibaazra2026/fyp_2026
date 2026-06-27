import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ========== REQUEST PERMISSION ==========
  Future<bool> requestPermission() async {
    PermissionStatus status = await Permission.location.request();
    if (status.isDenied) {
      return false;
    }
    if (status.isPermanentlyDenied) {
      return false;
    }
    return true;
  }

  // ========== CHECK GPS ENABLED ==========
  Future<bool> isGpsEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // ========== GET CURRENT LOCATION ==========
  Future<Position?> getCurrentLocation() async {
    bool hasPermission = await requestPermission();
    if (!hasPermission) return null;

    bool gpsEnabled = await isGpsEnabled();
    if (!gpsEnabled) return null;

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      return position;
    } catch (e) {
      print('❌ Error getting location: $e');
      return null;
    }
  }

  // ========== SAVE LOCATION TO FIREBASE ==========
  Future<void> saveLocation(Position position) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('locations').add({
        'userId': user.uid,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('✅ Location saved to Firebase');
    } catch (e) {
      print('❌ Error saving location: $e');
    }
  }

  // ========== GET LOCATION HISTORY ==========
  Future<List<Map<String, dynamic>>> getLocationHistory() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return [];

      QuerySnapshot snapshot = await _firestore
          .collection('locations')
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
      print('❌ Error getting location history: $e');
      return [];
    }
  }
}
