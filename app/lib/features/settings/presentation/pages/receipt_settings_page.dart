import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/providers/active_outlet_provider.dart';
import '../../../../core/widgets/outlet_selector.dart';

class ReceiptSettingsPage extends ConsumerStatefulWidget {
  const ReceiptSettingsPage({super.key});

  @override
  ConsumerState<ReceiptSettingsPage> createState() => _ReceiptSettingsPageState();
}

class _ReceiptSettingsPageState extends ConsumerState<ReceiptSettingsPage> {
  final _headerController = TextEditingController();
  final _footerController = TextEditingController();
  bool _showLogo = true;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _outletId;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
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
          .from('receipt_settings')
          .select()
          .eq('outlet_id', _outletId!)
          .maybeSingle();

      if (data != null && mounted) {
        _headerController.text = data['header_text'] ?? '';
        _footerController.text = data['footer_text'] ?? '';
        _showLogo = data['show_logo'] ?? true;
      } else if (mounted) {
        _headerController.clear();
        _footerController.clear();
        _showLogo = true;
      }
    } catch (e) {
      debugPrint('Error loading receipt settings: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_outletId == null) return;
    setState(() => _isSaving = true);

    try {
      await Supabase.instance.client.from('receipt_settings').upsert({
        'outlet_id': _outletId,
        'header_text': _headerController.text,
        'footer_text': _footerController.text,
        'show_logo': _showLogo,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'outlet_id');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Receipt settings saved!'),
            backgroundColor: context.theme.colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: context.theme.colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _headerController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeOutletProvider, (prev, next) {
      if (prev?.id != next?.id) {
        _loadSettings();
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
          'Receipt Settings',
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
              'Customize the header and footer that appears on printed receipts.',
              style: GoogleFonts.inter(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _headerController,
              label: 'Receipt Header',
              hint: 'e.g., Thank you for visiting Artisanal Cafe!',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _footerController,
              label: 'Receipt Footer',
              hint: 'e.g., Follow us on IG @artisanal_cafe',
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: Text(
                'Show Store Logo',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Include the logo at the top of the receipt.',
                style: GoogleFonts.inter(fontSize: 12),
              ),
              value: _showLogo,
              onChanged: (v) => setState(() => _showLogo = v),
              activeColor: context.theme.colorScheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.theme.colorScheme.primary,
                foregroundColor: context.theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Save Settings',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: context.theme.surfaceLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.theme.outlineVariantCustom),
            ),
          ),
        ),
      ],
    );
  }
}
