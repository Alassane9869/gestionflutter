import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/features/inventory/providers/dashboard_providers.dart';
import 'package:danaya_plus/features/inventory/providers/dashboard_customization_provider.dart';
import 'package:danaya_plus/features/inventory/presentation/widgets/dashboard_widgets.dart';
import 'package:danaya_plus/features/finance/providers/session_providers.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';

class CashierDashboardContent extends ConsumerStatefulWidget {
  const CashierDashboardContent({super.key});

  @override
  ConsumerState<CashierDashboardContent> createState() => _CashierDashboardContentState();
}

class _CashierDashboardContentState extends ConsumerState<CashierDashboardContent> {
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) {
        ref.read(dashboardProvider.notifier).refresh();
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final theme = Theme.of(context);
    final metricsAsync = ref.watch(dashboardProvider);
    final session = ref.watch(activeSessionProvider).value;
    final user = ref.watch(authServiceProvider).value;
    final customization = ref.watch(dashboardCustomizationProvider);

    return Container(
      color: c.bg,
      child: metricsAsync.when(
        skipLoadingOnRefresh: true,
        loading: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary))),
              const SizedBox(height: 16),
              Text('Chargement du tableau de bord...', style: TextStyle(color: c.textSecondary, fontSize: 13)),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.error_circle_24_regular, color: c.rose, size: 48),
              const SizedBox(height: 12),
              Text('Erreur de chargement', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 6),
              Text('$e', style: TextStyle(color: c.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  ref.read(dashboardProvider.notifier).refresh();
                },
                icon: const Icon(FluentIcons.arrow_sync_24_regular, size: 16),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (metrics) {
          final now = DateTime.now();
          final sessionDuration = session != null
              ? now.difference(session.openDate)
              : Duration.zero;
          final durationStr = '${sessionDuration.inHours}h ${sessionDuration.inMinutes % 60}min';

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ═══════ TOP HEADER CARD ═══════
                _buildHeaderCard(theme, c, metrics, session, user, durationStr),
                const SizedBox(height: 16),
                // ═══════ MAIN CONTENT ═══════
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LEFT: Recent Sales + Top Products
                      if (customization.showCashierRecentSales || customization.showCashierTopProducts)
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              if (customization.showCashierRecentSales)
                                Expanded(
                                  flex: 3,
                                  child: _RecentSalesPanel(metrics: metrics, ref: ref, c: c),
                                )
                              else
                                const SizedBox.shrink(),
                              if (customization.showCashierRecentSales && customization.showCashierTopProducts)
                                const SizedBox(height: 14),
                              if (customization.showCashierTopProducts)
                                Expanded(
                                  flex: 2,
                                  child: _TopProductsPanel(metrics: metrics, ref: ref, c: c),
                                )
                              else
                                const SizedBox.shrink(),
                            ],
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      if ((customization.showCashierRecentSales || customization.showCashierTopProducts) &&
                          (customization.showCashierSessionInfo || customization.showCashierStockAlerts))
                        const SizedBox(width: 14),
                      // RIGHT: Debtors + Quick Session Info
                      if (customization.showCashierSessionInfo || customization.showCashierStockAlerts)
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              // Quick Stats Card
                              if (customization.showCashierSessionInfo)
                                _buildQuickStatsCard(theme, c, metrics, session, durationStr)
                              else
                                const SizedBox.shrink(),
                              if (customization.showCashierSessionInfo && customization.showCashierStockAlerts)
                                const SizedBox(height: 14),
                              if (customization.showCashierStockAlerts)
                                Expanded(
                                  child: _StockAlertsPanel(metrics: metrics, ref: ref, c: c),
                                )
                              else
                                const SizedBox.shrink(),
                            ],
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme, DashColors c, DashboardMetrics metrics, dynamic session, dynamic user, String durationStr) {
    final primary = theme.colorScheme.primary;
    final monthNames = ['', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
    final now = DateTime.now();
    final dayNames = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    final dateStr = '${dayNames[now.weekday - 1]} ${now.day} ${monthNames[now.month]} ${now.year}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // Top Row: Title + Date + Refresh
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primary.withValues(alpha: 0.15), primary.withValues(alpha: 0.05)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(FluentIcons.desktop_pulse_20_filled, color: primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Tableau de Bord',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: c.textPrimary, letterSpacing: -0.3),
                        ),
                        const SizedBox(width: 8),
                        if (user != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              user.fullName,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primary),
                            ),
                          ),
                      ],
                    ),
                    Text(dateStr, style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              // Session Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: c.emerald.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.emerald.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(color: c.emerald, shape: BoxShape.circle),
                    ).animate(onPlay: (ctrl) => ctrl.repeat()).custom(
                      duration: 1500.ms,
                      builder: (ctx, v, child) => Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.emerald,
                          boxShadow: [BoxShadow(color: c.emerald.withValues(alpha: v * 0.6), blurRadius: v * 6)],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('Session Active', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.emerald)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Refresh Button
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () {
                    ref.read(dashboardProvider.notifier).refresh();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.arrow_sync_20_regular, color: c.textSecondary, size: 14),
                        const SizedBox(width: 6),
                        Text(timeStr, style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // KPI Strip
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _buildKpiTile(
                  icon: FluentIcons.money_20_filled,
                  label: "Ventes du Jour",
                  value: ref.fmt(metrics.periodRevenue),
                  color: c.emerald,
                  c: c,
                  trend: metrics.revenueTrend,
                  sparkData: metrics.revenueSparkline,
                ),
                _kpiDivider(c),
                _buildKpiTile(
                  icon: FluentIcons.receipt_20_filled,
                  label: "Tickets",
                  value: "${metrics.periodSalesCount}",
                  color: primary,
                  c: c,
                  trend: metrics.salesTrend,
                ),
                _kpiDivider(c),
                _buildKpiTile(
                  icon: FluentIcons.cart_20_filled,
                  label: "Panier Moyen",
                  value: ref.fmt(metrics.averageBasket),
                  color: c.cyan,
                  c: c,
                  trend: metrics.basketTrend,
                ),
                _kpiDivider(c),
                _buildKpiTile(
                  icon: FluentIcons.wallet_20_filled,
                  label: "Solde Ouverture",
                  value: session != null ? ref.fmt(session.openingBalance) : "—",
                  color: c.violet,
                  c: c,
                ),
                _kpiDivider(c),
                _buildKpiTile(
                  icon: FluentIcons.timer_20_filled,
                  label: "Durée Session",
                  value: durationStr,
                  color: c.amber,
                  c: c,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildKpiTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required DashColors c,
    double? trend,
    List<double>? sparkData,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          value,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: c.textPrimary, letterSpacing: -0.3),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (trend != null && trend != 0) ...[
                        const SizedBox(width: 4),
                        Icon(
                          trend >= 0 ? FluentIcons.arrow_trending_20_filled : FluentIcons.arrow_trending_down_20_filled,
                          size: 12,
                          color: trend >= 0 ? c.emerald : c.rose,
                        ),
                      ],
                    ],
                  ),
                  Text(label, style: TextStyle(fontSize: 10, color: c.textSecondary, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiDivider(DashColors c) => Container(width: 1, height: 30, color: c.border);

  Widget _buildQuickStatsCard(ThemeData theme, DashColors c, DashboardMetrics metrics, dynamic session, String durationStr) {
    final openTime = session != null
        ? '${session.openDate.hour.toString().padLeft(2, '0')}:${session.openDate.minute.toString().padLeft(2, '0')}'
        : '—';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FluentIcons.info_20_regular, color: c.textSecondary, size: 14),
              const SizedBox(width: 6),
              Text('Informations Session', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow(c, 'Ouvert à', openTime, FluentIcons.clock_20_regular),
          const SizedBox(height: 6),
          _infoRow(c, 'Durée', durationStr, FluentIcons.timer_20_regular),
          const SizedBox(height: 6),
          _infoRow(c, 'Solde initial', session != null ? ref.fmt(session.openingBalance) : '—', FluentIcons.wallet_20_regular),
          const SizedBox(height: 6),
          _infoRow(c, 'Total encaissé', ref.fmt(metrics.periodRevenue), FluentIcons.money_20_regular),
          const SizedBox(height: 6),
          _infoRow(c, 'Nb. transactions', '${metrics.periodSalesCount}', FluentIcons.document_bullet_list_20_regular),
          if (metrics.totalRevenue > 0) ...[
            const SizedBox(height: 6),
            _infoRow(c, 'CA cumulé', ref.fmt(metrics.totalRevenue), FluentIcons.data_bar_vertical_20_regular),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 100.ms);
  }

  Widget _infoRow(DashColors c, String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 13, color: c.textMuted),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w500))),
        Text(value, style: TextStyle(fontSize: 12, color: c.textPrimary, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ═════════════════════════════════════════════
// Recent Sales Panel — Time-sorted, with details
// ═════════════════════════════════════════════

class _RecentSalesPanel extends StatelessWidget {
  final DashboardMetrics metrics;
  final WidgetRef ref;
  final DashColors c;
  const _RecentSalesPanel({required this.metrics, required this.ref, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
        boxShadow: c.isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: c.emerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(FluentIcons.receipt_20_filled, color: c.emerald, size: 14),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ventes Récentes', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                      Text('Dernières transactions de la journée', style: TextStyle(color: c.textSecondary, fontSize: 10)),
                    ],
                  ),
                ),
                if (metrics.recentSales.isNotEmpty)
                  StatusBadge(text: '${metrics.recentSales.length.clamp(0, 10)} dernières', color: c.emerald),
              ],
            ),
          ),
          Divider(color: c.border, height: 1),
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            color: c.bg,
            child: Row(
              children: [
                SizedBox(width: 40, child: Text('#', style: TextStyle(color: c.textMuted, fontSize: 10, fontWeight: FontWeight.w700))),
                Expanded(flex: 2, child: Text('RÉFÉRENCE', style: TextStyle(color: c.textMuted, fontSize: 10, fontWeight: FontWeight.w700))),
                Expanded(flex: 2, child: Text('DATE & HEURE', style: TextStyle(color: c.textMuted, fontSize: 10, fontWeight: FontWeight.w700))),
                Expanded(flex: 1, child: Text('MONTANT', textAlign: TextAlign.right, style: TextStyle(color: c.textMuted, fontSize: 10, fontWeight: FontWeight.w700))),
              ],
            ),
          ),
          Divider(color: c.border, height: 1),
          // List
          Expanded(
            child: metrics.recentSales.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.cart_24_regular, color: c.textMuted, size: 40),
                        const SizedBox(height: 10),
                        Text('Aucune vente aujourd\'hui', style: TextStyle(color: c.textSecondary, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('Les ventes apparaîtront ici en temps réel', style: TextStyle(color: c.textMuted, fontSize: 11)),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: metrics.recentSales.length.clamp(0, 10),
                    separatorBuilder: (_, __) => Divider(color: c.border, height: 1),
                    itemBuilder: (ctx, i) {
                      final s = metrics.recentSales[i];
                      final id = s['id']?.toString() ?? '——';
                      final shortId = id.length > 6 ? id.substring(0, 6).toUpperCase() : id.toUpperCase();
                      final date = s['date']?.toString() ?? '';
                      String timeStr = '——';
                      String dateStr = '——';
                      if (date.length > 15) {
                        timeStr = date.substring(11, 16);
                        dateStr = date.substring(5, 10).replaceAll('-', '/');
                      }
                      final amount = (s['total_amount'] as num?)?.toDouble() ?? 0.0;
                      final refundedAmount = (s['refunded_amount'] as num?)?.toDouble() ?? 0.0;
                      final isPartialRefund = refundedAmount > 0 && refundedAmount < amount;
                      final isFullRefund = refundedAmount >= amount && refundedAmount > 0;

                      return _SaleTile(
                        index: i + 1,
                        shortId: shortId,
                        dateStr: dateStr,
                        timeStr: timeStr,
                        amount: ref.fmt(amount - refundedAmount),
                        isRefunded: isFullRefund,
                        isPartialRefund: isPartialRefund,
                        c: c,
                      );
                    },
                  ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 50.ms);
  }
}

// ═════════════════════════════════════════════
// Top Products Panel
// ═════════════════════════════════════════════

class _TopProductsPanel extends StatelessWidget {
  final DashboardMetrics metrics;
  final WidgetRef ref;
  final DashColors c;
  const _TopProductsPanel({required this.metrics, required this.ref, required this.c});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
        boxShadow: c.isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(FluentIcons.trophy_20_filled, color: theme.colorScheme.primary, size: 14),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Produits les Plus Vendus', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                      Text('Classement par quantité totale', style: TextStyle(color: c.textSecondary, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(color: c.border, height: 1),
          Expanded(
            child: metrics.topProducts.isEmpty
                ? Center(child: Text('Aucune donnée', style: TextStyle(color: c.textSecondary, fontSize: 12)))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: metrics.topProducts.length.clamp(0, 5),
                    separatorBuilder: (_, __) => Divider(color: c.border, height: 1),
                    itemBuilder: (ctx, i) {
                      final p = metrics.topProducts[i];
                      final name = p['name']?.toString() ?? '—';
                      final qty = (p['total_qty'] as num?)?.toInt() ?? 0;
                      final totalSales = (p['total_sales'] as num?)?.toDouble() ?? 0.0;
                      final rankColors = [c.amber, c.textSecondary, c.cyan, c.violet, c.textMuted];
                      final rankColor = i < rankColors.length ? rankColors[i] : c.textMuted;

                      return _TopProductTile(
                        rank: i + 1,
                        name: name,
                        qty: qty,
                        total: ref.fmt(totalSales),
                        rankColor: rankColor,
                        c: c,
                      );
                    },
                  ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 100.ms);
  }
}

// ═════════════════════════════════════════════
// ═════════════════════════════════════════════
// Stock Alerts Panel
// ═════════════════════════════════════════════

class _StockAlertsPanel extends StatelessWidget {
  final DashboardMetrics metrics;
  final WidgetRef ref;
  final DashColors c;
  const _StockAlertsPanel({required this.metrics, required this.ref, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
        boxShadow: c.isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: c.rose.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(FluentIcons.alert_20_filled, color: c.rose, size: 14),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Alertes Stock', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                      Text('Produits en rupture imminente', style: TextStyle(color: c.textSecondary, fontSize: 10)),
                    ],
                  ),
                ),
                if (metrics.lowStockProducts.isNotEmpty)
                  StatusBadge(text: '${metrics.lowStockCount}', color: c.rose),
              ],
            ),
          ),
          Divider(color: c.border, height: 1),
          Expanded(
            child: metrics.lowStockProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.checkmark_circle_24_regular, color: c.emerald, size: 40),
                        const SizedBox(height: 10),
                        Text('Stock OK', style: TextStyle(color: c.textSecondary, fontSize: 13)),
                        Text('Aucune rupture signalée 🎉', style: TextStyle(color: c.textMuted, fontSize: 11)),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: metrics.lowStockProducts.length,
                    separatorBuilder: (_, __) => Divider(color: c.border, height: 1),
                    itemBuilder: (ctx, i) {
                      final p = metrics.lowStockProducts[i];
                      final name = p['name']?.toString() ?? '—';
                      final qty = (p['quantity'] as num?)?.toInt() ?? 0;
                      final threshold = (p['alertThreshold'] as num?)?.toInt() ?? 0;
                      final urgencyColor = qty <= 0 ? c.rose : c.amber;
                      return _StockAlertTile(
                        name: name,
                        qty: qty,
                        threshold: threshold,
                        urgencyColor: urgencyColor,
                        c: c,
                      );
                    },
                  ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 150.ms);
  }
}

// ═════════════════════════════════════════════
// Tile Widgets
// ═════════════════════════════════════════════

class _SaleTile extends StatefulWidget {
  final int index;
  final String shortId, dateStr, timeStr, amount;
  final bool isRefunded, isPartialRefund;
  final DashColors c;
  const _SaleTile({required this.index, required this.shortId, required this.dateStr, required this.timeStr, required this.amount, this.isRefunded = false, this.isPartialRefund = false, required this.c});
  @override
  State<_SaleTile> createState() => _SaleTileState();
}
class _SaleTileState extends State<_SaleTile> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final statusColor = widget.isRefunded ? widget.c.rose : (widget.isPartialRefund ? widget.c.amber : widget.c.emerald);
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: AnimatedContainer(
        duration: 150.ms,
        color: _h ? widget.c.surfaceElev : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text('${widget.index}', style: TextStyle(color: widget.c.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '#${widget.shortId}',
                      style: TextStyle(color: widget.c.textPrimary, fontWeight: FontWeight.w600, fontSize: 12, fontFamily: 'monospace'),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.isRefunded) ...[
                    const SizedBox(width: 6),
                    StatusBadge(text: 'Remb.', color: widget.c.rose),
                  ] else if (widget.isPartialRefund) ...[
                    const SizedBox(width: 6),
                    StatusBadge(text: 'Partiel', color: widget.c.amber),
                  ],
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Icon(FluentIcons.clock_12_regular, size: 10, color: widget.c.textMuted),
                  const SizedBox(width: 4),
                  Text('${widget.dateStr} ${widget.timeStr}', style: TextStyle(color: widget.c.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                widget.amount,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: widget.isRefunded ? widget.c.rose : widget.c.emerald,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockAlertTile extends StatefulWidget {
  final String name;
  final int qty, threshold;
  final Color urgencyColor;
  final DashColors c;
  const _StockAlertTile({required this.name, required this.qty, required this.threshold, required this.urgencyColor, required this.c});
  @override
  State<_StockAlertTile> createState() => _StockAlertTileState();
}
class _StockAlertTileState extends State<_StockAlertTile> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final statusText = widget.qty <= 0 ? 'RUPTURE' : 'CRITIQUE';
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: AnimatedContainer(
        duration: 150.ms,
        color: _h ? widget.c.surfaceElev : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: widget.urgencyColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: widget.urgencyColor.withValues(alpha: 0.2)),
              ),
              child: Center(
                child: Icon(
                  widget.qty <= 0 ? FluentIcons.error_circle_20_regular : FluentIcons.warning_20_regular,
                  color: widget.urgencyColor,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.name, style: TextStyle(color: widget.c.textPrimary, fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('Seuil min: ${widget.threshold}', style: TextStyle(color: widget.c.textSecondary, fontSize: 11)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${widget.qty} en stock', style: TextStyle(color: widget.urgencyColor, fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 2),
              StatusBadge(text: statusText, color: widget.urgencyColor),
            ]),
          ],
        ),
      ),
    );
  }
}

class _TopProductTile extends StatefulWidget {
  final int rank;
  final String name, total;
  final int qty;
  final Color rankColor;
  final DashColors c;
  const _TopProductTile({required this.rank, required this.name, required this.qty, required this.total, required this.rankColor, required this.c});
  @override
  State<_TopProductTile> createState() => _TopProductTileState();
}
class _TopProductTileState extends State<_TopProductTile> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: AnimatedContainer(
        duration: 150.ms,
        color: _h ? widget.c.surfaceElev : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: widget.rank <= 3 ? widget.rankColor.withValues(alpha: 0.15) : widget.c.bg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: widget.rank <= 3 ? widget.rankColor.withValues(alpha: 0.3) : widget.c.border),
              ),
              child: Center(
                child: Text(
                  '${widget.rank}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: widget.rank <= 3 ? widget.rankColor : widget.c.textMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.name, style: TextStyle(color: widget.c.textPrimary, fontWeight: FontWeight.w600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${widget.qty} unités vendues', style: TextStyle(color: widget.c.textSecondary, fontSize: 10)),
                ],
              ),
            ),
            Text(widget.total, style: TextStyle(color: widget.c.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
