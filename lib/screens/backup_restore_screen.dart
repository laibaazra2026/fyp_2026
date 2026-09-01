import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/backup_restore_service.dart';
import '../services/subscription_service.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen>
    with SingleTickerProviderStateMixin {
  final BackupRestoreService _service = BackupRestoreService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  late TabController _tabController;
  bool _isLoading = false;
  String _statusMessage = '';

  List<dynamic> _restoredContacts = [];
  List<dynamic> _restoredCallLogs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<bool> _checkIfUserIsUpgraded() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('DEBUG: No authenticated user found.');
        return false;
      }

      String plan = await _subscriptionService.getCurrentPlan();
      print('DEBUG: Current subscription plan is: $plan');

      return plan != 'free' && plan.isNotEmpty;
    } catch (e) {
      print('❌ Error checking subscription plan: $e');
      return false;
    }
  }

  // 2️⃣ Full Backup Flow
  Future<void> _handleBackup() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking subscription status...';
    });

    bool isUpgraded = await _checkIfUserIsUpgraded();
    if (!isUpgraded) {
      setState(() {
        _isLoading = false;
        _statusMessage =
            'Access Denied: Please upgrade your plan to use Cloud Backup ❌';
      });
      return;
    }

    setState(() => _statusMessage = 'Requesting permissions...');
    Map<Permission, PermissionStatus> statuses = await [
      Permission.contacts,
      Permission.phone,
    ].request();

    if (statuses[Permission.contacts]!.isGranted &&
        statuses[Permission.phone]!.isGranted) {
      setState(() => _statusMessage = 'Uploading backup to cloud...');
      bool success = await _service.backupData();

      setState(() {
        _isLoading = false;
        _statusMessage = success ? 'Backup successful! ☁️' : 'Backup failed ❌';
      });
    } else {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Permissions denied. Cannot backup contacts/logs ❌';
      });

      if (statuses[Permission.contacts]!.isPermanentlyDenied ||
          statuses[Permission.phone]!.isPermanentlyDenied) {
        openAppSettings();
      }
    }
  }

  Future<void> _handleRestore() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking subscription status...';
    });

    bool isUpgraded = await _checkIfUserIsUpgraded();
    if (!isUpgraded) {
      setState(() {
        _isLoading = false;
        _statusMessage =
            'Access Denied: Please upgrade your plan to restore data ❌';
      });
      return;
    }

    setState(() => _statusMessage = 'Requesting contact permissions...');
    var contactStatus = await Permission.contacts.request();
    if (!contactStatus.isGranted) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Contacts permission required to restore ❌';
      });
      return;
    }

    setState(() => _statusMessage = 'Fetching data from cloud...');
    var data = await _service.restoreData();

    setState(() {
      _isLoading = false;
      if (data != null) {
        _restoredContacts = data['contacts'] ?? [];
        _restoredCallLogs = data['callLogs'] ?? [];
        _statusMessage =
            'Restored ${_restoredContacts.length} contacts and ${_restoredCallLogs.length} call logs! ✅';
      } else {
        _statusMessage = 'Restore failed or no backup found ❌';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cloud Backup & Restore',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.purple.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'Contacts (${_restoredContacts.length})'),
            Tab(text: 'Call Logs (${_restoredCallLogs.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_statusMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleBackup,
                  icon: const Icon(Icons.cloud_upload, color: Colors.white),
                  label: const Text(
                    'Backup Now',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleRestore,
                  icon: const Icon(Icons.cloud_download, color: Colors.white),
                  label: const Text(
                    'Restore Data',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _restoredContacts.isEmpty
                    ? const Center(
                        child: Text('No contacts loaded or restored yet.'),
                      )
                    : ListView.builder(
                        itemCount: _restoredContacts.length,
                        itemBuilder: (context, index) {
                          var c = _restoredContacts[index];
                          return ListTile(
                            leading: const Icon(
                              Icons.person,
                              color: Colors.purple,
                            ),
                            title: Text(c['name'] ?? 'Unknown'),
                            subtitle: Text(c['phone'] ?? ''),
                          );
                        },
                      ),

                _restoredCallLogs.isEmpty
                    ? const Center(
                        child: Text('No call logs loaded or restored yet.'),
                      )
                    : ListView.builder(
                        itemCount: _restoredCallLogs.length,
                        itemBuilder: (context, index) {
                          var log = _restoredCallLogs[index];
                          return ListTile(
                            leading: const Icon(Icons.call, color: Colors.teal),
                            title: Text(log['name'] ?? 'Unknown'),
                            subtitle: Text(
                              '${log['number'] ?? ''} • ${log['type'] ?? ''}',
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
