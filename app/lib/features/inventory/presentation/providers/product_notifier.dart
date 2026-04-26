import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/active_outlet_provider.dart';
import '../../../pos/domain/entities/product.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../pos/data/repositories/product_repository.dart';

/// Holds the list of products and manages loading / error states.
class ProductNotifier extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() {
    ref.watch(activeOutletProvider);
    ref.watch(userProfileProvider);
    return _fetch();
  }

  Future<List<Product>> _fetch() {
    return ref.read(productRepositoryProvider).getProducts();
  }

  /// Refresh the product list from the server.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Create a new product and prepend it to the local list.
  Future<void> addProduct(Product product) async {
    final repo = ref.read(productRepositoryProvider);
    final created = await repo.createProduct(product);

    // Optimistically prepend the new item
    state = AsyncData([created, ...state.value ?? []]);
  }

  /// Update an existing product.
  Future<void> updateProduct(Product product) async {
    final repo = ref.read(productRepositoryProvider);
    final updated = await repo.updateProduct(product);

    final list = [...?state.value];
    final idx = list.indexWhere((p) => p.id == updated.id);
    if (idx >= 0) list[idx] = updated;
    state = AsyncData(list);
  }

  /// Soft-delete a product (sets `is_active = false`).
  Future<void> deactivateProduct(String id) async {
    final repo = ref.read(productRepositoryProvider);
    await repo.deactivateProduct(id);

    final list = [...?state.value];
    list.removeWhere((p) => p.id == id);
    state = AsyncData(list);
  }
}

final productNotifierProvider =
    AsyncNotifierProvider<ProductNotifier, List<Product>>(
  ProductNotifier.new,
);
