import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/providers/active_outlet_provider.dart';

class ActiveOrder {
  ActiveOrder({
    required this.id,
    required this.referenceNo,
    required this.tableNumber,
    required this.totalAmount,
    required this.createdAt,
    required this.items,
  });

  final String id;
  final String referenceNo;
  final String? tableNumber;
  final double totalAmount;
  final DateTime createdAt;
  final List<ActiveOrderItem> items;

  factory ActiveOrder.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['transaction_items'] as List<dynamic>? ?? [];
    return ActiveOrder(
      id: json['id'] as String,
      referenceNo: json['reference_no'] as String,
      tableNumber: json['table_number'] as String?,
      totalAmount: (json['total_amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      items: itemsJson.map((i) => ActiveOrderItem.fromJson(i as Map<String, dynamic>)).toList(),
    );
  }
}

class ActiveOrderItem {
  ActiveOrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;

  factory ActiveOrderItem.fromJson(Map<String, dynamic> json) {
    return ActiveOrderItem(
      productId: json['product_id'] as String,
      productName: json['product_name'] as String? ?? 'Unknown Product',
      quantity: json['quantity'] as int,
      unitPrice: (json['unit_price'] as num).toDouble(),
    );
  }
}

class ActiveOrdersNotifier extends StateNotifier<AsyncValue<List<ActiveOrder>>> {
  ActiveOrdersNotifier(this._ref) : super(const AsyncValue.loading()) {
    _fetch();
    _ref.listen(activeOutletProvider, (_, __) => _fetch());
  }

  final Ref _ref;
  final _client = Supabase.instance.client;

  Future<void> _fetch() async {
    state = const AsyncValue.loading();
    final outlet = _ref.read(activeOutletProvider);
    if (outlet == null) {
      state = const AsyncValue.data([]);
      return;
    }

    try {
      final response = await _client
          .from('transactions')
          .select('''
            id,
            reference_no,
            table_number,
            total_amount,
            created_at,
            transaction_items (
              product_id,
              product_name,
              quantity,
              unit_price
            )
          ''')
          .eq('outlet_id', outlet.id)
          .eq('status', 'UNPAID')
          .order('created_at', ascending: true);

      final List<dynamic> data = response;
      final orders = data.map((json) => ActiveOrder.fromJson(json as Map<String, dynamic>)).toList();
      state = AsyncValue.data(orders);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => _fetch();
}

final activeOrdersProvider = StateNotifierProvider<ActiveOrdersNotifier, AsyncValue<List<ActiveOrder>>>((ref) {
  return ActiveOrdersNotifier(ref);
});
