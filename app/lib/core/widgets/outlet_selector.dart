import 'package:apos/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/active_outlet_provider.dart';
import '../../features/settings/presentation/providers/outlet_notifier.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';

/// Compact outlet selector chip — used in the AppBar of POS, Inventory, Accounting.
/// Shows the active outlet name with a dropdown to switch.
class OutletSelector extends ConsumerStatefulWidget {
  const OutletSelector({super.key, this.allowAll = false});
  final bool allowAll;
  
  @override
  ConsumerState<OutletSelector> createState() => _OutletSelectorState();
}

class _OutletSelectorState extends ConsumerState<OutletSelector> {
  @override
  Widget build(BuildContext context) {
    var activeOutlet = ref.watch(activeOutletProvider);
    final outletsAsync = ref.watch(outletNotifierProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.valueOrNull;

    return outletsAsync.when(
      loading: () => SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: context.theme.colorScheme.primary),
      ),
      error: (_, __) => const Icon(Icons.error_outline, size: 20),
      data: (outlets) {
        if (outlets.isEmpty) return const SizedBox.shrink();
        if (profileAsync.isLoading) return const SizedBox.shrink();

        final isAdmin = profile?.isAdmin ?? false;

        if (!isAdmin) {
          // Force non-admins to their assigned outlet
          final assignedOutlet = outlets.firstWhere(
            (o) => o.id == profile?.outletId, 
            orElse: () => outlets.first
          );
          if (activeOutlet?.id != assignedOutlet.id) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) ref.read(activeOutletProvider.notifier).setOutlet(assignedOutlet);
            });
            activeOutlet = assignedOutlet;
          }
        } else {
          // Admin fallback logic
          if (!widget.allowAll && activeOutlet == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ref.read(activeOutletProvider.notifier).setOutlet(outlets.first);
              }
            });
            activeOutlet = outlets.first;
          }
        }

        return PopupMenuButton<String>(
          enabled: isAdmin,
          onSelected: (id) {
            if (id == 'ALL') {
               ref.read(activeOutletProvider.notifier).setOutlet(null);
            } else {
               final selected = outlets.firstWhere((o) => o.id == id);
               ref.read(activeOutletProvider.notifier).setOutlet(selected);
            }
          },
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          color: context.theme.cardWhite,
          offset: const Offset(0, 44),
          itemBuilder: (_) {
            final items = <PopupMenuEntry<String>>[];

            // Inject All Outlets option if allowed
            if (widget.allowAll) {
              final isSelected = activeOutlet == null;
              items.add(
                PopupMenuItem<String>(
                  value: 'ALL',
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? context.theme.colorScheme.primaryContainer.withOpacity(0.15)
                              : context.theme.surfaceHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.language_rounded,
                          size: 16,
                          color: isSelected ? context.theme.colorScheme.primary : context.theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'All Outlets',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: context.theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle_rounded,
                            size: 18, color: context.theme.colorScheme.primary),
                    ],
                  ),
                ),
              );
              
              items.add(const PopupMenuDivider());
            }

            // Normal Outlets
            items.addAll(outlets.map((o) {
              final isSelected = activeOutlet?.id == o.id;
              return PopupMenuItem<String>(
                value: o.id,
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.theme.colorScheme.primaryContainer.withOpacity(0.15)
                            : context.theme.surfaceHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.storefront_rounded,
                        size: 16,
                        color: isSelected ? context.theme.colorScheme.primary : context.theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.name,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: context.theme.colorScheme.onSurface,
                            ),
                          ),
                          if (o.address != null && o.address!.isNotEmpty)
                            Text(
                              o.address!,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: context.theme.colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded,
                          size: 18, color: context.theme.colorScheme.primary),
                  ],
                ),
              );
            }));

            return items;
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: context.theme.colorScheme.primaryContainer.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.theme.colorScheme.primary.withOpacity(0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  activeOutlet == null ? Icons.language_rounded : Icons.storefront_rounded,
                  size: 15, 
                  color: context.theme.colorScheme.primary
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 100),
                  child: Text(
                    activeOutlet?.name ?? (widget.allowAll ? 'All Outlets' : 'Select Outlet'),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.theme.colorScheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 16, color: context.theme.colorScheme.primary),
              ],
            ),
          ),
        );
      },
    );
  }
}
