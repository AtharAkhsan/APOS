import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../domain/entities/outlet.dart';

/// Repository that handles all outlet CRUD via Supabase.
class OutletRepository {
  OutletRepository(this._ref);
  final Ref _ref;

  Future<List<Outlet>> getOutlets() async {
    final client = _ref.read(supabaseProvider);
    final data = await client
        .from('outlets')
        .select()
        .eq('is_active', true)
        .order('name');
    return (data as List)
        .map((e) => Outlet.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Outlet> createOutlet(Outlet outlet) async {
    final client = _ref.read(supabaseProvider);
    final data = await client
        .from('outlets')
        .insert(outlet.toInsertJson())
        .select()
        .single();
    return Outlet.fromJson(data);
  }

  Future<Outlet> updateOutlet(Outlet outlet) async {
    final client = _ref.read(supabaseProvider);
    final data = await client
        .from('outlets')
        .update(outlet.toInsertJson())
        .eq('id', outlet.id)
        .select()
        .single();
    return Outlet.fromJson(data);
  }

  Future<void> deactivateOutlet(String id) async {
    final client = _ref.read(supabaseProvider);
    await client.from('outlets').update({'is_active': false}).eq('id', id);
  }
}

final outletRepositoryProvider = Provider<OutletRepository>((ref) {
  return OutletRepository(ref);
});
