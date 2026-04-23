/// User profile model linked to Supabase `public.profiles`.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.role,
    this.fullName,
    this.outletId,
  });

  final String id;
  final String role; // 'admin', 'cashier', or 'waiter'
  final String? fullName;
  final String? outletId;

  bool get isAdmin => role == 'admin';
  bool get isCashier => role == 'cashier';
  bool get isWaiter => role == 'waiter';

  /// Display name — falls back to 'User' if no name set.
  String get displayName => (fullName != null && fullName!.isNotEmpty) ? fullName! : 'User';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      role: json['role'] as String? ?? 'cashier',
      fullName: json['full_name'] as String?,
      outletId: json['outlet_id'] as String?,
    );
  }
}
