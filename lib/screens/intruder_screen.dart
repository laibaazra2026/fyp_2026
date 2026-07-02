import 'package:flutter/material.dart';
import '../services/intruder_services.dart';

class IntruderScreen extends StatefulWidget {
  const IntruderScreen({super.key});

  @override
  State<IntruderScreen> createState() => _IntruderScreenState();
}

class _IntruderScreenState extends State<IntruderScreen> {
  final IntruderService _intruderService = IntruderService();
  List<Map<String, dynamic>> _photos = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);
    _photos = await _intruderService.getIntruderPhotos();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Intruder Capture'),
        backgroundColor: Colors.purple.shade700,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPhotos),
        ],
      ),
      body: Column(
        children: [
          // Capture Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                _intruderService.captureIntruderPhoto(context);
              },
              icon: const Icon(Icons.camera),
              label: const Text('Test Capture'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 14,
                ),
              ),
            ),
          ),

          // Photos Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _photos.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No intruder photos yet'),
                        Text('Tap "Test Capture" to test'),
                      ],
                    ),
                  )
                : GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _photos.length,
                    itemBuilder: (context, index) {
                      var photo = _photos[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Image.network(
                                photo['photoUrl'],
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Text(
                                photo['timestamp'] != null
                                    ? '${DateTime.fromMillisecondsSinceEpoch(photo['timestamp'].seconds * 1000).hour}:${DateTime.fromMillisecondsSinceEpoch(photo['timestamp'].seconds * 1000).minute}'
                                    : 'Unknown',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
