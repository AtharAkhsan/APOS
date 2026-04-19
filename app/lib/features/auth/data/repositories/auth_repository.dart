import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/user_profile.dart';

/// Repository wrapping Supabase Auth + the `profiles` table.
class AuthRepository {
  const AuthRepository(this._client);
  final SupabaseClient _client;

  // ── Auth ─────────────────────────────────────────────────

  /// Sign in with email & password.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign up with email, password, and optional full name.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: fullName != null ? {'full_name': fullName} : null,
    );
  }

  /// Sign out the current user.
  Future<void> signOut() => _client.auth.signOut();

  /// Stream of auth state changes.
  Stream<AuthState> onAuthStateChange() =>
      _client.auth.onAuthStateChange;

  /// The currently logged-in user (nullable).
  User? get currentUser => _client.auth.currentUser;

  // ── Profile ──────────────────────────────────────────────

  /// Fetch the profile (role, full_name) for the given user ID.
  Future<UserProfile> fetchProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select('id, role, full_name')
        .eq('id', userId)
        .single();
    return UserProfile.fromJson(data);
  }
}
