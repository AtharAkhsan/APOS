import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/providers/active_outlet_provider.dart';
import '../../domain/entities/product.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';

/// Repository that handles all product CRUD via Supabase.
class ProductRepository {
  ProductRepository(this._ref, this._outletId);

  final Ref _ref;
  final String? _outletId;

  // ── READ ───────────────────────────────────────────────

  /// Fetch all active products, optionally filtered by [categoryId].
  Future<List<Product>> getProducts({String? categoryId}) async {
    final client = _ref.read(supabaseProvider);

    var query = client
        .from('vw_products_with_stock')
        .select()
        .eq('is_active', true);

    if (_outletId != null) {
      query = query.eq('outlet_id', _outletId);
    }
    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }

    final data = await query.order('name');
    final productsList = (data as List)
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();

    // If _outletId is null, vw_products_with_stock returns a separate row for each outlet the product is in.
    // We aggregate them to show total stock across all outlets.
    if (_outletId == null) {
      final Map<String, Product> aggregated = {};
      for (final p in productsList) {
        if (aggregated.containsKey(p.id)) {
          final existing = aggregated[p.id]!;
          aggregated[p.id] = existing.copyWith(
            currentStock: existing.currentStock + p.currentStock,
          );
        } else {
          aggregated[p.id] = p;
        }
      }
      return aggregated.values.toList();
    }

    return productsList;
  }

  /// Fetch a single product by ID.
  Future<Product> getProduct(String id) async {
    if (_outletId == null) throw Exception('No active outlet');

    final client = _ref.read(supabaseProvider);
    final data = await client
        .from('vw_products_with_stock')
        .select()
        .eq('id', id)
        .eq('outlet_id', _outletId)
        .single();
    return Product.fromJson(data);
  }

  // ── CREATE ─────────────────────────────────────────────

  /// Insert a new product and return the created record.
  Future<Product> createProduct(Product product) async {
    if (_outletId == null) throw Exception('No active outlet');

    final client = _ref.read(supabaseProvider);
    
    // 1. Insert product
    final pData = await client
        .from('products')
        .insert(product.toInsertJson())
        .select()
        .single();
        
    final newProductId = pData['id'] as String;

    // 2. Upsert initial stock for the current outlet
    if (product.currentStock > 0) {
      await client.from('product_stock').upsert({
        'product_id': newProductId,
        'outlet_id': _outletId,
        'current_stock': product.currentStock,
      });
    }

    return getProduct(newProductId);
  }

  // ── UPDATE ─────────────────────────────────────────────

  /// Update an existing product by ID.
  Future<Product> updateProduct(Product product) async {
    if (_outletId == null) throw Exception('No active outlet');

    final client = _ref.read(supabaseProvider);
    
    // 1. Update product base info
    await client
        .from('products')
        .update(product.toInsertJson())
        .eq('id', product.id);

    // 2. Upsert stock for current outlet
    await client.from('product_stock').upsert({
      'product_id': product.id,
      'outlet_id': _outletId,
      'current_stock': product.currentStock,
    });

    return getProduct(product.id);
  }

  // ── DELETE (soft) ──────────────────────────────────────

  /// Soft-delete by setting `is_active = false`.
  Future<void> deactivateProduct(String id) async {
    final client = _ref.read(supabaseProvider);
    await client.from('products').update({'is_active': false}).eq('id', id);
  }
}

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final activeOutlet = ref.watch(activeOutletProvider);
  final profile = ref.watch(userProfileProvider).valueOrNull;
  
  String? outletId = activeOutlet?.id;
  if (profile != null && !profile.isAdmin) {
    outletId = profile.outletId;
  }
  
  return ProductRepository(ref, outletId);
});
