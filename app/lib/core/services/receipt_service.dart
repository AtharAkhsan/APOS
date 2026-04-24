import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Builds aligned label : value rows for the transaction info section.
  static List<pw.Widget> _buildInfoRows(Map<String, String> data) {
    return data.entries.map((e) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(
          children: [
            pw.SizedBox(
              width: 40,
              child: pw.Text(e.key, style: const pw.TextStyle(fontSize: 10)),
            ),
            pw.Text(' : ', style: const pw.TextStyle(fontSize: 10)),
            pw.Expanded(
              child: pw.Text(e.value, style: const pw.TextStyle(fontSize: 10)),
            ),
          ],
        ),
      );
    }).toList();
  }

  /// Generates a PDF receipt and opens the native print dialog.
  static Future<void> generateAndPrintReceipt({
    required CheckoutResult transaction,
    required List<ReceiptItem> items,
    required String cashierName,
    String? outletId,
    String? outletName,
    String? outletAddress,
    String? outletPhone,
    String orderType = 'Dine In',
  }) async {
    String storeName = outletName ?? 'APOS STORE';
    String footerText = 'Thank You!\nPlease come again';

    debugPrint('[ReceiptService] outletId=$outletId, outletName=$outletName');

    try {
      Map<String, dynamic>? response;

      if (outletId != null) {
        response = await Supabase.instance.client
            .from('receipt_settings')
            .select()
            .eq('outlet_id', outletId)
            .maybeSingle();
      }

      // Fallback: if no settings found for this outlet (or outletId null), grab any
      if (response == null) {
        debugPrint('[ReceiptService] No settings for outlet $outletId, trying fallback');
        final fallback = await Supabase.instance.client
            .from('receipt_settings')
            .select()
            .limit(1)
            .maybeSingle();
        response = fallback;
      }

      debugPrint('[ReceiptService] DB response=$response');

      if (response != null) {
        final headerText = response['header_text'] as String?;
        if (headerText != null && headerText.isNotEmpty) {
          storeName = headerText;
        }
        final footer = response['footer_text'] as String?;
        if (footer != null && footer.isNotEmpty) {
          footerText = footer;
        }
      }
    } catch (e) {
      debugPrint('[ReceiptService] Error fetching settings: $e');
    }

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
              // ── Logo Placeholder ──
              pw.Center(
                child: pw.Container(
                  width: 40,
                  height: 40,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Center(
                    child: pw.Text('A', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  ),
                ),
              ),
              pw.SizedBox(height: 6),

              // ── Store Name ──
              pw.Center(
                child: pw.Text(
                  storeName,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              // ── Outlet Info ──
              if (outletAddress != null && outletAddress.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    outletAddress,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              ],
              if (outletPhone != null && outletPhone.isNotEmpty) ...[
                pw.SizedBox(height: 1),
                pw.Center(
                  child: pw.Text(
                    '$outletPhone',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              ],

              pw.SizedBox(height: 8),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),

              // ── Transaction Info ──
              ..._buildInfoRows({
                'Ref': transaction.referenceNo,
                'Date': DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now()),
                'Staff': cashierName,
                'Pay': transaction.paymentMethod,
              }),
              
              pw.Divider(borderStyle: pw.BorderStyle.dashed),

              // ── Order Type ──
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  orderType.toUpperCase(),
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 6),

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
                  footerText,
                  textAlign: pw.TextAlign.center,
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
