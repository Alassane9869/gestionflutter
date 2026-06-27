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
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/inventory/presentation/product_movement_dialog.dart';

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
    
    final user = ref.watch(authServiceProvider).value;
    final canSeeMargin = user?.isAdmin == true || user?.isManager == true;

    return EnterpriseWidgets.buildPremiumDialog(
      context,
      title: "Fiche Article",
      icon: FluentIcons.apps_list_24_regular,
      width: 600,
      child: SingleChildScrollView(
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
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF070709) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
                    width: 1,
                  ),
                  image: product.imagePath != null
                      ? DecorationImage(
                          image: ImageResolver.getProductImage(product.imagePath, settings), 
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: product.imagePath == null
                    ? Icon(FluentIcons.image_24_regular, size: 32, color: isDark ? Colors.grey.shade700 : Colors.grey.shade400)
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
                      style: TextStyle(
                        fontWeight: FontWeight.w900, 
                        fontSize: 18, 
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.category ?? "Non catégorisé",
                      style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildCompactBadge(
                          context,
                          label: product.isOutOfStock ? "RUPTURE" : (product.isLowStock ? "STOCK BAS" : "EN STOCK"),
                          color: product.isOutOfStock ? const Color(0xFFEF4444) : (product.isLowStock ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                        ),
                        const SizedBox(width: 8),
                        _buildCompactBadge(
                          context,
                          label: product.isService ? "SERVICE" : "PHYSIQUE",
                          color: isDark ? Colors.blueAccent : Colors.blue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // --- FINANCES DENSES (Horizontales) ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200),
            ),
            child: Row(
              children: [
                _buildTinyStat(context, "PRIX VENTE", ref.fmt(product.sellingPrice), isDark ? Colors.blueAccent : Colors.blue),
                if (canSeeMargin) ...[
                  _buildStatDivider(isDark),
                  _buildTinyStat(context, "MARGE", "${product.marginPercent.toStringAsFixed(1)}%", isDark ? const Color(0xFF34D399) : Colors.green, sub: "+${ref.fmt(product.margin)}"),
                  _buildStatDivider(isDark),
                  _buildTinyStat(context, "VALEUR STOCK", ref.fmt(product.stockValue), isDark ? const Color(0xFFFBBF24) : Colors.amber.shade700),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // --- GRILLE DE DÉTAILS DENSE ---
          Text("DÉTAILS TECHNIQUES", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? theme.colorScheme.surface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200),
            ),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 20,
              childAspectRatio: 6,
              children: [
                _buildDetailRow("RÉFÉRENCE", product.reference ?? "—", FluentIcons.number_symbol_20_regular, isDark),
                _buildDetailRow("CODE BARRES", product.barcode ?? "—", FluentIcons.barcode_scanner_20_regular, isDark),
                _buildDetailRow("UNITÉ", product.unit ?? "Pièce", FluentIcons.ruler_20_regular, isDark),
                _buildDetailRow("STOCK MINIMUM", DateFormatter.formatQuantity(product.alertThreshold), FluentIcons.warning_20_regular, isDark),
              ],
            ),
          ),

          if (product.location != null && product.location!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? theme.colorScheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200),
              ),
              child: _buildDetailRow("LOCALISATION", product.location!, FluentIcons.location_20_regular, isDark),
            ),
          ],

          const SizedBox(height: 24),

          // --- DESCRIPTION COMPACTE ---
          if (product.description != null && product.description!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200),
              ),
              child: Text(
                product.description!,
                style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700, height: 1.5),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 24),
          ],

          // --- MINI HISTORY DENSE ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("DERNIERS MOUVEMENTS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Fermer la fiche article
                  showDialog(
                    context: context,
                    builder: (_) => ProductMovementHistoryDialog(product: product),
                  );
                },
                child: const Text("Voir tout", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? theme.colorScheme.surface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200),
            ),
            child: movementsAsync.when(
              data: (movements) {
                final recent = movements.take(2).toList();
                if (recent.isEmpty) return const Center(child: Text("Aucun mouvement", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)));
                return Column(
                  children: recent.map((m) => _buildTinyMovementRow(context, m, isDark)).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("FERMER", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () => _editProduct(context),
          icon: const Icon(FluentIcons.edit_20_regular, size: 16),
          label: const Text("MODIFIER", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactBadge(BuildContext context, {required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildTinyStat(BuildContext context, String label, String value, Color color, {String? sub}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey.shade500, letterSpacing: 1.0)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.8))),
          ],
        ],
      ),
    );
  }

  Widget _buildStatDivider(bool isDark) {
    return Container(
      height: 40,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300,
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: isDark ? Colors.grey.shade600 : Colors.grey.shade500, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTinyMovementRow(BuildContext context, StockMovement m, bool isDark) {
    final typeColor = m.type == MovementType.IN ? const Color(0xFF10B981) : (m.type == MovementType.OUT ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(m.type == MovementType.IN ? FluentIcons.add_12_filled : FluentIcons.subtract_12_filled, color: typeColor, size: 12),
          ),
          const SizedBox(width: 12),
          Text(
            "${m.type == MovementType.IN ? '+' : '-'}${DateFormatter.formatQuantity(m.quantity)}",
            style: TextStyle(fontWeight: FontWeight.w900, color: typeColor, fontSize: 13),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(m.reason, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis)),
          Text(DateFormatter.formatDateTime(m.date), style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
        ],
      ),
    );
  }
}
