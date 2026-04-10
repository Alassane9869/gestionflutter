import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/inventory/domain/models/product.dart';
import 'package:danaya_plus/features/inventory/application/inventory_automation_service.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';

class BarcodeLabelsDialog extends ConsumerStatefulWidget {
  final List<Product> initialProducts;
  const BarcodeLabelsDialog({super.key, required this.initialProducts});

  @override
  ConsumerState<BarcodeLabelsDialog> createState() => _BarcodeLabelsDialogState();
}

class _BarcodeLabelsDialogState extends ConsumerState<BarcodeLabelsDialog> {
  final Map<String, int> _selectedQuantities = {};
  String _searchQuery = "";
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Par défaut, on ne sélectionne rien pour laisser l'utilisateur choisir
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(Product p) {
    setState(() {
      if (_selectedQuantities.containsKey(p.id)) {
        _selectedQuantities.remove(p.id);
      } else {
        _selectedQuantities[p.id] = 1;
      }
    });
  }

  void _setQuantity(Product p, int qty) {
    if (qty <= 0) {
      setState(() => _selectedQuantities.remove(p.id));
    } else {
      setState(() => _selectedQuantities[p.id] = qty);
    }
  }

  void _selectAll() {
    setState(() {
      for (final p in widget.initialProducts) {
        if (p.barcode != null && p.barcode!.isNotEmpty) {
           _selectedQuantities[p.id] = 1;
        }
      }
    });
  }

  void _selectLowStock() {
    setState(() {
      _selectedQuantities.clear();
      for (final p in widget.initialProducts) {
        if (p.isLowStock || p.isOutOfStock) {
           if (p.barcode != null && p.barcode!.isNotEmpty) {
              _selectedQuantities[p.id] = 1;
           }
        }
      }
    });
  }

  Future<void> _handlePrint() async {
    if (_selectedQuantities.isEmpty) return;

    final List<Product> toPrint = [];
    for (final entry in _selectedQuantities.entries) {
      final product = widget.initialProducts.firstWhere((p) => p.id == entry.key);
      for (int i = 0; i < entry.value; i++) {
        toPrint.add(product);
      }
    }

    try {
      await ref.read(inventoryAutomationServiceProvider).printBarcodeLabels(toPrint);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filtered = widget.initialProducts.where((p) {
      final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (p.barcode?.contains(_searchQuery) ?? false) ||
          (p.reference?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      return matchesSearch && p.barcode != null && p.barcode!.isNotEmpty;
    }).toList();

    return EnterpriseWidgets.buildPremiumDialog(
      context,
      title: "Générateur d'Étiquettes",
      icon: FluentIcons.barcode_scanner_24_regular,
      width: 600,
      child: Column(
        children: [
          // Toolbar avec actions rapides
          Row(
            children: [
                _QuickActionBtn(
                  label: "Toute la liste",
                  icon: FluentIcons.checkbox_checked_24_regular,
                  onTap: _selectAll,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                _QuickActionBtn(
                  label: "Alertes Stock",
                  icon: FluentIcons.warning_24_regular,
                  onTap: _selectLowStock,
                  color: Colors.orange,
                ),
                const SizedBox(width: 12),
                _QuickActionBtn(
                  label: "Vider",
                  icon: FluentIcons.dismiss_24_regular,
                  onTap: () => setState(() => _selectedQuantities.clear()),
                  color: Colors.red,
                ),
            ],
          ),
          const SizedBox(height: 20),
          // Barre de recherche
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: "Rechercher un produit ou un code...",
              prefixIcon: const Icon(FluentIcons.search_24_regular, size: 20),
              filled: true,
              fillColor: isDark ? const Color(0xFF16181D) : const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          // Liste des produits
          Container(
            height: 350,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF16181D) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB)),
            ),
            child: filtered.isEmpty
                ? const Center(child: Text("Aucun produit correspondant", style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB)),
                    itemBuilder: (ctx, i) {
                      final p = filtered[i];
                      final isSelected = _selectedQuantities.containsKey(p.id);
                      final qty = _selectedQuantities[p.id] ?? 0;

                      return ListTile(
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        leading: Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleSelection(p),
                          activeColor: theme.colorScheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(p.name, 
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StockBadge(stock: p.quantity.toDouble(), minStock: p.alertThreshold.toDouble()),
                          ],
                        ),
                        subtitle: Text(p.barcode ?? p.reference ?? "Pas de code", 
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        trailing: isSelected
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _QtyBtn(icon: FluentIcons.subtract_16_regular, onTap: () => _setQuantity(p, qty - 1)),
                                    Container(
                                      constraints: const BoxConstraints(minWidth: 24),
                                      alignment: Alignment.center,
                                      child: Text("$qty", style: TextStyle(
                                        fontWeight: FontWeight.w900, 
                                        color: theme.colorScheme.primary,
                                        fontSize: 13,
                                      )),
                                    ),
                                    _QtyBtn(icon: FluentIcons.add_16_regular, onTap: () => _setQuantity(p, qty + 1)),
                                  ],
                                ),
                              )
                            : null,
                        onTap: () => _toggleSelection(p),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          // Info Format
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.amber.withValues(alpha: 0.15),
                  Colors.amber.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(FluentIcons.print_24_regular, color: Colors.amber, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "CONFIGURATION D'IMPRESSION",
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.amber, letterSpacing: 0.5),
                      ),
                      Text(
                        ref.watch(shopSettingsProvider).value?.labelFormat == LabelPrintingFormat.a4Sheets 
                            ? "Planches A4 multi-colonnes (Optimal)" 
                            : "Étiquette Unique (Rouleau Thermique)",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Résumé
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(FluentIcons.info_24_regular, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Total : ${_selectedQuantities.length} produits • ${_selectedQuantities.values.fold(0, (a, b) => a + b)} étiquettes",
                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text("Annuler"),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _selectedQuantities.isEmpty ? null : _handlePrint,
          icon: const Icon(FluentIcons.print_24_regular, size: 18),
          label: const Text("Générer PDF"),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _QuickActionBtn({required this.label, required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            color: color.withValues(alpha: 0.05),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final double stock;
  final double minStock;
  const _StockBadge({required this.stock, required this.minStock});

  @override
  Widget build(BuildContext context) {
    final bool isLow = stock <= minStock && stock > 0;
    final bool isCritical = stock <= 0;
    final Color color = isCritical ? Colors.red : (isLow ? Colors.orange : Colors.green);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        "${stock.toInt()}",
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 14),
      ),
    );
  }
}
