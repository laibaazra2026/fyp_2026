import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'professional_invoice_screen.dart';

class GatewaySuccessScreen extends StatefulWidget {
  final String planName;
  final double price;
  final String gatewayName;
  final String transactionId;

  const GatewaySuccessScreen({
    super.key,
    required this.planName,
    required this.price,
    required this.gatewayName,
    required this.transactionId,
  });

  @override
  State<GatewaySuccessScreen> createState() => _GatewaySuccessScreenState();
}

class _GatewaySuccessScreenState extends State<GatewaySuccessScreen> {
  @override
  void initState() {
    super.initState();
    _saveSubscriptionToFirestore();
  }

  Future<void> _saveSubscriptionToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email ?? 'N/A',
          'subscriptionPlan': widget.planName,
          'paymentMethod': widget.gatewayName,
          'verifiedPhoneNumber':
              user.phoneNumber ??
              '03001234567', // Or use your collected phone variable
          'lastTransactionId': widget.transactionId,
          'subscribedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error saving subscription: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isJazzCash = widget.gatewayName.toLowerCase().contains('jazz');
    Color brandColor = isJazzCash ? Colors.red.shade700 : Colors.green.shade700;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: brandColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle, size: 80, color: brandColor),
              ),
              const SizedBox(height: 24),
              Text(
                '${widget.gatewayName} Payment Successful',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: brandColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Security Handshake & MPIN verified successfully.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildRow('Plan Tier', widget.planName),
                    const Divider(height: 16),
                    _buildRow(
                      'Amount Paid',
                      'PKR ${widget.price.toStringAsFixed(0)}',
                    ),
                    const Divider(height: 16),
                    _buildRow('Transaction ID', widget.transactionId),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfessionalInvoiceScreen(
                          planName: widget.planName,
                          price: widget.price,
                          gatewayName: widget.gatewayName,
                          transactionId: widget.transactionId,
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'View Official Invoice',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
