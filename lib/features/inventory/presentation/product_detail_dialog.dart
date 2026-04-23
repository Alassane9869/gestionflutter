import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/inventory/domain/models/product.dart';
import 'package:danaya_plus/features/inventory/domain/models/stock_movement.dart';
import 'package:danaya_plus/features/inventory/providers/stock_movement_providers.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/core/utils/image_resolver.dart';
import 'package:danaya_plus/features/inventory/presentation/product_form_dialog.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';

class ProductDetailDialog extends ConsumerWidget {
  final Product product;

  const ProductDetailDialog({super.key, required this.product});

  void _editProduct(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (_) => ProductFormDialog(product: product),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(shopSettingsProvider).value;
    final movementsAsync = ref.watch(productMovementsProvider(product.id));

    return EnterpriseWidgets.buildPremiumDialog(
      context,
      title: "Fiche Article",
      icon: FluentIcons.apps_list_24_regular,
      width: 600, // Largeur resserrée
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER COMPACT ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image plus petite et stylisée
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2028) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1)),
                  image: product.imagePath != null
                      ? DecorationImage(
                          image: ImageResolver.getProductImage(product.imagePath, settings), 
                          fit: BoxFit.contain,
                        )
                      : null,
                ),
                child: product.imagePath == null
                    ? Icon(FluentIcons.image_24_regular, size: 32, color: Colors.grey.withValues(alpha: 0.4))
                    : null,
              ),
              const SizedBox(width: 20),
              // Infos principales denses
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.category ?? "Non catégorisé",
                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildCompactBadge(
                          context,
                          label: product.isOutOfStock ? "RUPTURE" : (product.isLowStock ? "STOCK BAS" : "EN STOCK"),
                          color: product.isOutOfStock ? Colors.red : (product.isLowStock ? Colors.orange : Colors.green),
                        ),
                        const SizedBox(width: 8),
                        _buildCompactBadge(
                          context,
                          label: product.isService ? "SERVICE" : "PHYSIQUE",
                          color: Colors.blueGrey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // --- FINANCES DENSES (Horizontales) ---
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF16181D) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                _buildTinyStat(context, "PRIX VENTE", ref.fmt(product.sellingPrice), Colors.blue),
                _buildStatDivider(),
                _buildTinyStat(context, "MARGE", "${product.marginPercent.toStringAsFixed(1)}%", Colors.green, sub: "+${ref.fmt(product.margin)}"),
                _buildStatDivider(),
                _buildTinyStat(context, "VALEUR STOCK", ref.fmt(product.stockValue), Colors.amber),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // --- GRILLE DE DÉTAILS DENSE ---
          const Text("DÉTAILS TECHNIQUES", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.grey)),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 20,
            childAspectRatio: 5,
            children: [
              _buildDetailRow("RÉFÉRENCE", product.reference ?? "—", FluentIcons.number_symbol_20_regular),
              _buildDetailRow("CODE BARRES", product.barcode ?? "—", FluentIcons.barcode_scanner_20_regular),
              _buildDetailRow("UNITÉ", product.unit ?? "Pièce", FluentIcons.ruler_20_regular),
              _buildDetailRow("STOCK MINIMUM", DateFormatter.formatQuantity(product.alertThreshold), FluentIcons.warning_20_regular),
            ],
          ),

          if (product.location != null && product.location!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildDetailRow("LOCALISATION", product.location!, FluentIcons.location_20_regular),
          ],

          const SizedBox(height: 20),

          // --- DESCRIPTION COMPACTE ---
          if (product.description != null && product.description!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                product.description!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // --- MINI HISTORY DENSE ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("DERNIERS MOUVEMENTS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.grey)),
              TextButton(
                onPressed: () {
                  // TODO: Ouvrir historique complet
                },
                child: const Text("Voir tout", style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          movementsAsync.when(
            data: (movements) {
              final recent = movements.take(2).toList();
              if (recent.isEmpty) return const Text("Aucun mouvement", style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic));
              return Column(
                children: recent.map((m) => _buildTinyMovementRow(context, m)).toList(),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("FERMER"),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () => _editProduct(context),
          icon: const Icon(FluentIcons.edit_20_regular, size: 16),
          label: const Text("MODIFIER", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildCompactBadge(BuildContext context, {required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 9),
      ),
    );
  }

  Widget _buildTinyStat(BuildContext context, String label, String value, Color color, {String? sub}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey.shade500)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
          if (sub != null) Text(sub, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 30,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.grey.withValues(alpha: 0.1),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildTinyMovementRow(BuildContext context, StockMovement m) {
    final typeColor = m.type == MovementType.IN ? Colors.green : (m.type == MovementType.OUT ? Colors.red : Colors.orange);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(m.type == MovementType.IN ? FluentIcons.add_12_filled : FluentIcons.subtract_12_filled, color: typeColor, size: 12),
          const SizedBox(width: 8),
          Text(
            "${m.type == MovementType.IN ? '+' : '-'}${DateFormatter.formatQuantity(m.quantity)}",
            style: TextStyle(fontWeight: FontWeight.w900, color: typeColor, fontSize: 11),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(m.reason, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
          Text(DateFormatter.formatDateTime(m.date), style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}
