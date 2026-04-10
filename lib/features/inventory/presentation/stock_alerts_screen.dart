import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/inventory/providers/product_providers.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/inventory/application/inventory_report_service.dart';
import 'package:danaya_plus/features/inventory/presentation/widgets/dashboard_widgets.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'dashboard_screen.dart';

class StockAlertsScreen extends ConsumerWidget {
  const StockAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = DashColors.of(context);
    final productsAsync = ref.watch(productListProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        centerTitle: false,
        title: Text(
          "Tour de Contrôle Stock",
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        leading: IconButton(
          icon: Icon(FluentIcons.chevron_left_24_regular, color: c.textPrimary),
          onPressed: () => ref.read(navigationProvider.notifier).setPage(0, ref),
        ),
        actions: [
          _PrintButton(productsAsync: productsAsync),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: c.border, height: 1),
        ),
      ),
      body: productsAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: c.blue)),
        error: (e, st) => Center(child: Text("Erreur: $e", style: TextStyle(color: c.rose))),
        data: (products) {
          final lowStock = products.where((p) => p.isLowStock || p.isOutOfStock).toList();
          final outOfStockCount = products.where((p) => p.isOutOfStock).length;
          final lowCount = products.where((p) => p.isLowStock && !p.isOutOfStock).length;

          if (lowStock.isEmpty) {
            return _EmptyState(c: c);
          }

          return CustomScrollView(
            slivers: [
              // 1. STATS HEADER
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatMiniCard(
                          label: "RUPTURES",
                          value: "$outOfStockCount",
                          color: c.rose,
                          icon: FluentIcons.dismiss_circle_24_regular,
                          c: c,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatMiniCard(
                          label: "STOCK FAIBLE",
                          value: "$lowCount",
                          color: c.amber,
                          icon: FluentIcons.warning_24_regular,
                          c: c,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. LIST TITLE
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        "ARTICLES CRITIQUES",
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "${lowStock.length} produits",
                        style: TextStyle(color: c.blue, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. ALERTS LIST
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final p = lowStock[index];
                      return _AlertCard(p: p, c: c)
                          .animate(delay: (index * 30).ms)
                          .fadeIn(duration: 250.ms)
                          .slideX(begin: 0.05, end: 0, curve: Curves.easeOut);
                    },
                    childCount: lowStock.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          );
        },
      ),
    );
  }
}

class _PrintButton extends ConsumerWidget {
  final AsyncValue productsAsync;
  const _PrintButton({required this.productsAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = DashColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ElevatedButton.icon(
        icon: const Icon(FluentIcons.print_24_regular, size: 18),
        label: const Text("LISTE DE COURSES", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: c.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onPressed: () {
          productsAsync.whenData((products) {
            final List items = products as List;
            final lowStock = items
                .where((p) => (p as dynamic).isLowStock || (p as dynamic).isOutOfStock)
                .cast<dynamic>()
                .toList();
            if (lowStock.isNotEmpty) {
              showDialog(
                context: context,
                builder: (ctx) => _ShoppingListDialog(
                  products: lowStock,
                  ref: ref,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Aucun produit en stock critique à imprimer.")),
              );
            }
          });
        },
      ),
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final DashColors c;

  const _StatMiniCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)), // highlight border with stat color
        boxShadow: [
          if (!c.isDark)
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(color: c.textPrimary, fontSize: 26, fontWeight: FontWeight.w900, height: 1.0),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
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

class _EmptyState extends StatelessWidget {
  final DashColors c;
  const _EmptyState({required this.c});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: c.emerald.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(FluentIcons.checkmark_circle_24_filled, size: 64, color: c.emerald),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text(
            "Tout est sous contrôle !",
            style: TextStyle(color: c.textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            "Aucun article n'est actuellement en situation critique.",
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final dynamic p;
  final DashColors c;

  const _AlertCard({required this.p, required this.c});

  @override
  Widget build(BuildContext context) {
    final bool isOut = p.isOutOfStock;
    final color = isOut ? c.rose : c.amber;
    final double stockRatio = (p.alertThreshold > 0) ? (p.quantity / p.alertThreshold).clamp(0.0, 1.0) : 0.0;
    final double urgency = 1.0 - stockRatio;
    final double needed = ((p.alertThreshold * 2) - p.quantity).clamp(0.0, double.infinity);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // 1. Status icon
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isOut ? FluentIcons.dismiss_circle_24_filled : FluentIcons.warning_24_filled,
              color: color, size: 20,
            ),
          ).animate(onPlay: (ctrl) => ctrl.repeat(reverse: true)).shimmer(duration: 2.seconds, color: color.withValues(alpha: 0.2)),

          const SizedBox(width: 12),

          // 2. Name + subtitle
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isOut ? "⛔ En rupture totale" : "⚠️ Stock insuffisant",
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // 3. Progress bar + info
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Stock : ${DateFormatter.formatQuantity(p.quantity)} / ${DateFormatter.formatQuantity(p.alertThreshold)}",
                      style: TextStyle(color: c.textSecondary, fontSize: 10),
                    ),
                    Text(
                      "${(urgency * 100).toInt()}% urgent",
                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: urgency,
                    minHeight: 7,
                    backgroundColor: color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // 4. Commander
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "À commander",
                style: TextStyle(color: c.textSecondary, fontSize: 9),
              ),
              Text(
                "+ ${DateFormatter.formatQuantity(needed)}",
                style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── DIALOG ÉDITION LISTE DE COURSES ──────────────────────────────────────────

class _ShoppingListDialog extends StatefulWidget {
  final List<dynamic> products;
  final WidgetRef ref;

  const _ShoppingListDialog({required this.products, required this.ref});

  @override
  State<_ShoppingListDialog> createState() => _ShoppingListDialogState();
}

class _ShoppingListDialogState extends State<_ShoppingListDialog> {
  late List<ShoppingListEntry> _entries;
  late List<TextEditingController> _controllers;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    _entries = widget.products.map((p) {
      final besoin = ((p.alertThreshold * 2) - p.quantity).clamp(0.0, double.infinity);
      return ShoppingListEntry(product: p, orderQty: besoin);
    }).toList();
    _controllers = _entries.map((e) => TextEditingController(text: e.orderQty.toStringAsFixed(0))).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncEntries() {
    for (int i = 0; i < _entries.length; i++) {
      final v = double.tryParse(_controllers[i].text) ?? 0.0;
      _entries[i] = _entries[i].copyWith(orderQty: v);
    }
  }

  Future<void> _print() async {
    _syncEntries();
    final settings = widget.ref.read(shopSettingsProvider).value;
    if (settings == null) return;
    setState(() => _printing = true);
    try {
      await InventoryReportService.generateShoppingListPdf(
        entries: _entries,
        settings: settings,
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = DashColors.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D2E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 30, offset: const Offset(0, 10))],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: c.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: Icon(FluentIcons.cart_24_regular, color: c.blue, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Liste de Courses", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
                        Text("Ajustez les quantités à commander avant impression", style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: isDark ? Colors.white60 : Colors.black45,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Column headers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Expanded(flex: 3, child: Text("Article", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1))),
                  const SizedBox(width: 8),
                  const Expanded(flex: 1, child: Text("Stock", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1))),
                  const SizedBox(width: 8),
                  const Expanded(flex: 1, child: Text("Seuil", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1))),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: Text("Qté à commander", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c.blue, letterSpacing: 1))),
                ],
              ),
            ),

            // List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _entries.length,
                itemBuilder: (ctx, i) {
                  final e = _entries[i];
                  final isOut = e.product.isOutOfStock;
                  final color = isOut ? c.rose : c.amber;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        // Indicator dot
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        // Name
                        Expanded(
                          flex: 3,
                          child: Text(
                            e.product.name,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Stock actuel
                        Expanded(
                          flex: 1,
                          child: Text(
                            DateFormatter.formatQuantity(e.product.quantity),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Seuil
                        Expanded(
                          flex: 1,
                          child: Text(
                            DateFormatter.formatQuantity(e.product.alertThreshold),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Qty input
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _controllers[i],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: c.blue),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.blue.withValues(alpha: 0.3))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.blue, width: 2)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.blue.withValues(alpha: 0.2))),
                              filled: true,
                              fillColor: c.blue.withValues(alpha: 0.05),
                            ),
                            onChanged: (v) {
                              setState(() {
                                final val = double.tryParse(v) ?? 0.0;
                                _entries[i] = _entries[i].copyWith(orderQty: val);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Footer actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Total à commander : ${DateFormatter.formatQuantity(_entries.fold(0.0, (s, e) => s + e.orderQty))} unités",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.blue),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Annuler"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: _printing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(FluentIcons.print_24_regular, size: 18),
                    label: Text(_printing ? "Impression..." : "Imprimer le PDF"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: _printing ? null : _print,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
