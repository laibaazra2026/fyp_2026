import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart'; // For native Android location permission popups
import 'package:permission_handler/permission_handler.dart'; // For Camera, Phone, Contacts, Storage
import '../services/security_guard_service.dart'; // Points to your services folder
import 'login_screen.dart';
import 'gps_screen.dart';
import 'subscription_screen.dart';
import 'sim_screen.dart';
import 'backup_restore_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isTheftModeActive = true;
  final User? user = FirebaseAuth.instance.currentUser;

  // 🛡️ Initialize the Security Guard Service
  final SecurityGuardService _securityGuard = SecurityGuardService();

  @override
  void initState() {
    super.initState();
    _fetchInitialTheftMode();
  }

  // Fetch initial switch UI state from Firestore on load
  Future<void> _fetchInitialTheftMode() async {
    bool active = await _securityGuard.isTheftModeActive();
    setState(() {
      _isTheftModeActive = active;
    });
  }

  // Update Theft Mode state in Firestore when toggle switch changes
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
        print('Error updating theft mode: $e');
      }
    }
  }

  // ==================== 🛡️ MODULE PERMISSION HANDLERS ====================

  // 1. GPS Tracking Permission (Triggers native Android "While using the app" / "Deny" popup)
  Future<bool> _checkAndRequestLocationPermission(BuildContext context) async {
    // Step 1: Check if global device location services are enabled
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

    // Step 2: Check app-level permissions and trigger the native Allow/Deny popup
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

    // Step 3: Handle permanently denied permissions
    if (permission == LocationPermission.deniedForever) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permissions are permanently denied. Opening settings...',
          ),
        ),
      );
      await openAppSettings();
      return false;
    }

    return true;
  }

  // 2. SIM Change Detection Permission (Triggers native phone state permission popup)
  Future<bool> _checkAndRequestSimPermission(BuildContext context) async {
    PermissionStatus status = await Permission.phone.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Phone state permission is required for SIM detection.',
          ),
        ),
      );
      return false;
    }
    return true;
  }

  // 3. Intruder Capture Permission (Triggers native camera permission popup)
  Future<bool> _checkAndRequestCameraPermission(BuildContext context) async {
    PermissionStatus cameraStatus = await Permission.camera.request();
    if (cameraStatus.isDenied || cameraStatus.isPermanentlyDenied) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera permission is required to capture intruders.'),
        ),
      );
      return false;
    }
    return true;
  }

  // 4. Backup & Restore Permissions (Triggers native contacts & storage permission popup)
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

  // =======================================================================

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
            padding: const EdgeInsets.only(right: 12.0),
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- GRADIENT THEFT MODE CARD ---
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
                    onChanged: (value) {
                      _updateTheftModeToggle(value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Subscription Banner Card
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
                          'Upgrade to unlock backups & features',
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

            // 🛡️ Protected Module Grid Cards with Native System Permission Popups
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.1,
              children: [
                // 1. GPS Tracking Module (Triggers Native Location Popup)
                _buildModuleCard(
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
                // 2. SIM Change Detection Module (Triggers Native Phone State Popup)
                _buildModuleCard(
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
                // 3. Intruder Capture Module (Triggers Native Camera Popup)
                _buildModuleCard(
                  title: 'Intruder Capture',
                  subtitle: 'Failed unlock snaps',
                  icon: Icons.camera_alt,
                  color: Colors.red,
                  onTap: () {
                    _securityGuard.runModuleIfTheftModeOn(
                      context: context,
                      moduleName: 'Intruder Capture',
                      moduleTask: () async {
                        bool hasPermission =
                            await _checkAndRequestCameraPermission(context);
                        if (hasPermission && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Camera permission granted for intruder capture!',
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
                // 4. Backup & Restore Module (Triggers Native Contacts Popup)
                _buildModuleCard(
                  title: 'Backup & Restore',
                  subtitle: 'Contacts & Call Logs ☁️',
                  icon: Icons.cloud_sync,
                  color: Colors.purple,
                  onTap: () {
                    _securityGuard.runModuleIfTheftModeOn(
                      context: context,
                      moduleName: 'Backup & Restore',
                      moduleTask: () async {
                        bool hasPermission =
                            await _checkAndRequestBackupPermissions(context);
                        if (hasPermission && context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const BackupRestoreScreen(),
                            ),
                          );
                        }
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

  Widget _buildModuleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// 👤 Profile & Settings Screen with Name Edit, Password Reset & Logout
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

    setState(() => _isLoading = true);
    try {
      await user?.updateDisplayName(newName);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .update({'name': newName});
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile name updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
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
        padding: const EdgeInsets.all(24.0),
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
