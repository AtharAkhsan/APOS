import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:toempah_rempah/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/product_notifier.dart';
import '../providers/categories_provider.dart';
import '../../../pos/domain/entities/product.dart';
import '../../../../core/widgets/outlet_selector.dart';
import '../../../../core/providers/active_outlet_provider.dart';

/// ════════════════════════════════════════════════════════════
/// INVENTORY PAGE — "The Artisanal Interface" design system
/// Full CRUD: Create, Read, Update, Delete
/// ════════════════════════════════════════════════════════════

// ── Design Tokens ────────────────────────────────────────────
class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _stockFilter = 'All'; // All, Low Stock, Out of Stock

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
    final activeOutlet = ref.watch(activeOutletProvider);
    final productsAsync = ref.watch(productNotifierProvider);

    return Scaffold(
      backgroundColor: context.theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: context.theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 24,
        title: Text(
          'Inventory',
          style: GoogleFonts.manrope(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: context.theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          const OutletSelector(allowAll: true),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.theme.colorScheme.onSurfaceVariant),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(productNotifierProvider.notifier).refresh(),
          ),
          const SizedBox(width: 8),
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
                  hintText: 'Search products...',
                  hintStyle:
                      GoogleFonts.inter(fontSize: 14, color: context.theme.colorScheme.onSurfaceVariant),
                  prefixIcon:
                      Icon(Icons.search, color: context.theme.colorScheme.onSurfaceVariant, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          // ── Stock Filter Chips ─────────────────────────
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: ['All', 'In Stock', 'Low Stock', 'Out of Stock']
                  .map((filter) => _FilterChip(
                        label: filter,
                        isSelected: _stockFilter == filter,
                        onTap: () => setState(() => _stockFilter = filter),
                      ))
                  .toList(),
            ),
          ),

          const SizedBox(height: 8),

          // ── Inventory Stats Bar ────────────────────────
          productsAsync.whenData((products) {
            final total = products.length;
            final inStock =
                products.where((p) => p.currentStock > 5).length;
            final lowStock =
                products.where((p) => p.currentStock > 0 && p.currentStock <= 5).length;
            final outOfStock =
                products.where((p) => p.currentStock <= 0).length;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  _StatChip(
                    label: 'Total',
                    value: '$total',
                    color: context.theme.surfaceHighest,
                    textColor: context.theme.colorScheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    label: 'In Stock',
                    value: '$inStock',
                    color: context.theme.stockInBg,
                    textColor: context.theme.stockInFg,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    label: 'Low Stock',
                    value: '$lowStock',
                    color: context.theme.stockLowBg,
                    textColor: context.theme.stockLowFg,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    label: 'Out',
                    value: '$outOfStock',
                    color: context.theme.colorScheme.errorContainer,
                    textColor: context.theme.colorScheme.error,
                  ),
                ],
              ),
            );
          }).value ?? const SizedBox.shrink(),

          const SizedBox(height: 8),

          // ── Product List ───────────────────────────────
          Expanded(
            child: productsAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: context.theme.colorScheme.primary,
                  strokeWidth: 2,
                ),
              ),
              error: (err, _) => _ErrorState(
                message: err.toString(),
                onRetry: () =>
                    ref.read(productNotifierProvider.notifier).refresh(),
              ),
              data: (products) {
                // Apply filters
                var filtered = products.where((p) {
                  final matchesSearch = _searchQuery.isEmpty ||
                      p.name.toLowerCase().contains(_searchQuery) ||
                      p.sku.toLowerCase().contains(_searchQuery);

                  bool matchesStock = true;
                  switch (_stockFilter) {
                    case 'In Stock':
                      matchesStock = p.currentStock > 5;
                      break;
                    case 'Low Stock':
                      matchesStock =
                          p.currentStock > 0 && p.currentStock <= 5;
                      break;
                    case 'Out of Stock':
                      matchesStock = p.currentStock <= 0;
                      break;
                  }

                  return matchesSearch && matchesStock;
                }).toList();

                if (filtered.isEmpty) {
                  return _EmptyState(
                    hasProducts: products.isNotEmpty,
                    onAdd: () => _showProductDialog(context, ref),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 720) {
                      return _DesktopInventoryTable(
                        products: filtered,
                        currency: _currency,
                        onEdit: activeOutlet != null ? (p) => _showProductDialog(context, ref, product: p) : null,
                        onDelete: activeOutlet != null ? (id) => _confirmDelete(context, ref, id) : null,
                      );
                    }
                    return _MobileInventoryList(
                      products: filtered,
                      currency: _currency,
                      onEdit: activeOutlet != null ? (p) => _showProductDialog(context, ref, product: p) : null,
                      onDelete: activeOutlet != null ? (id) => _confirmDelete(context, ref, id) : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // ── FAB ────────────────────────────────────────────
      floatingActionButton: activeOutlet == null ? null : Container(
        decoration: BoxDecoration(
          color: context.theme.accentButton,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: context.theme.accentButton.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _showProductDialog(context, ref),
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: Icon(Icons.add_rounded, color: context.theme.onAccentButton),
          label: Text(
            'Add Product',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: context.theme.onAccentButton,
            ),
          ),
        ),
      ),
    );
  }

  // ── Show Add/Edit Dialog ────────────────────────────────
  void _showProductDialog(BuildContext context, WidgetRef ref,
      {Product? product}) {
    showDialog(
      context: context,
      builder: (_) => _ProductFormDialog(product: product),
    );
  }

  // ── Confirm Delete ──────────────────────────────────────
  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.theme.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.theme.colorScheme.errorContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.delete_outline, color: context.theme.colorScheme.error, size: 28),
        ),
        title: Text(
          'Delete Product',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            color: context.theme.colorScheme.onSurface,
          ),
        ),
        content: Text(
          'This product will be deactivated and hidden from the list. Continue?',
          style: GoogleFonts.inter(color: context.theme.colorScheme.onSurfaceVariant, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: context.theme.outlineVariantCustom),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Cancel',
                      style: GoogleFonts.inter(color: context.theme.colorScheme.onSurfaceVariant)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.theme.colorScheme.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    ref
                        .read(productNotifierProvider.notifier)
                        .deactivateProduct(id);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Product deactivated',
                            style: GoogleFonts.inter()),
                        backgroundColor: context.theme.colorScheme.primaryContainer,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                  child: Text('Delete',
                      style: GoogleFonts.inter(color: context.theme.colorScheme.onPrimary)),
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
// FILTER CHIP
// ════════════════════════════════════════════════════════════

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
// STAT CHIP (top summary bar)
// ════════════════════════════════════════════════════════════

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.textColor,
  });
  final String label;
  final String value;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: textColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// DESKTOP — Inventory Table
// ════════════════════════════════════════════════════════════

class _DesktopInventoryTable extends StatelessWidget {
  const _DesktopInventoryTable({
    required this.products,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Product> products;
  final NumberFormat currency;
  final void Function(Product)? onEdit;
  final void Function(String id)? onDelete;

  @override
  Widget build(BuildContext context) {
    final headerStyle = GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: context.theme.colorScheme.onSurfaceVariant,
    );
    final bodyStyle = GoogleFonts.inter(fontSize: 13, color: context.theme.colorScheme.onSurface);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: context.theme.cardWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1B1D0E).withOpacity(0.04),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Table Header ──────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: context.theme.surfaceLow,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.inventory_2_rounded,
                      color: context.theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    '${products.length} Products',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            // ── Column Headers ────────────────────────
            Container(
              color: context.theme.surfaceHighest.withOpacity(0.3),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text('SKU', style: headerStyle)),
                  Expanded(flex: 4, child: Text('Product Name', style: headerStyle)),
                  Expanded(flex: 3, child: Text('Purchase', style: headerStyle, textAlign: TextAlign.right)),
                  Expanded(flex: 3, child: Text('Selling', style: headerStyle, textAlign: TextAlign.right)),
                  Expanded(flex: 2, child: Text('Margin', style: headerStyle, textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('Stock', style: headerStyle, textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('Unit', style: headerStyle, textAlign: TextAlign.center)),
                  SizedBox(width: 80, child: Text('Actions', style: headerStyle, textAlign: TextAlign.center)),
                ],
              ),
            ),
            // ── Data Rows ────────────────────────────
            ...products.map((p) {
              final isLowStock = p.currentStock > 0 && p.currentStock <= 5;
              final isOutOfStock = p.currentStock <= 0;
              final margin = p.sellingPrice - p.purchasePrice;
              final marginPct = p.purchasePrice > 0
                  ? (margin / p.purchasePrice * 100)
                  : 0.0;

              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: context.theme.surfaceHighest.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        p.sku,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: context.theme.colorScheme.primary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        p.name,
                        style: bodyStyle.copyWith(fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        currency.format(p.purchasePrice),
                        style: bodyStyle,
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        currency.format(p.sellingPrice),
                        style: bodyStyle.copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: margin > 0
                                ? context.theme.tertiaryFixedDim.withOpacity(0.3)
                                : context.theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${marginPct.toStringAsFixed(0)}%',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: margin > 0 ? context.theme.colorScheme.tertiary : context.theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: _StockBadge(
                          stock: p.currentStock,
                          isLow: isLowStock,
                          isOut: isOutOfStock,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(p.unit, style: bodyStyle, textAlign: TextAlign.center),
                    ),
                    SizedBox(
                      width: 80,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (onEdit != null) ...[
                            _ActionIcon(
                              icon: Icons.edit_outlined,
                              color: context.theme.colorScheme.primary,
                              tooltip: 'Edit',
                              onTap: () => onEdit!(p),
                            ),
                            const SizedBox(width: 4),
                            _ActionIcon(
                              icon: Icons.delete_outline,
                              color: context.theme.colorScheme.error,
                              tooltip: 'Delete',
                              onTap: () => onDelete!(p.id),
                            ),
                          ] else ...[
                            Icon(Icons.block, size: 16, color: context.theme.colorScheme.onSurfaceVariant),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// MOBILE — Inventory Card List
// ════════════════════════════════════════════════════════════

class _MobileInventoryList extends StatelessWidget {
  const _MobileInventoryList({
    required this.products,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Product> products;
  final NumberFormat currency;
  final void Function(Product)? onEdit;
  final void Function(String id)? onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final p = products[index];
        final isLowStock = p.currentStock > 0 && p.currentStock <= 5;
        final isOutOfStock = p.currentStock <= 0;
        final margin = p.sellingPrice - p.purchasePrice;
        final marginPct = p.purchasePrice > 0
            ? (margin / p.purchasePrice * 100)
            : 0.0;

        return GestureDetector(
          onTap: () => onEdit?.call(p),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.theme.cardWhite,
              borderRadius: BorderRadius.circular(16),
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
                // ── Title Row ──────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.theme.surfaceHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.inventory_2_rounded,
                          color: context.theme.colorScheme.primaryContainer, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: context.theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            p.sku,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: context.theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StockBadge(
                      stock: p.currentStock,
                      isLow: isLowStock,
                      isOut: isOutOfStock,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // ── Price Row ──────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _PriceTag(
                            label: 'Buy',
                            value: currency.format(p.purchasePrice),
                            bgColor: context.theme.colorScheme.secondaryContainer,
                            textColor: context.theme.colorScheme.onSecondaryContainer,
                          ),
                          _PriceTag(
                            label: 'Sell',
                            value: currency.format(p.sellingPrice),
                            bgColor: context.theme.surfaceHighest,
                            textColor: context.theme.colorScheme.primary,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: margin > 0
                                  ? context.theme.tertiaryFixedDim.withOpacity(0.3)
                                  : context.theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${marginPct.toStringAsFixed(0)}% margin',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: margin > 0 ? context.theme.colorScheme.tertiary : context.theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (onEdit != null) ...[
                      _ActionIcon(
                        icon: Icons.edit_outlined,
                        color: context.theme.colorScheme.primary,
                        tooltip: 'Edit',
                        onTap: () => onEdit!(p),
                      ),
                      const SizedBox(width: 4),
                      _ActionIcon(
                        icon: Icons.delete_outline,
                        color: context.theme.colorScheme.error,
                        tooltip: 'Delete',
                        onTap: () => onDelete!(p.id),
                      ),
                    ] else ...[
                      Icon(Icons.block, size: 16, color: context.theme.colorScheme.onSurfaceVariant),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════
// SHARED COMPONENTS
// ════════════════════════════════════════════════════════════

class _StockBadge extends StatelessWidget {
  const _StockBadge({
    required this.stock,
    required this.isLow,
    required this.isOut,
  });
  final int stock;
  final bool isLow;
  final bool isOut;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String text;

    if (isOut) {
      bg = context.theme.colorScheme.errorContainer;
      fg = context.theme.colorScheme.error;
      text = 'OUT';
    } else if (isLow) {
      bg = context.theme.stockLowBg;
      fg = context.theme.stockLowFg;
      text = '$stock left';
    } else {
      bg = context.theme.stockInBg;
      fg = context.theme.stockInFg;
      text = '$stock';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _PriceTag extends StatelessWidget {
  const _PriceTag({
    required this.label,
    required this.value,
    required this.bgColor,
    required this.textColor,
  });
  final String label;
  final String value;
  final Color bgColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// PRODUCT FORM DIALOG — Create & Edit (CRUD)
// ════════════════════════════════════════════════════════════

class _ProductFormDialog extends ConsumerStatefulWidget {
  const _ProductFormDialog({this.product});
  final Product? product;

  @override
  ConsumerState<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends ConsumerState<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _skuCtrl;
  late final TextEditingController _purchasePriceCtrl;
  late final TextEditingController _sellingPriceCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _imageUrlCtrl;

  final _picker = ImagePicker();
  Uint8List? _selectedImageBytes;
  String? _selectedImageExtension;

  String? _selectedCategoryId;
  bool _isSubmitting = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _skuCtrl = TextEditingController(text: p?.sku ?? '');
    _purchasePriceCtrl = TextEditingController(
      text: p != null ? p.purchasePrice.toStringAsFixed(0) : '',
    );
    _sellingPriceCtrl = TextEditingController(
      text: p != null ? p.sellingPrice.toStringAsFixed(0) : '',
    );
    _stockCtrl = TextEditingController(
      text: p != null ? '${p.currentStock}' : '0',
    );
    _unitCtrl = TextEditingController(text: p?.unit ?? 'pcs');
    _imageUrlCtrl = TextEditingController(text: p?.imageUrl ?? '');
    _selectedCategoryId = p?.categoryId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _sellingPriceCtrl.dispose();
    _stockCtrl.dispose();
    _unitCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageExtension = image.name.contains('.') ? image.name.split('.').last : 'jpg';
          _imageUrlCtrl.clear(); // Clear manual URL if picking a file
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: context.theme.colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      String? finalImageUrl = _imageUrlCtrl.text.trim().isEmpty ? null : _imageUrlCtrl.text.trim();

      if (_selectedImageBytes != null) {
        final ext = _selectedImageExtension ?? 'jpg';
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
        final filePath = 'products/$fileName';

        try {
          await Supabase.instance.client.storage
              .from('product_images')
              .uploadBinary(
                filePath,
                _selectedImageBytes!,
                fileOptions: FileOptions(contentType: 'image/$ext'),
              );
          finalImageUrl = Supabase.instance.client.storage
              .from('product_images')
              .getPublicUrl(filePath);
        } catch (e) {
          throw Exception('Failed to upload image: $e');
        }
      }

      final product = Product(
        id: widget.product?.id ?? '',
        name: _nameCtrl.text.trim(),
        sku: _skuCtrl.text.trim().toUpperCase(),
        categoryId: _selectedCategoryId,
        imageUrl: finalImageUrl,
        purchasePrice: double.parse(_purchasePriceCtrl.text.trim()),
        sellingPrice: double.parse(_sellingPriceCtrl.text.trim()),
        currentStock: int.parse(_stockCtrl.text.trim()),
        unit: _unitCtrl.text.trim().isEmpty ? 'pcs' : _unitCtrl.text.trim(),
      );

      if (_isEditing) {
        await ref.read(productNotifierProvider.notifier).updateProduct(product);
      } else {
        await ref.read(productNotifierProvider.notifier).addProduct(product);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? '${product.name} updated!'
                  : '${product.name} added!',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: context.theme.colorScheme.primaryContainer,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.inter()),
            backgroundColor: context.theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 600;

    return Dialog(
      backgroundColor: context.theme.cardWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isWide ? 120 : 20,
        vertical: 40,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ──────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _isEditing
                              ? context.theme.surfaceHighest
                              : context.theme.tertiaryFixedDim.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _isEditing
                              ? Icons.edit_rounded
                              : Icons.add_box_rounded,
                          color: _isEditing ? context.theme.colorScheme.primary : context.theme.colorScheme.tertiary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEditing ? 'Edit Product' : 'Add New Product',
                              style: GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: context.theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isEditing
                                  ? 'Update the product details below.'
                                  : 'Fill in the product details below.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: context.theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: context.theme.surfaceHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.close, size: 16,
                              color: context.theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Product Name ────────────────────────
                  _ArtisanalField(
                    controller: _nameCtrl,
                    label: 'Product Name',
                    hint: 'e.g. Indomie Goreng',
                    icon: Icons.label_outline,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Name is required'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // ── SKU ─────────────────────────────────
                  _ArtisanalField(
                    controller: _skuCtrl,
                    label: 'SKU',
                    hint: 'e.g. IDM-GRG-001',
                    icon: Icons.qr_code,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9\-]')),
                    ],
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'SKU is required'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // ── Category Dropdown ────────────────────
                  Consumer(
                    builder: (context, ref, _) {
                      final categoriesAsync = ref.watch(categoriesProvider);
                      return categoriesAsync.when(
                        loading: () => _ArtisanalField(
                          controller: TextEditingController(),
                          label: 'Category',
                          hint: 'Loading...',
                          icon: Icons.category_outlined,
                          enabled: false,
                        ),
                        error: (_, __) => _ArtisanalField(
                          controller: TextEditingController(),
                          label: 'Category',
                          hint: 'Failed to load categories',
                          icon: Icons.category_outlined,
                          enabled: false,
                        ),
                        data: (categories) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 4, bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(Icons.category_outlined,
                                        size: 14, color: context.theme.colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Category',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: context.theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DropdownButtonFormField<String?>(
                                initialValue: _selectedCategoryId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: context.theme.surfaceHighest.withOpacity(0.4),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: context.theme.colorScheme.primary.withOpacity(0.3), width: 1),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                ),
                                hint: Text(
                                  'Select a category',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: context.theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                                  ),
                                ),
                                style: GoogleFonts.inter(
                                    fontSize: 14, color: context.theme.colorScheme.onSurface),
                                dropdownColor: context.theme.cardWhite,
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('No Category',
                                        style: GoogleFonts.inter(
                                            color: context.theme.colorScheme.onSurfaceVariant)),
                                  ),
                                  ...categories.map((c) =>
                                      DropdownMenuItem<String?>(
                                        value: c.id,
                                        child: Text(c.name),
                                      )),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedCategoryId = v),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Image ────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.image_outlined,
                            size: 14, color: context.theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          'Product Image',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickImage,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: context.theme.outlineVariantCustom),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: Icon(Icons.upload_file_rounded, size: 18, color: context.theme.colorScheme.primary),
                          label: Text('Upload Image', style: GoogleFonts.inter(color: context.theme.colorScheme.primary)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('OR', style: GoogleFonts.inter(fontSize: 12, color: context.theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _ArtisanalField(
                          controller: _imageUrlCtrl,
                          label: '', // Hidden due to section header
                          hint: 'https://example.com/image.jpg',
                          icon: Icons.link,
                          keyboardType: TextInputType.url,
                          onChanged: (_) => setState(() {
                            if (_imageUrlCtrl.text.isNotEmpty) {
                              _selectedImageBytes = null;
                            }
                          }),
                        ),
                      ),
                    ],
                  ),
                  // ── Image Preview ────────────────────────
                  if (_selectedImageBytes != null || _imageUrlCtrl.text.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          color: context.theme.surfaceHighest.withOpacity(0.3),
                          child: _selectedImageBytes != null
                              ? Image.memory(
                                  _selectedImageBytes!,
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  _imageUrlCtrl.text.trim(),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.broken_image_outlined,
                                            size: 32, color: context.theme.colorScheme.onSurfaceVariant),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Invalid image URL',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: context.theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // ── Prices (side by side on wide) ───────
                  if (isWide)
                    Row(
                      children: [
                        Expanded(
                          child: _ArtisanalField(
                            controller: _purchasePriceCtrl,
                            label: 'Purchase Price',
                            hint: '0',
                            icon: Icons.arrow_downward_rounded,
                            prefixText: 'Rp ',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            validator: _priceValidator,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ArtisanalField(
                            controller: _sellingPriceCtrl,
                            label: 'Selling Price',
                            hint: '0',
                            icon: Icons.arrow_upward_rounded,
                            prefixText: 'Rp ',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            validator: _priceValidator,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _ArtisanalField(
                      controller: _purchasePriceCtrl,
                      label: 'Purchase Price',
                      hint: '0',
                      icon: Icons.arrow_downward_rounded,
                      prefixText: 'Rp ',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      validator: _priceValidator,
                    ),
                    const SizedBox(height: 16),
                    _ArtisanalField(
                      controller: _sellingPriceCtrl,
                      label: 'Selling Price',
                      hint: '0',
                      icon: Icons.arrow_upward_rounded,
                      prefixText: 'Rp ',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      validator: _priceValidator,
                    ),
                  ],
                  const SizedBox(height: 16),

                  // ── Stock & Unit (side by side) ─────────
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _ArtisanalField(
                          controller: _stockCtrl,
                          label: 'Stock',
                          hint: '0',
                          icon: Icons.inventory_rounded,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            final n = int.tryParse(v.trim());
                            if (n == null || n < 0) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ArtisanalField(
                          controller: _unitCtrl,
                          label: 'Unit',
                          hint: 'pcs',
                          icon: Icons.straighten_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Actions ─────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: context.theme.outlineVariantCustom),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text('Cancel',
                              style: GoogleFonts.inter(
                                  color: context.theme.colorScheme.onSurfaceVariant)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            color: context.theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              
                              
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: _isSubmitting
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: context.theme.colorScheme.onPrimary,
                                    ),
                                  )
                                : Icon(
                                    _isEditing
                                        ? Icons.save_rounded
                                        : Icons.add_rounded,
                                    color: context.theme.colorScheme.onPrimary,
                                    size: 18,
                                  ),
                            label: Text(
                              _isSubmitting
                                  ? 'Saving...'
                                  : _isEditing
                                      ? 'Update Product'
                                      : 'Save Product',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: context.theme.colorScheme.onPrimary,
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
          ),
        ),
      ),
    );
  }

  String? _priceValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final n = double.tryParse(v.trim());
    if (n == null || n < 0) return 'Invalid price';
    return null;
  }
}

// ════════════════════════════════════════════════════════════
// ARTISANAL TEXT FIELD
// ════════════════════════════════════════════════════════════

class _ArtisanalField extends StatelessWidget {
  const _ArtisanalField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.prefixText,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? prefixText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 14, color: context.theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          validator: validator,
          enabled: enabled,
          onChanged: onChanged,
          style: GoogleFonts.inter(fontSize: 14, color: context.theme.colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
                fontSize: 14, color: context.theme.outlineVariantCustom),
            prefixText: prefixText,
            prefixStyle: GoogleFonts.inter(
              color: context.theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: context.theme.surfaceHighest.withOpacity(0.4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: context.theme.colorScheme.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.theme.colorScheme.error, width: 1),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
// EMPTY & ERROR STATES
// ════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasProducts, required this.onAdd});
  final bool hasProducts;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 64, color: context.theme.outlineVariantCustom),
          const SizedBox(height: 16),
          Text(
            hasProducts ? 'No matching products' : 'No products yet',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasProducts
                ? 'Try a different search or filter.'
                : 'Tap the button below to add your first product.',
            style: GoogleFonts.inter(fontSize: 13, color: context.theme.colorScheme.onSurfaceVariant),
          ),
          if (!hasProducts) ...[
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: context.theme.accentButton,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(Icons.add, color: context.theme.onAccentButton),
                label: Text('Add Product',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: context.theme.onAccentButton,
                    )),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 48, color: context.theme.outlineVariantCustom),
            const SizedBox(height: 16),
            Text(
              'Failed to load products',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: context.theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 12, color: context.theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: context.theme.outlineVariantCustom),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(Icons.refresh, size: 18, color: context.theme.colorScheme.primary),
              label: Text('Retry',
                  style: GoogleFonts.inter(color: context.theme.colorScheme.primary)),
            ),
          ],
        ),
      ),
    );
  }
}
