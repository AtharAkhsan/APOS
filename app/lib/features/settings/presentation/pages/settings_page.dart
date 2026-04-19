import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:apos/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/router/app_router.dart';

import 'outlet_management_page.dart';

/// ════════════════════════════════════════════════════════════
/// SETTINGS PAGE — "The Artisanal Interface" design system
/// ════════════════════════════════════════════════════════════

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentThemeMode = ref.watch(themeModeProvider);
    final profileAsync = ref.watch(userProfileProvider);
    return Scaffold(
      backgroundColor: context.theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: context.theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 24,
        title: Text(
          'Settings',
          style: GoogleFonts.manrope(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: context.theme.colorScheme.onSurface,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Profile Card ─────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.theme.cardWhite,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1B1D0E).withOpacity(0.04),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: context.theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            profileAsync.valueOrNull?.displayName.substring(0, 1).toUpperCase() ?? 'U',
                            style: GoogleFonts.manrope(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: context.theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profileAsync.valueOrNull?.displayName ?? 'Loading...',
                              style: GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: context.theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              profileAsync.valueOrNull?.role ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: context.theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: profileAsync.valueOrNull?.isAdmin == true
                              ? context.theme.colorScheme.primaryContainer.withOpacity(0.3)
                              : context.theme.tertiaryFixedDim.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          profileAsync.valueOrNull?.isAdmin == true ? 'Admin' : 'Cashier',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: profileAsync.valueOrNull?.isAdmin == true
                                ? context.theme.colorScheme.primary
                                : context.theme.colorScheme.tertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── General Section (Admin only) ────────
                if (profileAsync.valueOrNull?.isAdmin == true) ...[
                const _SectionHeader(title: 'General'),
                const SizedBox(height: 8),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      icon: Icons.storefront_rounded,
                      iconBg: context.theme.colorScheme.primaryContainer.withOpacity(0.12),
                      iconColor: context.theme.colorScheme.primary,
                      title: 'Outlet Management',
                      subtitle: 'Manage outlets & branches',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const OutletManagementPage(),
                          ),
                        );
                      },
                    ),
                    _SettingsDivider(),
                    _SettingsTile(
                      icon: Icons.receipt_long_rounded,
                      iconBg: context.theme.surfaceHighest,
                      iconColor: context.theme.colorScheme.onSurfaceVariant,
                      title: 'Receipt Settings',
                      subtitle: 'Header, footer & format',
                      onTap: () {},
                    ),
                    _SettingsDivider(),
                    _SettingsTile(
                      icon: Icons.payments_outlined,
                      iconBg: context.theme.tertiaryFixedDim.withOpacity(0.3),
                      iconColor: context.theme.colorScheme.tertiary,
                      title: 'Payment Methods',
                      subtitle: 'Cash, QRIS & card settings',
                      onTap: () {},
                    ),
                  ],
                ),
                ],
                const SizedBox(height: 24),

                // ── Appearance Section ──────────────────
                const _SectionHeader(title: 'Appearance'),
                const SizedBox(height: 8),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      icon: Icons.palette_outlined,
                      iconBg: context.theme.colorScheme.primaryContainer.withOpacity(0.12),
                      iconColor: context.theme.colorScheme.primary,
                      title: 'Theme',
                      subtitle: 'The Artisanal Interface',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.theme.surfaceHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          currentThemeMode == ThemeMode.dark
                              ? 'Dark'
                              : currentThemeMode == ThemeMode.light
                                  ? 'Light'
                                  : 'System',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      onTap: () {
                        // Cycle themes
                        final nextTheme = currentThemeMode == ThemeMode.light 
                            ? ThemeMode.dark 
                            : currentThemeMode == ThemeMode.dark 
                                ? ThemeMode.system 
                                : ThemeMode.light;
                        ref.read(themeModeProvider.notifier).state = nextTheme;
                      },
                    ),
                    _SettingsDivider(),
                    _SettingsTile(
                      icon: Icons.language_rounded,
                      iconBg: context.theme.surfaceHighest,
                      iconColor: context.theme.colorScheme.onSurfaceVariant,
                      title: 'Language',
                      subtitle: 'Bahasa Indonesia',
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Account Section ─────────────────────
                const _SectionHeader(title: 'Account'),
                const SizedBox(height: 8),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      icon: Icons.lock_outline_rounded,
                      iconBg: context.theme.surfaceHighest,
                      iconColor: context.theme.colorScheme.onSurfaceVariant,
                      title: 'Change Password',
                      subtitle: 'Update your credentials',
                      onTap: () {},
                    ),
                    _SettingsDivider(),
                    _SettingsTile(
                      icon: Icons.logout_rounded,
                      iconBg: context.theme.colorScheme.errorContainer,
                      iconColor: context.theme.colorScheme.error,
                      title: 'Sign Out',
                      subtitle: 'Log out of your account',
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text('Sign Out',
                                style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
                            content: Text('Are you sure you want to sign out?',
                                style: GoogleFonts.inter()),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text('Cancel', style: GoogleFonts.inter()),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: TextButton.styleFrom(
                                    foregroundColor: context.theme.colorScheme.error),
                                child: Text('Sign Out',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await ref.read(authRepositoryProvider).signOut();
                          if (context.mounted) {
                            context.go(AppRoutes.login);
                          }
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // ── App Version ─────────────────────────
                Center(
                  child: Column(
                    children: [
                      Text(
                        'APOS — Point of Sale',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Version 1.0.0',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: context.theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// SECTION HEADER
// ════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: context.theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// SETTINGS CARD (groups multiple tiles)
// ════════════════════════════════════════════════════════════

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.theme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B1D0E).withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

// ════════════════════════════════════════════════════════════
// SETTINGS TILE
// ════════════════════════════════════════════════════════════

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: context.theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                trailing!,
                const SizedBox(width: 8),
              ],
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: context.theme.outlineVariantCustom),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// SETTINGS DIVIDER
// ════════════════════════════════════════════════════════════

class _SettingsDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        thickness: 1,
        color: context.theme.surfaceHighest.withOpacity(0.5),
      ),
    );
  }
}
