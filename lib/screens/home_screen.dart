import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/sim_service.dart';
import '../services/subscription_service.dart';
import 'gps_screen.dart';
import 'intruder_screen.dart';
import 'subscription_screen.dart';
import 'set_pin_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SimService _simService = SimService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SubscriptionService _subscriptionService = SubscriptionService();
  String _simStatus = "Checking device...";
  bool _isTheftMode = false;
  bool _isLoadingTheftMode = true;
  String _currentPlan = 'free';
  bool _isLoadingPlan = true;

  @override
  void initState() {
    super.initState();
    _checkSim();
    _loadTheftModeStatus();
    _listenToTheftModeChanges();
    _loadSubscriptionPlan();
  }

  Future<void> _checkSim() async {
    await _simService.checkOnStartup(context);
    String status = await _simService.getSimStatus();
    setState(() {
      _simStatus = status;
    });
  }

  Future<void> _loadTheftModeStatus() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        setState(() {
          _isTheftMode = doc.get('isTheftModeOn') ?? false;
          _isLoadingTheftMode = false;
        });
      }
    } catch (e) {
      print('Error loading theft mode: $e');
    }
  }

  void _listenToTheftModeChanges() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _firestore.collection('users').doc(user.uid).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        bool newTheftMode = snapshot.get('isTheftModeOn') ?? false;
        if (mounted && _isTheftMode != newTheftMode) {
          setState(() {
            _isTheftMode = newTheftMode;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                newTheftMode
                    ? '🛡️ Theft Mode Enabled Remotely!'
                    : '🔓 Theft Mode Disabled',
              ),
              backgroundColor: newTheftMode ? Colors.green : Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    });
  }

  Future<void> _loadSubscriptionPlan() async {
    String plan = await _subscriptionService.getCurrentPlan();
    setState(() {
      _currentPlan = plan;
      _isLoadingPlan = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Device Protection',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.purple.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Theft Mode Toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isTheftMode
                      ? [Colors.red, Colors.red.shade700]
                      : [Colors.green, Colors.green.shade700],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    _isTheftMode ? Icons.security : Icons.security_outlined,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isTheftMode
                              ? '🛡️ Theft Mode ON'
                              : '🔓 Theft Mode OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _isTheftMode
                              ? 'Your device is being monitored'
                              : 'Enable to protect your device',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isTheftMode,
                    onChanged: (value) async {
                      setState(() {
                        _isTheftMode = value;
                      });

                      User? user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        await _firestore
                            .collection('users')
                            .doc(user.uid)
                            .update({'isTheftModeOn': value});
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _isTheftMode
                                ? '✅ Theft Mode Activated!'
                                : '❌ Theft Mode Deactivated',
                          ),
                          backgroundColor: _isTheftMode
                              ? Colors.green
                              : Colors.red,
                        ),
                      );
                    },
                    activeColor: Colors.white,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.grey.shade400,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Subscription Plan Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _currentPlan != 'free'
                    ? Colors.green.shade50
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _currentPlan != 'free'
                      ? Colors.green.shade200
                      : Colors.blue.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _currentPlan != 'free' ? Icons.star : Icons.star_border,
                    color: _currentPlan != 'free' ? Colors.green : Colors.blue,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentPlan != 'free'
                              ? '🌟 Premium Plan'
                              : 'Free Plan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _currentPlan != 'free'
                                ? Colors.green.shade700
                                : Colors.blue.shade700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _currentPlan != 'free'
                              ? 'All premium features are active'
                              : 'Upgrade to Premium for advanced features',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _currentPlan != 'free'
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const SubscriptionScreen(),
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentPlan != 'free'
                          ? Colors.grey
                          : Colors.purple.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _currentPlan != 'free' ? 'Active' : 'Upgrade',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Device Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.devices,
                      color: Colors.orange.shade700,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Device Status',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _simStatus,
                          style: TextStyle(
                            color: _simStatus.contains('secure')
                                ? Colors.green
                                : Colors.orange,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      bool changed = await _simService.checkDeviceChanged();
                      if (changed) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('⚠️ Device Changed! Alert saved.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Device is secure'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                      String status = await _simService.getSimStatus();
                      setState(() {
                        _simStatus = status;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                    ),
                    child: const Text(
                      'Check Device',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Features Grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: [
                  _FeatureCard(
                    icon: Icons.gps_fixed,
                    title: 'GPS Tracking',
                    subtitle: 'Track your device',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: ((context) => const GPSScreen()),
                        ),
                      );
                    },
                  ),
                  _FeatureCard(
                    icon: Icons.sim_card,
                    title: 'SIM/Device Alert',
                    subtitle: _simStatus,
                    color: Colors.orange,
                    onTap: () async {
                      bool changed = await _simService.checkDeviceChanged();
                      if (changed) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('⚠️ Device Changed! Alert saved.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        String status = await _simService.getSimStatus();
                        setState(() {
                          _simStatus = status;
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Device is secure'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                  ),
                  _FeatureCard(
                    icon: Icons.camera_alt,
                    title: 'Intruder Capture',
                    subtitle: 'Capture intruder',
                    color: Colors.red,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const IntruderScreen(),
                        ),
                      );
                    },
                  ),
                  _FeatureCard(
                    icon: Icons.cloud_upload,
                    title: 'Backup & Restore',
                    subtitle: 'Premium feature',
                    color: Colors.purple,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Backup Feature - Premium Only'),
                        ),
                      );
                    },
                  ),
                  // ✅ NEW: Set Lock PIN Card
                  _FeatureCard(
                    icon: Icons.lock_outline,
                    title: 'Set Lock PIN',
                    subtitle: 'Custom lock PIN',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SetPinScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== FEATURE CARD WIDGET ==========
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
