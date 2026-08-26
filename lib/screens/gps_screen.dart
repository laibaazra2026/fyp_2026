import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

class GpsScreen extends StatefulWidget {
  const GpsScreen({super.key});

  @override
  State<GpsScreen> createState() => _GpsScreenState();
}

class _GpsScreenState extends State<GpsScreen> {
  final LocationService _locationService = LocationService();

  GoogleMapController? _mapController;
  bool _isLoading = true;
  String _statusMessage = 'Requesting location permissions...';

  // Default fallback location
  LatLng _currentLocation = const LatLng(33.6844, 73.0479);
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _fetchAndSavePosition();
  }

  Future<void> _fetchAndSavePosition() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking location permissions & GPS...';
    });

    try {
      Position? position = await _locationService.getCurrentLocation();

      if (position == null) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Location permission denied or GPS is turned off.';
        });
        return;
      }

      setState(() => _statusMessage = 'Saving location to cloud...');

      await _locationService.saveLocation(position);

      LatLng liveLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLocation = liveLatLng;
        _isLoading = false;

        _markers = {
          Marker(
            markerId: const MarkerId('device_location'),
            position: liveLatLng,
            infoWindow: const InfoWindow(
              title: 'Protected Device',
              snippet: 'Live GPS Coordinates Location',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueViolet,
            ),
          ),
        };
      });

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: liveLatLng, zoom: 16.0),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error getting location: $e';
      });
    }
  }

  Future<void> _zoomIn() async {
    if (_mapController != null) {
      _mapController!.animateCamera(CameraUpdate.zoomIn());
    }
  }

  Future<void> _zoomOut() async {
    if (_mapController != null) {
      _mapController!.animateCamera(CameraUpdate.zoomOut());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'GPS Map Tracking',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF841EA0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _fetchAndSavePosition,
            tooltip: 'Refresh Location',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF841EA0)),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage,
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation,
                    zoom: 15.0,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  compassEnabled: true,
                  zoomControlsEnabled: false,
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                  },
                ),

                // Professional Floating Zoom In / Out Controls (+ / -)
                Positioned(
                  right: 16,
                  bottom: 110,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton(
                        heroTag: 'map_zoom_in',
                        mini: true,
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF841EA0),
                        elevation: 4,
                        onPressed: _zoomIn,
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: 'map_zoom_out',
                        mini: true,
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF841EA0),
                        elevation: 4,
                        onPressed: _zoomOut,
                        child: const Icon(Icons.remove),
                      ),
                    ],
                  ),
                ),

                // Floating Status Card at the Bottom
                Positioned(
                  bottom: 24,
                  left: 24,
                  right: 24,
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF841EA0).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.gps_fixed,
                              color: Color(0xFF841EA0),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Live Tracking Active & Saved',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF841EA0),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Lat: ${_currentLocation.latitude.toStringAsFixed(4)}, Lng: ${_currentLocation.longitude.toStringAsFixed(4)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _fetchAndSavePosition,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF841EA0),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Update',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
