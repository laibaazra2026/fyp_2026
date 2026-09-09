import 'package:flutter/material.dart';
import 'professional_invoice_screen.dart';

class GatewaySuccessScreen extends StatelessWidget {
  final String planName;
  final double price;
  final String paymentMethod;
  final String transactionId;

  const GatewaySuccessScreen({
    super.key,
    required this.planName,
    required this.price,
    required this.paymentMethod,
    required this.transactionId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 80,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Payment Authorized!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your $paymentMethod wallet was successfully charged PKR ${price.toStringAsFixed(0)}.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Transaction ID:',
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text(
                      transactionId,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfessionalInvoiceScreen(
                          planName: planName,
                          price: price,
                          paymentMethod: paymentMethod,
                          transactionId: transactionId,
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'View Digital Invoice',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                child: const Text(
                  'Return to Home',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
