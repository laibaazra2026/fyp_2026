import 'package:flutter/material.dart';
import '../services/sim_service.dart';

class SimScreen extends StatefulWidget {
  const SimScreen({super.key});

  @override
  State<SimScreen> createState() => _SimScreenState();
}

class _SimScreenState extends State<SimScreen> {
  final SimService _simService = SimService();
  bool _isLoading = true;
  String _simStatusText = 'Checking SIM security status...';
  bool _isSimSwapped = false;

  @override
  void initState() {
    super.initState();
    _loadSimStatus();
  }

  Future<void> _loadSimStatus() async {
    setState(() => _isLoading = true);
    String status = await _simService.getSimStatus();
    setState(() {
      _simStatusText = status;
      _isSimSwapped = status.contains('Alert') || status.contains('Changed');
      _isLoading = false;
    });
  }

  // Normal check button
  Future<void> _triggerCheck() async {
    setState(() {
      _isLoading = true;
      _simStatusText = 'Scanning active SIM modules...';
    });

    bool isChanged = await _simService.detectSimChange(context);
    await _loadSimStatus();

    if (!mounted) return;
    _showResultSnackbar(isChanged);
  }

  // 🎓 FYP Defense Demo Trigger Button
  Future<void> _triggerFypDemoSwap() async {
    setState(() {
      _isLoading = true;
      _simStatusText = 'Simulating unauthorized SIM replacement...';
    });

    bool isChanged = await _simService.simulateSimSwapForDemo(context);
    await _loadSimStatus();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '🎓 FYP Demo: Simulated SIM swap executed! Emergency alert dispatched to sandbox contact.',
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showResultSnackbar(bool isChanged) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isChanged
              ? '🚨 SIM Swap Detected! Alert sent to emergency contacts.'
              : '✅ SIM card is secure and verified.',
        ),
        backgroundColor: isChanged ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SIM Security & Swap Alert',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF841EA0),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            (_isSimSwapped
                                    ? Colors.red
                                    : const Color(0xFF841EA0))
                                .withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isSimSwapped
                            ? Icons.warning_amber_rounded
                            : Icons.sim_card,
                        size: 70,
                        color: _isSimSwapped
                            ? Colors.red
                            : const Color(0xFF841EA0),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _isSimSwapped
                          ? 'SIM Swap Alert Triggered!'
                          : 'SIM Security Active',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _isSimSwapped
                            ? Colors.red
                            : const Color(0xFF841EA0),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : Text(
                            _simStatusText,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: _isSimSwapped
                                  ? Colors.red.shade700
                                  : Colors.grey.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                    const SizedBox(height: 30),

                    // Button 1: Normal Re-check
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _triggerCheck,
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        label: const Text(
                          'Re-check SIM Status',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF841EA0),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Button 2: FYP Live Evaluation Demo Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _triggerFypDemoSwap,
                        icon: const Icon(
                          Icons.bug_report,
                          color: Colors.orange,
                        ),
                        label: const Text(
                          '🧪 Test SIM Swap (FYP Demo)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Colors.orange,
                            width: 2,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
