import 'package:flutter/material.dart';
import 'package:toempah_rempah/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../providers/analytics_notifier.dart';
import '../../domain/models/analytics_data.dart';
import '../../../../core/widgets/outlet_selector.dart';

/// ════════════════════════════════════════════════════════════
/// DASHBOARD PAGE — "The Artisanal Interface" design system
/// ════════════════════════════════════════════════════════════

// ── Design Tokens ────────────────────────────────────────────
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(analyticsProvider);

    return Scaffold(
      backgroundColor: context.theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: context.theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 24,
        title: Text(
          'Analytics',
          style: GoogleFonts.manrope(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: context.theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          const OutletSelector(allowAll: true),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.theme.colorScheme.onSurfaceVariant),
            onPressed: () => ref.read(analyticsProvider.notifier).refresh(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: analyticsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.theme.colorScheme.primary, strokeWidth: 2),
        ),
        error: (err, st) => _ErrorState(
          message: err.toString(),
          onRetry: () => ref.read(analyticsProvider.notifier).refresh(),
        ),
        data: (state) {
          if (state.data == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bar_chart_rounded,
                      size: 64, color: context.theme.outlineVariantCustom),
                  const SizedBox(height: 16),
                  Text('No data yet',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: context.theme.colorScheme.onSurface,
                      )),
                  const SizedBox(height: 8),
                  Text('Complete some transactions to see analytics.',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: context.theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FiltersRow(
                  state: state,
                  onPeriodChanged: (p) {
                    if (p != null) {
                      ref
                          .read(analyticsProvider.notifier)
                          .updateFilters(newPeriod: p);
                    }
                  },
                ),
                const SizedBox(height: 24),
                _KpiGrid(data: state.data!),
                const SizedBox(height: 24),
                _TrendChartSection(
                    data: state.data!, period: state.selectedPeriod),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// FILTERS ROW
// ════════════════════════════════════════════════════════════

class _FiltersRow extends StatelessWidget {
  const _FiltersRow({
    required this.state,
    required this.onPeriodChanged,
  });

  final AnalyticsState state;
  final ValueChanged<String?> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final periodDropdown = _ArtisanalDropdown(
        label: 'Time Period',
        value: state.selectedPeriod,
        items: const [
          DropdownMenuItem(
              value: 'daily',
              child: Text('Daily', overflow: TextOverflow.ellipsis)),
          DropdownMenuItem(
              value: 'monthly',
              child: Text('Monthly', overflow: TextOverflow.ellipsis)),
          DropdownMenuItem(
              value: 'yearly',
              child: Text('Yearly', overflow: TextOverflow.ellipsis)),
          DropdownMenuItem(
              value: 'all',
              child: Text('All Time', overflow: TextOverflow.ellipsis)),
        ],
        onChanged: onPeriodChanged,
      );

      if (constraints.maxWidth > 600) {
        return Row(
          children: [
            Expanded(flex: 2, child: periodDropdown),
            const Spacer(flex: 3),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          periodDropdown,
        ],
      );
    });
  }
}

class _ArtisanalDropdown extends StatelessWidget {
  const _ArtisanalDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: context.theme.surfaceHighest.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: context.theme.colorScheme.primary.withOpacity(0.3), width: 1),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          style: GoogleFonts.inter(fontSize: 14, color: context.theme.colorScheme.onSurface),
          dropdownColor: context.theme.cardWhite,
          initialValue: value,
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
// KPI GRID
// ════════════════════════════════════════════════════════════

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data});
  final AnalyticsData data;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
        locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    final cards = [
      _ArtisanalKpiCard(
        title: 'Total Revenue',
        value: currency.format(data.totalSales),
        icon: Icons.trending_up_rounded,
        iconBg: context.theme.tertiaryFixedDim.withOpacity(0.3),
        iconColor: context.theme.colorScheme.tertiary,
      ),
      _ArtisanalKpiCard(
        title: 'Gross Profit',
        value: currency.format(data.grossProfit),
        icon: Icons.account_balance_wallet_rounded,
        iconBg: context.theme.colorScheme.primaryContainer.withOpacity(0.12),
        iconColor: context.theme.colorScheme.primary,
      ),
      _ArtisanalKpiCard(
        title: 'HPP (COGS)',
        value: currency.format(data.totalCogs),
        icon: Icons.inventory_2_rounded,
        iconBg: context.theme.colorScheme.errorContainer,
        iconColor: context.theme.colorScheme.error,
      ),
      _ArtisanalKpiCard(
        title: 'Transactions',
        value: '${data.transactionCount}',
        icon: Icons.receipt_long_rounded,
        iconBg: context.theme.surfaceHighest,
        iconColor: context.theme.colorScheme.onSurfaceVariant,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 700 ? 4 : 2;
        const spacing = 12.0;
        final cardWidth =
            (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map((card) => SizedBox(width: cardWidth, child: card))
              .toList(),
        );
      },
    );
  }
}

class _ArtisanalKpiCard extends StatelessWidget {
  const _ArtisanalKpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });
  final String title;
  final String value;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: context.theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// TREND CHART SECTION
// ════════════════════════════════════════════════════════════

class _TrendChartSection extends StatelessWidget {
  const _TrendChartSection({required this.data, required this.period});
  final AnalyticsData data;
  final String period;

  @override
  Widget build(BuildContext context) {
    if (data.salesTrend.isEmpty) return const SizedBox();

    final double maxAmount =
        data.salesTrend.fold(0.0, (m, e) => e.amount > m ? e.amount : m);
    final double maxY = maxAmount == 0 ? 100 : maxAmount * 1.2;

    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.theme.colorScheme.primaryContainer.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.show_chart_rounded,
                    color: context.theme.colorScheme.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Sales Trend',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: context.theme.surfaceHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  period.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final bool isWide = constraints.maxWidth > 500;

              return SizedBox(
                height: 280,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval:
                          (maxY / 4) == 0 ? 1 : (maxY / 4),
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: context.theme.outlineVariantCustom.withOpacity(0.3),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      handleBuiltInTouches: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => context.theme.colorScheme.primary,
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final value = NumberFormat.compactCurrency(
                                    locale: 'id_ID',
                                    symbol: 'Rp ',
                                    decimalDigits: 0)
                                .format(spot.y);
                            final labelX =
                                data.salesTrend[spot.x.toInt()].label;
                            return LineTooltipItem(
                              '$labelX\n$value',
                              GoogleFonts.inter(
                                color: context.theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          getTitlesWidget: (value, meta) {
                            if (value == 0 || value == maxY) {
                              return const SizedBox();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  NumberFormat.compactCurrency(
                                          locale: 'id_ID', symbol: 'Rp ')
                                      .format(value),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: context.theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final int index = value.toInt();
                            if (index < 0 || index >= data.salesTrend.length) {
                              return const SizedBox();
                            }
                            // Daily (24 points): 2h on desktop, 4h on mobile
                            // Monthly/Yearly: show every label
                            final len = data.salesTrend.length;
                            if (len > 20) {
                              // Daily mode
                              final step = isWide ? 2 : 4;
                              if (index % step != 0) return const SizedBox();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                data.salesTrend[index].label,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: context.theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: (data.salesTrend.length - 1).toDouble(),
                    minY: 0,
                    maxY: maxY,
                    lineBarsData: [
                      LineChartBarData(
                        spots: data.salesTrend.asMap().entries.map((e) {
                          return FlSpot(e.key.toDouble(), e.value.amount);
                        }).toList(),
                        isCurved: true,
                        preventCurveOverShooting: true,
                        preventCurveOvershootingThreshold: 0.0,
                        curveSmoothness: 0.15,
                        color: context.theme.colorScheme.primary,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              context.theme.colorScheme.primary.withOpacity(0.15),
                              context.theme.colorScheme.primary.withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// ERROR STATE
// ════════════════════════════════════════════════════════════

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: context.theme.outlineVariantCustom),
          const SizedBox(height: 12),
          Text('Failed to load analytics',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: context.theme.colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 12, color: context.theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: context.theme.outlineVariantCustom),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(Icons.refresh, size: 18, color: context.theme.colorScheme.primary),
            label: Text('Retry', style: GoogleFonts.inter(color: context.theme.colorScheme.primary)),
          ),
        ],
      ),
    );
  }
}
