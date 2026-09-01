import 'package:device_protection/screens/intruder_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/command_service.dart';
import '../services/security_guard_service.dart';
import '../utils/feature_access_card.dart';
import 'login_screen.dart';
import 'gps_screen.dart';
import 'subscription_screen.dart';
import 'sim_screen.dart';
import 'backup_restore_screen.dart';
import '../services/subscription_service.dart';
import '../services/backup_restore_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isTheftModeActive = false;
  final SubscriptionService _subscriptionService = SubscriptionService();

  final User? user = FirebaseAuth.instance.currentUser;
  final SecurityGuardService _securityGuard = SecurityGuardService();

  @override
  void initState() {
    super.initState();
    CommandService().listenForCommands(context);

    _listenToTheftModeChanges();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showUpgradePopupIfNeeded();
    });
  }

  void _listenToTheftModeChanges() {
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists && mounted) {
            var data = snapshot.data() as Map<String, dynamic>?;
            setState(() {
              _isTheftModeActive = data?['isTheftModeOn'] ?? false;
            });
          }
        });
  }

  Future<void> _updateTheftModeToggle(bool value) async {
    setState(() {
      _isTheftModeActive = value;
    });

    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user!.uid).set(
          {'isTheftModeOn': value, 'theftMode': value},
          SetOptions(merge: true),
        );
      } catch (e) {
        debugPrint('Error updating theft mode: $e');
      }
    }
  }

  Future<void> _handleBackupCardTap() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF841EA0)),
      ),
    );

    try {
      String currentPlan = await _subscriptionService.getCurrentPlan();
      Navigator.of(context).pop();

      if (currentPlan == 'free') {
        _showProFeatureDialog();
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BackupRestoreScreen()),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      _showProFeatureDialog();
    }
  }

  void _showProFeatureDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pro Feature'),
        content: const Text(
          'Backup & Restore is a Pro feature. Upgrade now to unlock it instantly!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF841EA0),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionScreen(),
                ),
              );
            },
            child: const Text(
              'View Plans',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpgradePopupIfNeeded() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(22),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: Colors.purple.shade700,
                  size: 36,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Unlock Protection! 🚀',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                'You are on Free Tier. Upgrade to Pro to unlock '
                'Backup & Restore and Remote Commands.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SubscriptionScreen(),
                      ),
                    );
                  },

                  child: const Text(
                    'Upgrade Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Maybe Later',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _checkSubscriptionAndProceed({
    required BuildContext context,
    required String featureName,
    required VoidCallback onSubscribed,
  }) async {
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.purple),
        );
      },
    );

    try {
      String currentPlan = await _subscriptionService.getCurrentPlan();

      if (!context.mounted) return;

      Navigator.pop(context);

      if (currentPlan.toLowerCase() != 'free') {
        onSubscribed();
      } else {
        _showSubscriptionRequiredDialog(context, featureName);
      }
    } catch (e) {
      if (!context.mounted) return;

      Navigator.pop(context);

      _showSubscriptionRequiredDialog(context, featureName);
    }
  }

  void _showSubscriptionRequiredDialog(
    BuildContext context,
    String featureName,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.lock, color: Colors.purple.shade700),
              const SizedBox(width: 8),
              const Text('Pro Feature'),
            ],
          ),
          content: Text(
            '$featureName is a Pro feature. '
            'Upgrade now to unlock it instantly!',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SubscriptionScreen(),
                  ),
                );
              },
              child: const Text(
                'View Plans',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _checkAndRequestLocationPermission(BuildContext context) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (!context.mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please turn on your device location/GPS services.'),
        ),
      );

      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        if (!context.mounted) return false;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission was denied.')),
        );

        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!context.mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permissions are permanently denied. '
            'Opening settings...',
          ),
        ),
      );

      await openAppSettings();

      return false;
    }

    return true;
  }

  Future<bool> _checkAndRequestSimPermission(BuildContext context) async {
    PermissionStatus status = await Permission.phone.request();

    if (status.isDenied || status.isPermanentlyDenied) {
      if (!context.mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Phone state permission is required '
            'for SIM detection.',
          ),
        ),
      );

      return false;
    }

    return true;
  }

  Future<bool> _checkAndRequestCameraPermission(BuildContext context) async {
    PermissionStatus cameraStatus = await Permission.camera.request();

    if (cameraStatus.isDenied || cameraStatus.isPermanentlyDenied) {
      if (!context.mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Camera permission is required '
            'to capture intruders.',
          ),
        ),
      );

      return false;
    }

    return true;
  }

  Future<bool> _checkAndRequestBackupPermissions(BuildContext context) async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.contacts,
      Permission.storage,
    ].request();

    if (statuses[Permission.contacts] != PermissionStatus.granted) {
      if (!context.mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contacts permission is required for backups.'),
        ),
      );

      return false;
    }

    return true;
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? photoUrl = user?.photoURL;

    final String displayName =
        user?.displayName ?? user?.email?.split('@')[0] ?? 'User';

    final String email = user?.email ?? 'No email';

    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      appBar: AppBar(
        backgroundColor: Colors.purple.shade700,
        elevation: 0,

        title: const Text(
          'Home Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),

        iconTheme: const IconThemeData(color: Colors.white),

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.purple.shade200,
                backgroundImage: photoUrl != null
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl == null
                    ? Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),

      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Colors.purple.shade700),

              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: photoUrl != null
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl == null
                    ? Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          color: Colors.purple.shade700,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),

              accountName: Text(
                displayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),

              accountEmail: Text(email),

              onDetailsPressed: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.star, color: Colors.amber),
              title: const Text('Subscription & Plans'),
              onTap: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SubscriptionScreen(),
                  ),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.settings, color: Colors.grey),
              title: const Text('Settings & Profile'),
              onTap: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
            ),

            const Spacer(),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => _logout(context),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),

              width: double.infinity,

              padding: const EdgeInsets.all(20),

              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isTheftModeActive
                      ? [const Color(0xFF2E7D32), Colors.teal.shade500]
                      : [Colors.red.shade800, Colors.deepOrange.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),

                borderRadius: BorderRadius.circular(20),

                boxShadow: [
                  BoxShadow(
                    color: (_isTheftModeActive ? Colors.green : Colors.red)
                        .withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),

              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),

                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),

                    child: Icon(
                      _isTheftModeActive
                          ? Icons.security
                          : Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isTheftModeActive
                              ? 'Theft Mode is ACTIVE'
                              : 'Theft Mode is OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          _isTheftModeActive
                              ? 'All security modules are fully running'
                              : 'Tap switch to enable device protection',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Switch(
                    value: _isTheftModeActive,
                    activeColor: Colors.white,
                    activeTrackColor: Colors.green.shade900,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.red.shade900,
                    onChanged: _updateTheftModeToggle,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),

              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade200),
              ),

              child: Row(
                children: [
                  Icon(
                    Icons.star_border,
                    color: Colors.blue.shade700,
                    size: 28,
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Free Tier Plan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),

                        Text(
                          'Upgrade to unlock Backup & Remote Commands',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SubscriptionScreen(),
                        ),
                      );
                    },

                    child: const Text(
                      'Upgrade',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Security Modules',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 2,

              shrinkWrap: true,

              physics: const NeverScrollableScrollPhysics(),

              crossAxisSpacing: 16,

              mainAxisSpacing: 16,

              // Keeps the cards square
              childAspectRatio: 1.0,

              children: [
                FeatureAccessCard(
                  title: 'GPS Tracking',
                  subtitle: 'Live Map Location',
                  icon: Icons.my_location,
                  color: Colors.blue,

                  onTap: () {
                    _securityGuard.runModuleIfTheftModeOn(
                      context: context,
                      moduleName: 'GPS Tracking',

                      moduleTask: () async {
                        bool hasPermission =
                            await _checkAndRequestLocationPermission(context);

                        if (hasPermission && context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const GpsScreen(),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),

                FeatureAccessCard(
                  title: 'SIM/Device Alert',
                  subtitle: 'Tap to check security',
                  icon: Icons.sim_card,
                  color: Colors.orange,

                  onTap: () {
                    _securityGuard.runModuleIfTheftModeOn(
                      context: context,
                      moduleName: 'SIM Detection',

                      moduleTask: () async {
                        bool hasPermission =
                            await _checkAndRequestSimPermission(context);

                        if (hasPermission && context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SimScreen(),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),

                FeatureAccessCard(
                  title: 'Intruder Capture',
                  subtitle: 'Failed unlock snaps',
                  icon: Icons.camera_alt,
                  color: Colors.red,
                  isLocked: false,
                  onTap: () {
                    _securityGuard.runModuleIfTheftModeOn(
                      context: context,
                      moduleName: 'Intruder Capture',

                      moduleTask: () async {
                        bool hasPermission =
                            await _checkAndRequestCameraPermission(context);

                        if (hasPermission && context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const IntruderScreen(),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),

                FeatureAccessCard(
                  title: 'Backup & Restore',
                  subtitle: 'Contacts & Call Logs ☁️',
                  icon: Icons.cloud_sync,
                  color: Colors.purple,

                  isLocked: true,

                  onTap: () {
                    _checkSubscriptionAndProceed(
                      context: context,
                      featureName: 'Backup & Restore',

                      onSubscribed: () async {
                        _securityGuard.runModuleIfTheftModeOn(
                          context: context,
                          moduleName: 'Backup & Restore',

                          moduleTask: () async {
                            bool hasPermission =
                                await _checkAndRequestBackupPermissions(
                                  context,
                                );

                            if (hasPermission && context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const BackupRestoreScreen(),
                                ),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  late TextEditingController _nameController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: user?.displayName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateProfileName() async {
    String newName = _nameController.text.trim();

    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name cannot be empty.'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await user?.updateDisplayName(newName);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .update({'name': newName});

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile name updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating name: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resetPassword() async {
    if (user?.email == null) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent! Check your inbox.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile & Settings',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.purple.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 10),

            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.purple.shade200,

              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : null,

              child: user?.photoURL == null
                  ? Text(
                      user?.email != null && user!.email!.isNotEmpty
                          ? user!.email![0].toUpperCase()
                          : 'U',

                      style: TextStyle(
                        fontSize: 32,
                        color: Colors.purple.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),

            const SizedBox(height: 12),

            Text(
              user?.email ?? 'No email',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),

            const SizedBox(height: 30),

            TextField(
              controller: _nameController,

              decoration: InputDecoration(
                labelText: 'Display Name',

                prefixIcon: const Icon(Icons.person, color: Colors.purple),

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,

                  padding: const EdgeInsets.symmetric(vertical: 14),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),

                onPressed: _isLoading ? null : _updateProfileName,

                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Update Profile Name',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 24),

            const Divider(),

            const SizedBox(height: 10),

            ListTile(
              leading: const Icon(Icons.lock_reset, color: Colors.purple),

              title: const Text('Reset Password'),

              subtitle: const Text('Send password reset email'),

              trailing: const Icon(Icons.arrow_forward_ios, size: 16),

              onTap: _resetPassword,
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),

              title: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),

              subtitle: const Text('Sign out from your account'),

              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }
}
