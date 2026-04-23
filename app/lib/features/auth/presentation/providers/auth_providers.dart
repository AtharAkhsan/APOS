import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/supabase_provider.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/models/user_profile.dart';

// ── Repository Provider ──────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(supabaseProvider));
});

// ── Auth State Stream ────────────────────────────────────────
// Emits the current Supabase Session whenever auth state changes.

final authStateProvider = StreamProvider<Session?>((ref) {
  final client = Supabase.instance.client;

  // Use a StreamController to merge the initial value + the stream
  final controller = StreamController<Session?>.broadcast();

  // Seed initial value
  controller.add(client.auth.currentSession);

  final subscription = client.auth.onAuthStateChange.listen((authState) {
    controller.add(authState.session);
  });

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

// ── User Profile Provider ────────────────────────────────────
// Fetches the profile (role, name) from `public.profiles` for
// the currently authenticated user.

final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  // Watch auth state — recomputes when auth changes
  final authAsync = ref.watch(authStateProvider);

  // Get current user directly from Supabase (more reliable)
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;

  final repo = ref.read(authRepositoryProvider);
  try {
    final profile = await repo.fetchProfile(user.id);
    debugPrint('Profile fetched: role=${profile.role}, name=${profile.fullName}, outletId=${profile.outletId}');
    return profile;
  } catch (e) {
    debugPrint('Failed to fetch profile: $e');
    return null;
  }
});

// ── Derived: User Role ───────────────────────────────────────
// Quick access to the role string ('admin' | 'cashier' | null).

final userRoleProvider = Provider<String?>((ref) {
  return ref.watch(userProfileProvider).valueOrNull?.role;
});
