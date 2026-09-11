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
    final String currentDate = DateTime.now().toString().split('.').first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Easypaisa Digital Receipt'),
        backgroundColor: const Color(0xFF00A651),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EASYPAISA MOBILE WALLET',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF00A651),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'PayFast Verified Transaction',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F5E9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet,
                            color: Color(0xFF00A651),
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30),

                    _buildMetaRow(
                      'Transaction Status',
                      'SUCCESS',
                      color: const Color(0xFF00A651),
                    ),
                    const SizedBox(height: 8),
                    _buildMetaRow('Token Number', token, isMonospace: true),
                    const SizedBox(height: 8),
                    _buildMetaRow(
                      'Transaction ID',
                      'EP-TXN-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
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

                    ...items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00A651),
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A651),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Easypaisa receipt successfully printed / saved!',
                              ),
                              backgroundColor: Color(0xFF00A651),
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
