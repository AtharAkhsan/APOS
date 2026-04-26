import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/active_outlet_provider.dart';
import '../../../../core/providers/supabase_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

DateTime _parseUtcDate(dynamic raw) {
  if (raw == null) return DateTime.now();
  String s = raw.toString();
  if (!s.endsWith('Z') && !s.contains('+') && !RegExp(r'-\d{2}:\d{2}$').hasMatch(s)) {
    s += 'Z';
  }
  return DateTime.tryParse(s)?.toUtc() ?? DateTime.now();
}

class LedgerEntry {
  final String id;
  final DateTime date;
  final String description;
  final String accountCode;
  final String accountName;
  final double debit;
  final double credit;
  final String? outletName;

  LedgerEntry({
    required this.id,
    required this.date,
    required this.description,
    required this.accountCode,
    required this.accountName,
    required this.debit,
    required this.credit,
    this.outletName,
  });

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    final journal = json['journal_entries'] as Map<String, dynamic>? ?? {};
    final account = json['accounts'] as Map<String, dynamic>? ?? {};

    return LedgerEntry(
      id: json['id'] as String,
      date: _parseUtcDate(journal['entry_date']),
      description: journal['description'] ?? 'No Description',
      accountCode: account['code'] ?? '-',
      accountName: account['name'] ?? 'Unknown Account',
      debit: (json['debit'] as num?)?.toDouble() ?? 0,
      credit: (json['credit'] as num?)?.toDouble() ?? 0,
      outletName: journal['outlets'] != null ? journal['outlets']['name'] as String? : null,
    );
  }
}

class AccountingTotals {
  final int totalLedgerEntries;
  final int totalJournalEntries;
  final double totalDebit;
  final double totalCredit;
  final double netBalance;
  final bool isBalanced;

  const AccountingTotals({
    required this.totalLedgerEntries,
    required this.totalJournalEntries,
    required this.totalDebit,
    required this.totalCredit,
    required this.netBalance,
    required this.isBalanced,
  });

  factory AccountingTotals.fromJson(Map<String, dynamic> json) {
    return AccountingTotals(
      totalLedgerEntries: (json['total_ledger_entries'] as num?)?.toInt() ?? 0,
      totalJournalEntries: (json['total_journal_entries'] as num?)?.toInt() ?? 0,
      totalDebit: (json['total_debit'] as num?)?.toDouble() ?? 0,
      totalCredit: (json['total_credit'] as num?)?.toDouble() ?? 0,
      netBalance: (json['net_balance'] as num?)?.toDouble() ?? 0,
      isBalanced: json['is_balanced'] as bool? ?? false,
    );
  }
}

class AccountingRepository {
  AccountingRepository(this._supabase, this._outletId);
  final SupabaseClient _supabase;
  final String? _outletId;

  Future<List<LedgerEntry>> getGeneralLedger() async {
    var query = _supabase
        .from('ledger_entries')
        .select('''
          id,
          debit,
          credit,
          journal_entries!inner ( entry_date, description, outlet_id ),
          accounts ( code, name )
        ''');

    if (_outletId != null) {
      query = query.eq('journal_entries.outlet_id', _outletId);
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(100);

    return (response as List).map((e) => LedgerEntry.fromJson(e)).toList();
  }

  /// Fetches ALL ledger entries for exporting (no pagination).
  Future<List<LedgerEntry>> getAllGeneralLedger(String? specificOutletId) async {
    var query = _supabase
        .from('ledger_entries')
        .select('''
          id,
          debit,
          credit,
          journal_entries!inner ( entry_date, description, outlet_id, outlets ( name ) ),
          accounts ( code, name )
        ''');

    if (specificOutletId != null) {
      query = query.eq('journal_entries.outlet_id', specificOutletId);
    }

    final response = await query.order('created_at', ascending: false);

    return (response as List).map((e) => LedgerEntry.fromJson(e)).toList();
  }

  /// Fetches the true, database-level aggregated totals via RPC,
  /// bypassing any frontend LIMIT/pagination.
  Future<AccountingTotals> fetchAccountingTotals() async {
    final response = await _supabase.rpc('get_accounting_totals', params: {
      'p_outlet_id': _outletId,
    });

    return AccountingTotals.fromJson(response as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> getExpenseAccounts() async {
    return await _supabase
        .from('accounts')
        .select('id, code, name')
        .eq('account_type', 'EXPENSE')
        .order('code');
  }

  Future<void> addExpense({
    required String description,
    required double amount,
    required String expenseAccountId,
  }) async {
    if (_outletId == null) throw Exception('No outlet selected');

    final cashAccountRes = await _supabase
        .from('accounts')
        .select('id')
        .eq('code', '1-1001')
        .single();
    final cashAccountId = cashAccountRes['id'] as String;

    await _supabase.rpc('insert_expense', params: {
      'p_description': description,
      'p_amount': amount,
      'p_expense_acc': expenseAccountId,
      'p_cash_acc': cashAccountId,
      'p_staff_id': _supabase.auth.currentUser?.id, 
      'p_outlet_id': _outletId,
    });
  }
}

final accountingRepositoryProvider = Provider<AccountingRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  final activeOutlet = ref.watch(activeOutletProvider);
  return AccountingRepository(client, activeOutlet?.id);
});
