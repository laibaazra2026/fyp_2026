import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/purchase_cart_item.dart';
import '../../services/app_config.dart';

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

    final String prefix = AppConfig.isLiveProductionMode
        ? 'EP-LIVE'
        : 'EP-SANDBOX';
    final String transactionId =
        '$prefix-TXN-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    final Color themeColor = AppConfig.isLiveProductionMode
        ? const Color(0xFF00A651)
        : Colors.purple.shade700;

    final Color containerBgColor = AppConfig.isLiveProductionMode
        ? const Color(0xFFE8F5E9)
        : Colors.purple.shade50;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppConfig.isLiveProductionMode
              ? 'Easypaisa Verified Receipt (Live)'
              : 'Easypaisa Digital Receipt (Sandbox Mock)',
        ),
        backgroundColor: themeColor,
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppConfig.isLiveProductionMode
                                  ? 'EASYPAISA MOBILE WALLET (LIVE)'
                                  : 'EASYPAISA MOBILE WALLET (SANDBOX)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: themeColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  AppConfig.isLiveProductionMode
                                      ? Icons.verified
                                      : Icons.science,
                                  size: 14,
                                  color: AppConfig.isLiveProductionMode
                                      ? Colors.blue
                                      : Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  AppConfig.isLiveProductionMode
                                      ? 'PayFast Real Payment Verified'
                                      : 'PayFast Sandbox Simulation',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: containerBgColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            AppConfig.isLiveProductionMode
                                ? Icons.person_pin_circle
                                : Icons.account_balance_wallet,
                            color: themeColor,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30),

                    _buildMetaRow(
                      'Transaction Status',
                      AppConfig.isLiveProductionMode
                          ? 'SUCCESS (LIVE PRODUCTION)'
                          : 'SUCCESS (MOCK SIMULATION)',
                      color: themeColor,
                    ),
                    const SizedBox(height: 8),
                    _buildMetaRow('Token Number', token, isMonospace: true),
                    const SizedBox(height: 8),
                    _buildMetaRow('Transaction ID', transactionId),
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: themeColor,
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
                          backgroundColor: themeColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          await _printInvoice(
                            currentDate,
                            transactionId,
                            themeColor,
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

  Future<void> _printInvoice(
    String currentDate,
    String transactionId,
    Color themeColor,
  ) async {
    final pdf = pw.Document();

    final int pdfColorValue = AppConfig.isLiveProductionMode
        ? 0xFF00A651
        : 0xFF6A1B9A;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
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
                          AppConfig.isLiveProductionMode
                              ? 'EASYPAISA MOBILE WALLET (LIVE)'
                              : 'EASYPAISA MOBILE WALLET (SANDBOX)',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 18,
                            color: PdfColor.fromInt(pdfColorValue),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          AppConfig.isLiveProductionMode
                              ? 'PayFast Verified Real Payment'
                              : 'PayFast Sandbox Simulation',
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
                _buildPdfMetaRow(
                  'Transaction Status',
                  AppConfig.isLiveProductionMode
                      ? 'SUCCESS (LIVE PRODUCTION)'
                      : 'SUCCESS (MOCK SIMULATION)',
                ),
                pw.SizedBox(height: 8),
                _buildPdfMetaRow('Token Number', token),
                pw.SizedBox(height: 8),
                _buildPdfMetaRow('Transaction ID', transactionId),
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
                        color: PdfColor.fromInt(pdfColorValue),
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
      name: 'Easypaisa-Invoice-$transactionId.pdf',
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
