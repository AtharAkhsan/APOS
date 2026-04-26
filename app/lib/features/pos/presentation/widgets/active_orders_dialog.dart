import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/active_orders_notifier.dart';
import '../providers/checkout_notifier.dart';
import '../../../../core/services/receipt_service.dart';

class ActiveOrdersDialog extends ConsumerWidget {
  const ActiveOrdersDialog({super.key});

  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeOrdersAsync = ref.watch(activeOrdersProvider);

    return Dialog(
      backgroundColor: context.theme.cardWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 600,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Orders',
                  style: GoogleFonts.manrope(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: context.theme.colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: context.theme.colorScheme.onSurfaceVariant),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: activeOrdersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
                data: (orders) {
                  if (orders.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 48, color: context.theme.outlineVariantCustom),
                          const SizedBox(height: 12),
                          Text('No active orders', style: GoogleFonts.inter(color: context.theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _OrderCard(order: order, currency: _currency);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends ConsumerStatefulWidget {
  const _OrderCard({required this.order, required this.currency});

  final ActiveOrder order;
  final NumberFormat currency;

  @override
  ConsumerState<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends ConsumerState<_OrderCard> {
  String _selectedPaymentMethod = 'CASH';
  bool _isProcessing = false;

  void _processPayment() async {
    setState(() => _isProcessing = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      // Call the RPC directly (not via checkoutControllerProvider)
      // to avoid triggering the ref.listen in pos_page while this dialog is open.
      final response = await supabase.rpc('process_unpaid_checkout', params: {
        'p_transaction_id': widget.order.id,
        'p_payment_method': _selectedPaymentMethod,
        'p_staff_id': userId,
      });

      final responseData = response as Map<String, dynamic>;

      final receiptItems = widget.order.items.map((i) => ReceiptItem(
        name: i.productName,
        qty: i.quantity,
        price: i.unitPrice,
        subtotal: i.quantity * i.unitPrice,
      )).toList();

      final result = CheckoutResult(
        transactionId: responseData['transaction_id'] as String? ?? widget.order.id,
        referenceNo: responseData['reference_no'] as String? ?? widget.order.referenceNo,
        totalAmount: (responseData['total_amount'] as num?)?.toDouble() ?? widget.order.totalAmount,
        totalCogs: (responseData['total_cogs'] as num?)?.toDouble() ?? 0,
        paymentMethod: _selectedPaymentMethod,
        itemCount: receiptItems.length,
        createdAt: responseData['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        receiptItems: receiptItems,
      );

      // Refresh the active orders list so the badge updates
      ref.read(activeOrdersProvider.notifier).refresh();

      if (mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.theme.surfaceHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.order.tableNumber ?? 'No Table',
                style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                widget.currency.format(widget.order.totalAmount),
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: context.theme.colorScheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Ref: ${widget.order.referenceNo} • ${DateFormat('hh:mm a').format(widget.order.createdAt.toLocal())}',
            style: GoogleFonts.inter(fontSize: 12, color: context.theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          // Items Preview
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.order.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${item.quantity}x ${item.productName}',
                style: GoogleFonts.inter(fontSize: 13, color: context.theme.colorScheme.onSurface),
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),
          // Payment Form
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedPaymentMethod,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: ['CASH', 'BANK_TRANSFER', 'QRIS', 'CREDIT_CARD', 'DEBIT_CARD']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedPaymentMethod = val!),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.theme.colorScheme.primary,
                  foregroundColor: context.theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isProcessing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Pay Now'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
