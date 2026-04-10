import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/srm/domain/models/supplier.dart';
import 'package:danaya_plus/features/srm/domain/models/purchase_order.dart';
import 'package:danaya_plus/features/srm/providers/purchase_provider.dart';
import 'package:danaya_plus/features/srm/providers/supplier_providers.dart';
import 'package:danaya_plus/features/srm/application/purchase_pdf_service.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/features/inventory/providers/product_providers.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';

class PurchaseDetailDialog extends ConsumerWidget {
  final PurchaseOrder order;

  const PurchaseDetailDialog({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(purchaseItemsProvider(order.id));
    final suppliersAsync = ref.watch(supplierListProvider);
    final productsAsync = ref.watch(productListProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        height: 500,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16181D) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Icon(FluentIcons.receipt_20_regular, color: Colors.blue, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Bon : ${order.reference}",
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          "Le ${DateFormatter.formatCompact(order.date)}",
                          style: const TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(FluentIcons.dismiss_16_regular, size: 16),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // CONTENT
            Expanded(
              child: itemsAsync.when(
                data: (items) {
                  return productsAsync.when(
                    data: (products) {
                      return ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // FINANCIAL SUMMARY GRID (DENSE)
                          Row(
                            children: [
                              _buildMiniMetric("TOTAL", ref.fmt(order.totalAmount), Colors.blue),
                              const SizedBox(width: 8),
                              _buildMiniMetric("PAYÉ", ref.fmt(order.amountPaid), Colors.green),
                              const SizedBox(width: 8),
                              _buildMiniMetric("RESTE", ref.fmt(order.totalAmount - order.amountPaid), order.isCredit ? Colors.orange : Colors.grey),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // ITEMS TABLE
                          const Text("ARTICLES", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey)),
                          const SizedBox(height: 8),
                          for (int i = 0; i < items.length; i++) ...[
                            _buildItemRow(ref, items[i], products, i == items.length - 1),
                            if (i < items.length - 1) Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                          ],
                        ],
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, __) => Center(child: Text("Erreur produits: $e")),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, __) => Center(child: Text("Erreur items: $e")),
              ),
            ),

            // FOOTER ACTIONS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("FERMER", style: TextStyle(fontSize: 11)),
                  ),
                  const SizedBox(width: 6),
                  suppliersAsync.when(
                    data: (suppliers) {
                      final supplier = suppliers.firstWhere((s) => s.id == order.supplierId, orElse: () => Supplier(id: "??", name: "Inconnu"));
                      return FilledButton.icon(
                        onPressed: () async {
                          final settings = ref.read(shopSettingsProvider).value;
                          final items = ref.read(purchaseItemsProvider(order.id)).value;
                          final products = ref.read(productListProvider).value;
                          
                          if (settings != null && items != null && products != null) {
                            await PurchasePdfService.generateAndPrint(PurchasePdfData(
                              order: order,
                              supplier: supplier,
                              settings: settings,
                              items: items.map((i) {
                                final p = products.firstWhere((prod) => prod.id == i.productId);
                                return PurchasePdfItem(
                                  productName: p.name,
                                  quantity: i.quantity,
                                  unitCost: i.unitPrice,
                                );
                              }).toList(),
                            ));
                          }
                        },
                        icon: const Icon(FluentIcons.print_16_regular, size: 14),
                        label: const Text("IMPRIMER", style: TextStyle(fontSize: 11)),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: const Size(0, 32),
                        ),
                      );
                    },
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildMiniMetric(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildItemRow(WidgetRef ref, PurchaseOrderItem item, List<dynamic> products, bool isLast) {
    final matching = products.where((p) => p.id == item.productId);
    final product = matching.isNotEmpty ? matching.first : null;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            child: Text(product?.name ?? "Produit inconnu", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text("x${ref.qty(item.quantity)}", style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blue, fontSize: 12)),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              ref.fmt(item.quantity * item.unitPrice),
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
