import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

class GPSScreen extends StatefulWidget {
  const GPSScreen({super.key});

  @override
  State<GPSScreen> createState() => _GPSScreenState();
}

class _GPSScreenState extends State<GPSScreen> {
  final LocationService _locationService = LocationService();
  late GoogleMapController _mapController;

  LatLng? _currentPosition;
  bool _isLoading = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    Position? position = await _locationService.getCurrentLocation();
    if (position != null) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _statusMessage =
            '📍 Location: ${position.latitude}, ${position.longitude}';
        _isLoading = false;
      });
      await _locationService.saveLocation(position);
    } else {
      setState(() {
        _statusMessage = '❌ Could not get location. Check GPS.';
        _isLoading = false;
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Tracking'),
        backgroundColor: Colors.purple.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Message
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            width: double.infinity,
            child: Text(
              _statusMessage,
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),

          // Map
          Expanded(
            child: _currentPosition == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Getting location...'),
                      ],
                    ),
                  )
                : GoogleMap(
                    onMapCreated: _onMapCreated,
                    initialCameraPosition: CameraPosition(
                      target: _currentPosition!,
                      zoom: 15.0,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('current'),
                        position: _currentPosition!,
                        infoWindow: const InfoWindow(
                          title: 'Current Location',
                          snippet: 'Your device is here',
                        ),
                      ),
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
