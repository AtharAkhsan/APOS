import 'package:flutter/material.dart';
import 'package:toempah_rempah/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/outlet_notifier.dart';
import '../../domain/entities/outlet.dart';

/// ════════════════════════════════════════════════════════════
/// OUTLET MANAGEMENT PAGE — "The Artisanal Interface"
/// Full CRUD: Create, Read, Update, Delete
/// ════════════════════════════════════════════════════════════

// ── Design Tokens ────────────────────────────────────────────
class OutletManagementPage extends ConsumerWidget {
  const OutletManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outletsAsync = ref.watch(outletNotifierProvider);

    return Scaffold(
      backgroundColor: context.theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: context.theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Outlet Management',
          style: GoogleFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: context.theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.theme.colorScheme.onSurfaceVariant),
            onPressed: () =>
                ref.read(outletNotifierProvider.notifier).refresh(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: outletsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.theme.colorScheme.primary, strokeWidth: 2),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: context.theme.colorScheme.error),
              const SizedBox(height: 12),
              Text('Error: $err', style: GoogleFonts.inter(color: context.theme.colorScheme.error)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(outletNotifierProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (outlets) {
          if (outlets.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: context.theme.surfaceHighest.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.storefront_outlined,
                        size: 48, color: context.theme.outlineVariantCustom),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No Outlets Yet',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first outlet to get started.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: outlets.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final outlet = outlets[index];
              return _OutletCard(
                outlet: outlet,
                onEdit: () => _showOutletDialog(context, ref, outlet: outlet),
                onDelete: () => _confirmDelete(context, ref, outlet),
              );
            },
          );
        },
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          color: context.theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: context.theme.colorScheme.primary.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _showOutletDialog(context, ref),
          
          elevation: 0,
          icon: Icon(Icons.add_rounded, color: context.theme.colorScheme.onPrimary),
          label: Text(
            'Add Outlet',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: context.theme.colorScheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }

  void _showOutletDialog(BuildContext context, WidgetRef ref, {Outlet? outlet}) {
    showDialog(
      context: context,
      builder: (_) => _OutletFormDialog(outlet: outlet),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Outlet outlet) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.theme.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.theme.colorScheme.errorContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.delete_outline, color: context.theme.colorScheme.error, size: 32),
        ),
        title: Text(
          'Delete Outlet?',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            color: context.theme.colorScheme.onSurface,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${outlet.name}"? This action cannot be undone.',
          style: GoogleFonts.inter(color: context.theme.colorScheme.onSurfaceVariant, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: context.theme.colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(outletNotifierProvider.notifier)
                  .deactivateOutlet(outlet.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('${outlet.name} deleted', style: GoogleFonts.inter()),
                    backgroundColor: context.theme.colorScheme.primaryContainer,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.theme.colorScheme.error,
              foregroundColor: context.theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// OUTLET CARD
// ════════════════════════════════════════════════════════════

class _OutletCard extends StatelessWidget {
  const _OutletCard({
    required this.outlet,
    required this.onEdit,
    required this.onDelete,
  });

  final Outlet outlet;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Icon(Icons.storefront_rounded,
                        color: context.theme.colorScheme.onPrimary, size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        outlet.name,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.theme.colorScheme.onSurface,
                        ),
                      ),
                      if (outlet.address != null &&
                          outlet.address!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 13, color: context.theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                outlet.address!,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: context.theme.colorScheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (outlet.phone != null &&
                          outlet.phone!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.phone_outlined,
                                size: 13, color: context.theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              outlet.phone!,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: context.theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // ── Actions ────────────────────────────
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: context.theme.colorScheme.onSurfaceVariant),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  color: context.theme.cardWhite,
                  onSelected: (val) {
                    if (val == 'edit') onEdit();
                    if (val == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 18, color: context.theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 10),
                          Text('Edit', style: GoogleFonts.inter(fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              size: 18, color: context.theme.colorScheme.error),
                          const SizedBox(width: 10),
                          Text('Delete',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: context.theme.colorScheme.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// OUTLET FORM DIALOG — Create & Edit
// ════════════════════════════════════════════════════════════

class _OutletFormDialog extends ConsumerStatefulWidget {
  const _OutletFormDialog({this.outlet});
  final Outlet? outlet;

  @override
  ConsumerState<_OutletFormDialog> createState() => _OutletFormDialogState();
}

class _OutletFormDialogState extends ConsumerState<_OutletFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;

  bool _isSubmitting = false;
  bool get _isEditing => widget.outlet != null;

  @override
  void initState() {
    super.initState();
    final o = widget.outlet;
    _nameCtrl = TextEditingController(text: o?.name ?? '');
    _addressCtrl = TextEditingController(text: o?.address ?? '');
    _phoneCtrl = TextEditingController(text: o?.phone ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final outlet = Outlet(
        id: widget.outlet?.id ?? '',
        name: _nameCtrl.text.trim(),
        address:
            _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        phone:
            _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      );

      if (_isEditing) {
        await ref.read(outletNotifierProvider.notifier).updateOutlet(outlet);
      } else {
        await ref.read(outletNotifierProvider.notifier).addOutlet(outlet);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? '${outlet.name} updated!'
                  : '${outlet.name} added!',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: context.theme.colorScheme.primaryContainer,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
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
                borderRadius: BorderRadius.circular(12)),
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
        constraints: const BoxConstraints(maxWidth: 480),
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
                              : Icons.add_business_rounded,
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
                              _isEditing ? 'Edit Outlet' : 'Add New Outlet',
                              style: GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: context.theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isEditing
                                  ? 'Update the outlet details below.'
                                  : 'Fill in the outlet details below.',
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
                          child: Icon(Icons.close,
                              size: 16, color: context.theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Outlet Name ─────────────────────────
                  _OutletField(
                    controller: _nameCtrl,
                    label: 'Outlet Name',
                    hint: 'e.g. Main Store',
                    icon: Icons.storefront_outlined,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Name is required'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // ── Address ─────────────────────────────
                  _OutletField(
                    controller: _addressCtrl,
                    label: 'Address',
                    hint: 'e.g. Jl. Merdeka No. 10',
                    icon: Icons.location_on_outlined,
                    textCapitalization: TextCapitalization.words,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // ── Phone ───────────────────────────────
                  _OutletField(
                    controller: _phoneCtrl,
                    label: 'Phone Number',
                    hint: 'e.g. 08123456789',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
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
                                      ? 'Update Outlet'
                                      : 'Save Outlet',
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
}

// ════════════════════════════════════════════════════════════
// FORM FIELD
// ════════════════════════════════════════════════════════════

class _OutletField extends StatelessWidget {
  const _OutletField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final int maxLines;

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
          textCapitalization: textCapitalization,
          validator: validator,
          maxLines: maxLines,
          style: GoogleFonts.inter(fontSize: 14, color: context.theme.colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                GoogleFonts.inter(fontSize: 14, color: context.theme.outlineVariantCustom),
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
