import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

class GPSScreen extends StatefulWidget {
  const GPSScreen({super.key});

  @override
  State<GPSScreen> createState() => _GPSScreenState();
}

class _GPSScreenState extends State<GPSScreen> {
  final LocationService _locationService = LocationService();
  String _locationText = 'Getting location...';
  bool _isLoading = true;
  Position? _position;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    setState(() {
      _isLoading = true;
      _locationText = 'Getting location...';
    });

    Position? position = await _locationService.getCurrentLocation();

    if (position != null) {
      setState(() {
        _position = position;
        _locationText =
            '📍 Your Device Location\n\n'
            'Latitude: ${position.latitude}\n'
            'Longitude: ${position.longitude}\n'
            'Accuracy: ${position.accuracy} meters\n'
            'Time: ${DateTime.now().toLocal()}';
        _isLoading = false;
      });
      await _locationService.saveLocation(position);
    } else {
      setState(() {
        _locationText =
            '❌ Could not get location.\n\n'
            'Please:\n'
            '1. Turn ON GPS\n'
            '2. Allow location permission\n'
            '3. Go outside for better signal\n'
            '4. Tap refresh button';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Tracking'),
        backgroundColor: Colors.purple.shade700,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _getLocation),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Loading or Icon
            _isLoading
                ? const CircularProgressIndicator()
                : Icon(
                    _position != null ? Icons.location_on : Icons.location_off,
                    size: 100,
                    color: _position != null ? Colors.green : Colors.red,
                  ),
            const SizedBox(height: 30),

            // Location Details Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  _locationText,
                  style: const TextStyle(fontSize: 16, height: 1.8),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Buttons Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _getLocation,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Location saved to Firebase!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // GPS Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                '🛰️ ${_position != null ? 'GPS Connected' : 'GPS Disconnected'}',
                style: TextStyle(
                  color: _position != null
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
