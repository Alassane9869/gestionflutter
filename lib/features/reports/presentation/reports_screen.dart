import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';

import 'package:danaya_plus/features/reports/providers/report_providers.dart';
import 'package:danaya_plus/features/reports/domain/models/report_models.dart';
import 'package:danaya_plus/features/reports/services/pdf_report_service.dart';
import 'package:danaya_plus/features/reports/services/excel_export_service.dart';
import 'package:danaya_plus/features/reports/services/receipt_report_service.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/core/widgets/access_denied_screen.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/core/services/email_service.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/features/inventory/presentation/dashboard_screen.dart';
import 'package:danaya_plus/features/inventory/presentation/widgets/dashboard_widgets.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _selectedRange = 'Ce Mois';

  void _updateRange(String preset) {
    setState(() => _selectedRange = preset);
    final now = DateTime.now();
    DateTime start;
    DateTime end = now;

    switch (preset) {
      case "Aujourd'hui":
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'Cette Semaine':
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        break;
      case 'Ce Mois':
        start = DateTime(now.year, now.month, 1);
        break;
      case 'Cette Année':
        start = DateTime(now.year, 1, 1);
        break;
      default:
        start = DateTime(now.year, now.month, 1);
    }

    ref.read(dateRangeProvider.notifier).updateRange(DateTimeRange(start: start, end: end));
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final range = ref.watch(dateRangeProvider);
    final kpisAsync = ref.watch(reportKPIsProvider(range));
    final topProductsAsync = ref.watch(topProductsProvider(range));
    final chartDataAsync = ref.watch(revenueChartProvider(range));

    final user = ref.watch(authServiceProvider).value;
    if (user == null || !user.canAccessReports) {
      return const AccessDeniedScreen(
        message: "Rapports Restreints",
        subtitle: "Vous n'avez pas l'autorisation de consulter les analyses financières.",
      );
    }

    // Log access once
    final loggedUserId = user.id;
    final loggedUserName = user.username;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).logActivity(
        userId: loggedUserId,
        actionType: 'VIEW_REPORTS',
        description: 'Consultation des rapports par $loggedUserName',
      );
    });

    final w = MediaQuery.of(context).size.width;
    final isWide = w > 1100;

    return Container(
      color: c.bg,
      child: Column(
        children: [
          // ═══════════════════════════════════════════════════
          // TOP BAR — Identique au Dashboard
          // ═══════════════════════════════════════════════════
          _buildTopBar(c, range),

          // ═══════════════════════════════════════════════════
          // SCROLLABLE CONTENT
          // ═══════════════════════════════════════════════════
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ═══════════════════════════════════════════════════
                  // SECTION 1 — KPIs
                  // ═══════════════════════════════════════════════════
                  kpisAsync.when(
                    loading: () => SizedBox(
                      height: 80,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation(c.primary),
                        ),
                      ),
                    ),
                    error: (e, _) => const SizedBox(height: 80),
                    data: (kpi) => _buildKpiGrid(c, kpi, w),
                  ),

                  const SizedBox(height: 24),

                  // ═══════════════════════════════════════════════════
                  // ACTIONS D'EXPORT ET IMPRESSION
                  // ═══════════════════════════════════════════════════
                  _buildSectionLabel("Actions & Exports", FluentIcons.print_24_regular, c),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildBigActionBtn(c, "Ticket Z", FluentIcons.print_24_regular, c.primary, () => _confirmZReport(context)),
                      const SizedBox(width: 12),
                      _buildBigActionBtn(c, "Rapport PDF", FluentIcons.document_pdf_24_regular, c.rose, () => _exportPDF(context)),
                      const SizedBox(width: 12),
                      _buildBigActionBtn(c, "Export Excel", FluentIcons.table_24_regular, c.emerald, () => _exportExcel(context)),
                      const SizedBox(width: 12),
                      _buildBigActionBtn(c, "Partager", FluentIcons.share_24_regular, c.blue, () => _showShareOptions(context)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ═══════════════════════════════════════════════════
                  // SECTION 2 — PERFORMANCE COMMERCIALE
                  // ═══════════════════════════════════════════════════
                  _buildSectionLabel("Performance Commerciale", FluentIcons.chart_multiple_24_regular, c),
                  const SizedBox(height: 12),
                  if (isWide)
                    SizedBox(
                      height: 340,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 3, child: _buildRevenueChart(c, chartDataAsync)),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: _buildTopProducts(c, topProductsAsync)),
                        ],
                      ),
                    )
                  else ...[
                    _buildRevenueChart(c, chartDataAsync),
                    const SizedBox(height: 12),
                    _buildTopProducts(c, topProductsAsync),
                  ],

                  const SizedBox(height: 24),

                  // ═══════════════════════════════════════════════════
                  // SECTION 3 — ANALYSE FINANCIÈRE
                  // ═══════════════════════════════════════════════════
                  kpisAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (kpi) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel("Analyse Financière", FluentIcons.calculator_24_regular, c),
                          const SizedBox(height: 12),
                          if (isWide)
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(flex: 3, child: _buildPnlCard(c, kpi)),
                                  const SizedBox(width: 12),
                                  Expanded(flex: 2, child: _buildMetricsCard(c, kpi, range)),
                                ],
                              ),
                            )
                          else ...[
                            _buildPnlCard(c, kpi),
                            const SizedBox(height: 12),
                            _buildMetricsCard(c, kpi, range),
                          ],
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // TOP BAR — Même design que le Dashboard
  // ═══════════════════════════════════════════════════════════════════════════════
  Widget _buildTopBar(DashColors c, DateTimeRange range) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border, width: 1)),
      ),
      child: Row(
        children: [
          // Back button if needed
          if (Navigator.canPop(context) || ref.watch(navigationProvider) != 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    ref.read(navigationProvider.notifier).setPage(0, ref);
                  }
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: c.surfaceElev,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.border),
                  ),
                  child: Icon(FluentIcons.chevron_left_24_regular, size: 16, color: c.textSecondary),
                ),
              ),
            ),
          // Animated dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c.violet, shape: BoxShape.circle),
          )
              .animate(onPlay: (ctrl) => ctrl.repeat())
              .custom(
                duration: 1500.ms,
                builder: (ctx, v, child) => Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.violet,
                    boxShadow: [
                      BoxShadow(
                        color: c.violet.withValues(alpha: v * 0.7),
                        blurRadius: v * 14,
                        spreadRadius: v * 2,
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(width: 12),
          Text(
            'Rapports & Analytics',
            style: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${DateFormatter.formatCompactDate(range.start)} → ${DateFormatter.formatCompactDate(range.end)}',
            style: TextStyle(color: c.textMuted, fontSize: 11),
          ),
          const Spacer(),
          // Period filter chips
          Container(
            height: 34,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: ["Aujourd'hui", "Cette Semaine", "Ce Mois", "Cette Année"].map((p) {
                final sel = _selectedRange == p;
                return GestureDetector(
                  onTap: () => _updateRange(p),
                  child: AnimatedContainer(
                    duration: 200.ms,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? c.blue : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      _shortLabel(p),
                      style: TextStyle(
                        color: sel ? Colors.white : c.textSecondary,
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 12),
          // Export actions
          _buildTopBarAction(FluentIcons.document_pdf_24_regular, 'PDF', () => _exportPDF(context), c),
          const SizedBox(width: 6),
          _buildTopBarAction(FluentIcons.table_24_regular, 'Excel', () => _exportExcel(context), c),
          const SizedBox(width: 6),
          _buildTopBarAction(FluentIcons.print_24_regular, 'Z', () => _confirmZReport(context), c),
          const SizedBox(width: 6),
          _buildTopBarAction(FluentIcons.share_24_regular, null, () => _showShareOptions(context), c),
        ],
      ),
    );
  }

  String _shortLabel(String label) {
    switch (label) {
      case "Aujourd'hui": return 'Auj.';
      case 'Cette Semaine': return 'Sem.';
      case 'Ce Mois': return 'Mois';
      case 'Cette Année': return 'Année';
      default: return label;
    }
  }

  Widget _buildTopBarAction(IconData icon, String? label, VoidCallback onTap, DashColors c) {
    return Tooltip(
      message: label ?? 'Partager',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 34,
            padding: EdgeInsets.symmetric(horizontal: label != null ? 10 : 8),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: c.textSecondary),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBigActionBtn(DashColors c, String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Icon(icon, size: 28, color: color),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // SECTION LABEL — Même style que Dashboard
  // ═══════════════════════════════════════════════════════════════════════════════
  Widget _buildSectionLabel(String title, IconData icon, DashColors c) {
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
          child: Container(height: 1, color: c.border),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // KPI GRID — Réutilise UltraKpiCard du Dashboard
  // ═══════════════════════════════════════════════════════════════════════════════
  Widget _buildKpiGrid(DashColors c, ReportKPIs kpi, double w) {
    final cols = w > 1200 ? 5 : (w > 800 ? 3 : (w > 500 ? 2 : 1));
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
          value: ref.fmt(kpi.totalRevenue),
          icon: FluentIcons.money_24_regular,
          accent: c.blue,
        ),
        UltraKpiCard(
          label: "Marge Brute",
          value: ref.fmt(kpi.totalProfit),
          icon: FluentIcons.receipt_24_regular,
          accent: c.emerald,
          change: kpi.totalRevenue > 0
              ? "${kpi.marginPercentage.toStringAsFixed(1)}%"
              : null,
          positive: kpi.marginPercentage > 0,
        ),
        UltraKpiCard(
          label: "Bénéfice Net",
          value: ref.fmt(kpi.netProfit),
          icon: FluentIcons.money_hand_24_regular,
          accent: kpi.netProfit >= 0 ? c.emerald : c.rose,
        ),
        UltraKpiCard(
          label: "Nombre de Ventes",
          value: DateFormatter.formatNumber(kpi.salesCount),
          icon: FluentIcons.cart_24_regular,
          accent: c.amber,
        ),
        UltraKpiCard(
          label: "Rentabilité Nette",
          value: "${kpi.netMarginPercentage.toStringAsFixed(1)}%",
          icon: FluentIcons.data_pie_24_regular,
          accent: c.violet,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // REVENUE CHART — Wrapped dans SectionCard
  // ═══════════════════════════════════════════════════════════════════════════════
  Widget _buildRevenueChart(DashColors c, AsyncValue<List<ChartDataPoint>> chartDataAsync) {
    return SectionCard(
      title: "Évolution du chiffre d'affaires",
      subtitle: _selectedRange,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
        child: SizedBox(
          height: 220,
          child: chartDataAsync.when(
            loading: () => Center(
              child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation(c.primary)),
            ),
            error: (err, _) => Center(
              child: Text("Erreur: $err", style: TextStyle(color: c.rose, fontSize: 12)),
            ),
            data: (chartData) {
              if (chartData.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(FluentIcons.chart_multiple_24_regular, size: 40, color: c.textMuted),
                      const SizedBox(height: 10),
                      Text(
                        "Aucune donnée pour cette période",
                        style: TextStyle(color: c.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }

              double maxVal = chartData.map((e) => e.value).reduce(math.max);
              if (maxVal == 0) maxVal = 1000;

              return BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal * 1.15,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => c.surfaceElev,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final idx = group.x.toInt();
                        if (idx < 0 || idx >= chartData.length) return null;
                        return BarTooltipItem(
                          "${chartData[idx].label}\n${ref.fmt(rod.toY)}",
                          TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, _) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= chartData.length) return const SizedBox.shrink();
                          final labelInterval = (chartData.length / 7).ceil();
                          if (chartData.length > 7 && idx % labelInterval != 0 && idx != chartData.length - 1) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              chartData[idx].label,
                              style: TextStyle(fontSize: 10, color: c.textSecondary, fontWeight: FontWeight.w600),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 52,
                        getTitlesWidget: (val, _) {
                          String label;
                          if (val >= 1000000) {
                            label = "${(val / 1000000).toStringAsFixed(1)}M";
                          } else if (val >= 1000) {
                            label = "${(val / 1000).toStringAsFixed(0)}k";
                          } else {
                            label = val.toStringAsFixed(0);
                          }
                          return Text(label, style: TextStyle(fontSize: 10, color: c.textSecondary));
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxVal / 4,
                    getDrawingHorizontalLine: (_) => FlLine(color: c.border, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(
                    chartData.length,
                    (i) => BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: chartData[i].value,
                          gradient: LinearGradient(
                            colors: [c.primary, c.primary.withValues(alpha: 0.6)],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          width: chartData.length > 15 ? 12 : 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // TOP PRODUITS — Wrapped dans SectionCard + MetricRow
  // ═══════════════════════════════════════════════════════════════════════════════
  Widget _buildTopProducts(DashColors c, AsyncValue<List<TopProduct>> topProductsAsync) {
    return SectionCard(
      title: 'Top Produits',
      subtitle: 'Volume de vente',
      child: topProductsAsync.when(
        loading: () => SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation(c.primary))),
        ),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(20),
          child: Text("Erreur: $err", style: TextStyle(color: c.rose)),
        ),
        data: (products) {
          if (products.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text("Aucune donnée", style: TextStyle(color: c.textMuted))),
            );
          }
          final maxRev = products.first.totalRevenue;
          final colors = [c.blue, c.emerald, c.violet, c.amber, c.rose, c.cyan];
          return Column(
            children: products.take(4).toList().asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              final pct = maxRev > 0 ? p.totalRevenue / maxRev : 0.0;
              return MetricRow(
                rank: i + 1,
                title: p.name,
                subtitle: '${ref.qty(p.totalQuantity.toDouble())} unités',
                value: ref.fmt(p.totalRevenue),
                progress: pct,
                accent: colors[i % colors.length],
                icon: FluentIcons.box_24_regular,
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // COMPTE DE RÉSULTAT (P&L) — SectionCard
  // ═══════════════════════════════════════════════════════════════════════════════
  Widget _buildPnlCard(DashColors c, ReportKPIs kpi) {
    final netResult = kpi.totalProfit - kpi.totalExpenses;
    final isPositive = netResult >= 0;

    return SectionCard(
      title: 'Compte de résultat',
      subtitle: 'Simplifié',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: c.isDark ? Colors.white.withValues(alpha: 0.01) : Colors.black.withValues(alpha: 0.01),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: Column(
            children: [
              _pnlRow(c, "Chiffre d'affaires", ref.fmt(kpi.totalRevenue), isBold: true, color: c.textPrimary),
              Divider(color: c.border, height: 1, indent: 16, endIndent: 16),
              _pnlRow(c, "Coût des marchandises", "- ${ref.fmt(kpi.totalRevenue - kpi.totalProfit)}", color: c.rose),
              Divider(color: c.border, height: 1),
              _pnlRow(c, "Marge brute", ref.fmt(kpi.totalProfit), isBold: true, color: c.emerald),
              Divider(color: c.border, height: 1, indent: 16, endIndent: 16),
              _pnlRow(c, "Dépenses opérationnelles", "- ${ref.fmt(kpi.totalExpenses)}", color: c.rose),
              Divider(color: c.border, height: 1),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: (isPositive ? c.emerald : c.rose).withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: _pnlRow(
                  c,
                  "RÉSULTAT NET",
                  ref.fmt(netResult),
                  isBold: true,
                  isLarge: true,
                  color: isPositive ? c.emerald : c.rose,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pnlRow(DashColors c, String label, String value, {bool isBold = false, bool isLarge = false, Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isLarge ? 16 : 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isLarge ? 13 : 12,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: isBold ? c.textPrimary : c.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isLarge ? 18 : 14,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: color ?? c.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // INDICATEURS DE PERFORMANCE — SectionCard + MetricRow style
  // ═══════════════════════════════════════════════════════════════════════════════
  Widget _buildMetricsCard(DashColors c, ReportKPIs kpi, DateTimeRange range) {
    final days = range.duration.inDays > 0 ? range.duration.inDays : 1;
    return SectionCard(
      title: 'Indicateurs de performance',
      subtitle: 'Métriques clés',
      child: Column(
        children: [
          _metricTile(c, "Marge brute", "${kpi.marginPercentage.toStringAsFixed(1)}%",
              FluentIcons.arrow_trending_lines_24_regular,
              kpi.marginPercentage > 30 ? c.emerald : (kpi.marginPercentage > 15 ? c.amber : c.rose)),
          _metricTile(c, "Panier moyen",
              kpi.salesCount > 0 ? ref.fmt(kpi.totalRevenue / kpi.salesCount) : "–",
              FluentIcons.cart_24_regular, c.blue),
          _metricTile(c, "Ventes / jour",
              DateFormatter.formatNumberValue(kpi.salesCount / days, decimalDigits: 1),
              FluentIcons.clock_24_regular, c.violet),
          _metricTile(c, "CA / jour", ref.fmt(kpi.totalRevenue / days),
              FluentIcons.calendar_24_regular, c.amber),
          _metricTile(c, "Ratio dépenses/CA",
              kpi.totalRevenue > 0 ? "${(kpi.totalExpenses / kpi.totalRevenue * 100).toStringAsFixed(1)}%" : "–",
              FluentIcons.arrow_trending_down_24_regular, c.rose),
        ],
      ),
    );
  }

  Widget _metricTile(DashColors c, String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════════
  // EXPORT & SHARE — Logique inchangée
  // ═══════════════════════════════════════════════════════════════════════════════

  Future<void> _confirmZReport(BuildContext context) async {
    final now = DateTime.now();
    final timeStr = DateFormatter.formatDateTime(now);
    
    await EnterpriseWidgets.showPremiumConfirmDialog(
      context,
      title: "Clôture de Caisse (Rapport Z)",
      message: "Êtes-vous sûr de vouloir imprimer le Rapport Z maintenant ?\n\nHorodatage : $timeStr\n\nCette action consolide les ventes de la période sélectionnée sur le ticket de caisse.",
      confirmText: "CONFIRMER & IMPRIMER",
      isDestructive: false,
      onConfirm: () async {
        await _exportZReport(context);
      },
    );
  }

  Future<void> _exportExcel(BuildContext context) async {
    _showToast(context, "📊 Génération du fichier Excel...");
    try {
      final range = ref.read(dateRangeProvider);
      final kpis = await ref.read(reportKPIsProvider(range).future);
      final topProducts = await ref.read(topProductsProvider(range).future);
      final db = await ref.read(databaseServiceProvider).database;

      final userSales = await ref.read(userSalesSummaryProvider(range).future);
      final settings = ref.read(shopSettingsProvider).value;
      
      await ExcelExportService.exportToExcel(
        range: range,
        kpis: kpis,
        topProducts: topProducts,
        userSales: userSales,
        shopName: settings?.name ?? "Mon Commerce",
        currency: settings?.currency ?? "F",
        db: db,
      );
      if (!context.mounted) return;
      _showToast(context, "✅ Excel exporté dans vos téléchargements", isError: false);
    } catch (e) {
      if (!context.mounted) return;
      _showToast(context, "Erreur Excel : $e", isError: true);
    }
  }

  Future<void> _exportZReport(BuildContext context) async {
    _showToast(context, "🧾 Impression du Rapport Z...");
    try {
      final range = ref.read(dateRangeProvider);
      final kpis = await ref.read(reportKPIsProvider(range).future);
      final topProducts = await ref.read(topProductsProvider(range).future);
      final user = await ref.read(authServiceProvider.future);

      final settings = ref.read(shopSettingsProvider).value;
      await ReceiptReportService.generateZReport(
        range: range,
        kpis: kpis,
        topProducts: topProducts,
        username: user?.username ?? "Utilisateur",
        shopName: settings?.name ?? "Mon Commerce",
        shopAddress: settings?.address,
        shopPhone: settings?.phone,
        targetPrinter: settings?.reportPrinterName ?? settings?.thermalPrinterName,
        directPrint: settings?.directPhysicalPrinting ?? false,
        currencySymbol: settings?.currency ?? "F",
        locale: "fr-FR",
        removeDecimals: settings?.removeDecimals ?? true,
      );
    } catch (e) {
      if (!context.mounted) return;
      _showToast(context, "Erreur Rapport Z : $e", isError: true);
    }
  }

  Future<void> _exportPDF(BuildContext context) async {
    _showToast(context, "📄 Génération du rapport PDF A4...");
    try {
      final range = ref.read(dateRangeProvider);
      final kpis = await ref.read(reportKPIsProvider(range).future);
      final topProducts = await ref.read(topProductsProvider(range).future);
      final userSales = await ref.read(userSalesSummaryProvider(range).future);
      final user = await ref.read(authServiceProvider.future);

      final settings = ref.read(shopSettingsProvider).value;
      await PdfReportService.generateAndSaveReport(
        range: range,
        kpis: kpis,
        topProducts: topProducts,
        userSales: userSales,
        username: user?.username ?? "Utilisateur",
        shopName: settings?.name ?? "Mon Commerce",
        shopAddress: settings?.address,
        shopPhone: settings?.phone,
        targetPrinter: settings?.reportPrinterName ?? settings?.invoicePrinterName,
        directPrint: settings?.directPhysicalPrinting ?? false,
        currencySymbol: settings?.currency ?? "F",
        locale: "fr-FR",
        removeDecimals: settings?.removeDecimals ?? true,
      );
      if (!context.mounted) return;
      _showToast(context, "✅ Rapport PDF exporté et/ou imprimé", isError: false);
    } catch (e) {
      if (!context.mounted) return;
      _showToast(context, "Erreur PDF : $e", isError: true);
    }
  }

  Future<void> _showShareOptions(BuildContext context) async {
    final c = DashColors.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: 0.98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: c.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: c.textMuted.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            Text(
              "PARTAGER LE RAPPORT",
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.5, color: c.textMuted),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _shareOption(c, "PDF (A4)", "Impression officielle", FluentIcons.document_pdf_24_regular, c.rose, () {
                    Navigator.pop(ctx);
                    _shareReport(context, isPdf: true);
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _shareOption(c, "EXCEL", "Analyse détaillée", FluentIcons.table_24_regular, c.emerald, () {
                    Navigator.pop(ctx);
                    _shareReport(context, isPdf: false);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _shareOption(c, "ENVOYER PAR EMAIL", "Expédition directe au format combiné", FluentIcons.mail_24_regular, c.violet, () {
              Navigator.pop(ctx);
              _showEmailRecipientDialog(context);
            }),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _shareOption(DashColors c, String label, String sub, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 14),
            Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: c.textPrimary, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(sub, style: TextStyle(fontSize: 11, color: c.textSecondary), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Future<void> _showEmailRecipientDialog(BuildContext context) async {
    final settings = ref.read(shopSettingsProvider).value;
    final defaultEmail = settings?.backupEmailRecipient ?? settings?.email ?? "";
    final controller = TextEditingController(text: defaultEmail);

    showDialog(
      context: context,
      builder: (ctx) => EnterpriseWidgets.buildPremiumDialog(
        context,
        title: "Destinataire du Rapport",
        icon: FluentIcons.mail_24_regular,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("À quelle adresse email souhaitez-vous envoyer ce rapport ?"),
            const SizedBox(height: 16),
            EnterpriseWidgets.buildPremiumTextField(
              context,
              ctrl: controller,
              label: "Adresse Email",
              hint: "Ex: patron@gmail.com",
              icon: FluentIcons.mail_24_regular,
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Annuler"),
            onPressed: () => Navigator.pop(ctx),
          ),
          const SizedBox(width: 8),
          FilledButton(
            child: const Text("Envoyer le Rapport"),
            onPressed: () {
              Navigator.pop(ctx);
              _sendEmailDirectly(context, controller.text.trim());
            },
          ),
        ],
      ),
    );
  }

  Future<void> _sendEmailDirectly(BuildContext context, String recipient) async {
    if (recipient.isEmpty) {
      _showToast(context, "Veuillez saisir une adresse email", isError: true);
      return;
    }

    _showToast(context, "📧 Envoi du rapport par email...");
    try {
      final range = ref.read(dateRangeProvider);
      final kpis = await ref.read(reportKPIsProvider(range).future);
      final topProducts = await ref.read(topProductsProvider(range).future);
      final userSales = await ref.read(userSalesSummaryProvider(range).future);
      final user = await ref.read(authServiceProvider.future);
      
      final settings = ref.read(shopSettingsProvider).value;
      // Générer les deux fichiers pour un rapport complet
      final pdfPath = await PdfReportService.generateReportFile(
        range: range,
        kpis: kpis,
        topProducts: topProducts,
        userSales: userSales,
        username: user?.username ?? "Utilisateur",
        shopName: settings?.name ?? "Mon Commerce",
        currencySymbol: settings?.currency ?? "F",
        locale: "fr-FR",
      );

      final db = await ref.read(databaseServiceProvider).database;
      final excelPath = await ExcelExportService.exportToExcel(
        range: range,
        kpis: kpis,
        topProducts: topProducts,
        userSales: userSales,
        shopName: settings?.name ?? "Mon Commerce",
        currency: settings?.currency ?? "F",
        db: db,
      );

      final emailService = ref.read(emailServiceProvider);
      final result = await emailService.sendSalesReport(
        recipient: recipient,
        range: range,
        kpis: kpis,
        topProducts: topProducts,
        userSales: userSales,
        attachments: [File(pdfPath), File(excelPath)],
      );

      if (!context.mounted) return;
      if (result.success) {
        _showToast(context, "✅ Rapport envoyé avec succès à $recipient", isError: false);
      } else {
        _showToast(context, "❌ Échec de l'envoi : ${result.errorMessage}", isError: true);
      }
    } catch (e) {
      if (!context.mounted) return;
      _showToast(context, "Erreur d'envoi Email : $e", isError: true);
    }
  }

  Future<void> _shareReport(BuildContext context, {required bool isPdf}) async {
    _showToast(context, "⏳ Préparation du fichier...");
    try {
      final range = ref.read(dateRangeProvider);
      final kpis = await ref.read(reportKPIsProvider(range).future);
      final topProducts = await ref.read(topProductsProvider(range).future);
      final userSales = await ref.read(userSalesSummaryProvider(range).future);
      final user = await ref.read(authServiceProvider.future);
      
      String filePath;

      if (isPdf) {
        final settings = ref.read(shopSettingsProvider).value;
        filePath = await PdfReportService.generateReportFile(
          range: range,
          kpis: kpis,
          topProducts: topProducts,
          userSales: userSales,
          username: user?.username ?? "Utilisateur",
          shopName: settings?.name ?? "Mon Commerce",
          currencySymbol: settings?.currency ?? "F",
          locale: "fr-FR",
        );
      } else {
        final db = await ref.read(databaseServiceProvider).database;
        final settings = ref.read(shopSettingsProvider).value;
        filePath = await ExcelExportService.exportToExcel(
          range: range,
          kpis: kpis,
          topProducts: topProducts,
          userSales: userSales,
          shopName: settings?.name ?? "Mon Commerce",
          currency: settings?.currency ?? "F",
          db: db,
        );
      }

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: "Rapport de ventes Danaya+ - ${DateFormatter.formatDate(range.start)}",
      );
    } catch (e) {
      if (!context.mounted) return;
      _showToast(context, "Erreur de partage : $e", isError: true);
    }
  }

  void _showToast(BuildContext context, String msg, {bool isError = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
