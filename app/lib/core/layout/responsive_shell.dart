import 'package:toempah_rempah/core/theme/app_theme.dart';
import 'package:toempah_rempah/core/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../router/app_router.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';

/// ════════════════════════════════════════════════════════════
/// RESPONSIVE SHELL — "The Artisanal Interface" design system
/// Switches between NavigationRail (desktop) and BottomNavigationBar (mobile)
/// ════════════════════════════════════════════════════════════

class ResponsiveShell extends ConsumerWidget {
  const ResponsiveShell({super.key, required this.child});

  final Widget child;

  // ── All Nav Destinations ──────────────────────────────────
  static final _allDestinations = <_NavItem>[
    _NavItem(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Dashboard', path: AppRoutes.dashboard, adminOnly: true),
    _NavItem(icon: Icons.point_of_sale_outlined, selectedIcon: Icons.point_of_sale, label: 'POS', path: AppRoutes.pos, adminOnly: false),
    _NavItem(icon: Icons.inventory_2_outlined, selectedIcon: Icons.inventory_2, label: 'Inventory', path: AppRoutes.inventory, adminOnly: true),
    _NavItem(icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long, label: 'Accounting', path: AppRoutes.accounting, adminOnly: true),
    _NavItem(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'Settings', path: AppRoutes.settings, adminOnly: false),
  ];

  /// Filter destinations based on user role.
  static List<_NavItem> _getDestinations(String? role) {
    if (role == 'admin' || role == null) {
      // null = profile not yet loaded, show all until loaded
      return _allDestinations;
    }
    // CASHIER: only non-admin tabs
    return _allDestinations.where((d) => !d.adminOnly).toList();
  }

  int _currentIndex(BuildContext context, List<_NavItem> destinations) {
    final location = GoRouterState.of(context).uri.toString();
    final idx = destinations.indexWhere((d) => location.startsWith(d.path));
    return idx < 0 ? 0 : idx;
  }

  void _onTap(BuildContext context, int index, List<_NavItem> destinations) {
    context.go(destinations[index].path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final role = ref.watch(userRoleProvider);
    final destinations = _getDestinations(role);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        final selected = _currentIndex(context, destinations);

        if (isWide) {
          // ── Desktop / Web: NavigationRail ──────────────
          return Scaffold(
            backgroundColor: context.theme.scaffoldBackgroundColor,
            body: Row(
              children: [
                _ArtisanalNavRail(
                  destinations: destinations,
                  selectedIndex: selected,
                  extended: constraints.maxWidth > 1200,
                  onDestinationSelected: (i) => _onTap(context, i, destinations),
                  isDark: isDark,
                  onToggleTheme: () => _toggleTheme(ref),
                ),
                Expanded(child: child),
              ],
            ),
          );
        }

        // ── Mobile: BottomNavigationBar ────────────────
        return Scaffold(
          backgroundColor: context.theme.scaffoldBackgroundColor,
          body: child,
          bottomNavigationBar: _ArtisanalBottomNav(
            destinations: destinations,
            selectedIndex: selected,
            onDestinationSelected: (i) => _onTap(context, i, destinations),
          ),
        );
      },
    );
  }

  void _toggleTheme(WidgetRef ref) {
    final current = ref.read(themeModeProvider);
    ref.read(themeModeProvider.notifier).state =
        current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }
}

// ════════════════════════════════════════════════════════════
// DESKTOP — Custom NavigationRail
// ════════════════════════════════════════════════════════════

class _ArtisanalNavRail extends StatelessWidget {
  const _ArtisanalNavRail({
    required this.destinations,
    required this.selectedIndex,
    required this.extended,
    required this.onDestinationSelected,
    required this.isDark,
    required this.onToggleTheme,
  });

  final List<_NavItem> destinations;
  final int selectedIndex;
  final bool extended;
  final ValueChanged<int> onDestinationSelected;
  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: extended ? 200 : 72,
      decoration: BoxDecoration(
        color: context.theme.surfaceLow,
        border: Border(
          right: BorderSide(
            color: context.theme.surfaceHighest,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // ── Logo ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.theme.colorScheme.primaryContainer.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.storefront, size: 28, color: context.theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 8),
          // ── Nav Items ────────────────────────────────
          ...destinations.asMap().entries.map((entry) {
            final i = entry.key;
            final d = entry.value;
            final isSelected = i == selectedIndex;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onDestinationSelected(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                      horizontal: extended ? 16 : 0,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.theme.colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: extended
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        Icon(
                          isSelected ? d.selectedIcon : d.icon,
                          size: 22,
                          color: isSelected ? context.theme.colorScheme.onPrimary : context.theme.colorScheme.onSurfaceVariant,
                        ),
                        if (extended) ...[
                          const SizedBox(width: 12),
                          Text(
                            d.label,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? context.theme.colorScheme.onPrimary : context.theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          // ── Theme Toggle ────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onToggleTheme,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: extended ? 16 : 0,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: context.theme.surfaceHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: extended
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, anim) =>
                            RotationTransition(turns: Tween(begin: 0.75, end: 1.0).animate(anim), child: FadeTransition(opacity: anim, child: child)),
                        child: Icon(
                          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          key: ValueKey(isDark),
                          size: 20,
                          color: context.theme.accentButton,
                        ),
                      ),
                      if (extended) ...[
                        const SizedBox(width: 12),
                        Text(
                          isDark ? 'Light Mode' : 'Dark Mode',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: context.theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// MOBILE — Custom BottomNavigationBar
// ════════════════════════════════════════════════════════════

class _ArtisanalBottomNav extends StatelessWidget {
  const _ArtisanalBottomNav({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<_NavItem> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.theme.surfaceLow,
        border: Border(
          top: BorderSide(
            color: context.theme.surfaceHighest,
            width: 1,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: destinations.asMap().entries.map((entry) {
          final i = entry.key;
          final d = entry.value;
          final isSelected = i == selectedIndex;

          return Expanded(
            child: GestureDetector(
              onTap: () => onDestinationSelected(i),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.theme.colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        isSelected ? d.selectedIcon : d.icon,
                        size: 22,
                        color: isSelected ? context.theme.colorScheme.onPrimary : context.theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      d.label,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? context.theme.colorScheme.primary : context.theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Internal model ────────────────────────────────────────

class _NavItem {
  _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.path,
    required this.adminOnly,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String path;
  final bool adminOnly;
}
