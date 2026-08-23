import 'package:flutter/material.dart';
import '../services/backup_restore_service.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final BackupRestoreService _service = BackupRestoreService();
  bool _isLoading = false;
  String _statusMessage = 'Tap backup to sync your contacts & call logs.';

  List<Map<String, dynamic>> _restoredContacts = [];
  List<Map<String, dynamic>> _restoredCalls = [];

  void _handleBackup() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Backing up data to cloud...';
    });

    bool success = await _service.uploadUserDataBackup();

    setState(() {
      _isLoading = false;
      _statusMessage = success
          ? '✅ Backup completed successfully!'
          : '❌ Backup failed. Check permissions.';
    });
  }

  void _handleRestore() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Restoring data from cloud...';
    });

    var contacts = await _service.restoreContactsFromCloud();
    var calls = await _service.restoreCallLogsFromCloud();

    setState(() {
      _isLoading = false;
      _restoredContacts = contacts;
      _restoredCalls = calls;
      _statusMessage =
          '✅ Restored ${contacts.length} contacts and ${calls.length} call logs!';
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.purple.shade900,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade700,
                    ),
                    onPressed: _isLoading ? null : _handleBackup,
                    icon: const Icon(Icons.cloud_upload, color: Colors.white),
                    label: const Text(
                      'Backup Now',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                    ),
                    onPressed: _isLoading ? null : _handleRestore,
                    icon: const Icon(Icons.cloud_download, color: Colors.white),
                    label: const Text(
                      'Restore Data',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_isLoading)
              const CircularProgressIndicator(color: Colors.purple)
            else
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: Colors.purple.shade700,
                        unselectedLabelColor: Colors.grey,
                        tabs: const [
                          Tab(text: 'Restored Contacts'),
                          Tab(text: 'Restored Call Logs'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            ListView.builder(
                              itemCount: _restoredContacts.length,
                              itemBuilder: (context, index) {
                                var contact = _restoredContacts[index];
                                return ListTile(
                                  leading: const Icon(
                                    Icons.person,
                                    color: Colors.purple,
                                  ),
                                  title: Text(contact['name'] ?? 'No Name'),
                                  subtitle: Text(contact['phone'] ?? ''),
                                );
                              },
                            ),
                            ListView.builder(
                              itemCount: _restoredCalls.length,
                              itemBuilder: (context, index) {
                                var call = _restoredCalls[index];
                                return ListTile(
                                  leading: const Icon(
                                    Icons.phone_callback,
                                    color: Colors.teal,
                                  ),
                                  title: Text(
                                    call['name'] != 'Unknown'
                                        ? call['name']
                                        : call['number'],
                                  ),
                                  subtitle: Text(
                                    'Type: ${call['type'].split('.').last} | Duration: ${call['duration']}s',
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
              ),
          ],
        ),
      ),
    );
  }
}
