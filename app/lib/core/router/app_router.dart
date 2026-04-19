import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../layout/responsive_shell.dart';
import '../../features/pos/presentation/pages/pos_page.dart';
import '../../features/inventory/presentation/pages/inventory_page.dart';
import '../../features/accounting/presentation/pages/accounting_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';

// ── Route Paths ─────────────────────────────────────────

class AppRoutes {
  AppRoutes._();
  static const login      = '/login';
  static const pos        = '/pos';
  static const dashboard  = '/dashboard';
  static const inventory  = '/inventory';
  static const accounting = '/accounting';
  static const settings   = '/settings';

  /// Routes restricted to ADMIN only.
  static const adminOnly = {dashboard, inventory, accounting};
}

// ── Router Provider ─────────────────────────────────────

final appRouterProvider = Provider<GoRouter>((ref) {
  // Create a listenable that fires when auth state changes,
  // so GoRouter re-evaluates its redirect logic.
  final authNotifier = _RouterAuthNotifier(ref);

  return GoRouter(
    initialLocation: AppRoutes.pos,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final isOnLogin = state.uri.toString() == AppRoutes.login;

      // 1. Not logged in → force to login page
      if (!isLoggedIn) {
        return isOnLogin ? null : AppRoutes.login;
      }

      // 2. Logged in but on login page → go to default
      if (isOnLogin) {
        return AppRoutes.pos;
      }

      // 3. RBAC: check role for restricted routes
      final role = ref.read(userRoleProvider);
      final currentPath = state.uri.toString();

      if (role == 'cashier' && AppRoutes.adminOnly.contains(currentPath)) {
        return AppRoutes.pos;
      }

      return null; // no redirect needed
    },
    routes: [
      // ── Login (outside shell) ───────────────────────
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => const NoTransitionPage(
          child: LoginPage(),
        ),
      ),

      // ── Authenticated Shell ─────────────────────────
      ShellRoute(
        builder: (context, state, child) {
          return ResponsiveShell(child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.pos,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PosPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.dashboard,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DashboardPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.inventory,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: InventoryPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.accounting,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AccountingPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsPage(),
            ),
          ),
        ],
      ),
    ],
  );
});

// ── Internal: Auth Change → GoRouter Refresh ─────────────

class _RouterAuthNotifier extends ChangeNotifier {
  _RouterAuthNotifier(this._ref) {
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      // Whenever auth changes, also invalidate profile so role updates
      _ref.invalidate(userProfileProvider);
      notifyListeners();
    });
  }

  final Ref _ref;
  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
