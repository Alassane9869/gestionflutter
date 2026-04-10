import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/inventory/presentation/dashboard_screen.dart';
import '../domain/models/stock_audit.dart';
import '../providers/stock_audit_provider.dart';
import '../providers/product_providers.dart';

class StockAuditScreen extends ConsumerStatefulWidget {
  const StockAuditScreen({super.key});

  @override
  ConsumerState<StockAuditScreen> createState() => _StockAuditScreenState();
}

class _StockAuditScreenState extends ConsumerState<StockAuditScreen> {
  String? _selectedAuditId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_selectedAuditId != null) {
      return _AuditDetailsView(
        auditId: _selectedAuditId!,
        onBack: () => setState(() => _selectedAuditId = null),
      );
    }

    final auditsAsync = ref.watch(stockAuditListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.05),
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "Inventaires Physiques",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(FluentIcons.chevron_left_24_regular),
          onPressed: () => ref.read(navigationProvider.notifier).setPage(0, ref),
        ),
        actions: [
          IconButton(
            icon: const Icon(FluentIcons.add_24_filled),
            onPressed: () => _startNewAudit(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: auditsAsync.when(
                data: (audits) {
                  if (audits.isEmpty) return _buildEmptyState(theme, isDark);
                  return ListView.builder(
                    itemCount: audits.length,
                    padding: const EdgeInsets.only(bottom: 100),
                    itemBuilder: (context, index) {
                      final audit = audits[index];
                      return _AuditCard(
                        audit: audit,
                        onTap: () => setState(() => _selectedAuditId = audit.id),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, __) => Center(child: Text("Erreur: $e")),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(FluentIcons.clipboard_search_24_regular, size: 80, color: Colors.grey.shade300),
          ),
          const SizedBox(height: 32),
          const Text(
            "Aucun inventaire enregistré",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 300,
            child: Text(
              "Commencez un nouvel audit pour vérifier la précision de votre stock.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startNewAudit(BuildContext context) async {
    final notesCtrl = TextEditingController();
    String? selectedCategory;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final productsAsync = ref.read(productListProvider);
    final categories = productsAsync.value?.map((p) => p.category ?? "Sans catégorie").toSet().toList() ?? [];
    categories.sort();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1A1C23) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              title: Row(
                children: [
                  Icon(FluentIcons.clipboard_pulse_24_filled, color: theme.colorScheme.primary, size: 28),
                  const SizedBox(width: 14),
                  const Text("Démarrer un inventaire", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Cible de l'audit",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.grey.shade500, letterSpacing: 1),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedCategory,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    hint: const Text("Stock complet"),
                    items: [
                      const DropdownMenuItem(value: null, child: Text("Tout le stock (Complet)")),
                      ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (v) => setDialogState(() => selectedCategory = v),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Description / Notes",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.grey.shade500, letterSpacing: 1),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: notesCtrl,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: "Ex : Audit mensuel fin de mois...",
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text("ANNULER", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w900, fontSize: 13)),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: const Text("DÉMARRER L'AUDIT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                ),
              ],
            );
          }
        );
      },
    );

    if (confirm == true) {
      final id = await ref.read(stockAuditActionsProvider).startNewAudit(
        notes: notesCtrl.text,
        category: selectedCategory,
      );
      if (mounted) setState(() => _selectedAuditId = id);
    }
  }
}

class _AuditCard extends StatelessWidget {
  final StockAudit audit;
  final VoidCallback onTap;

  const _AuditCard({required this.audit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isCompleted = audit.status == StockAuditStatus.completed;
    final accentColor = isCompleted ? Colors.green : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2028).withValues(alpha: 0.7) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor.withValues(alpha: 0.2), accentColor.withValues(alpha: 0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                  ),
                  child: Icon(
                    isCompleted ? FluentIcons.checkmark_circle_24_filled : FluentIcons.clock_24_filled,
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            DateFormatter.formatDate(audit.date),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormatter.formatTime(audit.date),
                            style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        audit.notes?.isNotEmpty == true ? audit.notes! : (audit.category ?? "Inventaire Complet"),
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isCompleted ? "VALIDÉ" : "EN COURS",
                        style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuditDetailsView extends ConsumerStatefulWidget {
  final String auditId;
  final VoidCallback onBack;

  const _AuditDetailsView({required this.auditId, required this.onBack});

  @override
  ConsumerState<_AuditDetailsView> createState() => _AuditDetailsViewState();
}

class _AuditDetailsViewState extends ConsumerState<_AuditDetailsView> {
  final _searchCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  String _filter = '';
  String _discrepancyFilter = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _barcodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final itemsAsync = ref.watch(stockAuditItemsProvider(widget.auditId));
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          children: [
            _buildDetailsHeader(theme, isDark, itemsAsync),
            const SizedBox(height: 4),
            _buildSearchAndFilter(theme, isDark),
            const SizedBox(height: 4),
            Expanded(
              child: itemsAsync.when(
                data: (items) {
                  final filtered = items.where((i) {
                    final matchesSearch = (i.productName ?? '').toLowerCase().contains(_filter.toLowerCase());
                    if (_discrepancyFilter == 'discrepancy') return matchesSearch && i.difference != 0;
                    if (_discrepancyFilter == 'ok') return matchesSearch && i.difference == 0;
                    return matchesSearch;
                  }).toList();

                  if (filtered.isEmpty) return _buildEmptyFilterState();

                  return ListView.builder(
                    itemCount: filtered.length,
                    padding: const EdgeInsets.only(bottom: 20),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _AuditItemRow(
                        item: item,
                        readOnly: ref.read(stockAuditListProvider).value?.firstWhere((a) => a.id == widget.auditId).status == StockAuditStatus.completed,
                        onUpdate: (qty) => ref.read(stockAuditActionsProvider).updateItemQty(item.id, qty),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, __) => Center(child: Text("Erreur: $e")),
              ),
            ),
            itemsAsync.when(
              data: (items) => _buildFinancialSummary(theme, isDark, items),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsHeader(ThemeData theme, bool isDark, AsyncValue<List<StockAuditItem>> itemsAsync) {
    final audit = ref.read(stockAuditListProvider).value?.firstWhere((a) => a.id == widget.auditId);
    final isCompleted = audit?.status == StockAuditStatus.completed;

    return Row(
      children: [
        IconButton(
          onPressed: widget.onBack,
          icon: const Icon(FluentIcons.arrow_left_24_regular),
          style: IconButton.styleFrom(
            backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text("Audit Stock", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  const SizedBox(width: 16),
                  if (audit?.category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        audit!.category!.toUpperCase(),
                        style: TextStyle(color: theme.colorScheme.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
                    ),
                ],
              ),
              Text(
                DateFormatter.formatDateTime(audit?.date ?? DateTime.now()),
                style: TextStyle(color: Colors.grey.shade500, fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        if (isCompleted)
          const SuccessBadge(label: "Audit Finalisé")
        else
          FilledButton.icon(
            onPressed: () => _confirmFinalize(context),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 4,
              shadowColor: Colors.green.withValues(alpha: 0.3),
            ),
            icon: const Icon(FluentIcons.checkmark_starburst_24_filled),
            label: const Text("TERMINER ET AJUSTER", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
          ),
      ],
    );
  }

  Widget _buildEmptyFilterState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FluentIcons.search_info_24_regular, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text("Aucun article ne correspond", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter(ThemeData theme, bool isDark) {
    return Column(
      children: [
        // --- BARCODE SCANNER BAR ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Icon(FluentIcons.barcode_scanner_24_filled, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _barcodeCtrl,
                  autofocus: true,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  onSubmitted: (barcode) async {
                    if (barcode.trim().isEmpty) return;
                    final success = await ref.read(stockAuditActionsProvider).incrementItemByBarcode(widget.auditId, barcode.trim());
                    if (!success) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Produit non trouvé"), backgroundColor: Colors.orange),
                        );
                      }
                    }
                    _barcodeCtrl.clear();
                  },
                  decoration: InputDecoration(
                    hintText: "SCANNER UN PRODUIT...",
                    hintStyle: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 12, 
                      letterSpacing: 1, 
                      color: theme.colorScheme.primary.withValues(alpha: 0.3)
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (_barcodeCtrl.text.isNotEmpty)
                IconButton(
                  icon: const Icon(FluentIcons.dismiss_20_filled),
                  onPressed: () => setState(() => _barcodeCtrl.clear()),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // --- TEXT SEARCH & FILTERS ---
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _filter = v),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
                  decoration: InputDecoration(
                    hintText: "Rechercher...",
                    icon: Icon(FluentIcons.search_24_regular, color: Colors.grey.shade400, size: 16),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildQuickFilter("TOUS", 'all', theme),
            const SizedBox(width: 8),
            _buildQuickFilter("ÉCARTS", 'discrepancy', theme, color: Colors.orange.shade400),
            const SizedBox(width: 12),
            _buildQuickFilter("OK", 'ok', theme, color: Colors.green.shade400),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickFilter(String label, String value, ThemeData theme, {Color? color}) {
    final active = _discrepancyFilter == value;
    final baseColor = color ?? theme.colorScheme.primary;
    
    return InkWell(
      onTap: () => setState(() => _discrepancyFilter = value),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? baseColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? baseColor.withValues(alpha: 0.3) : Colors.grey.shade200),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? baseColor : Colors.grey.shade500,
            fontWeight: FontWeight.bold,
            fontSize: 10,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildFinancialSummary(ThemeData theme, bool isDark, List<StockAuditItem> items) {
    final totalDiff = items.fold(0.0, (sum, item) => sum + item.difference);
    final countDiscrepancies = items.where((i) => i.difference != 0).length;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2028).withValues(alpha: 0.8) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildSummaryStat("Articles", "${items.length}", FluentIcons.box_24_regular, Colors.blue),
          _divider(),
          _buildSummaryStat("Écarts", "$countDiscrepancies", FluentIcons.warning_24_regular, countDiscrepancies > 0 ? Colors.orange : Colors.green),
          _divider(),
          _buildSummaryStat("Balance", totalDiff > 0 ? "+$totalDiff" : "$totalDiff", FluentIcons.arrow_trending_lines_24_filled, totalDiff == 0 ? Colors.grey : (totalDiff > 0 ? Colors.green : Colors.red)),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 24, color: Colors.grey.withValues(alpha: 0.1), margin: const EdgeInsets.symmetric(horizontal: 16));

  Widget _buildSummaryStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: -0.2)),
              Text(label.toUpperCase(), style: TextStyle(color: Colors.grey.shade500, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.2)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmFinalize(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1C23) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Row(
          children: [
            Icon(FluentIcons.warning_24_filled, color: Colors.orange),
            SizedBox(width: 12),
            Text("Valider l'ajustement ?", style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: const Text("Cette action va ajuster définitivement le stock physique. Des mouvements de correction seront générés automatiquement."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("ANNULER", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w900))),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("CONFIRMER ET AJUSTER", style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(stockAuditActionsProvider).finalizeAudit(widget.auditId);
    }
  }
}

class _AuditItemRow extends StatefulWidget {
  final StockAuditItem item;
  final Function(double) onUpdate;
  final bool readOnly;

  const _AuditItemRow({required this.item, required this.onUpdate, this.readOnly = false});

  @override
  State<_AuditItemRow> createState() => _AuditItemRowState();
}

class _AuditItemRowState extends State<_AuditItemRow> {
  late TextEditingController _ctrl;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.item.actualQty.toString());
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _ctrl.selection = TextSelection(baseOffset: 0, extentOffset: _ctrl.text.length);
      }
    });
  }

  @override
  void didUpdateWidget(_AuditItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.actualQty != oldWidget.item.actualQty && !_focusNode.hasFocus) {
       _ctrl.text = widget.item.actualQty.toString();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diff = widget.item.actualQty - widget.item.theoreticalQty;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasDiscrepancy = diff != 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasDiscrepancy 
              ? (diff > 0 ? Colors.blue : Colors.red).withValues(alpha: 0.3) 
              : Colors.transparent,
        ),
        boxShadow: hasDiscrepancy ? [
          BoxShadow(color: (diff > 0 ? Colors.blue : Colors.red).withValues(alpha: 0.05), blurRadius: 10)
        ] : [],
      ),
      child: Row(
        children: [
          // --- PRODUCT INFO ---
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.productName ?? "Produit inconnu", 
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: -0.1)
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text("THÉO: ${widget.item.theoreticalQty}", style: TextStyle(color: Colors.grey.shade600, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // --- ACTUAL QTY INPUT ---
          Expanded(
            flex: 2,
            child: Center(
              child: widget.readOnly 
                ? Text("${widget.item.actualQty}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14))
                : SizedBox(
                    width: 60,
                    height: 34,
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.primary),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: theme.colorScheme.primary.withValues(alpha: 0.05),
                        contentPadding: EdgeInsets.zero,
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.1))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5)),
                      ),
                      onChanged: (v) {
                        final val = (double.tryParse(v) ?? 0.0).abs();
                        widget.onUpdate(val);
                        setState(() {});
                      },
                    ),
                  ),
            ),
          ),
          
          // --- DISCREPANCY STATUS ---
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasDiscrepancy)
                      Icon(diff > 0 ? FluentIcons.arrow_trending_lines_24_filled : FluentIcons.arrow_trending_down_24_filled, 
                           color: diff > 0 ? Colors.blue : Colors.red, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      diff == 0 ? "OK" : (diff > 0 ? "+$diff" : "$diff"),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: diff == 0 ? Colors.grey.shade300 : (diff > 0 ? Colors.blue : Colors.red),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                Text(
                  diff == 0 ? "IDEM" : (diff > 0 ? "SURPLUS" : "MANQUANT"), 
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 0.1)
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SuccessBadge extends StatelessWidget {
  final String label;
  const SuccessBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(FluentIcons.checkmark_circle_24_filled, color: Colors.green, size: 24),
          const SizedBox(width: 12),
          Text(
            label.toUpperCase(), 
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)
          ),
        ],
      ),
    );
  }
}
