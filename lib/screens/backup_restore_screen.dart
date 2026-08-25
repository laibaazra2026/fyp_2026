import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/backup_restore_service.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final BackupRestoreService _backupService = BackupRestoreService();
  bool _isLoading = false;

  // Backup Contacts Action
  void _handleBackupContacts() async {
    setState(() => _isLoading = true);
    bool success = await _backupService.backupContacts();
    setState(() => _isLoading = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '✅ All Contacts Backed Up Successfully!'
              : '❌ Failed to backup contacts.',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  // Restore Contacts Action
  void _handleRestoreContacts() async {
    setState(() => _isLoading = true);
    bool success = await _backupService.restoreContacts();
    setState(() => _isLoading = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '🔄 Contacts Restored to Phone Successfully!'
              : '❌ Failed to restore contacts.',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  // Pick & Backup Photo Action
  void _handleBackupPhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() => _isLoading = true);
      bool success = await _backupService.backupMedia(File(image.path));
      setState(() => _isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '📸 Media/Photo Backed Up Successfully!'
                : '❌ Failed to upload photo.',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Backup & Restore',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Cloud Data Recovery',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Secure your phone contacts and important media to Firebase. Restore them anytime, even after a factory reset.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 30),

                  // 1. Backup Contacts Button
                  ElevatedButton.icon(
                    onPressed: _handleBackupContacts,
                    icon: const Icon(Icons.contacts, color: Colors.white),
                    label: const Text(
                      'Backup All Contacts',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Restore Contacts Button
                  OutlinedButton.icon(
                    onPressed: _handleRestoreContacts,
                    icon: const Icon(Icons.restore, color: Colors.purple),
                    label: const Text(
                      'Restore Contacts to Phone',
                      style: TextStyle(color: Colors.purple, fontSize: 16),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.purple.shade700, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Backup Media / Photos Button
                  ElevatedButton.icon(
                    onPressed: _handleBackupPhoto,
                    icon: const Icon(Icons.photo_library, color: Colors.white),
                    label: const Text(
                      'Backup Photo / Media',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
