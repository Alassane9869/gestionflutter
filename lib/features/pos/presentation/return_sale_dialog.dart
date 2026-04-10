import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/theme/app_theme.dart';
import 'package:danaya_plus/features/pos/providers/sales_history_providers.dart';
import 'package:danaya_plus/features/pos/providers/pos_providers.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';

class ReturnSaleDialog extends ConsumerStatefulWidget {
  final SaleWithDetails saleData;

  const ReturnSaleDialog({super.key, required this.saleData});

  @override
  ConsumerState<ReturnSaleDialog> createState() => _ReturnSaleDialogState();
}

class _ReturnSaleDialogState extends ConsumerState<ReturnSaleDialog> {
  final Map<String, double> _returnQuantities = {};
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    for (var itemWithProd in widget.saleData.items) {
      final pid = itemWithProd.item.productId ?? 'custom_${itemWithProd.item.id}';
      _returnQuantities[pid] = 0.0;
    }
  }

  void _increment(String productId, double maxReturnable) {
    setState(() {
      final current = _returnQuantities[productId] ?? 0.0;
      if (current < maxReturnable) {
        _returnQuantities[productId] = (current + 1.0).clamp(0.0, maxReturnable);
      }
    });
  }

  void _decrement(String productId) {
    setState(() {
      final current = _returnQuantities[productId] ?? 0.0;
      if (current > 0) {
        _returnQuantities[productId] = (current - 1.0).clamp(0.0, double.infinity);
      }
    });
  }

  double get _totalRefundAmount {
    double total = 0.0;
    for (var itemWithProd in widget.saleData.items) {
      final pid = itemWithProd.item.productId ?? 'custom_${itemWithProd.item.id}';
      final qty = _returnQuantities[pid] ?? 0;
      final discountPercent = itemWithProd.item.discountPercent;
      final netPrice = itemWithProd.item.unitPrice * (1 - discountPercent / 100);
      total += qty * netPrice;
    }
    return total;
  }

  void _showManualQtyDialog(String productId, double current, double maxReturnable) {
    final controller = TextEditingController(text: DateFormatter.formatQuantity(current));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Saisir la quantité"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Entrez la quantité précise à retourner :"),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: "Quantité",
                hintText: "Maximum : ${DateFormatter.formatQuantity(maxReturnable)}",
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          FilledButton(
            onPressed: () {
              final text = controller.text.replaceAll(',', '.');
              final val = double.tryParse(text);
              if (val != null) {
                setState(() {
                  _returnQuantities[productId] = val.clamp(0.0, maxReturnable);
                });
                Navigator.pop(context);
              }
            },
            child: const Text("Confirmer"),
          ),
        ],
      ),
    );
  }

  Future<void> _processReturn() async {
    final hasReturns = _returnQuantities.values.any((qty) => qty > 0);
    if (!hasReturns) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Veuillez sélectionner au moins un article à retourner.")));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await ref.read(posProvider).processReturn(
        saleId: widget.saleData.sale.id,
        returnedQuantities: _returnQuantities,
      );

      setState(() => _isProcessing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Retour enregistré avec succès."), backgroundColor: Colors.green));
        ref.invalidate(salesHistoryProvider);
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E2128) : Colors.white,
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.warningClr.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(FluentIcons.arrow_hook_down_left_24_regular, color: AppTheme.warningClr),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Retour Client", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      Text("Vente #${widget.saleData.sale.id.substring(0, 8).toUpperCase()}", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(FluentIcons.dismiss_24_regular), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              decoration: AppTheme.strictBorder(isDark).copyWith(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.saleData.items.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB)),
                itemBuilder: (context, index) {
                  final itemData = widget.saleData.items[index];
                  final maxReturnable = itemData.item.quantity - itemData.item.returnedQuantity;
                  final pid = itemData.item.productId ?? 'custom_${itemData.item.id}';
                  final currentReturn = _returnQuantities[pid] ?? 0.0;

                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(itemData.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text("${ref.fmt(itemData.item.unitPrice)}/u  •  Achetés: ${DateFormatter.formatQuantity(itemData.item.quantity)} (Déjà rendus: ${DateFormatter.formatQuantity(itemData.item.returnedQuantity)})", 
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                            ],
                          ),
                        ),
                        if (maxReturnable > 0)
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(FluentIcons.subtract_circle_24_regular), 
                                onPressed: currentReturn > 0 ? () => _decrement(pid) : null,
                                color: currentReturn > 0 ? AppTheme.errorClr : Colors.grey,
                              ),
                              InkWell(
                                onTap: () => _showManualQtyDialog(pid, currentReturn, maxReturnable),
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  width: 45,
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    DateFormatter.formatQuantity(currentReturn), 
                                    textAlign: TextAlign.center, 
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(FluentIcons.add_circle_24_regular), 
                                onPressed: currentReturn < maxReturnable ? () => _increment(pid, maxReturnable) : null,
                                color: currentReturn < maxReturnable ? AppTheme.successClr : Colors.grey,
                              ),
                            ],
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                            child: const Text("Entièrement rendu", style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.warningClr.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Montant total à rembourser :", style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.warningClr)),
                      if (widget.saleData.sale.discountAmount > 0)
                        Text("(Remises incluses)", style: TextStyle(fontSize: 11, color: AppTheme.warningClr.withValues(alpha: 0.7))),
                    ],
                  ),
                  Text(ref.fmt(_totalRefundAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.warningClr)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _isProcessing || _totalRefundAmount == 0 ? null : _processReturn,
                icon: _isProcessing ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Icon(FluentIcons.arrow_hook_down_left_24_filled),
                label: Text(_isProcessing ? "Traitement..." : "Confirmer le Retour", style: const TextStyle(fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.warningClr, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
