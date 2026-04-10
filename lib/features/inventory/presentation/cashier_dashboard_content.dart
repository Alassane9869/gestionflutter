import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/inventory/providers/dashboard_providers.dart';
import 'package:danaya_plus/features/inventory/presentation/widgets/dashboard_widgets.dart';

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
    // Auto-refresh toutes les 60 secondes
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
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
    final metricsAsync = ref.watch(dashboardProvider);

    return Container(
      color: c.bg,
      child: metricsAsync.when(
        skipLoadingOnRefresh: true,
        loading: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40, height: 40,
                child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation(c.emerald)),
              ),
              const SizedBox(height: 16),
              Text('Chargement...', style: TextStyle(color: c.textSecondary)),
            ],
          ),
        ),
        error: (e, _) => Center(child: Text('Erreur: $e', style: TextStyle(color: c.rose))),
        data: (metrics) => Column(
          children: [
            _CashierTopBar(ref: ref, c: c),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // KPIs
                    Row(
                      children: [
                        Expanded(
                          child: UltraKpiCard(
                            label: "Ventes du Jour",
                            value: ref.fmt(metrics.periodRevenue),
                            icon: FluentIcons.money_24_regular,
                            accent: c.emerald,
                            sparkData: metrics.revenueSparkline,
                            change: metrics.revenueTrend != 0 ? "${metrics.revenueTrend.abs().toStringAsFixed(1)}%" : null,
                            positive: metrics.revenueTrend >= 0,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: UltraKpiCard(
                            label: "Panier Moyen",
                            value: ref.fmt(metrics.averageBasket),
                            icon: FluentIcons.cart_24_regular,
                            accent: c.cyan,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: UltraKpiCard(
                            label: "Clients Endettés",
                            value: "${DateFormatter.formatNumber(metrics.topDebtors.length)} client${metrics.topDebtors.length > 1 ? 's' : ''}",
                            icon: FluentIcons.person_warning_24_regular,
                            accent: c.amber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: Row(
                        children: [
                          // Colonne Gauche : Clients Endettés
                          Expanded(
                            child: _DebtorsPanel(metrics: metrics, ref: ref, c: c),
                          ),
                          const SizedBox(width: 20),
                          // Colonne Droite : Ventes Récentes
                          Expanded(
                            child: _RecentSalesPanel(metrics: metrics, ref: ref, c: c),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════
// Panneaux spécialisés
// ═════════════════════════════════════════

class _DebtorsPanel extends StatelessWidget {
  final DashboardMetrics metrics;
  final WidgetRef ref;
  final DashColors c;
  const _DebtorsPanel({required this.metrics, required this.ref, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
        boxShadow: c.isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0,2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Clients Endettés', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                  Text('Soldes à récupérer en priorité', style: TextStyle(color: c.textSecondary, fontSize: 12)),
                ]),
                if (metrics.topDebtors.isNotEmpty)
                  StatusBadge(text: '${DateFormatter.formatNumber(metrics.topDebtors.length)} CLIENT${metrics.topDebtors.length > 1 ? 'S' : ''}', color: c.amber),
              ],
            ),
          ),
          Divider(color: c.border, height: 1),
          Expanded(
            child: metrics.topDebtors.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.checkmark_circle_24_regular, color: c.emerald, size: 48),
                        const SizedBox(height: 12),
                        Text('Aucune dette 🎉', style: TextStyle(color: c.textSecondary, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: metrics.topDebtors.length,
                    separatorBuilder: (_, __) => Divider(color: c.border, height: 1),
                    itemBuilder: (ctx, i) {
                      final d = metrics.topDebtors[i];
                      final credit = (d['credit'] as num?)?.toDouble() ?? 0.0;
                      final urgency = credit > 50000 ? 'URGENT' : (credit > 20000 ? 'MOYEN' : 'FAIBLE');
                      final urgencyColor = urgency == 'URGENT' ? c.rose : (urgency == 'MOYEN' ? c.amber : c.textSecondary);
                      return _DebtorTile(
                        name: d['name']?.toString() ?? '—',
                        phone: d['phone']?.toString() ?? 'Pas de contact',
                        amount: ref.fmt(credit),
                        urgency: urgency,
                        urgencyColor: urgencyColor,
                        c: c,
                      );
                    },
                  ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0);
  }
}

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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
        boxShadow: c.isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0,2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ventes Récentes', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
              Text('Activité en temps réel', style: TextStyle(color: c.textSecondary, fontSize: 12)),
            ]),
          ),
          Divider(color: c.border, height: 1),
          Expanded(
            child: metrics.recentSales.isEmpty
                ? Center(child: Text('Aucune vente', style: TextStyle(color: c.textSecondary)))
                : ListView.separated(
                    itemCount: metrics.recentSales.length.clamp(0, 8),
                    separatorBuilder: (_, __) => Divider(color: c.border, height: 1),
                    itemBuilder: (ctx, i) {
                      final s = metrics.recentSales[i];
                      final id = s['id']?.toString() ?? '——';
                      final shortId = id.length > 6 ? id.substring(0, 6) : id;
                      final date = s['date']?.toString() ?? '——';
                      final time = date.length > 15 ? date.substring(11, 16) : '——';
                      return _SaleTile(shortId: shortId, time: time, amount: ref.fmt(s['total_amount']), c: c);
                    },
                  ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0);
  }
}

// ═════════════════════════════════════════
// Tiles
// ═════════════════════════════════════════

class _DebtorTile extends StatefulWidget {
  final String name, phone, amount, urgency;
  final Color urgencyColor;
  final DashColors c;
  const _DebtorTile({required this.name, required this.phone, required this.amount, required this.urgency, required this.urgencyColor, required this.c});
  @override
  State<_DebtorTile> createState() => _DebtorTileState();
}
class _DebtorTileState extends State<_DebtorTile> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: AnimatedContainer(
        duration: 150.ms,
        color: _h ? widget.c.surfaceElev : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: widget.urgencyColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: widget.urgencyColor.withValues(alpha: 0.2)),
              ),
              child: Center(
                child: Text(
                  widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                  style: TextStyle(color: widget.urgencyColor, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.name, style: TextStyle(color: widget.c.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                Text(widget.phone, style: TextStyle(color: widget.c.textSecondary, fontSize: 12)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(widget.amount, style: TextStyle(color: widget.urgencyColor, fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 4),
              StatusBadge(text: widget.urgency, color: widget.urgencyColor),
            ]),
          ],
        ),
      ),
    );
  }
}

class _SaleTile extends StatefulWidget {
  final String shortId, time, amount;
  final DashColors c;
  const _SaleTile({required this.shortId, required this.time, required this.amount, required this.c});
  @override
  State<_SaleTile> createState() => _SaleTileState();
}
class _SaleTileState extends State<_SaleTile> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: AnimatedContainer(
        duration: 150.ms,
        color: _h ? widget.c.surfaceElev : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: widget.c.emerald.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: widget.c.emerald.withValues(alpha: 0.2)),
              ),
              child: Icon(FluentIcons.receipt_24_regular, color: widget.c.emerald, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Vente #${widget.shortId}', style: TextStyle(color: widget.c.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                Row(children: [
                  Icon(FluentIcons.clock_24_regular, size: 10, color: widget.c.textMuted),
                  const SizedBox(width: 4),
                  Text(widget.time, style: TextStyle(color: widget.c.textSecondary, fontSize: 11)),
                ]),
              ]),
            ),
            Text(widget.amount, style: TextStyle(color: widget.c.emerald, fontWeight: FontWeight.w700, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════
// Top Bar
// ═════════════════════════════════════════

class _CashierTopBar extends StatelessWidget {
  final WidgetRef ref;
  final DashColors c;
  const _CashierTopBar({required this.ref, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: c.emerald.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.emerald.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: c.emerald, shape: BoxShape.circle))
                    .animate(onPlay: (ctrl) => ctrl.repeat()).custom(
                  duration: 1500.ms,
                  builder: (ctx, v, child) => Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: c.emerald, boxShadow: [BoxShadow(color: c.emerald.withValues(alpha: v * 0.8), blurRadius: v * 8)]),
                  ),
                ),
                const SizedBox(width: 8),
                Text('CAISSE EN LIGNE', style: TextStyle(color: c.emerald, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text('Tableau de Bord Caissier', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
          const Spacer(),
          GestureDetector(
            onTap: () => ref.read(dashboardProvider.notifier).refresh(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: c.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.arrow_sync_24_regular, color: c.textSecondary, size: 14),
                  const SizedBox(width: 6),
                  Text('Actualiser', style: TextStyle(color: c.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
