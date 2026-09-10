import 'package:flutter/material.dart';
import '../../models/purchase_cart_item.dart';

class JazzCashInvoiceScreen extends StatelessWidget {
  final List<PurchaseCartItem> items;
  final String txnId;
  final double totalAmount;

  const JazzCashInvoiceScreen({
    super.key,
    required this.items,
    required this.txnId,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JazzCash Receipt'),
        backgroundColor: const Color(0xFFE61C24),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'JAZZCASH MOBILE WALLET',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE61C24),
                      ),
                    ),
                    Icon(Icons.verified, color: Colors.green),
                  ],
                ),
                const Divider(height: 30),
                Text(
                  'Transaction ID: $txnId',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Purchased Items:',
                  style: TextStyle(color: Colors.grey),
                ),
                ...items.map(
                  (item) => ListTile(
                    dense: true,
                    title: Text(item.title),
                    trailing: Text('PKR ${item.price}'),
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Paid',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'PKR $totalAmount',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE61C24),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
