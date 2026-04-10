import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/reports/providers/report_providers.dart';
import 'package:danaya_plus/features/reports/services/pdf_report_service.dart';
import 'package:danaya_plus/features/reports/services/excel_export_service.dart';
import 'package:danaya_plus/features/reports/services/receipt_report_service.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/inventory/presentation/dashboard_screen.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/core/theme/app_theme.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/core/widgets/access_denied_screen.dart';
import 'package:danaya_plus/core/services/email_service.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).logActivity(
        userId: user.id,
        actionType: 'VIEW_REPORTS',
        description: 'Consultation des rapports par ${user.username}',
      );
    });



    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HEADER ──
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            if (Navigator.canPop(context) || ref.watch(navigationProvider) != 0)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: IconButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      ref.read(navigationProvider.notifier).setPage(0, ref);
                    }
                  },
                  icon: const Icon(FluentIcons.chevron_left_24_regular),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.7)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(FluentIcons.data_pie_24_filled, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Rapports & Analytics", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF1F2937))),
              Text("${DateFormatter.formatDate(range.start)} → ${DateFormatter.formatDate(range.end)}", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ])),
            // Period selector
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2128) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: ["Aujourd'hui", "Cette Semaine", "Ce Mois", "Cette Année"].map((p) {
                final sel = _selectedRange == p;
                return GestureDetector(
                  onTap: () => _updateRange(p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(p, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? Colors.white : Colors.grey.shade600)),
                  ),
                );
              }).toList()),
            ),
            const SizedBox(width: 12),
            _buildExportButtons(context),
          ]),
          const SizedBox(height: 20),

          // ── MAIN CONTENT ──
          Expanded(
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── KPI ROW ──
                kpisAsync.when(
                  loading: () => const SizedBox(height: 88, child: Center(child: CircularProgressIndicator())),
                  error: (err, _) => const SizedBox(height: 88),
                  data: (kpi) => Column(
                    children: [
                      Row(children: [
                        Expanded(
                          child: _PremiumKpiTile(
                            icon: FluentIcons.money_24_regular,
                            label: "Chiffre d'affaires",
                            value: ref.fmt(kpi.totalRevenue),
                            color: accent,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _PremiumKpiTile(
                            icon: FluentIcons.receipt_24_regular,
                            label: "Marge brute",
                            value: ref.fmt(kpi.totalProfit),
                            color: AppTheme.successClr,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _PremiumKpiTile(
                            icon: FluentIcons.money_hand_24_regular,
                            label: "Bénéfice Net",
                            value: ref.fmt(kpi.netProfit),
                            color: Colors.purple,
                            isDark: isDark,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                          child: _PremiumKpiTile(
                            icon: FluentIcons.cart_24_regular,
                            label: "Volume Ventes",
                            value: DateFormatter.formatNumber(kpi.salesCount),
                            sub: "transactions",
                            color: Colors.orange,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _PremiumKpiTile(
                            icon: FluentIcons.arrow_trending_down_24_regular,
                            label: "Dépenses",
                            value: ref.fmt(kpi.totalExpenses),
                            color: const Color(0xFFEF4444),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _PremiumKpiTile(
                            icon: FluentIcons.data_pie_24_regular,
                            label: "Rentabilité (%)",
                            value: "${kpi.netMarginPercentage.toStringAsFixed(1)}%",
                            sub: "marge nette",
                            color: Colors.teal,
                            isDark: isDark,
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── CHART + TOP PRODUCTS ROW ──
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Revenue chart
                  Expanded(
                    flex: 3,
                    child: _CardContainer(
                      isDark: isDark,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(FluentIcons.chart_multiple_24_regular, size: 18, color: accent),
                          const SizedBox(width: 10),
                          Text("Évolution du chiffre d'affaires", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: isDark ? Colors.white : const Color(0xFF1F2937))),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                            child: Text(_selectedRange, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accent)),
                          ),
                        ]),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 260,
                          child: chartDataAsync.when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (err, _) => Center(child: Text("Erreur: $err")),
                            data: (chartData) {
                              if (chartData.isEmpty) {
                                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Icon(FluentIcons.chart_multiple_24_regular, size: 40, color: Colors.grey.shade300),
                                  const SizedBox(height: 10),
                                  Text("Aucune donnée pour cette période", style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                                ]));
                              }
                              double maxVal = chartData.map((e) => e.value).reduce((a, b) => a > b ? a : b);
                              if (maxVal == 0) maxVal = 1000;

                              return BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY: maxVal * 1.15,
                                  barTouchData: BarTouchData(
                                    touchTooltipData: BarTouchTooltipData(
                                      getTooltipColor: (_) => isDark ? const Color(0xFF2D3039) : Colors.white,
                                      getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                                        "${chartData[group.x.toInt()].label}\n${ref.fmt(rod.toY)}",
                                        TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  titlesData: FlTitlesData(
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 32,
                                        getTitlesWidget: (value, _) {
                                          final idx = value.toInt();
                                          // Show every label if <= 10, otherwise every 2nd
                                          if (chartData.length > 10 && idx % 2 != 0) return const SizedBox.shrink();
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: Text(chartData[idx].label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                                          );
                                        },
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 60,
                                        getTitlesWidget: (value, _) {
                                          String label;
                                          if (value >= 1000000) {
                                            label = "${(value / 1000000).toStringAsFixed(1)}M";
                                          } else if (value >= 1000) {
                                            label = "${(value / 1000).toStringAsFixed(0)}k";
                                          } else {
                                            label = value.toStringAsFixed(0);
                                          }
                                          return Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade400));
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
                                    getDrawingHorizontalLine: (_) => FlLine(color: isDark ? const Color(0xFF2D3039) : const Color(0xFFF0F0F0), strokeWidth: 1),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  barGroups: List.generate(chartData.length, (i) => BarChartGroupData(
                                    x: i,
                                    barRods: [BarChartRodData(
                                      toY: chartData[i].value,
                                      gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.6)], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                                      width: chartData.length > 15 ? 12 : 20,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                    )],
                                  )),
                                ),
                              );
                            },
                          ),
                        ),
                      ]),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Top Products
                  Expanded(
                    flex: 2,
                    child: _CardContainer(
                      isDark: isDark,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(FluentIcons.trophy_24_filled, color: Colors.orange, size: 18),
                          const SizedBox(width: 10),
                          Text("Top Produits", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: isDark ? Colors.white : const Color(0xFF1F2937))),
                          const Spacer(),
                          Text("Qté · CA", style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 260,
                          child: topProductsAsync.when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (err, _) => Center(child: Text("Erreur: $err")),
                            data: (products) {
                              if (products.isEmpty) {
                                return Center(child: Text("Aucune donnée", style: TextStyle(color: Colors.grey.shade400)));
                              }
                              final maxRev = products.first.totalRevenue;
                              return ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: products.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 4),
                                itemBuilder: (_, i) {
                                  final p = products[i];
                                      final pct = maxRev > 0 ? p.totalRevenue / maxRev : 0.0;
                                      final medals = ['🥇', '🥈', '🥉'];
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                                        ),
                                        child: Row(children: [
                                          Container(
                                            width: 28,
                                            height: 28,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: i < 3 ? Colors.orange.withValues(alpha: 0.1) : (isDark ? Colors.white10 : Colors.black12),
                                              shape: BoxShape.circle,
                                            ),
                                            child: i < 3
                                                ? Text(medals[i], style: const TextStyle(fontSize: 12))
                                                : Text("${i + 1}", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(p.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isDark ? Colors.white : Colors.black), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                ),
                                                Text(ref.fmt(p.totalRevenue), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: isDark ? Colors.white : Colors.black)),
                                              ]
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(6),
                                                    child: LinearProgressIndicator(
                                                      value: pct,
                                                      minHeight: 6,
                                                      backgroundColor: isDark ? const Color(0xFF2D3039) : const Color(0xFFF0F0F0),
                                                      valueColor: AlwaysStoppedAnimation(i < 3 ? Colors.orange : accent.withValues(alpha: 0.7)),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text("${ref.qty(p.totalQuantity.toDouble())} u", style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontWeight: FontWeight.w800)),
                                              ],
                                            ),
                                          ])),
                                        ]),
                                      );
                                    },
                                  );
                            },
                          ),
                        ),
                      ]),
                    ),
                  ),
                ]),

                const SizedBox(height: 16),

                // ── BOTTOM ROW: Profit summary + Performance metrics ──
                kpisAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (kpi) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Profit / Loss Summary
                    Expanded(
                      flex: 3,
                      child: _CardContainer(
                        isDark: isDark,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Icon(FluentIcons.calculator_24_regular, size: 18, color: accent),
                            const SizedBox(width: 10),
                            Text("Compte de résultat simplifié", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: isDark ? Colors.white : const Color(0xFF1F2937))),
                          ]),
                          const SizedBox(height: 24),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.01) : Colors.black.withValues(alpha: 0.01),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                            ),
                            child: Column(
                              children: [
                                _PnlRow(label: "Chiffre d'affaires", value: ref.fmt(kpi.totalRevenue), isBold: true, color: isDark ? Colors.white : Colors.black, isDark: isDark),
                                const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
                                _PnlRow(label: "Coût des marchandises", value: ref.fmt(kpi.totalRevenue - kpi.totalProfit), isNeg: true, isDark: isDark),
                                const Divider(height: 1, thickness: 1),
                                _PnlRow(label: "Marge brute", value: ref.fmt(kpi.totalProfit), isBold: true, color: const Color(0xFF10B981), isDark: isDark),
                                const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
                                _PnlRow(label: "Dépenses opérationnelles", value: ref.fmt(kpi.totalExpenses), isNeg: true, isDark: isDark),
                                const Divider(height: 1, thickness: 1),
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (kpi.totalProfit - kpi.totalExpenses) >= 0 ? const Color(0xFF10B981).withValues(alpha: 0.05) : const Color(0xFFEF4444).withValues(alpha: 0.05),
                                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                                  ),
                                  child: _PnlRow(
                                    label: "RÉSULTAT NET",
                                    value: ref.fmt(kpi.totalProfit - kpi.totalExpenses),
                                    isBold: true,
                                    isLarge: true,
                                    color: (kpi.totalProfit - kpi.totalExpenses) >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Performance metrics
                    Expanded(
                      flex: 2,
                      child: _CardContainer(
                        isDark: isDark,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Icon(FluentIcons.gauge_24_regular, size: 18, color: accent),
                            const SizedBox(width: 10),
                            Text("Indicateurs de performance", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: isDark ? Colors.white : const Color(0xFF1F2937))),
                          ]),
                          const SizedBox(height: 16),
                          _MetricRow(
                            label: "Marge brute",
                            value: "${kpi.marginPercentage.toStringAsFixed(1)}%",
                            icon: FluentIcons.arrow_trending_lines_24_regular,
                            color: kpi.marginPercentage > 30 ? const Color(0xFF10B981) : (kpi.marginPercentage > 15 ? Colors.orange : const Color(0xFFEF4444)),
                            isDark: isDark,
                          ),
                          const SizedBox(height: 10),
                          _MetricRow(
                            label: "Panier moyen",
                            value: kpi.salesCount > 0 ? ref.fmt(kpi.totalRevenue / kpi.salesCount) : "–",
                            icon: FluentIcons.cart_24_regular,
                            color: accent,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 10),
                          _MetricRow(
                            label: "Ventes / jour",
                            value: range.duration.inDays > 0 ? DateFormatter.formatNumberValue(kpi.salesCount / range.duration.inDays, decimalDigits: 1) : DateFormatter.formatNumber(kpi.salesCount),
                            icon: FluentIcons.clock_24_regular,
                            color: const Color(0xFF6366F1),
                            isDark: isDark,
                          ),
                          const SizedBox(height: 10),
                          _MetricRow(
                            label: "CA / jour",
                            value: range.duration.inDays > 0 ? ref.fmt(kpi.totalRevenue / range.duration.inDays) : ref.fmt(kpi.totalRevenue),
                            icon: FluentIcons.calendar_24_regular,
                            color: Colors.orange,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 10),
                          _MetricRow(
                            label: "Ratio dépenses/CA",
                            value: kpi.totalRevenue > 0 ? "${(kpi.totalExpenses / kpi.totalRevenue * 100).toStringAsFixed(1)}%" : "–",
                            icon: FluentIcons.arrow_trending_down_24_regular,
                            color: const Color(0xFFEF4444),
                            isDark: isDark,
                          ),
                        ]),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButtons(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bouton PDF
        _buildActionBtn(
          context,
          label: "PDF",
          icon: FluentIcons.document_pdf_24_regular,
          onPressed: () => _exportPDF(context),
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        // Bouton EXCEL
        _buildActionBtn(
          context,
          label: "EXCEL",
          icon: FluentIcons.table_24_regular,
          onPressed: () => _exportExcel(context),
          color: Colors.green.shade600,
        ),
        const SizedBox(width: 8),
        // Bouton TICKET Z (Plus petit)
        IconButton.filledTonal(
          onPressed: () => _confirmZReport(context),
          icon: const Icon(FluentIcons.print_24_regular, size: 18),
          tooltip: "Rapport Z (Ticket)",
          style: IconButton.styleFrom(
            padding: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 8),
        // Bouton PARTAGER
        IconButton.filledTonal(
          onPressed: () => _showShareOptions(context),
          icon: const Icon(FluentIcons.share_24_regular, size: 18),
          tooltip: "Partager le rapport",
          style: IconButton.styleFrom(
            padding: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: Colors.indigo.shade50,
            foregroundColor: Colors.indigo,
          ),
        ),
      ],
    );
  }

  Widget _buildActionBtn(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5)),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

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

      await ExcelExportService.exportToExcel(range: range, kpis: kpis, topProducts: topProducts, db: db);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.95),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            Text(
              "Partager le rapport".toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildShareCard(
                  context,
                  label: "PDF (A4)",
                  sub: "Impression officielle",
                  icon: FluentIcons.document_pdf_24_regular,
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(ctx);
                    _shareReport(context, isPdf: true);
                  },
                ),
                const SizedBox(width: 12),
                _buildShareCard(
                  context,
                  label: "EXCEL",
                  sub: "Analyse détaillée",
                  icon: FluentIcons.table_24_regular,
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(ctx);
                    _shareReport(context, isPdf: false);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildShareCard(
              context,
              label: "ENVOYER PAR EMAIL",
              sub: "Expédition directe au format combiné",
              icon: FluentIcons.mail_24_regular,
              color: Colors.indigo,
              isFullWidth: true,
              onTap: () {
                Navigator.pop(ctx);
                _showEmailRecipientDialog(context);
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildShareCard(BuildContext context, {
    required String label,
    required String sub,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isFullWidth = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: isFullWidth ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            const SizedBox(height: 4),
            Text(sub, style: TextStyle(fontSize: 10, color: isDark ? Colors.grey : Colors.grey.shade600)),
          ],
        ),
      ),
    );

    return isFullWidth ? SizedBox(width: double.infinity, child: content) : Expanded(child: content);
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
        filePath = await ExcelExportService.exportToExcel(
          range: range,
          kpis: kpis,
          topProducts: topProducts,
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

// ─────────────────────────────────────────────────────────────────────────────
// Helper Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _CardContainer extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const _CardContainer({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(24),
      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.02),
      border: Border.all(color: (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05))),
      child: child,
    );
  }
}

class _PremiumKpiTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Color color;
  final bool isDark;
  
  const _PremiumKpiTile({required this.icon, required this.label, required this.value, this.sub, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: BorderRadius.circular(12),
      color: color.withValues(alpha: 0.03),
      border: Border.all(color: color.withValues(alpha: 0.15)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(sub!, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w800)),
                ]
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16, // Ultra compact mais lisible
              fontWeight: FontWeight.w900, 
              color: isDark ? Colors.white : const Color(0xFF1F2937),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}




class _PnlRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool isNeg;
  final bool isLarge;
  final Color? color;
  final bool isDark;

  const _PnlRow({required this.label, required this.value, this.isBold = false, this.isNeg = false, this.isLarge = false, this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: isLarge ? 13 : 12, fontWeight: isBold ? FontWeight.w800 : FontWeight.w600, color: isBold ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.grey.shade400 : Colors.grey.shade600), letterSpacing: isLarge ? 1 : 0)),
        Text(isNeg ? "- $value" : value, style: TextStyle(
          fontSize: isLarge ? 18 : 14,
          fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
          color: color ?? (isNeg ? const Color(0xFFEF4444) : (isDark ? Colors.white : Colors.black)),
          letterSpacing: -0.5,
        )),
      ]),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _MetricRow({required this.label, required this.value, required this.icon, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(16),
      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.02),
      border: Border.all(color: (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05))),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontWeight: FontWeight.w600))),
        Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5, color: color)),
      ]),
    );
  }
}
