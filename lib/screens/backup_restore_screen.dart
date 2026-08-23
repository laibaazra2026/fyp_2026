import 'package:flutter/material.dart';
import 'backup_restore_service.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final BackupRestoreService _service = BackupRestoreService();
  bool _isLoading = false;
  String _statusMessage = 'Tap an option below to manage cloud backups.';

  List<Map<String, dynamic>> _restoredContacts = [];
  List<Map<String, dynamic>> _restoredCalls = [];

  // Trigger Backup
  void _handleBackup() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Backing up contacts and call logs...';
    });

    bool success = await _service.uploadUserDataBackup();

    setState(() {
      _isLoading = false;
      _statusMessage = success
          ? '✅ Backup completed successfully!'
          : '❌ Backup failed. Check permissions.';
    });
  }

  // Trigger Restore
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
        title: const Text('Cloud Backup & Restore'),
        backgroundColor: const Color(0xFF841EA0),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF841EA0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusMessage,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
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
                      backgroundColor: const Color(0xFF841EA0),
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
              const CircularProgressIndicator(color: Color(0xFF841EA0))
            else
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const TabBar(
                        labelColor: Color(0xFF841EA0),
                        tabs: [
                          Tab(text: 'Restored Contacts'),
                          Tab(text: 'Restored Call Logs'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Contacts List
                            ListView.builder(
                              itemCount: _restoredContacts.length,
                              itemBuilder: (context, index) {
                                var contact = _restoredContacts[index];
                                return ListTile(
                                  leading: const Icon(
                                    Icons.person,
                                    color: Color(0xFF841EA0),
                                  ),
                                  title: Text(contact['name'] ?? 'No Name'),
                                  subtitle: Text(contact['phone'] ?? ''),
                                );
                              },
                            ),
                            // Call Logs List
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
