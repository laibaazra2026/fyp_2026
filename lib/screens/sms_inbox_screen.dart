import 'package:flutter/material.dart';
import '../services/sandbox_sms_service.dart';

class SmsInboxScreen extends StatelessWidget {
  const SmsInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final smsService = SandboxSmsService();
    final messages = smsService.getInboxMessages();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sandbox SMS Inbox',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.purple.shade700,
      ),
      body: messages.isEmpty
          ? const Center(
              child: Text(
                'No sandbox SMS received yet.\nPerform a checkout to see mock notifications.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            )
          : ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  elevation: 2,
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.purple,
                      child: Icon(Icons.message, color: Colors.white),
                    ),
                    title: Text(
                      msg['sender'] ?? 'Gateway',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(msg['body'] ?? ''),
                        const SizedBox(height: 6),
                        Text(
                          'To: ${msg['phone']} • ${msg['time']}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
