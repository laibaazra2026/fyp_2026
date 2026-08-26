import 'package:flutter/material.dart';
import '../services/backup_restore_service.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen>
    with SingleTickerProviderStateMixin {
  final BackupRestoreService _service = BackupRestoreService();
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

  Future<void> _handleBackup() async {
    setState(() => _isLoading = true);
    bool success = await _service.backupData();
    setState(() {
      _isLoading = false;
      _statusMessage = success ? 'Backup successful ☁️' : 'Backup failed ❌';
    });
  }

  Future<void> _handleRestore() async {
    setState(() => _isLoading = true);
    var data = await _service.restoreData();
    setState(() {
      _isLoading = false;
      if (data != null) {
        _restoredContacts = data['contacts'];
        _restoredCallLogs = data['callLogs'];
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
          tabs: const [
            Tab(text: 'Restored Contacts'),
            Tab(text: 'Restored Call Logs'),
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
          if (_isLoading) const CircularProgressIndicator(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                ListView.builder(
                  itemCount: _restoredContacts.length,
                  itemBuilder: (context, index) {
                    var c = _restoredContacts[index];
                    return ListTile(
                      leading: const Icon(Icons.person, color: Colors.purple),
                      title: Text(c['name'] ?? 'Unknown'),
                      subtitle: Text(c['phone'] ?? ''),
                    );
                  },
                ),
                ListView.builder(
                  itemCount: _restoredCallLogs.length,
                  itemBuilder: (context, index) {
                    var log = _restoredCallLogs[index];
                    return ListTile(
                      leading: const Icon(Icons.call, color: Colors.teal),
                      title: Text(log['name'] ?? 'Unknown'),
                      subtitle: Text(log['number'] ?? ''),
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
