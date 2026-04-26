import 'package:flutter/material.dart';
import 'package:apos/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../inventory/presentation/providers/product_notifier.dart';
import '../../../inventory/presentation/providers/categories_provider.dart';
import '../../../pos/domain/entities/product.dart';
import '../../../pos/presentation/providers/cart_notifier.dart';
import '../providers/waiter_order_notifier.dart';

/// ════════════════════════════════════════════════════════════
/// WAITER SCREEN — "The Artisanal Interface" 
/// ════════════════════════════════════════════════════════════

class WaiterScreen extends ConsumerStatefulWidget {
  const WaiterScreen({super.key});

  @override
  ConsumerState<WaiterScreen> createState() => _WaiterScreenState();
}

class _WaiterScreenState extends ConsumerState<WaiterScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSuccessDialog(String referenceNo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.theme.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.theme.tertiaryFixedDim,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_circle, color: context.theme.colorScheme.tertiary, size: 48),
        ),
        title: Text(
          'Order Sent to Kitchen!',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            color: context.theme.colorScheme.onSurface,
          ),
        ),
        content: Text(
          'Reference: $referenceNo\nThe cashier and kitchen have received this order.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: context.theme.colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(productNotifierProvider.notifier).refresh();
              },
              style: FilledButton.styleFrom(
                backgroundColor: context.theme.colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Done', style: GoogleFonts.inter(color: context.theme.colorScheme.onPrimary)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    
    // Listen for order submission result
    ref.listen<WaiterOrderState>(waiterOrderProvider, (prev, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: context.theme.colorScheme.error,
          ),
        );
        ref.read(waiterOrderProvider.notifier).clearError();
      } else if (prev?.isSubmitting == true && !next.isSubmitting && next.lastReferenceNo != null) {
        _showSuccessDialog(next.lastReferenceNo!);
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 720;

        if (isWide) {
          return Row(
            children: [
              Expanded(flex: 3, child: _buildProductSection(context, isDesktop: true)),
              SizedBox(
                width: constraints.maxWidth * 0.30,
                child: _WaiterDesktopCartPanel(cart: cart, currency: _currency),
              ),
            ],
          );
        }

        return Stack(
          children: [
            _buildProductSection(context, isDesktop: false),
            if (!cart.isEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _WaiterMobileCartBar(cart: cart, currency: _currency),
              ),
          ],
        );
      },
    );
  }

  Widget _buildProductSection(BuildContext context, {required bool isDesktop}) {
    final productsAsync = ref.watch(productNotifierProvider);
    final waiterState = ref.watch(waiterOrderProvider);

    return Scaffold(
      backgroundColor: context.theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: context.theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 24,
        title: Text(
          'Take Order',
          style: GoogleFonts.manrope(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: context.theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          // Table selector
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: context.theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.theme.colorScheme.primary.withOpacity(0.2)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: waiterState.selectedTable,
                hint: Text('Select Table', style: GoogleFonts.inter(fontSize: 13, color: context.theme.colorScheme.primary)),
                icon: Icon(Icons.arrow_drop_down, color: context.theme.colorScheme.primary),
                dropdownColor: context.theme.cardWhite,
                items: List.generate(20, (index) {
                  final t = 'Table ${index + 1}';
                  return DropdownMenuItem(
                    value: t,
                    child: Text(t, style: GoogleFonts.inter(fontSize: 13, color: context.theme.colorScheme.onSurface)),
                  );
                }),
                onChanged: (val) => ref.read(waiterOrderProvider.notifier).selectTable(val),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.theme.colorScheme.onSurfaceVariant),
            onPressed: () => ref.read(productNotifierProvider.notifier).refresh(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Search & categories
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: context.theme.surfaceHighest,
                borderRadius: BorderRadius.circular(28),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search menu items...',
                  hintStyle: GoogleFonts.inter(fontSize: 14, color: context.theme.colorScheme.onSurfaceVariant),
                  prefixIcon: Icon(Icons.search, color: context.theme.colorScheme.onSurfaceVariant, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: ['All', 'Beverage', 'Food', 'Snack', 'Other']
                  .map((cat) => _CategoryChip(
                        label: cat,
                        isSelected: _selectedCategory == cat,
                        onTap: () => setState(() => _selectedCategory = cat),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          
          // Product grid
          Expanded(
            child: productsAsync.when(
              loading: () => Center(child: CircularProgressIndicator(color: context.theme.colorScheme.primary)),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (products) {
                final categoriesAsync = ref.watch(categoriesProvider);
                final categoryMap = <String, String>{};
                if (categoriesAsync is AsyncData<List<Category>>) {
                  for (final c in categoriesAsync.value) {
                    categoryMap[c.name] = c.id;
                  }
                }
                var filtered = products.where((p) {
                  final matchesSearch = _searchQuery.isEmpty || p.name.toLowerCase().contains(_searchQuery) || p.sku.toLowerCase().contains(_searchQuery);
                  if (_selectedCategory == 'All') return matchesSearch;
                  final targetCatId = categoryMap[_selectedCategory];
                  return matchesSearch && targetCatId != null && p.categoryId == targetCatId;
                }).toList();
                
                if (filtered.isEmpty) {
                  return Center(child: Text('No products found', style: GoogleFonts.inter(color: context.theme.colorScheme.onSurfaceVariant)));
                }
                
                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isDesktop ? (MediaQuery.of(context).size.width > 900 ? 4 : 3) : 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: isDesktop ? 0.78 : 0.75,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _ArtisanalProductCard(product: filtered[index], currency: _currency),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// CATEGORY CHIP & PRODUCT CARD
// ════════════════════════════════════════════════════════════

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.isSelected, required this.onTap});
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? context.theme.colorScheme.primary : context.theme.surfaceHighest,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? context.theme.colorScheme.onPrimary : context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtisanalProductCard extends ConsumerWidget {
  const _ArtisanalProductCard({required this.product, required this.currency});
  final Product product;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Note: waiters still can't add out-of-stock items
    final isOutOfStock = product.currentStock <= 0;
    final isLowStock = product.currentStock > 0 && product.currentStock <= 5;
    return GestureDetector(
      onTap: isOutOfStock
          ? null
          : () {
              final result = ref.read(cartProvider.notifier).addItem(
                    productId: product.id,
                    productName: product.name,
                    sku: product.sku,
                    price: product.sellingPrice,
                    purchasePrice: product.purchasePrice,
                    availableStock: product.currentStock,
                  );
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      result.ok ? '${product.name} added' : result.message ?? 'Limit reached',
                      style: GoogleFonts.inter(color: result.ok ? context.theme.onAccentButton : null),
                    ),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: result.ok ? context.theme.accentButton : context.theme.colorScheme.error,
                  ),
                );
            },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isOutOfStock ? 0.45 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: context.theme.cardWhite,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: const Color(0xFF1B1D0E).withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: context.theme.surfaceHighest,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Center(
                        child: Icon(Icons.restaurant, size: 40, color: context.theme.colorScheme.primaryContainer),
                      ),
                    ),
                    if (isLowStock || isOutOfStock)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isOutOfStock ? context.theme.colorScheme.errorContainer : context.theme.tertiaryFixedDim,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isOutOfStock ? 'OUT' : 'LOW STOCK',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: isOutOfStock ? context.theme.colorScheme.error : context.theme.onTertiaryFixed,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: context.theme.colorScheme.onSurface),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              currency.format(product.sellingPrice),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: context.theme.colorScheme.primary),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isOutOfStock
                                  ? context.theme.colorScheme.errorContainer
                                  : isLowStock
                                      ? context.theme.tertiaryFixedDim.withValues(alpha: 0.5)
                                      : context.theme.surfaceHighest,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${product.currentStock}',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: isOutOfStock ? context.theme.colorScheme.error : context.theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// CART PANELS
// ════════════════════════════════════════════════════════════

class _WaiterDesktopCartPanel extends ConsumerWidget {
  const _WaiterDesktopCartPanel({required this.cart, required this.currency});
  final CartState cart;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waiterState = ref.watch(waiterOrderProvider);
    
    return Container(
      decoration: BoxDecoration(
        color: context.theme.cardWhite,
        border: Border(left: BorderSide(color: context.theme.surfaceHighest, width: 1)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Current Order', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700, color: context.theme.colorScheme.onSurface)),
                if (cart.totalUnits > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: context.theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                    child: Text('${cart.totalUnits}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: context.theme.colorScheme.onPrimaryContainer)),
                  ),
              ],
            ),
          ),
          if (cart.isEmpty)
            Expanded(child: Center(child: Text('No items added yet.', style: GoogleFonts.inter(color: context.theme.colorScheme.onSurfaceVariant))))
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: cart.items.length,
                separatorBuilder: (_, __) => Divider(color: context.theme.surfaceHighest, height: 24),
                itemBuilder: (context, index) => _CartItemTile(item: cart.items[index], currency: currency),
              ),
            ),
          _OrderFooter(cart: cart, currency: currency, state: waiterState),
        ],
      ),
    );
  }
}

class _WaiterMobileCartBar extends ConsumerWidget {
  const _WaiterMobileCartBar({required this.cart, required this.currency});
  final CartState cart;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: context.theme.cardWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF1B1D0E).withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${cart.totalUnits} Items', style: GoogleFonts.inter(fontSize: 13, color: context.theme.colorScheme.onSurfaceVariant)),
              Text(currency.format(cart.totalAmount), style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700, color: context.theme.colorScheme.onSurface)),
            ],
          ),
          FilledButton.icon(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => _MobileOrderReviewSheet(currency: currency),
              );
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Review Order'),
            style: FilledButton.styleFrom(
              backgroundColor: context.theme.colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemTile extends ConsumerWidget {
  const _CartItemTile({required this.item, required this.currency});
  final CartItem item;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: context.theme.surfaceHighest, borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.fastfood, color: context.theme.colorScheme.primaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.productName, maxLines: 2, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: context.theme.colorScheme.onSurface)),
              Text(currency.format(item.price), style: GoogleFonts.inter(fontSize: 12, color: context.theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.remove_circle_outline, color: context.theme.colorScheme.onSurfaceVariant),
              onPressed: () => ref.read(cartProvider.notifier).decrementQuantity(item.productId),
            ),
            SizedBox(
              width: 24,
              child: Text('${item.quantity}', textAlign: TextAlign.center, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.theme.colorScheme.onSurface)),
            ),
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: item.isAtStockLimit ? context.theme.colorScheme.onSurfaceVariant.withOpacity(0.3) : context.theme.colorScheme.primary),
              onPressed: item.isAtStockLimit ? null : () => ref.read(cartProvider.notifier).incrementQuantity(item.productId),
            ),
          ],
        ),
      ],
    );
  }
}

class _OrderFooter extends ConsumerWidget {
  const _OrderFooter({required this.cart, required this.currency, required this.state});
  final CartState cart;
  final NumberFormat currency;
  final WaiterOrderState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: context.theme.surfaceLow, border: Border(top: BorderSide(color: context.theme.surfaceHighest, width: 1))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: GoogleFonts.inter(fontSize: 15, color: context.theme.colorScheme.onSurfaceVariant)),
              Text(currency.format(cart.totalAmount), style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: context.theme.colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: cart.isEmpty || state.isSubmitting
                  ? null
                  : () => ref.read(waiterOrderProvider.notifier).submitOrder(),
              style: FilledButton.styleFrom(
                backgroundColor: context.theme.colorScheme.primary,
                disabledBackgroundColor: context.theme.surfaceHighest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: state.isSubmitting
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: context.theme.colorScheme.onPrimary))
                  : Text('Send Order to Kitchen', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: cart.isEmpty ? context.theme.colorScheme.onSurfaceVariant : context.theme.colorScheme.onPrimary)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileOrderReviewSheet extends ConsumerWidget {
  const _MobileOrderReviewSheet({required this.currency});
  final NumberFormat currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(waiterOrderProvider);
    final cart = ref.watch(cartProvider);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: context.theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: context.theme.surfaceHighest, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Review Order', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w700, color: context.theme.colorScheme.onSurface)),
                IconButton(icon: Icon(Icons.close, color: context.theme.colorScheme.onSurfaceVariant), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: cart.items.length,
              separatorBuilder: (_, __) => Divider(color: context.theme.surfaceHighest, height: 24),
              itemBuilder: (context, index) => _CartItemTile(item: cart.items[index], currency: currency),
            ),
          ),
          _OrderFooter(cart: cart, currency: currency, state: state),
        ],
      ),
    );
  }
}
