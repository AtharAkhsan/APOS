import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/providers/active_outlet_provider.dart';
import '../providers/cart_notifier.dart';

// ════════════════════════════════════════════════════════════
// CHECKOUT RESULT
// ════════════════════════════════════════════════════════════

import '../../../../core/services/receipt_service.dart';

class CheckoutResult {
  const CheckoutResult({
    required this.transactionId,
    required this.referenceNo,
    required this.totalAmount,
    required this.totalCogs,
    required this.paymentMethod,
    required this.itemCount,
    required this.createdAt,
    required this.receiptItems,
  });

  final String transactionId;
  final String referenceNo;
  final double totalAmount;
  final double totalCogs;
  final String paymentMethod;
  final int itemCount;
  final String createdAt;
  final List<ReceiptItem> receiptItems;

  factory CheckoutResult.fromJson(Map<String, dynamic> json, List<ReceiptItem> items) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return CheckoutResult(
      transactionId: (data['transaction_id'] ?? '') as String,
      referenceNo: (data['reference_no'] ?? '') as String,
      totalAmount: (data['total_amount'] as num?)?.toDouble() ?? 0,
      totalCogs: (data['total_cogs'] as num?)?.toDouble() ?? 0,
      paymentMethod: (data['payment_method'] ?? 'CASH') as String,
      itemCount: (data['items'] as List?)?.length ?? 0,
      createdAt: (data['created_at'] ?? '') as String,
      receiptItems: items,
    );
  }
}

// ════════════════════════════════════════════════════════════
// CHECKOUT CONTROLLER (AsyncNotifier)
// ════════════════════════════════════════════════════════════

class CheckoutController extends AsyncNotifier<CheckoutResult?> {
  @override
  Future<CheckoutResult?> build() async => null;

  /// Calls the `checkout` Edge Function.
  /// Uses auth user if available, otherwise the Edge Function
  /// defaults to a dummy staff UUID (MVP mode).
  Future<CheckoutResult> processCheckout() async {
    state = const AsyncLoading();

    try {
      final supabase = ref.read(supabaseProvider);
      final cart = ref.read(cartProvider);

      if (cart.isEmpty) {
        throw Exception('Cart is empty.');
      }

      // Use auth user if available, otherwise send null
      final userId = supabase.auth.currentUser?.id;

      final activeOutlet = ref.read(activeOutletProvider);
      if (activeOutlet == null) {
        throw Exception('No outlet selected.');
      }

      final payload = ref.read(cartProvider.notifier).toCheckoutPayload(
        staffId: userId,
        outletId: activeOutlet.id,
      );

      // Call Edge Function
      final response = await supabase.functions.invoke(
        'checkout',
        body: payload,
      );

      // Parse response
      final responseData = response.data is String
          ? jsonDecode(response.data as String) as Map<String, dynamic>
          : response.data as Map<String, dynamic>;

      if (responseData['success'] != true) {
        throw Exception(
          responseData['error'] as String? ?? 'Checkout failed.',
        );
      }

      final receiptItems = cart.items.map((i) => ReceiptItem(
        name: i.productName,
        qty: i.quantity,
        price: i.price,
        subtotal: i.subtotal,
      )).toList();

      final result = CheckoutResult.fromJson(responseData, receiptItems);

      // Clear cart on success
      ref.read(cartProvider.notifier).clear();

      state = AsyncData(result);
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Reset to idle state (after showing success dialog).
  void reset() {
    state = const AsyncData(null);
  }
}

final checkoutControllerProvider =
    AsyncNotifierProvider<CheckoutController, CheckoutResult?>(
  CheckoutController.new,
);
