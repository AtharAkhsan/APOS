import 'package:apos/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../providers/cart_notifier.dart';
import '../providers/qris_payment_notifier.dart';

class QrisDialog extends ConsumerWidget {
  const QrisDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qrisState = ref.watch(qrisPaymentProvider);
    final cart = ref.watch(cartProvider);
    final cs = context.theme.colorScheme;

    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    );

    return Dialog(
      backgroundColor: context.theme.cardWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Pembayaran QRIS',
              style: GoogleFonts.manrope(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Silakan scan kode QR di bawah menggunakan aplikasi M-Banking atau E-Wallet.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // ── Main UI State Switch ──
            qrisState.when(
              loading: () => Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: CircularProgressIndicator(color: context.theme.accentButton),
                ),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(Icons.error_outline, size: 48, color: cs.error),
                    const SizedBox(height: 16),
                    Text(
                      'Gagal membuat QRIS\n$err',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: cs.error),
                    ),
                  ],
                ),
              ),
              data: (result) {
                if (result == null) {
                  return Center(
                    child: Text(
                      'Generating QRIS...',
                      style: GoogleFonts.inter(color: cs.onSurfaceVariant),
                    ),
                  );
                }

                return Column(
                  children: [
                    // Total Amount Display
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: context.theme.accentButton,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Total Pembayaran',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF2C1600),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currency.format(cart.totalAmount),
                            style: GoogleFonts.manrope(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2C1600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // QR Code Image — always white background for scan readability
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.theme.outlineVariantCustom,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CachedNetworkImage(
                        imageUrl: result.qrUrl,
                        width: 250,
                        height: 250,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const SizedBox(
                          width: 250,
                          height: 250,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => const SizedBox(
                          width: 250,
                          height: 250,
                          child: Center(
                            child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Order ID: ${result.orderId}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),

            // ── Footer ──
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  ref.read(qrisPaymentProvider.notifier).reset();
                  Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.error,
                  side: BorderSide(color: cs.error.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Batalkan / Tutup',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper method to easily display the QRIS Dialog
void showQrisDialog(BuildContext context, WidgetRef ref) {
  ref.read(qrisPaymentProvider.notifier).generateQris();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const QrisDialog(),
  );
}
