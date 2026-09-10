import 'package:flutter/material.dart';
import '../../models/purchase_cart_item.dart';

class EasypaisaInvoiceScreen extends StatelessWidget {
  final List<PurchaseCartItem> items;
  final String token;
  final double totalAmount;

  const EasypaisaInvoiceScreen({
    super.key,
    required this.items,
    required this.token,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Easypaisa Receipt'),
        backgroundColor: const Color(0xFF00A651),
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
                      'EASYPAISA DIGITAL RECEIPT',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00A651),
                      ),
                    ),
                    Icon(Icons.receipt_long, color: Color(0xFF00A651)),
                  ],
                ),
                const Divider(height: 30),
                Text(
                  'Token Number: $token',
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
                        color: Color(0xFF00A651),
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
