import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/pos/presentation/providers/checkout_notifier.dart';

class ReceiptItem {
  final String name;
  final int qty;
  final double price;
  final double subtotal;

  ReceiptItem({
    required this.name,
    required this.qty,
    required this.price,
    required this.subtotal,
  });
}

class ReceiptService {
  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  /// Generates a PDF receipt and opens the native print dialog.
  static Future<void> generateAndPrintReceipt({
    required CheckoutResult transaction,
    required List<ReceiptItem> items,
    required String cashierName,
  }) async {
    final doc = pw.Document();

    // Standard 58mm thermal paper width approx. 58mm = ~164 points
    // 80mm approx 80mm = ~226 points
    // We'll use a continuous roll format (PdfPageFormat.roll80)
    
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              // ── Header ──
              pw.Center(
                child: pw.Text(
                  'APOS STORE',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'Jl. Jalan Asik\nTangerang Selatan',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),

              // ── Transaction Info ──
              pw.Text('Ref   : ${transaction.referenceNo}', style: const pw.TextStyle(fontSize: 10)),
              pw.Text(
                  'Date  : ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Staff : $cashierName', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Pay   : ${transaction.paymentMethod}', style: const pw.TextStyle(fontSize: 10)),
              
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),

              // ── Items ──
              ...items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(item.name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '${item.qty} x ${_currency.format(item.price)}',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                          pw.Text(
                            _currency.format(item.subtotal),
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 4),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),

              // ── Totals ──
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    _currency.format(transaction.totalAmount),
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // ── Footer ──
              pw.Center(
                child: pw.Text(
                  'Thank You!',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Please come again',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.SizedBox(height: 20),
            ],
          );
        },
      ),
    );

    // Call the printing package to show the native print dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Receipt_${transaction.referenceNo}',
    );
  }
}
