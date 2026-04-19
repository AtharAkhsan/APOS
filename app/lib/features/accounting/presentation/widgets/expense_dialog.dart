import 'package:apos/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/accounting_notifier.dart';

/// ════════════════════════════════════════════════════════════
/// EXPENSE DIALOG — "The Artisanal Interface" design system
/// ════════════════════════════════════════════════════════════

class ExpenseDialog extends ConsumerStatefulWidget {
  const ExpenseDialog({super.key});

  @override
  ConsumerState<ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends ConsumerState<ExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();

  String? _selectedAccountId;
  bool _isLoading = false;

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedAccountId == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amount =
          double.parse(_amountController.text.replaceAll(',', ''));

      await ref.read(generalLedgerProvider.notifier).addExpense(
            description: _descController.text.trim(),
            amount: amount,
            expenseAccountId: _selectedAccountId!,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Expense recorded!', style: GoogleFonts.inter()),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e', style: GoogleFonts.inter()),
            backgroundColor: context.theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(expenseAccountsProvider);
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
                          color: context.theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.receipt_long_rounded,
                            color: context.theme.colorScheme.error, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add Manual Expense',
                              style: GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: context.theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Record a new journal entry for expenses.',
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

                  // ── Description ─────────────────────────
                  _buildLabel('Description'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _descController,
                    style: GoogleFonts.inter(
                        fontSize: 14, color: context.theme.colorScheme.onSurface),
                    decoration: _artisanalInput(
                      hint: 'e.g. Electricity, Internet',
                      icon: Icons.description_outlined,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Description is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Amount ──────────────────────────────
                  _buildLabel('Amount (Rp)'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _amountController,
                    style: GoogleFonts.inter(
                        fontSize: 14, color: context.theme.colorScheme.onSurface),
                    decoration: _artisanalInput(
                      hint: '0',
                      icon: Icons.payments_outlined,
                      prefixText: 'Rp ',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Amount is required';
                      }
                      if (double.tryParse(val) == null ||
                          double.parse(val) <= 0) {
                        return 'Enter a valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Expense Category ────────────────────
                  _buildLabel('Expense Category'),
                  const SizedBox(height: 6),
                  accountsAsync.when(
                    loading: () => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          color: context.theme.colorScheme.primary,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    error: (e, st) => Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Error: $e',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: context.theme.colorScheme.error),
                      ),
                    ),
                    data: (accounts) {
                      if (accounts.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.theme.surfaceHighest.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('No expense accounts found.',
                              style: GoogleFonts.inter(
                                  color: context.theme.colorScheme.onSurfaceVariant, fontSize: 13)),
                        );
                      }
                      return DropdownButtonFormField<String>(
                        decoration: _artisanalInput(
                          hint: 'Select category',
                          icon: Icons.category_outlined,
                        ),
                        style: GoogleFonts.inter(
                            fontSize: 14, color: context.theme.colorScheme.onSurface),
                        dropdownColor: context.theme.cardWhite,
                        initialValue: _selectedAccountId,
                        items: accounts.map((acc) {
                          return DropdownMenuItem(
                            value: acc['id'] as String,
                            child: Text(
                              '${acc['code']} - ${acc['name']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedAccountId = val);
                        },
                        validator: (val) =>
                            val == null ? 'Please select a category' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // ── Actions ─────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              _isLoading ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
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
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              
                              
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: _isLoading
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: context.theme.colorScheme.onPrimary,
                                    ),
                                  )
                                : Icon(Icons.save_rounded,
                                    color: context.theme.colorScheme.onPrimary, size: 18),
                            label: Text(
                              _isLoading ? 'Saving...' : 'Save Expense',
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: context.theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  InputDecoration _artisanalInput({
    required String hint,
    required IconData icon,
    String? prefixText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 14, color: context.theme.outlineVariantCustom),
      prefixIcon: Icon(icon, color: context.theme.colorScheme.onSurfaceVariant, size: 18),
      prefixText: prefixText,
      prefixStyle: GoogleFonts.inter(
        color: context.theme.colorScheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: context.theme.surfaceHighest.withOpacity(0.5),
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
        borderSide:
            BorderSide(color: context.theme.colorScheme.primary.withOpacity(0.3), width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.theme.colorScheme.error, width: 1),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
