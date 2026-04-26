import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/active_outlet_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../pos/presentation/providers/cart_notifier.dart';
import '../../data/repositories/waiter_order_repository.dart';

/// State for the waiter order submission.
class WaiterOrderState {
  const WaiterOrderState({
    this.selectedTable,
    this.isSubmitting = false,
    this.lastReferenceNo,
    this.error,
  });

  final String? selectedTable;
  final bool isSubmitting;
  final String? lastReferenceNo;
  final String? error;

  WaiterOrderState copyWith({
    String? selectedTable,
    bool? isSubmitting,
    String? lastReferenceNo,
    String? error,
    bool clearTable = false,
    bool clearError = false,
    bool clearRef = false,
  }) {
    return WaiterOrderState(
      selectedTable: clearTable ? null : (selectedTable ?? this.selectedTable),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      lastReferenceNo: clearRef ? null : (lastReferenceNo ?? this.lastReferenceNo),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier managing waiter order state and submission.
class WaiterOrderNotifier extends Notifier<WaiterOrderState> {
  @override
  WaiterOrderState build() => const WaiterOrderState();

  void selectTable(String? table) {
    state = state.copyWith(selectedTable: table, clearError: true);
  }

  Future<bool> submitOrder() async {
    final cart = ref.read(cartProvider);
    final activeOutlet = ref.read(activeOutletProvider);
    final profile = ref.read(userProfileProvider).valueOrNull;

    // Validation
    if (state.selectedTable == null) {
      state = state.copyWith(error: 'Please select a table number');
      return false;
    }
    if (cart.isEmpty) {
      state = state.copyWith(error: 'Cart is empty');
      return false;
    }

    final outletId = activeOutlet?.id ?? profile?.outletId;
    if (outletId == null) {
      state = state.copyWith(error: 'No outlet assigned');
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final repo = ref.read(waiterOrderRepositoryProvider);
      final refNo = await repo.submitOrder(
        tableNumber: state.selectedTable!,
        outletId: outletId,
        staffId: profile?.id,
        items: cart.items,
        total: cart.totalAmount,
      );

      // Clear cart and reset table
      ref.read(cartProvider.notifier).clear();

      state = WaiterOrderState(lastReferenceNo: refNo);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'Failed to submit order: $e',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ── Provider ──────────────────────────────────────────────────

final waiterOrderProvider =
    NotifierProvider<WaiterOrderNotifier, WaiterOrderState>(
  WaiterOrderNotifier.new,
);
