import 'package:flutter/material.dart';
import 'package:apos/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../providers/accounting_notifier.dart';
import '../../data/repositories/accounting_repository.dart';
import '../widgets/expense_dialog.dart';
import '../../../../core/widgets/outlet_selector.dart';
import '../../../../core/providers/active_outlet_provider.dart';
import '../../data/services/excel_export_service.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// ════════════════════════════════════════════════════════════
/// ACCOUNTING PAGE — "The Artisanal Interface" design system
/// General Ledger view with Add Expense
/// ════════════════════════════════════════════════════════════

// ── Design Tokens ────────────────────────────────────────────
class AccountingPage extends ConsumerWidget {
  const AccountingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerState = ref.watch(generalLedgerProvider);
    final activeOutlet = ref.watch(activeOutletProvider);

    return Scaffold(
      backgroundColor: context.theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: context.theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 24,
        title: Text(
          'General Ledger',
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
            icon: Icon(Icons.file_download_outlined, color: context.theme.colorScheme.primary),
            tooltip: 'Export to Excel',
            onPressed: () => _exportExcel(context, ref),
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.theme.colorScheme.onSurfaceVariant),
            tooltip: 'Refresh Ledger',
            onPressed: () {
                ref.read(generalLedgerProvider.notifier).refresh();
                ref.invalidate(accountingTotalsProvider);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ledgerState.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.theme.colorScheme.primary, strokeWidth: 2),
        ),
        error: (err, st) => _ErrorState(
          message: err.toString(),
          onRetry: () => ref.read(generalLedgerProvider.notifier).refresh(),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return _EmptyState(
              onAdd: () => showDialog(
                context: context,
                builder: (_) => const ExpenseDialog(),
              ),
            );
          }

          final currency = NumberFormat.currency(
            locale: 'id_ID',
            symbol: 'Rp ',
            decimalDigits: 0,
          );

          return Column(
            children: [
              // ── RPC-backed Summary Bar ──────────────────
              Consumer(builder: (context, ref, _) {
                final totalsAsync = ref.watch(accountingTotalsProvider);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: totalsAsync.when(
                    loading: () => Row(
                      children: [
                        _SummaryChip(label: 'Entries', value: '...', bg: context.theme.surfaceHighest, fg: context.theme.colorScheme.onSurface),
                        const SizedBox(width: 8),
                        _SummaryChip(label: 'Debit', value: '...', bg: context.theme.tertiaryFixedDim.withOpacity(0.3), fg: context.theme.colorScheme.tertiary),
                        const SizedBox(width: 8),
                        _SummaryChip(label: 'Credit', value: '...', bg: context.theme.colorScheme.errorContainer, fg: context.theme.colorScheme.error),
                      ],
                    ),
                    error: (_, __) => Row(
                      children: [
                        _SummaryChip(label: 'Entries', value: '${entries.length}', bg: context.theme.surfaceHighest, fg: context.theme.colorScheme.onSurface),
                        const SizedBox(width: 8),
                        _SummaryChip(label: 'Debit', value: 'Error', bg: context.theme.tertiaryFixedDim.withOpacity(0.3), fg: context.theme.colorScheme.tertiary),
                        const SizedBox(width: 8),
                        _SummaryChip(label: 'Credit', value: 'Error', bg: context.theme.colorScheme.errorContainer, fg: context.theme.colorScheme.error),
                      ],
                    ),
                    data: (totals) => Row(
                      children: [
                        _SummaryChip(
                          label: 'Ledger Entries',
                          value: '${totals.totalLedgerEntries}',
                          bg: context.theme.surfaceHighest,
                          fg: context.theme.colorScheme.onSurface,
                        ),
                        const SizedBox(width: 8),
                        _SummaryChip(
                          label: 'Total Debit',
                          value: currency.format(totals.totalDebit),
                          bg: context.theme.tertiaryFixedDim.withOpacity(0.3),
                          fg: context.theme.colorScheme.tertiary,
                        ),
                        const SizedBox(width: 8),
                        _SummaryChip(
                          label: 'Total Credit',
                          value: currency.format(totals.totalCredit),
                          bg: context.theme.colorScheme.errorContainer,
                          fg: context.theme.colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        _SummaryChip(
                          label: 'Status',
                          value: totals.isBalanced ? 'Balanced ✓' : 'Unbalanced ✗',
                          bg: totals.isBalanced
                              ? context.theme.tertiaryFixedDim.withOpacity(0.3)
                              : context.theme.colorScheme.errorContainer,
                          fg: totals.isBalanced
                              ? context.theme.colorScheme.tertiary
                              : context.theme.colorScheme.error,
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              // ── Ledger Content ──────────────────────────
              Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                  if (constraints.maxWidth > 700) {
                    return _DesktopLedgerTable(
                      entries: entries,
                      currency: currency,
                    );
                  }
                  return _MobileLedgerList(
                    entries: entries,
                    currency: currency,
                  );
                }),
              ),
            ],
          );
        },
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
          onPressed: () => showDialog(
            context: context,
            builder: (_) => const ExpenseDialog(),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: Icon(Icons.add_rounded, color: context.theme.onAccentButton),
          label: Text(
            'Add Expense',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: context.theme.onAccentButton,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportExcel(BuildContext context, WidgetRef ref) async {
    final activeOutlet = ref.read(activeOutletProvider);
    final repo = ref.read(accountingRepositoryProvider);
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final entries = await repo.getAllGeneralLedger(activeOutlet?.id);
      final totals = await repo.fetchAccountingTotals();
      final profile = await ref.read(userProfileProvider.future);
      
      await ExcelExportService.exportLedger(
        outletName: activeOutlet?.name,
        userName: profile?.displayName ?? 'System',
        totals: totals,
        entries: entries,
      );

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to Excel successfully!', style: GoogleFonts.inter()),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export: $e', style: GoogleFonts.inter()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }
}


// ════════════════════════════════════════════════════════════
// SUMMARY CHIP
// ════════════════════════════════════════════════════════════

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.bg,
    required this.fg,
  });
  final String label;
  final String value;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: fg.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// DESKTOP — Ledger DataTable
// ════════════════════════════════════════════════════════════

class _DesktopLedgerTable extends StatelessWidget {
  const _DesktopLedgerTable({
    required this.entries,
    required this.currency,
  });
  final List<LedgerEntry> entries;
  final NumberFormat currency;

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
            // ── Section Header ──────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: context.theme.surfaceLow,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(Icons.menu_book_rounded,
                      color: context.theme.colorScheme.primary, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'Journal Entries',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            // ── Column Headers ──────────────────────────
            Container(
              color: context.theme.surfaceHighest.withOpacity(0.3),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text('Date & Time', style: headerStyle)),
                  Expanded(flex: 4, child: Text('Description', style: headerStyle)),
                  Expanded(flex: 4, child: Text('Account', style: headerStyle)),
                  Expanded(flex: 2, child: Text('Debit', style: headerStyle, textAlign: TextAlign.right)),
                  Expanded(flex: 2, child: Text('Credit', style: headerStyle, textAlign: TextAlign.right)),
                ],
              ),
            ),
            // ── Data Rows ───────────────────────────────
            ...entries.map((e) {
              final dateStr =
                  DateFormat('dd MMM yyyy, HH:mm').format(e.date.toLocal());
              final hasDebit = e.debit > 0;
              final hasCredit = e.credit > 0;

              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: context.theme.surfaceHighest.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        dateStr,
                        style: GoogleFonts.inter(fontSize: 12, color: context.theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        e.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: bodyStyle,
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        '${e.accountCode} - ${e.accountName}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: context.theme.colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        hasDebit ? currency.format(e.debit) : '-',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.inter(
                          fontWeight:
                              hasDebit ? FontWeight.w600 : FontWeight.w400,
                          color: hasDebit
                              ? context.theme.colorScheme.tertiary
                              : context.theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        hasCredit ? currency.format(e.credit) : '-',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.inter(
                          fontWeight:
                              hasCredit ? FontWeight.w600 : FontWeight.w400,
                          color: hasCredit
                              ? context.theme.colorScheme.error
                              : context.theme.colorScheme.onSurfaceVariant,
                        ),
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
// MOBILE — Ledger Card List
// ════════════════════════════════════════════════════════════

class _MobileLedgerList extends StatelessWidget {
  const _MobileLedgerList({
    required this.entries,
    required this.currency,
  });
  final List<LedgerEntry> entries;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final e = entries[index];
        final dateStr = DateFormat('dd MMM, HH:mm').format(e.date.toLocal());
        final hasDebit = e.debit > 0;
        final hasCredit = e.credit > 0;

        return Container(
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
              // ── Date & Account ───────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateStr,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.theme.surfaceHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      e.accountCode,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: context.theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // ── Description ─────────────────────────
              Text(
                e.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: context.theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                e.accountName,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              // ── Debit / Credit Row ──────────────────
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: hasDebit
                            ? context.theme.tertiaryFixedDim.withOpacity(0.2)
                            : context.theme.surfaceHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Debit',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: hasDebit
                                  ? context.theme.colorScheme.tertiary
                                  : context.theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasDebit
                                ? currency.format(e.debit)
                                : '-',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: hasDebit
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: hasDebit
                                  ? context.theme.colorScheme.tertiary
                                  : context.theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: hasCredit
                            ? context.theme.colorScheme.errorContainer
                            : context.theme.surfaceHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Credit',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: hasCredit
                                  ? context.theme.colorScheme.error
                                  : context.theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasCredit
                                ? currency.format(e.credit)
                                : '-',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: hasCredit
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: hasCredit
                                  ? context.theme.colorScheme.error
                                  : context.theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════
// EMPTY & ERROR STATES
// ════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_outlined,
              size: 64, color: context.theme.outlineVariantCustom),
          const SizedBox(height: 16),
          Text('No ledger entries',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.theme.colorScheme.onSurface,
              )),
          const SizedBox(height: 8),
          Text(
            'Journal entries will appear here after transactions.',
            style:
                GoogleFonts.inter(fontSize: 13, color: context.theme.colorScheme.onSurfaceVariant),
          ),
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
              label: Text('Add Expense',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: context.theme.onAccentButton,
                  )),
            ),
          ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 48, color: context.theme.outlineVariantCustom),
          const SizedBox(height: 12),
          Text('Failed to load ledger',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: context.theme.colorScheme.onSurface,
              )),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 12, color: context.theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: context.theme.outlineVariantCustom),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(Icons.refresh, size: 18, color: context.theme.colorScheme.primary),
            label: Text('Retry',
                style: GoogleFonts.inter(color: context.theme.colorScheme.primary)),
          ),
        ],
      ),
    );
  }
}
