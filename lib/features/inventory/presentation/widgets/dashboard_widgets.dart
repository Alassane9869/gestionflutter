import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PALETTE DYNAMIQUE — S'adapte automatiquement au thème (clair/sombre)
// ═══════════════════════════════════════════════════════════════════════════════
class DashColors {
  final bool isDark;
  const DashColors._(this.isDark);

  factory DashColors.of(BuildContext context) {
    return DashColors._(Theme.of(context).brightness == Brightness.dark);
  }

  Color get bg         => isDark ? const Color(0xFF0A0B0E) : const Color(0xFFF7F9FC);
  Color get surface    => isDark ? const Color(0xFF111318) : Colors.white;
  Color get surfaceElev => isDark ? const Color(0xFF181B22) : const Color(0xFFF3F4F6);
  Color get border     => isDark ? const Color(0xFF232730) : const Color(0xFFE5E7EB);
  Color get borderHover => isDark ? const Color(0xFF2E3441) : const Color(0xFFD1D5DB);
  Color get textPrimary => isDark ? const Color(0xFFF0F2F5) : const Color(0xFF111827);
  Color get textSecondary => isDark ? const Color(0xFF7C8499) : const Color(0xFF6B7280);
  Color get textMuted  => isDark ? const Color(0xFF4B535F) : const Color(0xFF9CA3AF);

  // Accents sémantiques (identiques en clair/sombre)
  Color get blue    => const Color(0xFF3B82F6);
  Color get emerald => const Color(0xFF10B981);
  Color get amber   => const Color(0xFFF59E0B);
  Color get rose    => const Color(0xFFEF4444);
  Color get violet  => const Color(0xFF8B5CF6);
  Color get cyan    => const Color(0xFF06B6D4);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ULTRA KPI CARD — Avec sparkline et animation de hover
// ═══════════════════════════════════════════════════════════════════════════════
class UltraKpiCard extends StatefulWidget {
  final String label;
  final String value;
  final String? change;
  final bool positive;
  final Color accent;
  final IconData icon;
  final List<double>? sparkData;
  final String? tooltip;

  const UltraKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.change,
    this.positive = true,
    required this.accent,
    required this.icon,
    this.sparkData,
    this.tooltip,
  });

  @override
  State<UltraKpiCard> createState() => _UltraKpiCardState();
}

class _UltraKpiCardState extends State<UltraKpiCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

    Widget card = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _hovered ? c.surfaceElev : c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hovered ? widget.accent.withValues(alpha: 0.35) : c.border,
            width: 1,
          ),
          boxShadow: _hovered
              ? [BoxShadow(color: widget.accent.withValues(alpha: 0.08), blurRadius: 16, spreadRadius: -2)]
              : [if (!c.isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: widget.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(widget.icon, color: widget.accent, size: 13),
                ),
                if (widget.change != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: (widget.positive ? c.emerald : c.rose).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (widget.positive ? c.emerald : c.rose).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.positive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                          size: 8,
                          color: widget.positive ? c.emerald : c.rose,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          widget.change!,
                          style: TextStyle(
                            color: widget.positive ? c.emerald : c.rose,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              widget.label.toUpperCase(),
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 7,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                widget.value,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            if (widget.sparkData != null && widget.sparkData!.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SizedBox(
                  height: 10,
                  child: _Sparkline(data: widget.sparkData!, color: widget.accent),
                ),
              ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        child: card,
      );
    }
    return card;
  }
}

class _Sparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  const _Sparkline({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.reduce(math.max);
    final minVal = data.reduce(math.min);
    final range = maxVal - minVal;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          minY: range > 0 ? minVal - range * 0.2 : minVal - 1,
          maxY: range > 0 ? maxVal + range * 0.2 : maxVal + 1,
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
              isCurved: true,
              curveSmoothness: 0.3,
              color: color,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.2), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// METRIC ROW — Liste avec barre de progression
// ═══════════════════════════════════════════════════════════════════════════════
class MetricRow extends StatefulWidget {
  final int rank;
  final String title;
  final String subtitle;
  final String value;
  final double? progress;
  final Color accent;
  final IconData icon;

  const MetricRow({
    super.key,
    required this.rank,
    required this.title,
    required this.subtitle,
    required this.value,
    this.progress,
    required this.accent,
    required this.icon,
  });

  @override
  State<MetricRow> createState() => _MetricRowState();
}

class _MetricRowState extends State<MetricRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: 150.ms,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _hovered ? c.surfaceElev : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '#${widget.rank}',
                style: TextStyle(color: c.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: widget.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(widget.icon, color: widget.accent, size: 14),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                  Text(widget.subtitle, style: TextStyle(color: c.textSecondary, fontSize: 11)),
                  if (widget.progress != null) ...[
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: widget.progress!.clamp(0.0, 1.0),
                        backgroundColor: c.border,
                        valueColor: AlwaysStoppedAnimation<Color>(widget.accent),
                        minHeight: 3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(widget.value, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACTIVITY ITEM — Ligne d'activité
// ═══════════════════════════════════════════════════════════════════════════════
class ActivityItem extends StatelessWidget {
  final String title;
  final String time;
  final String amount;
  final Color color;
  final IconData icon;

  const ActivityItem({
    super.key,
    required this.title,
    required this.time,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                Text(time, style: TextStyle(color: c.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Text(amount, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION CARD — Conteneur avec entête
// ═══════════════════════════════════════════════════════════════════════════════
class SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? action;

  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border, width: 1),
        boxShadow: c.isDark
            ? []
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14), overflow: TextOverflow.ellipsis),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: TextStyle(color: c.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                if (action != null) action!,
              ],
            ),
          ),
          Divider(color: c.border, height: 1),
          child,
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATUS BADGE
// ═══════════════════════════════════════════════════════════════════════════════
class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  const StatusBadge({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}
// ═══════════════════════════════════════════════════════════════════════════════
// DASHBOARD PIE CHART — Mix des ventes
// ═══════════════════════════════════════════════════════════════════════════════
class DashboardPieChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final DashColors c;

  const DashboardPieChart({super.key, required this.data, required this.c});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final List<Color> colors = [c.blue, c.emerald, c.violet, c.amber, c.rose, c.cyan];
    final totalQty = data.fold<double>(0, (sum, e) => sum + ((e['total_qty'] as num?)?.toDouble() ?? 0.0));

    return SizedBox(
      height: 160,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 36,
                sections: data.asMap().entries.map((entry) {
                  final i = entry.key;
                  final val = (entry.value['total_qty'] as num?)?.toDouble() ?? 0.0;
                  final pct = (val / totalQty * 100).toStringAsFixed(0);
                  return PieChartSectionData(
                    color: colors[i % colors.length],
                    value: val,
                    title: '$pct%',
                    radius: 34,
                    titleStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: data.asMap().entries.map((entry) {
                final i = entry.key;
                final name = entry.value['name']?.toString() ?? '—';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(name, style: TextStyle(color: c.textSecondary, fontSize: 10, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
