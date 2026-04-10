import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/features/inventory/domain/models/stock_movement.dart';
import 'package:danaya_plus/features/inventory/providers/product_providers.dart';
import 'package:danaya_plus/features/inventory/providers/stock_movement_providers.dart';
import 'package:danaya_plus/features/inventory/providers/warehouse_providers.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/auth/domain/models/user.dart';

class StockMovementScreen extends ConsumerStatefulWidget {
  const StockMovementScreen({super.key});

  @override
  ConsumerState<StockMovementScreen> createState() => _StockMovementScreenState();
}

class _StockMovementScreenState extends ConsumerState<StockMovementScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final movementsAsync = ref.watch(stockMovementsProvider);
    final productsAsync = ref.watch(productListProvider);
    final user = ref.watch(authServiceProvider).value;
    
    final isGlobalRole = user?.role == UserRole.admin || 
                         user?.role == UserRole.manager || 
                         user?.role == UserRole.adminPlus;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── HEADER PREMIUM ──
            EnterpriseWidgets.buildPremiumHeader(
              context,
              title: isGlobalRole ? "Logistique Globale" : "Ma Logistique",
              subtitle: isGlobalRole 
                ? "Historique complet de toutes les entrées, sorties et transferts entrepôts."
                : "Historique de vos propres mouvements de stock et ventes.",
              icon: FluentIcons.arrow_swap_24_regular,
              trailing: Row(
                children: [
                   _buildWarehouseSelector(context, ref),
                   const SizedBox(width: 12),
                   OutlinedButton.icon(
                    onPressed: () => _handleExport(context, movementsAsync, productsAsync),
                    icon: const Icon(FluentIcons.arrow_download_24_regular, size: 20),
                    label: const Text("Exporter"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── FILTERS ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16181D) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB)),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: "Filtrer par nom de produit ou motif...",
                  prefixIcon: const Icon(FluentIcons.search_20_regular, size: 18),
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── TABLE DES MOUVEMENTS ──
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB)),
                ),
                child: movementsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text("Erreur: $err")),
                  data: (movements) {
                    return productsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => const SizedBox(),
                      data: (products) {
                        final filteredMovements = movements.where((m) {
                          final p = products.firstWhere((prod) => prod.id == m.productId, orElse: () => products.first);
                          final matchesProduct = p.name.toLowerCase().contains(_searchQuery.toLowerCase());
                          final matchesReason = m.reason.toLowerCase().contains(_searchQuery.toLowerCase());
                          return matchesProduct || matchesReason;
                        }).toList();

                        if (filteredMovements.isEmpty) {
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(FluentIcons.history_24_regular, size: 48, color: Colors.grey),
                                SizedBox(height: 16),
                                Text("Aucun mouvement trouvé.", style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          );
                        }

                        return ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SingleChildScrollView(
                            child: DataTable(
                              horizontalMargin: 20,
                              headingRowHeight: 48,
                              dataRowMaxHeight: 52,
                              dataRowMinHeight: 52,
                              headingTextStyle: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                letterSpacing: 1.2,
                              ),
                              columns: [
                                const DataColumn(label: Text("DATE & HEURE")),
                                const DataColumn(label: Text("PRODUIT")),
                                const DataColumn(label: Text("OPÉRATION")),
                                const DataColumn(label: Text("QUANTITÉ")),
                                const DataColumn(label: Text("MOTIF / RÉFÉRENCE")),
                                if (isGlobalRole) const DataColumn(label: Text("OPÉRATEUR")),
                              ],
                              rows: filteredMovements.map((m) {
                                final product = products.firstWhere((p) => p.id == m.productId, 
                                  orElse: () => products.first);
                                
                                final typeColor = m.type == MovementType.IN 
                                    ? const Color(0xFF10B981) 
                                    : (m.type == MovementType.OUT ? theme.colorScheme.error 
                                    : (m.type == MovementType.TRANSFER ? Colors.blue : Colors.orange));
                                
                                return DataRow(
                                  key: ValueKey(m.id),
                                  cells: [
                                    DataCell(Text(DateFormatter.formatDateTime(m.date), style: const TextStyle(fontSize: 13))),
                                    DataCell(Text(product.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14))),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: typeColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          m.type.label.toUpperCase(),
                                          style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.w900),
                                        ),
                                      ),
                                    ),
                                    DataCell(Text("${m.type == MovementType.OUT ? '-' : '+'}${DateFormatter.formatQuantity(m.quantity)}", 
                                      style: TextStyle(color: typeColor, fontWeight: FontWeight.w900, fontSize: 15))),
                                    DataCell(Text(m.reason, style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic, fontSize: 13))),
                                    if (isGlobalRole) 
                                      DataCell(
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 12,
                                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                              child: Text(
                                                (m.userName ?? "A")[0].toUpperCase(),
                                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(m.userName ?? "Admin", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleExport(BuildContext context, AsyncValue<List<StockMovement>> movementsAsync, AsyncValue<List<dynamic>> productsAsync) async {
    final movements = movementsAsync.value;
    final products = productsAsync.value;
    
    if (movements == null || movements.isEmpty || products == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aucune donnée à exporter.")));
      return;
    }

    try {
      // Préparation du contenu CSV
      String csv = "Date;Produit;Operation;Quantite;Motif;Operateur\n";
      for (var m in movements) {
        final p = products.firstWhere((prod) => prod.id == m.productId, orElse: () => products.first);
        final dateStr = DateFormatter.formatDateTime(m.date);
        final typeStr = m.type.label.toUpperCase();
        final qtyStr = "${m.type == MovementType.OUT ? '-' : '+'}${DateFormatter.formatQuantity(m.quantity)}";
        
        csv += "$dateStr;${p.name};$typeStr;$qtyStr;${m.reason};${m.userName ?? 'Admin'}\n";
      }

      // Demander l'emplacement de sauvegarde
      final shopName = ref.read(shopSettingsProvider).value?.name.replaceAll(RegExp(r'[^\w\s-]'), '_') ?? 'Danaya';
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Exporter l\'historique des mouvements',
        fileName: 'Mouvements_Stock_$shopName.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (path != null) {
        String finalPath = path;
        if (!finalPath.toLowerCase().endsWith('.csv')) {
          finalPath += '.csv';
        }
        
        final file = File(finalPath);
        await file.writeAsString(csv);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Fichier CSV exporté avec succès !"),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: "OUVRIR",
                textColor: Colors.white,
                onPressed: () => OpenFilex.open(finalPath),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur lors de l'exportation : $e")));
    }
  }

  Widget _buildWarehouseSelector(BuildContext context, WidgetRef ref) {
    final warehousesAsync = ref.watch(warehouseListProvider);
    final selectedWarehouseId = ref.watch(selectedWarehouseIdProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2128) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: warehousesAsync.when(
          data: (warehouses) => DropdownButton<String?>(
            value: selectedWarehouseId,
            hint: const Text("Tous les entrepôts", style: TextStyle(fontSize: 13)),
            onChanged: (id) => ref.read(selectedWarehouseIdProvider.notifier).setId(id),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text("🌍 Tous les entrepôts", style: TextStyle(fontSize: 13)),
              ),
              ...warehouses.map((w) => DropdownMenuItem<String?>(
                value: w.id,
                child: Text("${w.isDefault ? '🏠 ' : '📦 '}${w.name}", style: const TextStyle(fontSize: 13)),
              )),
            ],
            icon: const Icon(FluentIcons.chevron_down_20_regular, size: 16),
            dropdownColor: isDark ? const Color(0xFF1E2128) : Colors.white,
          ),
          loading: () => const SizedBox(width: 100, child: LinearProgressIndicator()),
          error: (_, __) => const Icon(Icons.error, size: 16),
        ),
      ),
    );
  }
}
