import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/sim_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SimScreen extends StatefulWidget {
  const SimScreen({super.key});

  @override
  State<SimScreen> createState() => _SimScreenState();
}

class _SimScreenState extends State<SimScreen> {
  final SimService _simService = SimService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _simLogs = [];

  @override
  void initState() {
    super.initState();
    _loadSimData();
  }

  Future<void> _loadSimData() async {
    setState(() => _isLoading = true);
    await _simService.checkPhysicalSimSwap();
    List<Map<String, dynamic>> logs = await _simService.getUserSimLogs();
    setState(() {
      _simLogs = logs;
      _isLoading = false;
    });
  }

  // Dialog to view/edit trusted numbers
  void _showTrustedNumbersDialog() {
    final TextEditingController controller = TextEditingController(
      text:
          "+923144984339,+923128719043,+923157633912,+923005171794,+923241923864",
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Contacts'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Trusted numbers configured for emergency SMS alerts upon SIM change:',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Trusted Numbers',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade700,
            ),
            onPressed: () async {
              List<String> numbers = controller.text
                  .split(',')
                  .map((n) => n.trim())
                  .where((n) => n.isNotEmpty)
                  .toList();

              await _simService.saveTrustedNumbers(numbers);
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Trusted numbers saved successfully!'),
                ),
              );
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            icon: const Icon(Icons.contact_phone),
            tooltip: 'View Emergency Contacts',
            onPressed: _showTrustedNumbersDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.purple))
          : _simLogs.isEmpty
          ? Center(
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
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadSimData,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _simLogs.length,
                itemBuilder: (context, index) {
                  var log = _simLogs[index];
                  Timestamp? timestamp = log['timestamp'] as Timestamp?;
                  String formattedDate = timestamp != null
                      ? DateFormat(
                          'yyyy-MM-dd – hh:mm a',
                        ).format(timestamp.toDate())
                      : 'Just now';

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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          // Updated to display carrier name instead of deviceModel
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
              ),
            ),
    );
  }
}
