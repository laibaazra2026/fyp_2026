import 'package:flutter/material.dart';
import '../../models/purchase_cart_item.dart';

class CardInvoiceScreen extends StatelessWidget {
  final List<PurchaseCartItem> items;
  final String authCode;
  final double totalAmount;

  CardInvoiceScreen({
    super.key,
    required this.authCode,
    required double totalAmount,
    required dynamic cartItemOrItems,
  }) : items = cartItemOrItems is List<PurchaseCartItem>
           ? cartItemOrItems
           : [cartItemOrItems as PurchaseCartItem],
       totalAmount = totalAmount > 0
           ? totalAmount
           : (cartItemOrItems is PurchaseCartItem
                 ? cartItemOrItems.price
                 : (cartItemOrItems as List<PurchaseCartItem>).fold(
                     0.0,
                     (sum, item) => sum + item.price,
                   ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Payment Voucher'),
        backgroundColor: Colors.blue.shade800,
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
                      'SECURE CARD PAYMENT',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    Icon(Icons.credit_card, color: Colors.blue),
                  ],
                ),
                const Divider(height: 30),
                Text(
                  'Authorization Code: $authCode',
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
                        color: Colors.blue,
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
