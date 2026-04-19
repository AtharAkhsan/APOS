import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Global provider for the Supabase client instance.
/// Use `ref.read(supabaseProvider)` in any repository or notifier.
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Convenience provider for the current auth user.
final currentUserProvider = Provider<User?>((ref) {
  return ref.read(supabaseProvider).auth.currentUser;
});
