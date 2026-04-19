import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/supabase_provider.dart';
import '../../data/repositories/qris_payment_repository.dart';
import 'cart_notifier.dart';

// ── Repository Provider ─────────────────────────────────────

final qrisPaymentRepositoryProvider = Provider<QrisPaymentRepository>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return QrisPaymentRepository(supabase);
});

// ── QRIS Result ──────────────────────────────────────────────

class QrisResult {
  const QrisResult({required this.orderId, required this.qrUrl});
  final String orderId;
  final String qrUrl;
}

// ── QRIS Notifier ───────────────────────────────────────────

class QrisPaymentNotifier extends AsyncNotifier<QrisResult?> {
  @override
  Future<QrisResult?> build() async {
    return null;
  }

  /// Triggers the Edge Function to generate the QRIS.
  Future<void> generateQris() async {
    state = const AsyncLoading();

    try {
      final cart = ref.read(cartProvider);
      if (cart.items.isEmpty) {
        throw Exception('Cart is empty.');
      }

      final repo = ref.read(qrisPaymentRepositoryProvider);
      
      // Generate a unique order tracking ID
      final orderId = const Uuid().v4();

      final cartItemsPayload = cart.items.map((item) => {
        'product_id': item.productId,
        'name': item.productName,
        'quantity': item.quantity,
        'price': item.price,
      }).toList();

      final qrUrl = await repo.createQrisTransaction(
        orderId: orderId,
        grossAmount: cart.totalAmount,
        cartItems: cartItemsPayload,
      );

      state = AsyncData(QrisResult(orderId: orderId, qrUrl: qrUrl));
      
      // We do NOT clear the cart yet, because checkout is asynchronous with Midtrans.
      // The user clears the cart manually or we clear it when they close the dialog.
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void reset() {
    state = const AsyncData(null);
  }
}

final qrisPaymentProvider =
    AsyncNotifierProvider<QrisPaymentNotifier, QrisResult?>(
  QrisPaymentNotifier.new,
);
