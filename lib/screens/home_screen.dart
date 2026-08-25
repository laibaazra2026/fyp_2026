import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/sim_service.dart';
import '../services/subscription_service.dart';
import '../services/command_service.dart';
import 'gps_screen.dart';
import 'intruder_screen.dart';
import 'subscription_screen.dart';
import 'backup_restore_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SimService _simService = SimService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SubscriptionService _subscriptionService = SubscriptionService();
  final CommandService _commandService = CommandService();

  String _simStatus = "Checking device...";
  bool _isTheftMode = false;
  String _currentPlan = 'free';

  @override
  void initState() {
    super.initState();
    _checkSim();
    _loadTheftModeStatus();
    _listenToTheftModeChanges();
    _loadSubscriptionPlan().then((_) {
      _checkAndPromptFreeUser();
    });

    // Start listening for remote commands (lock, ring, etc.)
    _commandService.listenForCommands(context);
  }

  // Automatically prompt free users after login to view subscription options
  Future<void> _checkAndPromptFreeUser() async {
    if (_currentPlan == 'free') {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && _currentPlan == 'free') {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                '🌟 Unlock Full Protection',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: const Text(
                'Explore our Free, Premium, and Family tiers to get advanced remote commands and backup features. Swipe through to check them out!',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Later',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SubscriptionScreen(),
                      ),
                    ).then((_) => _loadSubscriptionPlan());
                  },
                  child: const Text(
                    'View All Plans',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        }
      });
    }
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
    });
  }

  // Strict Guard: Blocks any security module if Theft Mode is OFF
  void _guardAgainstTheftMode(VoidCallback action, String moduleName) {
    if (!_isTheftMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ $moduleName blocked: Please turn ON Theft Mode first!',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return; // Stop module execution completely
    }
    action(); // Run if Theft Mode is ON
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Device Protection Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple.shade700,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. Theft Mode Toggle Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isTheftMode
                      ? [Colors.red.shade600, Colors.red.shade800]
                      : [Colors.green.shade600, Colors.green.shade800],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                              ? '🛡️ Theft Mode is ACTIVE'
                              : '🔓 Theft Mode is OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isTheftMode
                              ? 'All security modules are running'
                              : 'Turn on to enable security features',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
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

            const SizedBox(height: 16),

            // 2. Subscription Plan Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentPlan == 'family'
                              ? '🌟 Family / Pro Tier'
                              : _currentPlan == 'premium'
                              ? '⭐ Premium Tier'
                              : 'Free Tier Plan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _currentPlan != 'free'
                                ? Colors.green.shade700
                                : Colors.blue.shade700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          _currentPlan != 'free'
                              ? 'Advanced features unlocked'
                              : 'Upgrade to unlock backups & commands',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SubscriptionScreen(),
                        ),
                      ).then((_) => _loadSubscriptionPlan());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      _currentPlan != 'free' ? 'Manage' : 'Upgrade',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Section Header
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Security Modules',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 3. Features Grid (Properly Aligned & Guarded)
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.15,
                children: [
                  // GPS Tracking Module
                  _FeatureCard(
                    icon: Icons.gps_fixed,
                    title: 'GPS Tracking',
                    subtitle: 'Live Map Location',
                    color: Colors.blue,
                    onTap: () {
                      _guardAgainstTheftMode(() {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: ((context) => const GPSScreen()),
                          ),
                        );
                      }, 'GPS Tracking');
                    },
                  ),

                  // SIM / Device Alert Module
                  _FeatureCard(
                    icon: Icons.sim_card,
                    title: 'SIM/Device Alert',
                    subtitle: _simStatus,
                    color: Colors.orange,
                    onTap: () async {
                      _guardAgainstTheftMode(() async {
                        bool changed = await _simService.detectSimChange(
                          context,
                        );
                        if (changed) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '⚠️ SIM/Device Changed! Alert saved.',
                              ),
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
                      }, 'SIM/Device Alert');
                    },
                  ),

                  // Intruder Capture Module
                  _FeatureCard(
                    icon: Icons.camera_alt,
                    title: 'Intruder Capture',
                    subtitle: 'Failed unlock snaps',
                    color: Colors.red,
                    onTap: () {
                      _guardAgainstTheftMode(() {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const IntruderScreen(),
                          ),
                        );
                      }, 'Intruder Capture');
                    },
                  ),

                  // Protected Backup & Restore Module (Family/Pro Tier Guard)
                  _FeatureCard(
                    icon: Icons.cloud_upload,
                    title: 'Media Backup',
                    subtitle: _currentPlan == 'family'
                        ? 'Unlocked'
                        : 'Family Tier Only',
                    color: Colors.purple,
                    onTap: () async {
                      _guardAgainstTheftMode(() async {
                        String plan = await _subscriptionService
                            .getCurrentPlan();
                        if (plan == 'family') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const BackupRestoreScreen(),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🔒 Requires Family / Pro Tier'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SubscriptionScreen(),
                            ),
                          ).then((_) {
                            _loadSubscriptionPlan();
                          });
                        }
                      }, 'Media Backup');
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
      elevation: 3,
      shadowColor: Colors.black12,
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 30, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
