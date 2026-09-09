import 'package:flutter/material.dart';

class ProfessionalInvoiceScreen extends StatelessWidget {
  final String planName;
  final double price;
  final String paymentMethod;
  final String transactionId;
  final String? verifiedPhoneNumber;

  const ProfessionalInvoiceScreen({
    super.key,
    required this.planName,
    required this.price,
    required this.paymentMethod,
    required this.transactionId,
    this.verifiedPhoneNumber,
  });

  @override
  Widget build(BuildContext context) {
    String currentDate = DateTime.now().toString().substring(0, 10);
    double taxAmount = 0.00;
    double subtotal = price;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tax & Subscription Invoice',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple.shade700,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.security,
                            color: Colors.purple.shade700,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'SAFEGUARD APP',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mobile Security & Anti-Theft Suite',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                      const Text(
                        'NTN: 7890123-4 | GST: 16-00-9988-77',
                        style: TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: const Text(
                      'PAID',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INVOICE NO',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'INV-${transactionId.isNotEmpty ? transactionId : '2026-001'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'ISSUE DATE',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentDate,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Billed To:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Authorized App User',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (verifiedPhoneNumber != null &&
                        verifiedPhoneNumber!.isNotEmpty)
                      Text(
                        'Mobile Wallet: $verifiedPhoneNumber',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    Text(
                      'Payment Method: $paymentMethod Gateway',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Transaction Ref: $transactionId',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(3),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1.2),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    children: const [
                      Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Description',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Qty',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Amount',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(
                          '$planName Tier Subscription\n(Monthly Protection Plan)',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(
                          '1',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(
                          'PKR ${subtotal.toStringAsFixed(0)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subtotal',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  Text(
                    'PKR ${subtotal.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sales Tax / Services (0%)',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  Text(
                    'PKR ${taxAmount.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Paid:',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'PKR ${price.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Center(
                child: Column(
                  children: [
                    Text(
                      'This is a system-generated electronic invoice.',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Thank you for securing your device with us.',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
