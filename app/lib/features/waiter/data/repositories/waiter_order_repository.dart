import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/supabase_provider.dart';
import '../../../pos/presentation/providers/cart_notifier.dart';

/// Repository for waiter order submission.
/// Inserts directly into transactions/transaction_items with status = 'UNPAID'.
/// Does NOT deduct inventory or create accounting entries.
class WaiterOrderRepository {
  WaiterOrderRepository(this._client);
  final SupabaseClient _client;

  /// Submit a waiter order.
  /// Returns the generated reference number on success.
  Future<String> submitOrder({
    required String tableNumber,
    required String outletId,
    required String? staffId,
    required List<CartItem> items,
    required double total,
  }) async {
    // Generate reference: ORD-YYYYMMDD-NNNNN
    final now = DateTime.now();
    final datePart = DateFormat('yyyyMMdd').format(now);

    // Get next sequence number for today
    final countResult = await _client
        .from('transactions')
        .select('id')
        .like('reference_no', 'ORD-$datePart-%');

    final seq = (countResult as List).length + 1;
    final referenceNo = 'ORD-$datePart-${seq.toString().padLeft(5, '0')}';

    debugPrint('[WaiterOrder] Submitting order: ref=$referenceNo, table=$tableNumber, items=${items.length}');

    // Calculate total COGS
    final totalCogs = items.fold<double>(
      0,
      (sum, item) => sum + (item.purchasePrice * item.quantity),
    );

    // 1. Insert transaction
    final txResult = await _client.from('transactions').insert({
      'reference_no': referenceNo,
      'total_amount': total,
      'total_cogs': totalCogs,
      'payment_method': 'UNPAID',
      'status': 'UNPAID',
      'transaction_type': 'SALE',
      'table_number': tableNumber,
      'outlet_id': outletId,
      'created_by': staffId,
    }).select('id').single();

    final transactionId = txResult['id'] as String;

    // 2. Insert transaction items
    final itemRows = items.map((item) => {
      'transaction_id': transactionId,
      'product_id': item.productId,
      'product_name': item.productName,
      'quantity': item.quantity,
      'unit_price': item.price,
      'cogs': item.purchasePrice * item.quantity,
    }).toList();

    await _client.from('transaction_items').insert(itemRows);

    debugPrint('[WaiterOrder] Order submitted successfully: $referenceNo');
    return referenceNo;
  }
}

// ── Provider ──────────────────────────────────────────────────

final waiterOrderRepositoryProvider = Provider<WaiterOrderRepository>((ref) {
  return WaiterOrderRepository(ref.read(supabaseProvider));
});
