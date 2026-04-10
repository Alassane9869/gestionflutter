import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/inventory/providers/dashboard_providers.dart';
import 'package:danaya_plus/features/inventory/presentation/widgets/dashboard_widgets.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/auth/domain/models/user.dart';

class DashboardContent extends ConsumerWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = DashColors.of(context);
    final metricsAsync = ref.watch(dashboardProvider);
    final filterState = ref.watch(dashboardFilterProvider);

    return Container(
      color: c.bg,
      child: metricsAsync.when(
        skipLoadingOnRefresh: true,
        loading: () => Center(
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(c.blue),
          ),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FluentIcons.error_circle_24_regular,
                color: c.rose,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(e.toString(), style: TextStyle(color: c.textSecondary)),
            ],
          ),
        ),
        data: (m) =>
            _Body(metrics: m, filterState: filterState, ref: ref, c: c),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final DashboardMetrics metrics;
  final DashboardFilterState filterState;
  final WidgetRef ref;
  final DashColors c;

  const _Body({
    required this.metrics,
    required this.filterState,
    required this.ref,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 1100;
    final user = ref.read(authServiceProvider).value;
    final isGlobal =
        user?.role == UserRole.admin ||
        user?.role == UserRole.manager ||
        user?.role == UserRole.adminPlus;

    return Column(
      children: [
        _TopBar(filterState: filterState, ref: ref, c: c),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── VUE COMPACTE DES KPIs (Strip) ──
                _buildCompactKpiStrip(w, isGlobal),
                const SizedBox(height: 16),

                // ── SECTION GRAPHIQUES (Bento Row 1) ──
                if (isWide)
                  SizedBox(
                    height: 280,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 3, child: _buildRevenueChart()),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _buildSectionWrapper(
                            title: "Mix Produits",
                            subtitle: "Meilleures ventes",
                            child: DashboardPieChart(
                              data: metrics.topProducts.take(5).toList(),
                              c: c,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  _buildRevenueChart(),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 16),

                // ── SECTION ANALYSE (Bento Row 2) ──
                if (isWide)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildTopProductsCompact()),
                        const SizedBox(width: 12),
                        Expanded(child: _buildRecentSales()),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStockAlerts()),
                      ],
                    ),
                  )
                else ...[
                  _buildTopProductsCompact(),
                  const SizedBox(height: 12),
                  _buildRecentSales(),
                  const SizedBox(height: 12),
                  _buildStockAlerts(),
                ],
                const SizedBox(height: 16),

                // ── SECTION FINANCIÈRE SECONDAIRE (Bento Row 3) ──
                if (isGlobal)
                  if (isWide)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildFinancialTilesRow1(c)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTopDebtors()),
                        ],
                      ),
                    )
                  else ...[
                    _buildFinancialTilesRow1(c),
                    const SizedBox(height: 12),
                    _buildTopDebtors(),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactKpiStrip(double w, bool isGlobal) {
    final count = isGlobal ? 4 : 3;
    final cols = w > 1200 ? count : (w > 600 ? 2 : 1);
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: cols,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: cols >= 4 ? 2.8 : (cols == 3 ? 2.4 : 2.8),
      children: [
        UltraKpiCard(
          label: "Chiffre d'Affaires",
          value: ref.fmt(metrics.periodRevenue),
          icon: FluentIcons.money_24_regular,
          accent: c.blue,
          sparkData: metrics.revenueSparkline,
        ),
        UltraKpiCard(
          label: "Nombre de Ventes",
          value: DateFormatter.formatNumber(metrics.periodSalesCount),
          icon: FluentIcons.receipt_24_regular,
          accent: c.emerald,
          change:
              "${metrics.salesTrend >= 0 ? '+' : ''}${metrics.salesTrend.toStringAsFixed(0)}%",
          positive: metrics.salesTrend >= 0,
        ),
        UltraKpiCard(
          label: "Panier Moyen",
          value: ref.fmt(metrics.averageBasket),
          icon: FluentIcons.cart_24_regular,
          accent: c.violet,
          sparkData: metrics.basketSparkline,
        ),
        if (isGlobal)
          UltraKpiCard(
            label: "Résultat Net",
            value: ref.fmt(metrics.totalProfitPeriod),
            icon: FluentIcons.money_calculator_24_regular,
            accent: metrics.totalProfitPeriod >= 0 ? c.emerald : c.rose,
            change:
                "${metrics.profitTrend >= 0 ? '+' : ''}${metrics.profitTrend.toStringAsFixed(0)}%",
            positive: metrics.profitTrend >= 0,
          ),
      ],
    );
  }

  Widget _buildFinancialTilesRow1(DashColors c) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: UltraKpiCard(
                label: "Valeur Stock",
                value: ref.fmt(metrics.totalStockValue),
                icon: FluentIcons.box_24_regular,
                accent: c.blue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: UltraKpiCard(
                label: "Dépenses",
                value: ref.fmt(metrics.totalExpensesPeriod),
                icon: FluentIcons.receipt_bag_24_regular,
                accent: c.rose,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: UltraKpiCard(
                label: "Profit Potentiel",
                value: ref.fmt(metrics.totalPotentialProfit),
                icon: FluentIcons.arrow_trending_24_regular,
                accent: c.emerald,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: UltraKpiCard(
                label: "Total Dettes",
                value: ref.fmt(metrics.totalDebtAmount),
                icon: FluentIcons.person_money_24_regular,
                accent: c.amber,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionWrapper({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return SectionCard(
      title: title,
      subtitle: subtitle,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // GRAPHIQUE DE REVENUS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildRevenueChart() {
    final data = metrics.revenueChartData;
    return SectionCard(
      title: 'Revenus',
      subtitle: '7 derniers jours',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 16, 12),
        child: SizedBox(
          height: 180,
          child: data.isEmpty
              ? Center(
                  child: Text(
                    'Aucune donnée',
                    style: TextStyle(color: c.textSecondary),
                  ),
                )
              : LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: c.border, strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 52,
                          getTitlesWidget: (val, m) => Text(
                            val > 1000
                                ? '${(val / 1000).toStringAsFixed(0)}k'
                                : val.toInt().toString(),
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          getTitlesWidget: (val, m) {
                            final idx = val.toInt();
                            if (idx < 0 || idx >= data.length) {
                              return const SizedBox.shrink();
                            }
                            final raw = data[idx]['day']?.toString() ?? '';
                            final parts = raw.split('-');
                            final label = parts.length >= 3
                                ? '${parts[2]}/${parts[1]}'
                                : raw;
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (spot) => c.surfaceElev,
                        getTooltipItems: (spots) => spots
                            .map(
                              (s) => LineTooltipItem(
                                ref.fmt(s.y),
                                TextStyle(
                                  color: c.blue,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: data
                            .asMap()
                            .entries
                            .map(
                              (e) => FlSpot(
                                e.key.toDouble(),
                                (e.value['total'] as num?)?.toDouble() ?? 0,
                              ),
                            )
                            .toList(),
                        isCurved: true,
                        curveSmoothness: 0.3,
                        color: c.blue,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, _, __, ___) =>
                              FlDotCirclePainter(
                                radius: 4,
                                color: c.blue,
                                strokeWidth: 2,
                                strokeColor: c.surface,
                              ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              c.blue.withValues(alpha: 0.15),
                              Colors.transparent,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TOP PRODUITS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTopProductsCompact() {
    final products = metrics.topProducts;
    return SectionCard(
      title: 'Top Ventes',
      subtitle: 'Volume de vente',
      child: Column(
        children: products.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Aucune vente',
                    style: TextStyle(color: c.textSecondary, fontSize: 12),
                  ),
                ),
              ]
            : products
                  .take(4)
                  .map(
                    (p) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: c.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Icon(
                                FluentIcons.box_16_regular,
                                size: 12,
                                color: c.blue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              p['name']?.toString() ?? '—',
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            ref.fmt(p['total_sales']),
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // VENTES RÉCENTES
  // ═══════════════════════════════════════════════════════════════
  Widget _buildRecentSales() {
    return SectionCard(
      title: 'Activité Récente',
      subtitle: '${metrics.recentSales.length} dernières transactions',
      child: Column(
        children: metrics.recentSales.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Aucune vente',
                    style: TextStyle(color: c.textSecondary),
                  ),
                ),
              ]
            : metrics.recentSales.take(6).map((s) {
                final id = s['id']?.toString() ?? '——';
                final shortId = id.length > 6 ? id.substring(0, 6) : id;
                final date = s['date']?.toString() ?? '——';
                final time = date.length > 15 ? date.substring(11, 16) : '——';
                return ActivityItem(
                  title: 'Vente #$shortId',
                  time: time,
                  amount: ref.fmt(s['total_amount']),
                  color: c.emerald,
                  icon: FluentIcons.receipt_24_regular,
                );
              }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // DETTES CLIENTS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTopDebtors() {
    return SectionCard(
      title: 'Dettes Clients',
      subtitle: 'Total : ${ref.fmt(metrics.totalDebtAmount)}',
      action: metrics.topDebtors.isEmpty
          ? null
          : StatusBadge(
              text:
                  '${metrics.debtClientsCount} CLIENT${metrics.debtClientsCount > 1 ? 'S' : ''}',
              color: c.amber,
            ),
      child: Column(
        children: metrics.topDebtors.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Aucune dette 🎉',
                    style: TextStyle(color: c.textSecondary),
                  ),
                ),
              ]
            : [
                ...metrics.topDebtors.asMap().entries.map((entry) {
                  final d = entry.value;
                  return MetricRow(
                    rank: entry.key + 1,
                    title: d['name']?.toString() ?? '—',
                    subtitle: d['phone']?.toString() ?? 'N/A',
                    value: ref.fmt(d['credit']),
                    accent: c.amber,
                    icon: FluentIcons.person_money_24_regular,
                  );
                }),
              ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ALERTES STOCK — NOUVELLE SECTION
  // ═══════════════════════════════════════════════════════════════
  Widget _buildStockAlerts() {
    final hasAlerts = metrics.lowStockCount > 0 || metrics.outOfStockCount > 0;

    return SectionCard(
      title: 'Alertes Stock',
      subtitle:
          '${metrics.lowStockCount} faible${metrics.lowStockCount > 1 ? 's' : ''} · ${metrics.outOfStockCount} rupture${metrics.outOfStockCount > 1 ? 's' : ''}',
      action: hasAlerts
          ? StatusBadge(
              text: metrics.outOfStockCount > 0 ? 'CRITIQUE' : 'ATTENTION',
              color: metrics.outOfStockCount > 0 ? c.rose : c.amber,
            )
          : StatusBadge(text: 'OK', color: c.emerald),
      child: Column(
        children: [
          if (!hasAlerts)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    FluentIcons.checkmark_circle_24_regular,
                    color: c.emerald,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tous les stocks sont normaux',
                    style: TextStyle(color: c.textSecondary),
                  ),
                ],
              ),
            )
          else ...[
            if (metrics.outOfStockCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Icon(
                      FluentIcons.dismiss_circle_24_filled,
                      color: c.rose,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${metrics.outOfStockCount} produit${metrics.outOfStockCount > 1 ? 's' : ''} en rupture totale',
                      style: TextStyle(
                        color: c.rose,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ...metrics.lowStockProducts.asMap().entries.map((entry) {
              final p = entry.value;
              final qty = (p['quantity'] as num?)?.toDouble() ?? 0.0;
              final threshold =
                  (p['alertThreshold'] as num?)?.toDouble() ?? 0.0;
              return MetricRow(
                rank: entry.key + 1,
                title: p['name']?.toString() ?? '—',
                subtitle: 'Seuil : ${ref.qty(threshold)}',
                value: '${ref.qty(qty)} restants',
                progress: threshold > 0 ? (qty / threshold).clamp(0.0, 1.0) : 0,
                accent: qty == 0 ? c.rose : c.amber,
                icon: FluentIcons.box_24_regular,
              );
            }),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOP BAR
// ═══════════════════════════════════════════════════════════════════════════════
class _TopBar extends StatelessWidget {
  final DashboardFilterState filterState;
  final WidgetRef ref;
  final DashColors c;
  const _TopBar({
    required this.filterState,
    required this.ref,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final filter = filterState.filter;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border, width: 1)),
      ),
      child: Row(
        children: [
          Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: c.emerald,
                  shape: BoxShape.circle,
                ),
              )
              .animate(onPlay: (ctrl) => ctrl.repeat())
              .custom(
                duration: 1500.ms,
                builder: (ctx, v, child) => Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.emerald,
                    boxShadow: [
                      BoxShadow(
                        color: c.emerald.withValues(alpha: v * 0.7),
                        blurRadius: v * 14,
                        spreadRadius: v * 2,
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(width: 12),
          Text(
            'Vue d\'ensemble',
            style: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          Container(
            height: 34,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                for (final f in DashboardFilter.values)
                  _FilterChip(
                    label: switch (f) {
                      DashboardFilter.today => 'Auj.',
                      DashboardFilter.week => 'Sem.',
                      DashboardFilter.month => 'Mois',
                      DashboardFilter.custom => 'Perso',
                    },
                    active: filter == f,
                    accentColor: c.blue,
                    c: c,
                    onTap: () async {
                      if (f == DashboardFilter.custom) {
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: c.emerald,
                                  onPrimary: Colors.white,
                                  surface: c.surface,
                                  onSurface: c.textPrimary,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (range != null) {
                          ref
                              .read(dashboardFilterProvider.notifier)
                              .setCustomRange(range.start, range.end);
                        }
                      } else {
                        ref.read(dashboardFilterProvider.notifier).setFilter(f);
                      }
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _IconBtn(
            icon: FluentIcons.arrow_sync_24_regular,
            onTap: () => ref.read(dashboardProvider.notifier).refresh(),
            tooltip: 'Actualiser',
            c: c,
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color accentColor;
  final DashColors c;
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    required this.accentColor,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : c.textSecondary,
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final DashColors c;
  const _IconBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    required this.c,
  });
  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _h = true),
        onExit: (_) => setState(() => _h = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: 150.ms,
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _h ? widget.c.surfaceElev : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _h ? widget.c.border : Colors.transparent,
              ),
            ),
            child: Icon(
              widget.icon,
              color: _h ? widget.c.textPrimary : widget.c.textSecondary,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}
