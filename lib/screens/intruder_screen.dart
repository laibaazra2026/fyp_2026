import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';

class IntruderScreen extends StatefulWidget {
  const IntruderScreen({Key? key}) : super(key: key);

  @override
  State<IntruderScreen> createState() => _IntruderScreenState();
}

class _IntruderScreenState extends State<IntruderScreen> {
  static const platform = MethodChannel('device_protection/admin');

  @override
  void initState() {
    super.initState();
    _listenForRemoteLocks();
  }

  void _listenForRemoteLocks() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('device_commands')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) async {
          if (snapshot.exists) {
            final data = snapshot.data();
            if (data != null && data['lockRequested'] == true) {
              try {
                await platform.invokeMethod('lockDevice');
                await FirebaseFirestore.instance
                    .collection('device_commands')
                    .doc(user.uid)
                    .update({
                      'lockRequested': false,
                      'lastLockedAt': FieldValue.serverTimestamp(),
                    });
              } catch (e) {
                print("❌ Remote lock failed: $e");
              }
            }
          }
        });
  }

  Future<void> _enableDeviceAdmin(BuildContext context) async {
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Camera permission is required.")),
        );
      }
      return;
    }

    try {
      await platform.invokeMethod('enableAdmin');
    } on PlatformException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to open admin settings: ${e.message}"),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Intruder Gallery & Security'),
        backgroundColor: const Color(0xFF841EA0),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF841EA0).withOpacity(0.1),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF841EA0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _enableDeviceAdmin(context),
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text(
                'Activate Device Admin Permission',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: user == null
                ? const Center(
                    child: Text('Please log in to view intruder records.'),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('intruder_photos')
                        .where('userId', isEqualTo: user.uid)
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error loading gallery: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'No intruders detected yet!',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        );
                      }

                      final docs = snapshot.data!.docs;

                      return GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.75,
                            ),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data =
                              docs[index].data() as Map<String, dynamic>;
                          final String? base64String = data['imageBase64'];

                          var rawTimestamp = data['timestamp'];
                          String formattedTime = 'Unknown time';
                          if (rawTimestamp is Timestamp) {
                            formattedTime = rawTimestamp
                                .toDate()
                                .toString()
                                .split('.')[0];
                          }

                          return Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: (() {
                                    if (base64String == null ||
                                        base64String.isEmpty) {
                                      return Container(
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: Text('No image'),
                                        ),
                                      );
                                    }

                                    try {
                                      String cleanedString = base64String
                                          .replaceAll('\n', '')
                                          .replaceAll('\r', '')
                                          .trim();

                                      if (cleanedString.contains(',')) {
                                        cleanedString = cleanedString
                                            .split(',')
                                            .last;
                                      }

                                      return Image.memory(
                                        base64Decode(cleanedString),
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                                  color: Colors.grey[300],
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.broken_image,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                      );
                                    } catch (e) {
                                      return Container(
                                        color: Colors.red[100],
                                        child: Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(
                                              'Decode Error: $e',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.red,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  }()),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.person_outline,
                                            size: 14,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              user.email ?? 'Account User',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.access_time,
                                            size: 14,
                                            color: Colors.red,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              formattedTime,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.black54,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
