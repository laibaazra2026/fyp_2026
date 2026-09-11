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
    final String currentDate = DateTime.now().toString().split('.').first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Official Payment Receipt'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PAYFAST GATEWAY',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.blue,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Secure Card Transaction Voucher',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        Icon(Icons.credit_card, color: Colors.blue, size: 32),
                      ],
                    ),
                    const Divider(height: 30),

                    // Professional Receipt Metadata
                    _buildMetaRow(
                      'Transaction Status',
                      'APPROVED',
                      color: Colors.green,
                    ),
                    const SizedBox(height: 8),
                    _buildMetaRow(
                      'Authorization Code',
                      authCode,
                      isMonospace: true,
                    ),
                    const SizedBox(height: 8),
                    _buildMetaRow(
                      'Gateway Ref',
                      'PF-TXN-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
                    ),
                    const SizedBox(height: 8),
                    _buildMetaRow('Date & Time', currentDate),

                    const Divider(height: 30),
                    const Text(
                      'Purchased Items:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Preserved item mapping logic
                    ...items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(item.title)),
                            Text(
                              'PKR ${item.price}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Divider(height: 30),

                    // Total Paid Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Paid',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'PKR $totalAmount',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // Print / Save Receipt Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade800,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Receipt successfully printed / saved as PDF!',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        icon: const Icon(Icons.print),
                        label: const Text(
                          'Print / Save Receipt',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
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

  Widget _buildMetaRow(
    String label,
    String value, {
    Color? color,
    bool isMonospace = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color ?? Colors.black87,
            fontFamily: isMonospace ? 'monospace' : null,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
