import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/widgets/glass_widgets.dart';
import 'package:danaya_plus/features/inventory/domain/models/product.dart';
import 'package:danaya_plus/features/inventory/domain/models/stock_movement.dart';
import 'package:danaya_plus/features/inventory/providers/stock_movement_providers.dart';

class MovementFilterNotifier extends Notifier<MovementType?> {
  @override
  MovementType? build() => null;
  void setFilter(MovementType? type) => state = type;
}

final movementFilterProvider = NotifierProvider<MovementFilterNotifier, MovementType?>(
  MovementFilterNotifier.new,
);

class ProductMovementHistoryDialog extends ConsumerWidget {
  final Product product;

  const ProductMovementHistoryDialog({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final movementsAsync = ref.watch(productMovementsProvider(product.id));

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 750),
        child: GlassContainer(
          borderRadius: 24,
          blur: 40,
          opacity: isDark ? 0.1 : 0.6,
          color: isDark ? const Color(0xFF1A1D24) : Colors.white,
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
            width: 0.5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- HEADER ---
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(FluentIcons.history_24_regular, 
                        color: theme.colorScheme.primary, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "HISTORIQUE DES MOUVEMENTS",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatBadge(
                      context,
                      label: "STOCK ACTUEL",
                      value: DateFormatter.formatQuantity(product.quantity),
                      color: product.isOutOfStock ? Colors.red : (product.isLowStock ? Colors.orange : Colors.green),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Génération de la fiche de stock PDF en cours... (Simulé)"))
                        );
                      },
                      icon: const Icon(FluentIcons.print_20_regular, size: 18),
                      label: const Text("IMPRIMER FICHE"),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.1),
                        foregroundColor: theme.colorScheme.secondary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(FluentIcons.dismiss_24_regular),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // --- FILTERS ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      "FILTRER PAR : ",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.grey.shade500,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildFilterChip(context, "TOUS", null, ref),
                    const SizedBox(width: 8),
                    _buildFilterChip(context, "ENTRÉES", MovementType.IN, ref),
                    const SizedBox(width: 8),
                    _buildFilterChip(context, "SORTIES", MovementType.OUT, ref),
                    const SizedBox(width: 8),
                    _buildFilterChip(context, "AJUSTEMENTS", MovementType.ADJUSTMENT, ref),
                  ],
                ),
              ),

              const Divider(height: 1),

              // --- CONTENT ---
              Expanded(
                child: movementsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text("Erreur lors du chargement: $err")),
                  data: (allMovements) {
                    final filter = ref.watch(movementFilterProvider);
                    final movements = filter == null 
                        ? allMovements 
                        : allMovements.where((m) => m.type == filter).toList();

                    if (movements.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(FluentIcons.history_24_regular, 
                              size: 64, color: Colors.grey.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            Text(
                              filter == null 
                                  ? "Aucun mouvement enregistré." 
                                  : "Aucun mouvement de ce type trouvé.",
                              style: const TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          ],
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.shade50,
                            border: Border.all(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: DataTable(
                            horizontalMargin: 20,
                            headingRowHeight: 45,
                            dataRowMaxHeight: 52,
                            headingTextStyle: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              letterSpacing: 1.0,
                            ),
                            columns: const [
                              DataColumn(label: Text("DATE & HEURE")),
                              DataColumn(label: Text("OPÉRATION")),
                              DataColumn(label: Text("QTÉ")),
                              DataColumn(label: Text("MOTIF / RÉFÉRENCE")),
                              DataColumn(label: Text("OPÉRATEUR")),
                            ],
                            rows: movements.map((m) {
                              final typeColor = m.type == MovementType.IN 
                                  ? const Color(0xFF10B981) 
                                  : (m.type == MovementType.OUT ? Colors.red 
                                  : (m.type == MovementType.TRANSFER ? Colors.blue : Colors.orange));
                              
                              return DataRow(
                                key: ValueKey(m.id),
                                cells: [
                                  DataCell(Text(
                                    DateFormatter.formatDateTime(m.date),
                                    style: const TextStyle(fontSize: 13),
                                  )),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: typeColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        m.type == MovementType.IN ? "ENTRÉE" 
                                        : m.type == MovementType.OUT ? "SORTIE" 
                                        : (m.type == MovementType.TRANSFER ? "TRANSFERT" : "AJUSTEMENT"),
                                        style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(
                                    "${m.type == MovementType.OUT ? '-' : '+'}${DateFormatter.formatQuantity(m.quantity)}", 
                                    style: TextStyle(
                                      color: typeColor, 
                                      fontWeight: FontWeight.w900, 
                                      fontSize: 14,
                                    ),
                                  )),
                                  DataCell(Text(
                                    m.reason, 
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontStyle: FontStyle.italic),
                                  )),
                                  DataCell(Text(
                                    m.userName ?? "Admin",
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  )),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // --- FOOTER ---
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("FERMER"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(BuildContext context, {required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, MovementType? type, WidgetRef ref) {
    final selectedType = ref.watch(movementFilterProvider);
    final isSelected = selectedType == type;
    final theme = Theme.of(context);

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        ref.read(movementFilterProvider.notifier).setFilter(type);
      },
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: isSelected ? Colors.white : Colors.grey,
      ),
      selectedColor: theme.colorScheme.primary,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isSelected ? theme.colorScheme.primary : Colors.grey.withValues(alpha: 0.2)),
      ),
    );
  }
}
