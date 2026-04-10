import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/inventory/domain/models/product.dart';
import 'package:danaya_plus/features/inventory/providers/warehouse_providers.dart';
import 'package:danaya_plus/features/inventory/providers/product_providers.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';

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
    // Par défaut, l'entrepôt source est celui sélectionné dans la liste si présent
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

    return EnterpriseWidgets.buildPremiumDialog(
      context,
      title: "Transfert de Stock",
      icon: FluentIcons.arrow_swap_24_regular,
      actions: const [],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Déplacez des articles entre vos entrepôts de manière sécurisée.",
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          
          // Entrepôt Source
          const Text("De (Source)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          warehousesAsync.when(
            data: (list) => DropdownButtonFormField<String>(
              initialValue: _fromWarehouseId,
              items: list.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
              onChanged: (v) => setState(() => _fromWarehouseId = v),
              decoration: const InputDecoration(hintText: "Sélectionnez l'entrepôt source"),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text("Erreur"),
          ),
          const SizedBox(height: 16),

          // Entrepôt Destination
          const Text("Vers (Destination)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          warehousesAsync.when(
            data: (list) => DropdownButtonFormField<String>(
              initialValue: _toWarehouseId,
              items: list.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
              onChanged: (v) => setState(() => _toWarehouseId = v),
              decoration: const InputDecoration(hintText: "Sélectionnez l'entrepôt de destination"),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text("Erreur"),
          ),
          const SizedBox(height: 16),

          // Produit
          const Text("Produit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          productsAsync.when(
            data: (list) => DropdownButtonFormField<Product>(
              initialValue: _selectedProduct,
              items: list.map((p) => DropdownMenuItem(value: p, child: Text("${p.name} (Dispo: ${DateFormatter.formatQuantity(p.quantity)})"))).toList(),
              onChanged: (v) => setState(() => _selectedProduct = v),
              decoration: const InputDecoration(hintText: "Sélectionnez un produit"),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text("Erreur"),
          ),
          const SizedBox(height: 16),

          // Quantité
          const Text("Quantité à transférer", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          TextField(
            controller: _qtyController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: "Ex: 10.5"),
          ),
          
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _handleTransfer,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: theme.colorScheme.primary,
              ),
              child: _isSubmitting 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text("Confirmer le Transfert"),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleTransfer() async {
    if (_fromWarehouseId == null || _toWarehouseId == null || _selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Veuillez remplir tous les champs")));
      return;
    }
    if (_fromWarehouseId == _toWarehouseId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Les entrepôts doivent être différents")));
      return;
    }
    
    final qty = double.tryParse(_qtyController.text) ?? 0.0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Quantité invalide")));
      return;
    }

    setState(() => _isSubmitting = true);
    
    try {
      await ref.read(warehouseTransferProvider).transferStock(
        productId: _selectedProduct!.id,
        fromWarehouseId: _fromWarehouseId!,
        toWarehouseId: _toWarehouseId!,
        quantity: qty,
      );
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Transfert réussi avec succès !"),
          backgroundColor: Colors.green,
        ));
        // Refresh product list to see updated stock
        ref.read(productListProvider.notifier).refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
