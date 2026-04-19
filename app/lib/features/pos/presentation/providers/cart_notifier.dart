import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';

// ════════════════════════════════════════════════════════════
// DOMAIN MODEL
// ════════════════════════════════════════════════════════════

/// Represents a single item inside the POS cart.
class CartItem extends Equatable {
  const CartItem({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.price,
    required this.purchasePrice,
    required this.availableStock,
    this.quantity = 1,
  });

  final String productId;
  final String productName;
  final String sku;

  /// Selling price per unit.
  final double price;

  /// Cost price per unit (needed for COGS calculation).
  final double purchasePrice;

  /// Snapshot of current_stock at the time the item was added.
  /// Used for client-side stock validation.
  final int availableStock;

  final int quantity;

  double get subtotal => price * quantity;

  /// Whether adding one more unit would exceed available stock.
  bool get isAtStockLimit => quantity >= availableStock;

  CartItem copyWith({int? quantity, int? availableStock}) {
    return CartItem(
      productId: productId,
      productName: productName,
      sku: sku,
      price: price,
      purchasePrice: purchasePrice,
      availableStock: availableStock ?? this.availableStock,
      quantity: quantity ?? this.quantity,
    );
  }

  /// Convert to the payload shape expected by the checkout RPC.
  Map<String, dynamic> toCheckoutJson() => {
        'product_id': productId,
        'quantity': quantity,
        'price': price,
      };

  @override
  List<Object?> get props =>
      [productId, productName, sku, price, purchasePrice, availableStock, quantity];
}

// ════════════════════════════════════════════════════════════
// CART STATE
// ════════════════════════════════════════════════════════════

class CartState extends Equatable {
  const CartState({
    this.items = const [],
    this.paymentMethod = 'CASH',
  });

  final List<CartItem> items;
  final String paymentMethod;

  /// Total selling price.
  double get totalAmount =>
      items.fold(0, (sum, item) => sum + item.subtotal);

  /// Total cost price (for COGS).
  double get totalCost =>
      items.fold(0, (sum, item) => sum + (item.purchasePrice * item.quantity));

  /// Number of distinct products in the cart.
  int get distinctCount => items.length;

  /// Total units across all items.
  int get totalUnits =>
      items.fold(0, (sum, item) => sum + item.quantity);

  bool get isEmpty => items.isEmpty;

  CartState copyWith({
    List<CartItem>? items,
    String? paymentMethod,
  }) {
    return CartState(
      items: items ?? this.items,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }

  @override
  List<Object?> get props => [items, paymentMethod];
}

// ════════════════════════════════════════════════════════════
// ADD-TO-CART RESULT
// ════════════════════════════════════════════════════════════

/// Returned by [CartNotifier.addItem] to signal success or stock limit.
class AddToCartResult {
  const AddToCartResult.success() : ok = true, message = null;
  const AddToCartResult.stockExceeded(String this.message) : ok = false;

  final bool ok;
  final String? message;
}

// ════════════════════════════════════════════════════════════
// CART NOTIFIER (Riverpod Notifier)
// ════════════════════════════════════════════════════════════

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  // ── Add Item (with stock check) ───────────────────────
  /// Adds a product to the cart.
  /// Returns [AddToCartResult.stockExceeded] if adding would
  /// exceed [availableStock].
  AddToCartResult addItem({
    required String productId,
    required String productName,
    required String sku,
    required double price,
    required double purchasePrice,
    required int availableStock,
    int quantity = 1,
  }) {
    final existingIdx = state.items.indexWhere(
      (i) => i.productId == productId,
    );

    if (existingIdx >= 0) {
      final current = state.items[existingIdx];
      final newQty = current.quantity + quantity;

      // ── Stock check ──
      if (newQty > availableStock) {
        return AddToCartResult.stockExceeded(
          'Only $availableStock units of "${current.productName}" available '
          '(already ${current.quantity} in cart).',
        );
      }

      final updated = List<CartItem>.from(state.items);
      updated[existingIdx] = current.copyWith(
        quantity: newQty,
        availableStock: availableStock,
      );
      state = state.copyWith(items: updated);
    } else {
      // ── Stock check for new item ──
      if (quantity > availableStock) {
        return AddToCartResult.stockExceeded(
          'Only $availableStock units of "$productName" available.',
        );
      }

      state = state.copyWith(
        items: [
          ...state.items,
          CartItem(
            productId: productId,
            productName: productName,
            sku: sku,
            price: price,
            purchasePrice: purchasePrice,
            availableStock: availableStock,
            quantity: quantity,
          ),
        ],
      );
    }

    return const AddToCartResult.success();
  }

  // ── Remove Item ───────────────────────────────────────
  void removeItem(String productId) {
    state = state.copyWith(
      items: state.items.where((i) => i.productId != productId).toList(),
    );
  }

  // ── Update Quantity (with stock check) ────────────────
  /// Returns false if the new quantity exceeds stock.
  bool updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return true;
    }

    final item = state.items.firstWhere(
      (i) => i.productId == productId,
      orElse: () => throw StateError('Item not in cart: $productId'),
    );

    if (quantity > item.availableStock) {
      return false; // blocked by stock
    }

    final updated = state.items.map((i) {
      if (i.productId == productId) return i.copyWith(quantity: quantity);
      return i;
    }).toList();

    state = state.copyWith(items: updated);
    return true;
  }

  // ── Increment / Decrement ─────────────────────────────
  /// Returns false if incrementing would exceed stock.
  bool incrementQuantity(String productId) {
    final item = state.items.firstWhere(
      (i) => i.productId == productId,
      orElse: () => throw StateError('Item not in cart: $productId'),
    );
    return updateQuantity(productId, item.quantity + 1);
  }

  void decrementQuantity(String productId) {
    final item = state.items.firstWhere(
      (i) => i.productId == productId,
      orElse: () => throw StateError('Item not in cart: $productId'),
    );
    updateQuantity(productId, item.quantity - 1);
  }

  // ── Payment Method ────────────────────────────────────
  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  // ── Clear Cart ────────────────────────────────────────
  void clear() {
    state = const CartState();
  }

  // ── Build Checkout Payload ────────────────────────────
  Map<String, dynamic> toCheckoutPayload({
    required String? staffId,
    required String outletId,
  }) {
    return {
      'cart_items': state.items.map((i) => i.toCheckoutJson()).toList(),
      'payment_method': state.paymentMethod,
      'staff_id': staffId,
      'outlet_id': outletId,
    };
  }
}

// ════════════════════════════════════════════════════════════
// PROVIDER
// ════════════════════════════════════════════════════════════

final cartProvider = NotifierProvider<CartNotifier, CartState>(
  CartNotifier.new,
);
