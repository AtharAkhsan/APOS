import 'package:flutter/material.dart';
import 'package:apos/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../inventory/presentation/providers/product_notifier.dart';
import '../../../inventory/presentation/providers/categories_provider.dart';
import '../../../pos/domain/entities/product.dart';
import '../providers/cart_notifier.dart';
import '../providers/checkout_notifier.dart';
import '../../../../core/services/receipt_service.dart';
import '../../../../core/widgets/outlet_selector.dart';
import '../../../../core/providers/active_outlet_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../widgets/qris_dialog.dart';

/// ════════════════════════════════════════════════════════════
/// POS PAGE — "The Artisanal Interface" cashier screen
/// Matches the Stitch General Ledger design system exactly.
/// ════════════════════════════════════════════════════════════

// ── Design Tokens ────────────────────────────────────────────
class PosPage extends ConsumerStatefulWidget {
  const PosPage({super.key});

  @override
  ConsumerState<PosPage> createState() => _PosPageState();
}

class _PosPageState extends ConsumerState<PosPage> {
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

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    // Listen for checkout results
    ref.listen<AsyncValue<CheckoutResult?>>(
      checkoutControllerProvider,
      (prev, next) {
        if (next is AsyncData<CheckoutResult?> && next.value != null) {
          _showSuccessDialog(context, ref, next.value!);
        }
        if (next is AsyncError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Checkout failed: ${next.error}'),
              backgroundColor: context.theme.colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 720;

        if (isWide) {
          // ── Desktop: product grid + cart panel ────────────
          return Row(
            children: [
              // Main product area
              Expanded(
                flex: 3,
                child: _buildProductSection(context, isDesktop: true),
              ),
              // Cart panel (white background, like Stitch "Current Order")
              SizedBox(
                width: constraints.maxWidth * 0.30,
                child: _DesktopCartPanel(cart: cart, currency: _currency),
              ),
            ],
          );
        }

        // ── Mobile: product grid + floating cart bar ──────
        return Stack(
          children: [
            _buildProductSection(context, isDesktop: false),
            if (!cart.isEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _MobileCartBar(cart: cart, currency: _currency),
              ),
          ],
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  // PRODUCT SECTION (shared between mobile and desktop)
  // ════════════════════════════════════════════════════════════

  Widget _buildProductSection(BuildContext context, {required bool isDesktop}) {
    final productsAsync = ref.watch(productNotifierProvider);

    return Scaffold(
      backgroundColor: context.theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: context.theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 24,
        title: Text(
          'POS Terminal',
          style: GoogleFonts.manrope(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: context.theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          const OutletSelector(),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.notifications_none_rounded, color: context.theme.colorScheme.onSurface),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.only(right: 20),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.person_outline, 
              color: context.theme.brightness == Brightness.dark 
                  ? const Color(0xFFF0BD8B) 
                  : context.theme.colorScheme.onPrimary, 
              size: 20
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search Bar ─────────────────────────────────
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
                style: GoogleFonts.inter(fontSize: 14, color: context.theme.colorScheme.onSurface),
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

          // ── Category Chips ─────────────────────────────
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

          // ── Product Grid ───────────────────────────────
          Expanded(
            child: productsAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: context.theme.colorScheme.primary,
                  strokeWidth: 2,
                ),
              ),
              error: (err, _) => _ErrorState(
                onRetry: () =>
                    ref.read(productNotifierProvider.notifier).refresh(),
              ),
              data: (products) {
                // Resolve category name → id for filtering
                final categoriesAsync = ref.watch(categoriesProvider);
                final categoryMap = <String, String>{}; // name → id
                if (categoriesAsync is AsyncData<List<Category>>) {
                  for (final c in categoriesAsync.value) {
                    categoryMap[c.name] = c.id;
                  }
                }

                // Filter
                var filtered = products.where((p) {
                  final matchesSearch = _searchQuery.isEmpty ||
                      p.name.toLowerCase().contains(_searchQuery) ||
                      p.sku.toLowerCase().contains(_searchQuery);
                  if (_selectedCategory == 'All') return matchesSearch;
                  final targetCatId = categoryMap[_selectedCategory];
                  final matchesCategory = targetCatId != null &&
                      p.categoryId == targetCatId;
                  return matchesSearch && matchesCategory;
                }).toList();

                if (filtered.isEmpty) {
                  return _EmptyState();
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = isDesktop
                        ? (constraints.maxWidth > 900 ? 4 : 3)
                        : 2;

                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: isDesktop ? 0.78 : 0.75,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        return _ArtisanalProductCard(
                          product: filtered[index],
                          currency: _currency,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // SUCCESS DIALOG
  // ════════════════════════════════════════════════════════════

  void _showSuccessDialog(
      BuildContext context, WidgetRef ref, CheckoutResult result) {
    final activeOutlet = ref.read(activeOutletProvider);
    final profile = ref.read(userProfileProvider).valueOrNull;
    final cart = ref.read(cartProvider);
    
    // In case the active outlet isn't set, default to profile's assigned outlet
    final outletId = activeOutlet?.id ?? profile?.outletId;
    final cashierName = profile?.displayName ?? 'System Account';
    final orderType = cart.orderType;

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
          'Transaction Successful!',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            color: context.theme.colorScheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Journal Entry Created',
              style: GoogleFonts.inter(
                color: context.theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            _InfoRow(label: 'Reference', value: result.referenceNo),
            _InfoRow(
              label: 'Total',
              value: _currency.format(result.totalAmount),
              isBold: true,
            ),
            _InfoRow(label: 'Payment', value: result.paymentMethod),
            _InfoRow(label: 'Items', value: '${result.itemCount} products'),
            _InfoRow(
              label: 'COGS',
              value: _currency.format(result.totalCogs),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ReceiptService.generateAndPrintReceipt(
                      transaction: result,
                      items: result.receiptItems,
                      cashierName: cashierName,
                      outletId: outletId,
                      outletName: activeOutlet?.name,
                      outletAddress: activeOutlet?.address,
                      outletPhone: activeOutlet?.phone,
                      orderType: orderType,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: context.theme.outlineVariantCustom),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(Icons.print, size: 18, color: context.theme.colorScheme.primary),
                  label: Text('Print',
                      style: GoogleFonts.inter(color: context.theme.colorScheme.primary)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ref.read(checkoutControllerProvider.notifier).reset();
                    ref.read(productNotifierProvider.notifier).refresh();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: context.theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Done', style: GoogleFonts.inter(color: context.theme.colorScheme.onPrimary)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// CATEGORY CHIP
// ════════════════════════════════════════════════════════════

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
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

// ════════════════════════════════════════════════════════════
// PRODUCT CARD — Artisanal Style
// ════════════════════════════════════════════════════════════

class _ArtisanalProductCard extends ConsumerWidget {
  const _ArtisanalProductCard({
    required this.product,
    required this.currency,
  });
  final Product product;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOutOfStock = product.currentStock <= 0;
    final isLowStock =
        product.currentStock > 0 && product.currentStock <= 5;

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
                      result.ok
                          ? '${product.name} added to cart'
                          : result.message ?? 'Stock limit reached',
                      style: GoogleFonts.inter(
                        color: result.ok ? context.theme.onAccentButton : null,
                      ),
                    ),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: result.ok ? context.theme.accentButton : context.theme.colorScheme.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
            // Ambient shadow from design spec
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1B1D0E).withOpacity(0.04),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Product Image Placeholder ─────────────
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: context.theme.surfaceHighest,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            context.theme.colorScheme.primaryContainer.withOpacity(0.15),
                            context.theme.surfaceHighest,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.coffee_rounded,
                          size: 40,
                          color: context.theme.colorScheme.primaryContainer,
                        ),
                      ),
                    ),
                    // ── Stock Badge ────────────────────────
                    if (isLowStock || isOutOfStock)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isOutOfStock
                                ? context.theme.colorScheme.errorContainer
                                : context.theme.tertiaryFixedDim,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isOutOfStock
                                ? 'OUT'
                                : 'LOW STOCK',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: isOutOfStock
                                  ? context.theme.colorScheme.error
                                  : context.theme.onTertiaryFixed,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // ── Product Info ──────────────────────────
              Expanded(
                flex: 2,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              product.sku,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: context.theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              currency.format(product.sellingPrice),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: context.theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Stock count chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isOutOfStock
                                  ? context.theme.colorScheme.errorContainer
                                  : isLowStock
                                      ? context.theme.tertiaryFixedDim.withOpacity(0.5)
                                      : context.theme.surfaceHighest,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${product.currentStock}',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: isOutOfStock
                                    ? context.theme.colorScheme.error
                                    : context.theme.colorScheme.onSurfaceVariant,
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
// DESKTOP CART PANEL — "Current Order" (Right Column)
// ════════════════════════════════════════════════════════════

class _DesktopCartPanel extends ConsumerWidget {
  const _DesktopCartPanel({required this.cart, required this.currency});
  final CartState cart;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkout = ref.watch(checkoutControllerProvider);

    return Container(
      color: context.theme.cardWhite,
      child: Column(
        children: [
          // ── Header ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Order',
                        style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: context.theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${cart.totalUnits} items • ${DateFormat('hh:mm a').format(DateTime.now())}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: context.theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!cart.isEmpty)
                  GestureDetector(
                    onTap: () => ref.read(cartProvider.notifier).clear(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.theme.surfaceHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.delete_outline,
                          size: 18, color: context.theme.colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Order Type Toggle ───────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: ['Dine In', 'Take Away'].map((type) {
                final isSelected = cart.orderType == type;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => ref.read(cartProvider.notifier).setOrderType(type),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.theme.colorScheme.primary
                            : context.theme.surfaceHighest,
                        borderRadius: type == 'Dine In'
                            ? const BorderRadius.horizontal(left: Radius.circular(10))
                            : const BorderRadius.horizontal(right: Radius.circular(10)),
                      ),
                      child: Center(
                        child: Text(
                          type,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? context.theme.colorScheme.onPrimary
                                : context.theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // ── Cart Items ─────────────────────────────────
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 48, color: context.theme.outlineVariantCustom),
                        const SizedBox(height: 12),
                        Text('No items yet',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: context.theme.colorScheme.onSurfaceVariant,
                            )),
                        const SizedBox(height: 4),
                        Text('Tap a product to add it',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: context.theme.outlineVariantCustom,
                            )),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 20),
                    itemBuilder: (context, index) {
                      return _ArtisanalCartItem(
                        item: cart.items[index],
                        currency: currency,
                        ref: ref,
                      );
                    },
                  ),
          ),

          // ── Checkout Footer ────────────────────────────
          if (!cart.isEmpty)
            _ArtisanalCheckoutBar(
              cart: cart,
              currency: currency,
              isLoading: checkout.isLoading,
              onCheckout: () =>
                  ref.read(checkoutControllerProvider.notifier).processCheckout(),
              onQris: () => showQrisDialog(context, ref),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// CART ITEM (Artisanal Style — no borders, whitespace separator)
// ════════════════════════════════════════════════════════════

class _ArtisanalCartItem extends StatelessWidget {
  const _ArtisanalCartItem({
    required this.item,
    required this.currency,
    required this.ref,
  });
  final CartItem item;
  final NumberFormat currency;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Info ────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    currency.format(item.subtotal),
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '@ ${currency.format(item.price)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              // ── Quantity Controls ─────────────────────
              Row(
                children: [
                  _ArtisanalQtyButton(
                    icon: item.quantity == 1
                        ? Icons.delete_outline
                        : Icons.remove,
                    color: item.quantity == 1 ? context.theme.colorScheme.error : context.theme.colorScheme.onSurfaceVariant,
                    onTap: () => ref
                        .read(cartProvider.notifier)
                        .decrementQuantity(item.productId),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '${item.quantity}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: context.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  _ArtisanalQtyButton(
                    icon: Icons.add,
                    color: item.isAtStockLimit
                        ? context.theme.outlineVariantCustom
                        : context.theme.colorScheme.onSurfaceVariant,
                    onTap: () {
                      final ok = ref
                          .read(cartProvider.notifier)
                          .incrementQuantity(item.productId);
                      if (!ok) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(
                                'Stock limit: only ${item.availableStock} '
                                'units of "${item.productName}" available.',
                                style: GoogleFonts.inter(),
                              ),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: context.theme.colorScheme.error,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArtisanalQtyButton extends StatelessWidget {
  const _ArtisanalQtyButton({
    required this.icon,
    required this.onTap,
    required this.color,
  });
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: context.theme.surfaceHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// CHECKOUT BAR — Artisanal Style
// ════════════════════════════════════════════════════════════

class _ArtisanalCheckoutBar extends StatelessWidget {
  const _ArtisanalCheckoutBar({
    required this.cart,
    required this.currency,
    required this.isLoading,
    required this.onCheckout,
    required this.onQris,
  });
  final CartState cart;
  final NumberFormat currency;
  final bool isLoading;
  final VoidCallback onCheckout;
  final VoidCallback onQris;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: context.theme.cardWhite,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Summary ──────────────────────────────────
            _SummaryLine(
              label: 'Subtotal',
              value: currency.format(cart.totalAmount),
            ),
            const SizedBox(height: 12),
            // ── Total ────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  currency.format(cart.totalAmount),
                  style: GoogleFonts.manrope(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: context.theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ── Pay Buttons ──────────────────────────────
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: isLoading ? null : onCheckout,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        side: BorderSide(color: context.theme.outlineVariantCustom),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isLoading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: context.theme.colorScheme.primary),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.payments_outlined,
                                    size: 16, color: context.theme.colorScheme.primary),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Cash',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      color: context.theme.colorScheme.primary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // QRIS / Charge button — the "signature gradient"
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: context.theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        onPressed: isLoading ? null : onQris,
                        style: ElevatedButton.styleFrom(
                          
                          
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: context.theme.colorScheme.onPrimary),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.qr_code_2,
                                      size: 18, color: context.theme.colorScheme.onPrimary),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Charge Order',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        color: context.theme.colorScheme.onPrimary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, color: context.theme.colorScheme.onSurfaceVariant),
        ),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 13, color: context.theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
// MOBILE CART BAR (Floating pill at bottom)
// ════════════════════════════════════════════════════════════

class _MobileCartBar extends ConsumerWidget {
  const _MobileCartBar({required this.cart, required this.currency});
  final CartState cart;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _openCartSheet(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          // Signature gradient
          color: context.theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: context.theme.colorScheme.primary.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: context.theme.colorScheme.onPrimary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Badge(
                label: Text(
                  '${cart.totalUnits}',
                  style: GoogleFonts.inter(fontSize: 10),
                ),
                child: Icon(Icons.shopping_cart_outlined,
                    color: context.theme.colorScheme.onPrimary, size: 20),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              '${cart.distinctCount} items',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                color: context.theme.colorScheme.onPrimary.withOpacity(0.85),
              ),
            ),
            const Spacer(),
            Text(
              currency.format(cart.totalAmount),
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.theme.colorScheme.onPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios,
                size: 14, color: context.theme.colorScheme.onPrimary),
          ],
        ),
      ),
    );
  }

  void _openCartSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.theme.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return _MobileCartSheet(
            currency: currency,
            scrollController: scrollController,
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// MOBILE CART BOTTOM SHEET
// ════════════════════════════════════════════════════════════

class _MobileCartSheet extends ConsumerWidget {
  const _MobileCartSheet({
    required this.currency,
    required this.scrollController,
  });
  final NumberFormat currency;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(cartProvider, (previous, next) {
      if ((previous?.items.isNotEmpty ?? false) && next.items.isEmpty) {
        if (Navigator.canPop(context)) Navigator.pop(context);
      }
    });

    final cart = ref.watch(cartProvider);
    final checkout = ref.watch(checkoutControllerProvider);

    return Column(
      children: [
        // ── Drag handle ──────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: context.theme.surfaceDim,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // ── Header ───────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Text(
                'Current Order',
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  ref.read(cartProvider.notifier).clear();
                  Navigator.pop(context);
                },
                child: Text(
                  'Clear',
                  style: GoogleFonts.inter(
                    color: context.theme.colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // ── Items list ───────────────────────────────
        Expanded(
          child: ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: cart.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 20),
            itemBuilder: (context, index) {
              return _ArtisanalCartItem(
                item: cart.items[index],
                currency: currency,
                ref: ref,
              );
            },
          ),
        ),
        // ── Checkout bar ─────────────────────────────
        _ArtisanalCheckoutBar(
          cart: cart,
          currency: currency,
          isLoading: checkout.isLoading,
          onCheckout: () {
            Navigator.pop(context);
            ref.read(checkoutControllerProvider.notifier).processCheckout();
          },
          onQris: () {
            Navigator.pop(context);
            showQrisDialog(context, ref);
          },
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
// ERROR & EMPTY STATES
// ════════════════════════════════════════════════════════════

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: context.theme.outlineVariantCustom),
          const SizedBox(height: 12),
          Text(
            'Failed to load products',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: context.theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: context.theme.outlineVariantCustom),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: Icon(Icons.refresh, size: 18, color: context.theme.colorScheme.primary),
            label: Text('Retry', style: GoogleFonts.inter(color: context.theme.colorScheme.primary)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storefront_outlined,
              size: 64, color: context.theme.outlineVariantCustom),
          const SizedBox(height: 12),
          Text(
            'No products available',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: context.theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add products from the Inventory tab.',
            style: GoogleFonts.inter(fontSize: 13, color: context.theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// SUCCESS DIALOG INFO ROW
// ════════════════════════════════════════════════════════════

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });
  final String label;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(color: context.theme.colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: isBold ? context.theme.colorScheme.primary : context.theme.colorScheme.onSurface,
              fontSize: isBold ? 16 : 13,
            ),
          ),
        ],
      ),
    );
  }
}
