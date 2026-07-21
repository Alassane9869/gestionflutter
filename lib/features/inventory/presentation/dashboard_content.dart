import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/inventory/providers/dashboard_providers.dart';
import 'package:danaya_plus/features/inventory/providers/dashboard_customization_provider.dart';
import 'package:danaya_plus/features/inventory/presentation/widgets/dashboard_widgets.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';

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

class _Body extends StatefulWidget {
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
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  DashboardMetrics get metrics => widget.metrics;
  DashboardFilterState get filterState => widget.filterState;
  WidgetRef get ref => widget.ref;
  DashColors get c => widget.c;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 1100;
    final user = ref.read(authServiceProvider).value;
    final isGlobal = user?.canViewGlobalSalesHistory ?? false;
    final customization = ref.watch(dashboardCustomizationProvider);

    return Column(
      children: [
        _TopBar(filterState: filterState, ref: ref, c: c),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ═══════════════════════════════════════════════════
                // SECTION 1 — KPIs
                // ═══════════════════════════════════════════════════
                if (customization.showKpis) ...[
                  _buildCompactKpiStrip(w, isGlobal),
                  const SizedBox(height: 20),
                ],

                // ═══════════════════════════════════════════════════
                // SECTION 2 — PERFORMANCE COMMERCIALE
                // ═══════════════════════════════════════════════════
                if (customization.showRevenueChart || customization.showProductMix) ...[
                  _buildSectionLabel("Performance Commerciale", FluentIcons.chart_multiple_24_regular),
                  const SizedBox(height: 12),
                  if (isWide)
                    SizedBox(
                      height: 300,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (customization.showRevenueChart)
                            Expanded(flex: 3, child: _buildRevenueChart(filterState))
                          else
                            const SizedBox.shrink(),
                          if (customization.showRevenueChart && customization.showProductMix)
                            const SizedBox(width: 12),
                          if (customization.showProductMix)
                            Expanded(
                              flex: 2,
                              child: _buildSectionWrapper(
                                title: "Mix Produits",
                                subtitle: "Meilleures ventes",
                                child: DashboardPieChart(data: metrics.topProducts.take(5).toList(), c: c),
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                        ],
                      ),
                    )
                  else ...[
                    if (customization.showRevenueChart) ...[
                      _buildRevenueChart(filterState),
                      const SizedBox(height: 12),
                    ],
                    if (customization.showProductMix) ...[
                      _buildSectionWrapper(
                        title: "Mix Produits",
                        subtitle: "Meilleures ventes",
                        child: SizedBox(height: 200, child: DashboardPieChart(data: metrics.topProducts.take(5).toList(), c: c)),
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                ],

                // ═══════════════════════════════════════════════════
                // SECTION 3 — ACTIVITÉ & STOCK
                // ═══════════════════════════════════════════════════
                if (customization.showTopSales || customization.showRecentSales || customization.showStockAlerts) ...[
                  _buildSectionLabel("Activité & Inventaire", FluentIcons.box_checkmark_24_regular),
                  const SizedBox(height: 12),
                  if (isWide)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (customization.showTopSales)
                            Expanded(child: _buildTopProductsCompact())
                          else
                            const SizedBox.shrink(),
                          if (customization.showTopSales && (customization.showRecentSales || customization.showStockAlerts))
                            const SizedBox(width: 12),
                          if (customization.showRecentSales)
                            Expanded(child: _buildRecentSales())
                          else
                            const SizedBox.shrink(),
                          if (customization.showRecentSales && customization.showStockAlerts)
                            const SizedBox(width: 12),
                          if (customization.showStockAlerts)
                            Expanded(child: _buildStockAlerts())
                          else
                            const SizedBox.shrink(),
                        ],
                      ),
                    )
                  else ...[
                    if (customization.showTopSales) ...[
                      _buildTopProductsCompact(),
                      const SizedBox(height: 12),
                    ],
                    if (customization.showRecentSales) ...[
                      _buildRecentSales(),
                      const SizedBox(height: 12),
                    ],
                    if (customization.showStockAlerts) ...[
                      _buildStockAlerts(),
                    ],
                  ],
                  const SizedBox(height: 24),
                ],

                // ═══════════════════════════════════════════════════
                // SECTION 3.5 — ANALYSE CROISÉE DES CATÉGORIES
                // ═══════════════════════════════════════════════════
                if (metrics.categoryMatrix.isNotEmpty) ...[
                  _buildSectionLabel("Analyse Croisée des Catégories", FluentIcons.table_24_regular),
                  const SizedBox(height: 12),
                  _buildCategoryPerformanceMatrix(isWide, isGlobal),
                  const SizedBox(height: 24),
                ],

                // ═══════════════════════════════════════════════════
                // SECTION 4 — ANALYSE FINANCIÈRE (Global uniquement)
                // ═══════════════════════════════════════════════════
                if (isGlobal) ...[
                  _buildSectionLabel("Analyse Financière", FluentIcons.data_pie_24_regular),
                  const SizedBox(height: 12),

                  // Ligne 1 : KPI financiers + Débiteurs
                  if (customization.showFinancialSummary || customization.showDebtors) ...[
                    if (isWide)
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (customization.showFinancialSummary)
                              Expanded(child: _buildFinancialTilesRow1(c))
                            else
                              const SizedBox.shrink(),
                            if (customization.showFinancialSummary && customization.showDebtors)
                              const SizedBox(width: 12),
                            if (customization.showDebtors)
                              Expanded(child: _buildTopDebtors())
                            else
                              const SizedBox.shrink(),
                          ],
                        ),
                      )
                    else ...[
                      if (customization.showFinancialSummary) ...[
                        _buildFinancialTilesRow1(c),
                        const SizedBox(height: 12),
                      ],
                      if (customization.showDebtors) ...[
                        _buildTopDebtors(),
                      ],
                    ],
                    const SizedBox(height: 16),
                  ],

                  // Ligne 2 : Marge Nette + Bilan Revenus/Dépenses
                  if (isWide)
                    SizedBox(
                      height: 260,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildSectionWrapper(
                              title: "Marge Nette",
                              subtitle: "Rentabilité globale",
                              expandChild: true,
                              child: DashboardProfitMarginGauge(
                                c: c,
                                profitMargin: metrics.periodRevenue > 0
                                    ? (metrics.totalProfitPeriod / metrics.periodRevenue)
                                    : 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: _buildSectionWrapper(
                              title: "Bilan Financier",
                              subtitle: "Revenus vs Dépenses",
                              expandChild: true,
                              child: DashboardExpenseVsIncomeChart(
                                c: c,
                                income: metrics.periodRevenue,
                                expense: metrics.totalExpensesPeriod,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: _buildSectionWrapper(
                              title: "Santé du Stock",
                              subtitle: "Disponibilité",
                              expandChild: true,
                              child: DashboardStockHealthChart(
                                c: c,
                                inStock: (metrics.totalProductsCount - metrics.lowStockCount - metrics.outOfStockCount).clamp(0, 999999),
                                lowStock: metrics.lowStockCount,
                                outOfStock: metrics.outOfStockCount,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    _buildSectionWrapper(
                      title: "Marge Nette",
                      subtitle: "Rentabilité globale",
                      child: SizedBox(
                        height: 220,
                        child: DashboardProfitMarginGauge(
                          c: c,
                          profitMargin: metrics.periodRevenue > 0
                              ? (metrics.totalProfitPeriod / metrics.periodRevenue)
                              : 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSectionWrapper(
                      title: "Bilan Financier",
                      subtitle: "Revenus vs Dépenses",
                      child: SizedBox(
                        height: 220,
                        child: DashboardExpenseVsIncomeChart(
                          c: c,
                          income: metrics.periodRevenue,
                          expense: metrics.totalExpensesPeriod,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSectionWrapper(
                      title: "Santé du Stock",
                      subtitle: "Disponibilité",
                      child: SizedBox(
                        height: 160,
                        child: DashboardStockHealthChart(
                          c: c,
                          inStock: (metrics.totalProductsCount - metrics.lowStockCount - metrics.outOfStockCount).clamp(0, 999999),
                          lowStock: metrics.lowStockCount,
                          outOfStock: metrics.outOfStockCount,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Ligne 3 : Radar Performance
                  _buildSectionWrapper(
                    title: "Performance Globale",
                    subtitle: "Indicateurs clés",
                    child: SizedBox(
                      height: 220,
                      child: DashboardRadarChart(
                        c: c,
                        salesScore: (metrics.periodRevenue > 0) ? 0.85 : 0.2,
                        profitScore: (metrics.totalProfitPeriod > 0) ? 0.75 : 0.1,
                        stockScore: metrics.outOfStockCount == 0 ? 0.95 : 0.6,
                        clientScore: metrics.periodSalesCount > 0 ? 0.8 : 0.3,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // SECTION LABEL — Titres de section élégants
  // ─────────────────────────────────────────────────
  Widget _buildSectionLabel(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: c.blue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 16, color: c.textSecondary),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            color: c.border,
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
    bool expandChild = false,
  }) {
    final paddingChild = Padding(padding: const EdgeInsets.all(16), child: child);
    return SectionCard(
      title: title,
      subtitle: subtitle,
      child: expandChild ? Expanded(child: paddingChild) : paddingChild,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // GRAPHIQUE DE REVENUS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildRevenueChart(DashboardFilterState filterState) {
    final data = metrics.revenueChartData;
    String subtitle = '7 derniers jours';
    
    if (filterState.filter == DashboardFilter.today) {
      subtitle = "Aujourd'hui";
    } else if (filterState.filter == DashboardFilter.week) {
      subtitle = "7 derniers jours";
    } else if (filterState.filter == DashboardFilter.month) {
      subtitle = "Ce mois-ci";
    } else if (filterState.filter == DashboardFilter.custom) {
      final startStr = filterState.customStartDate != null
          ? '${filterState.customStartDate!.day.toString().padLeft(2, '0')}/${filterState.customStartDate!.month.toString().padLeft(2, '0')}/${filterState.customStartDate!.year}'
          : '';
      final endStr = filterState.customEndDate != null
          ? '${filterState.customEndDate!.day.toString().padLeft(2, '0')}/${filterState.customEndDate!.month.toString().padLeft(2, '0')}/${filterState.customEndDate!.year}'
          : '';
      subtitle = startStr.isNotEmpty && endStr.isNotEmpty
          ? 'Du $startStr au $endStr'
          : 'Période personnalisée';
    }

    return SectionCard(
      title: 'Revenus',
      subtitle: subtitle,
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
                      minX: 0,
                      maxX: data.length > 1 ? (data.length - 1).toDouble() : 1.0,
                      minY: 0,
                      maxY: data.isEmpty ? 100 : (data.map((e) => (e['total'] as num?)?.toDouble() ?? 0).reduce(math.max) * 1.2).clamp(10.0, double.infinity),
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
                              // Empêcher la superposition des étiquettes si la période est longue (plus de 7 jours)
                              final labelInterval = (data.length / 7).ceil();
                              if (idx % labelInterval != 0 && idx != data.length - 1) {
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
                                    color: c.primary,
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
                        color: c.primary,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, _, __, ___) =>
                              FlDotCirclePainter(
                                radius: 4,
                                color: c.primary,
                                strokeWidth: 2,
                                strokeColor: c.surface,
                              ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              c.primary.withValues(alpha: 0.15),
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
  // MATRICE DE PERFORMANCE CATÉGORIES
  // ═══════════════════════════════════════════════════════════════
  Widget _buildCategoryPerformanceMatrix(bool isWide, bool isGlobal) {
    final matrix = metrics.categoryMatrix;
    return SectionCard(
      title: "Performance Croisée par Catégorie",
      subtitle: "Analyse croisée des flux de stock, ventes et rentabilité par catégorie d'articles",
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(c.surfaceElev),
              dataRowMinHeight: 48,
              dataRowMaxHeight: 48,
              columnSpacing: isWide ? 24 : 14,
              horizontalMargin: 12,
              columns: [
                DataColumn(label: Text("Catégorie", style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text("Réf. Articles", style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
                DataColumn(label: Text("Stock (Qté)", style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
                if (isGlobal)
                  DataColumn(label: Text("Valeur Stock", style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
                DataColumn(label: Text("Unités Vendues", style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
                DataColumn(label: Text("C.A. Généré", style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
                if (isGlobal)
                  DataColumn(label: Text("Bénéfice Brut", style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)), numeric: true),
                DataColumn(label: Text("Indicateur de Rotation", style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
              ],
              rows: matrix.map((row) {
                final catName = row['category'] as String? ?? 'Non classé';
                final productsCount = row['products_count'] as int? ?? 0;
                final stockQty = (row['stock_qty'] as num?)?.toDouble() ?? 0.0;
                final stockValue = (row['stock_value'] as num?)?.toDouble() ?? 0.0;
                final qtySold = (row['qty_sold'] as num?)?.toDouble() ?? 0.0;
                final salesValue = (row['sales_value'] as num?)?.toDouble() ?? 0.0;
                final profitValue = (row['profit_value'] as num?)?.toDouble() ?? 0.0;

                // Taux de Rotation = Qte Vendue / (Qte en Stock + Qte Vendue)
                final double totalFlow = stockQty + qtySold;
                final double rotationRate = totalFlow > 0 ? (qtySold / totalFlow) : 0.0;

                Color rotationColor = c.rose;
                String rotationLabel = "Faible";
                if (rotationRate >= 0.5) {
                  rotationColor = c.emerald;
                  rotationLabel = "Excellent";
                } else if (rotationRate >= 0.15) {
                  rotationColor = c.amber;
                  rotationLabel = "Modéré";
                }

                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FluentIcons.folder_24_regular, size: 14, color: c.blue),
                          const SizedBox(width: 8),
                          Text(catName, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
                        ],
                      ),
                    ),
                    DataCell(Text(productsCount.toString(), style: TextStyle(color: c.textPrimary, fontSize: 12))),
                    DataCell(Text(DateFormatter.formatNumber(stockQty), style: TextStyle(color: c.textPrimary, fontSize: 12))),
                    if (isGlobal)
                      DataCell(Text(ref.fmt(stockValue), style: TextStyle(color: c.textPrimary, fontSize: 12))),
                    DataCell(Text(DateFormatter.formatNumber(qtySold), style: TextStyle(color: c.textPrimary, fontSize: 12))),
                    DataCell(Text(ref.fmt(salesValue), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
                    if (isGlobal)
                      DataCell(Text(ref.fmt(profitValue), style: TextStyle(color: c.emerald, fontWeight: FontWeight.w700, fontSize: 12))),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 40,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: rotationRate,
                                backgroundColor: c.border,
                                valueColor: AlwaysStoppedAnimation<Color>(rotationColor),
                                minHeight: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "${(rotationRate * 100).toStringAsFixed(0)}% ($rotationLabel)",
                            style: TextStyle(color: rotationColor, fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
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
