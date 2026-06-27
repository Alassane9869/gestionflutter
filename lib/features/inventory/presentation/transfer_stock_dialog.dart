import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/inventory/domain/models/product.dart';
import 'package:danaya_plus/features/inventory/providers/warehouse_providers.dart';
import 'package:danaya_plus/features/inventory/providers/product_providers.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/inventory/application/stock_transfer_service.dart';

class TransferStockDialog extends ConsumerStatefulWidget {
  final Product? initialProduct;
  const TransferStockDialog({super.key, this.initialProduct});

  @override
  ConsumerState<TransferStockDialog> createState() => _TransferStockDialogState();
}

class _TransferStockDialogState extends ConsumerState<TransferStockDialog> {
  String? _fromWarehouseId;
  String? _toWarehouseId;
  Product? _selectedProduct;
  final _qtyController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.initialProduct;
    // Par défaut, l'entrepôt source est celui actuellement sélectionné dans le filtre de l'écran principal
    _fromWarehouseId = ref.read(selectedWarehouseIdProvider);
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final warehousesAsync = ref.watch(warehouseListProvider);
    final productsAsync = ref.watch(productListProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return EnterpriseWidgets.buildPremiumDialog(
      context,
      title: "Transfert Inter-Entrepôts",
      icon: FluentIcons.arrow_swap_24_regular,
      width: 600,
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text("Annuler"),
        ),
        const SizedBox(width: 12),
        _isSubmitting
            ? const SizedBox(width: 100, child: LinearProgressIndicator())
            : FilledButton.icon(
                onPressed: _handleTransfer,
                icon: const Icon(FluentIcons.checkmark_24_filled, size: 18),
                label: const Text("Confirmer le Transfert"),
              ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // BENTO HEADER: SECURE TRANSFER
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.blue.withValues(alpha: 0.05) : Colors.blue.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(FluentIcons.shield_24_regular, color: Colors.blue, size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("TRANSFERT SÉCURISÉ", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2)),
                      Text("Mouvement d'inventaire inter-entrepôts avec traçabilité complète.", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ORIGIN & DESTINATION
          Row(
            children: [
              Expanded(
                child: warehousesAsync.when(
                  data: (list) => EnterpriseWidgets.buildPremiumDropdown<String>(
                    label: "ENTREPÔT SOURCE",
                    value: list.any((w) => w.id == _fromWarehouseId) ? _fromWarehouseId : null,
                    icon: FluentIcons.arrow_right_24_regular,
                    items: list.map((w) => w.id).toList(),
                    itemLabel: (id) => list.firstWhere((w) => w.id == id).name,
                    onChanged: (id) => setState(() => _fromWarehouseId = id),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Icon(Icons.error),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Icon(FluentIcons.arrow_right_24_regular, color: Colors.grey, size: 16),
              ),
              Expanded(
                child: warehousesAsync.when(
                  data: (list) => EnterpriseWidgets.buildPremiumDropdown<String>(
                    label: "DESTINATION",
                    value: list.any((w) => w.id == _toWarehouseId) ? _toWarehouseId : null,
                    icon: FluentIcons.arrow_right_24_regular,
                    items: list.map((w) => w.id).toList(),
                    itemLabel: (id) => list.firstWhere((w) => w.id == id).name,
                    onChanged: (id) => setState(() => _toWarehouseId = id),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Icon(Icons.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // PRODUCT SELECTION
          productsAsync.when(
            data: (products) => EnterpriseWidgets.buildPremiumDropdown<Product>(
              label: "ARTICLE À TRANSFÉRER",
              value: _selectedProduct != null && products.any((p) => p.id == _selectedProduct!.id) 
                  ? products.firstWhere((p) => p.id == _selectedProduct!.id) 
                  : null,
              icon: FluentIcons.box_24_regular,
              items: products,
              itemLabel: (p) => "${p.name} (${DateFormatter.formatQuantity(p.quantity)} dispos)",
              onChanged: (v) => setState(() => _selectedProduct = v),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text("Erreur"),
          ),
          const SizedBox(height: 20),

          // QUANTITY INPUT
          EnterpriseWidgets.buildPremiumTextField(
            context,
            ctrl: _qtyController,
            label: "QUANTITÉ À DÉPLACER",
            hint: "0",
            icon: FluentIcons.number_symbol_24_regular,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            tooltip: "La quantité sera déduite de la source et ajoutée à la destination.",
          ),
          
          if (_selectedProduct != null && _fromWarehouseId != null) ...[
             const SizedBox(height: 16),
             Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(
                 color: isDark ? Colors.blue.withValues(alpha: 0.1) : const Color(0xFFF3F4F6),
                 borderRadius: BorderRadius.circular(12),
                 border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
               ),
               child: Row(
                 children: [
                   const Icon(FluentIcons.info_20_regular, size: 16, color: Colors.blue),
                   const SizedBox(width: 12),
                   Expanded(
                     child: Text(
                       "Le stock sera débité instantanément après confirmation.",
                       style: TextStyle(fontSize: 11, color: isDark ? Colors.blue.shade200 : Colors.blue.shade800),
                     ),
                   ),
                 ],
               ),
             ),
          ],
        ],
      ),
    );
  }


  Future<void> _handleTransfer() async {
    if (_fromWarehouseId == null || _toWarehouseId == null || _selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Veuillez sélectionner les entrepôts et le produit."),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    if (_fromWarehouseId == _toWarehouseId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("L'entrepôt de destination doit être différent de la source."),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final qty = double.tryParse(_qtyController.text) ?? 0.0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("La quantité doit être supérieure à zéro."),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(stockTransferServiceProvider).transferStock(
            productId: _selectedProduct!.id,
            fromWarehouseId: _fromWarehouseId!,
            toWarehouseId: _toWarehouseId!,
            quantity: qty,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text("Transfert de $qty ${_selectedProduct!.name} réussi !")),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        // Refresh local lists
        ref.invalidate(productListProvider);
        ref.invalidate(warehouseListProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Erreur de transfert : $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
