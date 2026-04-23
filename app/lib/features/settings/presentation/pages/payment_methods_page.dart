import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/providers/active_outlet_provider.dart';
import '../../../../core/widgets/outlet_selector.dart';

class PaymentMethodsPage extends ConsumerStatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  ConsumerState<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends ConsumerState<PaymentMethodsPage> {
  bool _isLoading = true;
  String? _outletId;
  
  // Local state for payment methods
  final Map<String, bool> _methods = {
    'cash': true,
    'qris': true,
    'card': true,
    'transfer': true,
  };

  @override
  void initState() {
    super.initState();
    _loadMethods();
  }

  Future<void> _loadMethods() async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile == null) return;
    
    if (!profile.isAdmin) {
       _outletId = profile.outletId;
    } else {
       final activeOutlet = ref.read(activeOutletProvider);
       _outletId = activeOutlet?.id;
    }

    if (_outletId == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }
    
    setState(() => _isLoading = true);

    try {
      final data = await Supabase.instance.client
          .from('payment_methods')
          .select()
          .eq('outlet_id', _outletId!);

      if (data.isNotEmpty && mounted) {
        setState(() {
          for (var row in data) {
            final type = row['type'] as String;
            final isActive = row['is_active'] as bool;
            _methods[type] = isActive;
          }
        });
      } else {
        // If empty, initialize them
        await _initializeMethods();
      }
    } catch (e) {
      debugPrint('Error loading payment methods: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeMethods() async {
    if (_outletId == null) return;
    try {
      final rows = _methods.entries.map((e) => {
        'outlet_id': _outletId,
        'name': e.key.toUpperCase(),
        'type': e.key,
        'is_active': e.value,
      }).toList();
      await Supabase.instance.client.from('payment_methods').insert(rows);
    } catch (e) {
      debugPrint('Error initializing payment methods: $e');
    }
  }

  Future<void> _toggleMethod(String type, bool isActive) async {
    if (_outletId == null) return;
    
    setState(() {
      _methods[type] = isActive;
    });

    try {
      // Upsert the specific method
      final existing = await Supabase.instance.client
          .from('payment_methods')
          .select('id')
          .eq('outlet_id', _outletId!)
          .eq('type', type)
          .maybeSingle();

      if (existing != null) {
        await Supabase.instance.client
            .from('payment_methods')
            .update({'is_active': isActive})
            .eq('id', existing['id']);
      } else {
        await Supabase.instance.client.from('payment_methods').insert({
          'outlet_id': _outletId,
          'name': type.toUpperCase(),
          'type': type,
          'is_active': isActive,
        });
      }
    } catch (e) {
      debugPrint('Error toggling payment method: $e');
      // Revert on error
      if (mounted) {
        setState(() => _methods[type] = !isActive);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update $type'),
            backgroundColor: context.theme.colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeOutletProvider, (prev, next) {
      if (prev?.id != next?.id) {
        _loadMethods();
      }
    });

    final profile = ref.watch(userProfileProvider).valueOrNull;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.theme.scaffoldBackgroundColor,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: context.theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: context.theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Payment Methods',
          style: GoogleFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: context.theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          if (profile?.isAdmin == true) const OutletSelector(),
          const SizedBox(width: 8),
        ],
      ),
      body: _outletId == null 
        ? Center(
            child: Text(
              'Please select an outlet from the top right.',
              style: GoogleFonts.inter(color: context.theme.colorScheme.onSurfaceVariant),
            ),
          )
        : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Toggle which payment methods are accepted at this outlet.',
              style: GoogleFonts.inter(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            _buildToggleTile(
              title: 'Cash',
              subtitle: 'Accept physical cash payments',
              icon: Icons.money_rounded,
              type: 'cash',
            ),
            const SizedBox(height: 12),
            _buildToggleTile(
              title: 'QRIS',
              subtitle: 'Accept QR-based digital payments',
              icon: Icons.qr_code_2_rounded,
              type: 'qris',
            ),
            const SizedBox(height: 12),
            _buildToggleTile(
              title: 'Debit/Credit Card',
              subtitle: 'Accept EDC terminal payments',
              icon: Icons.credit_card_rounded,
              type: 'card',
            ),
            const SizedBox(height: 12),
            _buildToggleTile(
              title: 'Bank Transfer',
              subtitle: 'Accept manual bank transfers',
              icon: Icons.account_balance_rounded,
              type: 'transfer',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required String type,
  }) {
    final isActive = _methods[type] ?? false;
    
    return Container(
      decoration: BoxDecoration(
        color: context.theme.surfaceLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.theme.outlineVariantCustom.withOpacity(0.5),
        ),
      ),
      child: SwitchListTile(
        title: Row(
          children: [
            Icon(icon, color: context.theme.colorScheme.primary, size: 20),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(left: 32, top: 4),
          child: Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 12),
          ),
        ),
        value: isActive,
        onChanged: (v) => _toggleMethod(type, v),
        activeColor: context.theme.colorScheme.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
