import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/inventory/domain/models/product.dart';
import 'package:danaya_plus/features/inventory/application/inventory_automation_service.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/core/widgets/premium_settings_widgets.dart';
import 'package:danaya_plus/features/inventory/presentation/widgets/dashboard_widgets.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';

class BarcodeLabelsDialog extends ConsumerStatefulWidget {
  final List<Product> initialProducts;
  const BarcodeLabelsDialog({super.key, required this.initialProducts});

  @override
  ConsumerState<BarcodeLabelsDialog> createState() => _BarcodeLabelsDialogState();
}

class _BarcodeLabelsDialogState extends ConsumerState<BarcodeLabelsDialog> {
  final Map<String, int> _itemsToPrint = {}; // Map ProductID -> Qty
  final Set<String> _selectedIds = {};       // Checked items
  final _searchController = TextEditingController();
  final Map<String, TextEditingController> _qtyControllers = {};
  String _currentSearch = "";

  @override
  void initState() {
    super.initState();
    // Par défaut, si on vient avec des produits initiaux, on les ajoute
    for (var p in widget.initialProducts) {
      _itemsToPrint[p.id] = 1;
      _selectedIds.add(p.id);
      _qtyControllers[p.id] = TextEditingController(text: "1");
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (var ctrl in _qtyControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _selectAll() {
    setState(() {
      for (var p in widget.initialProducts) {
        if (!_itemsToPrint.containsKey(p.id)) {
          _itemsToPrint[p.id] = 1;
          _qtyControllers[p.id] = TextEditingController(text: "1");
        }
        _selectedIds.add(p.id);
      }
    });
  }

  void _selectAlerts() {
    setState(() {
      for (var p in widget.initialProducts) {
        if (p.isLowStock || p.isOutOfStock) {
          if (!_itemsToPrint.containsKey(p.id)) {
            _itemsToPrint[p.id] = 1;
            _qtyControllers[p.id] = TextEditingController(text: "1");
          }
          _selectedIds.add(p.id);
        } else {
          _selectedIds.remove(p.id);
        }
      }
    });
  }

  void _clearAll() {
    setState(() {
      _selectedIds.clear();
      _itemsToPrint.clear();
      for (var ctrl in _qtyControllers.values) {
        ctrl.dispose();
      }
      _qtyControllers.clear();
    });
  }

  void _toggleItem(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
        if (!_itemsToPrint.containsKey(id)) {
          _itemsToPrint[id] = 1;
          _qtyControllers[id] = TextEditingController(text: "1");
        }
      }
    });
  }

  void _updateQty(String id, int next) {
    if (next < 1) return;
    setState(() {
      _itemsToPrint[id] = next;
      _qtyControllers[id]?.text = next.toString();
    });
  }

  void _handleManualQty(String id, String value) {
    final val = int.tryParse(value);
    if (val != null && val > 0) {
      _itemsToPrint[id] = val;
    }
  }

  Future<void> _handlePrint() async {
    final selectedItems = _selectedIds.toList();
    if (selectedItems.isEmpty) return;

    final List<Product> toPrint = [];
    for (final id in selectedItems) {
      try {
        final product = widget.initialProducts.firstWhere((p) => p.id == id);
        final qty = _itemsToPrint[id] ?? 1;
        for (int i = 0; i < qty; i++) {
          toPrint.add(product);
        }
      } catch (_) {}
    }

    try {
      await ref.read(inventoryAutomationServiceProvider).printBarcodeLabels(toPrint);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      EnterpriseWidgets.showPremiumErrorDialog(context, title: "Erreur d'impression", message: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    
    final filteredProducts = widget.initialProducts.where((p) {
      if (_currentSearch.isEmpty) return true;
      return p.name.toLowerCase().contains(_currentSearch.toLowerCase()) || 
             (p.barcode?.contains(_currentSearch) ?? false) ||
             (p.reference?.contains(_currentSearch) ?? false);
    }).toList();

    final totalLabels = _selectedIds.fold(0, (a, id) => a + (_itemsToPrint[id] ?? 0));

    return EnterpriseWidgets.buildPremiumDialog(
      context,
      title: "Générateur d'Étiquettes",
      icon: FluentIcons.barcode_scanner_24_filled,
      width: 850,
      child: Column(
        children: [
          // ── HEADER CARDS (Bento Style) ──
          Row(
            children: [
              Expanded(
                child: _buildHeaderActionCard(
                  context,
                  title: "Toute la liste",
                  icon: FluentIcons.checkbox_checked_24_regular,
                  color: c.amber,
                  onTap: _selectAll,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHeaderActionCard(
                  context,
                  title: "Alertes Stock",
                  icon: FluentIcons.warning_24_regular,
                  color: c.amber,
                  onTap: _selectAlerts,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHeaderActionCard(
                  context,
                  title: "Vider",
                  icon: FluentIcons.dismiss_24_regular,
                  color: c.rose,
                  onTap: _clearAll,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── SEARCH BAR ──
          Container(
            decoration: BoxDecoration(
              color: c.isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _currentSearch = v),
              decoration: InputDecoration(
                hintText: "Rechercher un produit ou un code...",
                prefixIcon: Icon(FluentIcons.search_24_regular, color: c.textMuted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── PRODUCT LIST ──
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: c.isDark ? const Color(0xFF14161B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.border),
              ),
              child: filteredProducts.isEmpty 
                ? Center(child: Text("Aucun produit trouvé", style: TextStyle(color: c.textMuted)))
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final p = filteredProducts[index];
                      final isSelected = _selectedIds.contains(p.id);
                      final qty = _itemsToPrint[p.id] ?? 1;
                      
                      if (!_qtyControllers.containsKey(p.id)) {
                        _qtyControllers[p.id] = TextEditingController(text: qty.toString());
                      }

                      return _PrintingItemTile(
                        product: p,
                        quantity: qty,
                        isSelected: isSelected,
                        qtyController: _qtyControllers[p.id]!,
                        onToggle: () => _toggleItem(p.id),
                        onUpdateQty: (val) => _updateQty(p.id, qty + val),
                        onManualQty: (val) => _handleManualQty(p.id, val),
                      );
                    },
                  ),
            ),
          ),
          const SizedBox(height: 16),

          // ── CONFIGURATION BANNER ──
          _buildConfigBanner(context, c),
          const SizedBox(height: 16),

          // ── SUMMARY FOOTER ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: c.surfaceElev,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(FluentIcons.info_24_regular, color: c.amber, size: 20),
                const SizedBox(width: 12),
                Text(
                  "Total : ${_selectedIds.length} produits • $totalLabels étiquettes",
                  style: TextStyle(fontWeight: FontWeight.w800, color: c.amber, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            foregroundColor: c.textPrimary,
          ),
          child: const Text("Annuler"),
        ),
        const SizedBox(width: 8),
        PremiumSettingsWidgets.buildGradientBtn(
          onPressed: _selectedIds.isEmpty ? () {} : _handlePrint,
          icon: FluentIcons.document_pdf_24_regular,
          label: "Générer PDF",
          colors: [const Color(0xFFFF8008), const Color(0xFFFFC837)], // Orange gradient
        ),
      ],
    );
  }

  Widget _buildHeaderActionCard(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          color: color.withValues(alpha: 0.02),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigBanner(BuildContext context, DashColors c) {
    final settings = ref.watch(shopSettingsProvider).value;
    final format = settings?.labelFormat ?? LabelPrintingFormat.a4Sheets;
    final isA4 = format == LabelPrintingFormat.a4Sheets;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF282C34).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: c.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(FluentIcons.print_24_regular, color: c.amber, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("CONFIGURATION D'IMPRESSION", style: TextStyle(fontWeight: FontWeight.w900, color: c.amber, fontSize: 11, letterSpacing: 0.5)),
                Text(
                  isA4 ? "Planches A4 (Impression Standard)" : "Étiquette Unique (Rouleau Thermique)",
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrintingItemTile extends StatelessWidget {
  final Product product;
  final int quantity;
  final bool isSelected;
  final TextEditingController qtyController;
  final VoidCallback onToggle;
  final Function(int) onUpdateQty;
  final Function(String) onManualQty;

  const _PrintingItemTile({
    required this.product,
    required this.quantity,
    required this.isSelected,
    required this.qtyController,
    required this.onToggle,
    required this.onUpdateQty,
    required this.onManualQty,
  });

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? c.surfaceElev : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? c.borderHover : Colors.transparent),
      ),
      child: Row(
        children: [
          // Checkbox circular
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? c.amber : c.textMuted, width: 2),
                color: isSelected ? c.amber : Colors.transparent,
              ),
              child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.black) : null,
            ),
          ),
          const SizedBox(width: 16),
          
          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: isSelected ? c.textPrimary : c.textSecondary)),
                Text(product.barcode ?? product.reference ?? "Sans code", style: TextStyle(color: c.textMuted, fontSize: 12)),
              ],
            ),
          ),

          // Stock Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: c.emerald.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              product.quantity.toInt().toString(),
              style: TextStyle(color: c.emerald, fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
          const SizedBox(width: 16),

          // Qty Selector with Manual Input
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: c.isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiniBtn(icon: FluentIcons.subtract_16_regular, onTap: () => onUpdateQty(-1)),
                Container(
                  width: 45,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextField(
                    controller: qtyController,
                    onChanged: onManualQty,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: c.textPrimary),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                _MiniBtn(icon: FluentIcons.add_16_regular, color: c.amber, onTap: () => onUpdateQty(1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const _MiniBtn({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
