/// User profile model linked to Supabase `public.profiles`.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.role,
    this.fullName,
  });

  final String id;
  final String role; // 'ADMIN' or 'CASHIER'
  final String? fullName;

  bool get isAdmin => role == 'admin';
  bool get isCashier => role == 'cashier';

  /// Display name — falls back to 'User' if no name set.
  String get displayName => (fullName != null && fullName!.isNotEmpty) ? fullName! : 'User';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      role: json['role'] as String? ?? 'CASHIER',
      fullName: json['full_name'] as String?,
    );
  }
}
