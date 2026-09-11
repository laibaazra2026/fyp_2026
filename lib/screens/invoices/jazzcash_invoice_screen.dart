import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
    final String currentDate = DateTime.now().toString().split('.').first;
    final String gatewayRef =
        'JC-TXN-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('JazzCash Transaction Receipt'),
        backgroundColor: const Color(0xFFE61C24),
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
                              'JAZZCASH MOBILE ACCOUNT',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFFE61C24),
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
                            color: Color(0xFFFFEBEE),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.phone_android,
                            color: Color(0xFFE61C24),
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30),

                    _buildMetaRow(
                      'Transaction Status',
                      'SUCCESS',
                      color: Colors.green,
                    ),
                    const SizedBox(height: 8),
                    _buildMetaRow('Transaction ID', txnId, isMonospace: true),
                    const SizedBox(height: 8),
                    _buildMetaRow('Gateway Ref', gatewayRef),
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
                            color: Color(0xFFE61C24),
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
                          backgroundColor: const Color(0xFFE61C24),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          await _printInvoice(currentDate, gatewayRef);
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

  Future<void> _printInvoice(String currentDate, String gatewayRef) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24), // Fixed with pw. prefix
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'JAZZCASH MOBILE ACCOUNT',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 18,
                            color: PdfColor.fromInt(0xFFE61C24),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'PayFast Verified Transaction',
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.PdfLogo(),
                  ],
                ),
                pw.Divider(height: 30),
                _buildPdfMetaRow('Transaction Status', 'SUCCESS'),
                pw.SizedBox(height: 8),
                _buildPdfMetaRow('Transaction ID', txnId),
                pw.SizedBox(height: 8),
                _buildPdfMetaRow('Gateway Ref', gatewayRef),
                pw.SizedBox(height: 8),
                _buildPdfMetaRow('Date & Time', currentDate),
                pw.Divider(height: 30),
                pw.Text(
                  'Purchased Items:',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                pw.SizedBox(height: 8),
                ...items.map(
                  (item) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4.0),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(child: pw.Text(item.title)),
                        pw.Text('PKR ${item.price}'),
                      ],
                    ),
                  ),
                ),
                pw.Divider(height: 30),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Paid',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    pw.Text(
                      'PKR $totalAmount',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 18,
                        color: PdfColor.fromInt(0xFFE61C24),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'JazzCash-Invoice-$txnId.pdf',
    );
  }

  pw.Widget _buildPdfMetaRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey700)),
        pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      ],
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
