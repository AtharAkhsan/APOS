import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/accounting_repository.dart';

import '../../../../core/providers/active_outlet_provider.dart';

// ── Expense Accounts Provider ───────────────────────────────

final expenseAccountsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(accountingRepositoryProvider);
  return repo.getExpenseAccounts();
});

// ── General Ledger Notifier ─────────────────────────────────

class GeneralLedgerNotifier extends AsyncNotifier<List<LedgerEntry>> {
  @override
  Future<List<LedgerEntry>> build() async {
    // Watch active outlet so the ledger auto-refreshes when swapped
    ref.watch(activeOutletProvider);
    return _fetchLedger();
  }

  Future<List<LedgerEntry>> _fetchLedger() async {
    final repo = ref.read(accountingRepositoryProvider);
    return repo.getGeneralLedger();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final data = await _fetchLedger();
      state = AsyncData(data);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Adds a new expense via the repository and automatically refreshes the ledger.
  /// Throws an error to be caught by the UI if the RPC fails.
  Future<void> addExpense({
    required String description,
    required double amount,
    required String expenseAccountId,
  }) async {
    final prev = state;
    state = const AsyncLoading();
    try {
      final repo = ref.read(accountingRepositoryProvider);
      await repo.addExpense(
        description: description,
        amount: amount,
        expenseAccountId: expenseAccountId,
      );
      // Wait to ensure DB triggers/RPC finish
      await Future.delayed(const Duration(milliseconds: 300));
      await refresh();
      ref.invalidate(accountingTotalsProvider);
    } catch (e) {
      state = prev; // Restore previous state on error
      rethrow;    // Let the UI dialog handle showing the error
    }
  }
}

final generalLedgerProvider =
    AsyncNotifierProvider<GeneralLedgerNotifier, List<LedgerEntry>>(
  GeneralLedgerNotifier.new,
);

// ── Accounting Totals Provider (RPC-backed, no pagination) ──

final accountingTotalsProvider = FutureProvider<AccountingTotals>((ref) async {
  // Auto-refresh when the active outlet changes
  ref.watch(activeOutletProvider);
  final repo = ref.watch(accountingRepositoryProvider);
  return repo.fetchAccountingTotals();
});
