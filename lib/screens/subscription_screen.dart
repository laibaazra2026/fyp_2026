import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import '../services/subscription_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({Key? key}) : super(key: key);

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late ConfettiController _confettiController;
  String? _selectedPaymentMethod;
  final TextEditingController _phoneController = TextEditingController();

  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    _confettiController.play();

    _phoneController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _processSubscription() async {
    if (_selectedPaymentMethod == null) return;

    String enteredNumber = _phoneController.text.trim();

    setState(() {
      _isLoading = true;
    });

    try {
      String? validationError = _subscriptionService.validateAndNormalizeNumber(
        enteredNumber,
      );
      if (validationError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(validationError), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
        return;
      }

      await _subscriptionService.sendSandboxSms(
        recipientNumber: enteredNumber,
        planName: 'PREMIUM',
        price: 1000.0,
        gateway: _selectedPaymentMethod!,
      );

      String transactionId =
          'SBX-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
      await _subscriptionService.updateSubscriptionWithMethod(
        'PREMIUM',
        1000.0,
        _selectedPaymentMethod!,
        verifiedPhoneNumber: enteredNumber,
        transactionId: transactionId,
      );

      _confettiController.play();

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Subscription Successful!'),
          content: Text(
            'Subscribed via $_selectedPaymentMethod using number: $enteredNumber',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Upgrade Subscription'),
            backgroundColor: Colors.deepPurple,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                const Text(
                  'Choose Your Payment Method',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                Card(
                  elevation: 4,
                  child: RadioListTile<String>(
                    title: const Text('Easypaisa'),
                    subtitle: const Text('Pay via Easypaisa mobile account'),
                    value: 'Easypaisa',
                    groupValue: _selectedPaymentMethod,
                    onChanged: (value) {
                      setState(() {
                        _selectedPaymentMethod = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 10),

                Card(
                  elevation: 4,
                  child: RadioListTile<String>(
                    title: const Text('JazzCash'),
                    subtitle: const Text('Pay via JazzCash mobile account'),
                    value: 'JazzCash',
                    groupValue: _selectedPaymentMethod,
                    onChanged: (value) {
                      setState(() {
                        _selectedPaymentMethod = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Enter Authorized Test Number',
                    hintText: 'e.g., 03005171794',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 30),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed:
                      (_selectedPaymentMethod == null ||
                          _phoneController.text.isEmpty ||
                          _isLoading)
                      ? null
                      : _processSubscription,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _selectedPaymentMethod == null
                              ? 'Select a Payment Method'
                              : 'Proceed with $_selectedPaymentMethod',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),

        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: pi / 2,
            maxBlastForce: 5,
            minBlastForce: 2,
            emissionFrequency: 0.05,
            numberOfParticles: 30,
            gravity: 0.2,
            shouldLoop: false,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple,
            ],
          ),
        ),
      ],
    );
  }
}
