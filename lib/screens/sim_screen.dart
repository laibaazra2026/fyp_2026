import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/sim_service.dart';

class SimScreen extends StatefulWidget {
  const SimScreen({super.key});

  @override
  State<SimScreen> createState() => _SimScreenState();
}

class _SimScreenState extends State<SimScreen> {
  final SimService _simService = SimService();
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    // Check for SIM swap on screen open
    _simService.checkPhysicalSimSwap();
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SIM Change Logs',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.purple.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Check SIM Now',
            onPressed: () => _simService.checkPhysicalSimSwap(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection('sim_logs')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.purple),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.sim_card_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No SIM Swaps Detected',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Your device SIM is secure and verified.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade700,
                      ),
                      onPressed: () => _simService.checkPhysicalSimSwap(),
                      icon: const Icon(Icons.search, color: Colors.white),
                      label: const Text(
                        'Re-Scan SIM Status',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final simLogs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: simLogs.length,
            itemBuilder: (context, index) {
              var log = simLogs[index].data() as Map<String, dynamic>;
              var rawTimestamp = log['timestamp'];
              String formattedDate = 'Just now';

              if (rawTimestamp is Timestamp) {
                formattedDate = DateFormat(
                  'yyyy-MM-dd – hh:mm a',
                ).format(rawTimestamp.toDate());
              } else if (rawTimestamp is String) {
                DateTime? parsedDate = DateTime.tryParse(rawTimestamp);
                if (parsedDate != null) {
                  formattedDate = DateFormat(
                    'yyyy-MM-dd – hh:mm a',
                  ).format(parsedDate);
                }
              }

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                    ),
                  ),
                  title: const Text(
                    'Physical SIM Changed',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'Carrier: ${log['carrierName'] ?? 'Unknown'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Time: $formattedDate',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  trailing: const Chip(
                    label: Text(
                      'Alert',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                    backgroundColor: Colors.red,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
