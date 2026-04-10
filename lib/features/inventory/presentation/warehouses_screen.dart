import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:uuid/uuid.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/features/inventory/domain/models/warehouse.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/inventory/providers/warehouse_providers.dart';

class WarehousesScreen extends ConsumerStatefulWidget {
  const WarehousesScreen({super.key});

  @override
  ConsumerState<WarehousesScreen> createState() => _WarehousesScreenState();
}

class _WarehousesScreenState extends ConsumerState<WarehousesScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final warehousesAsync = ref.watch(warehouseListProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HEADER ──
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.7)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(FluentIcons.building_factory_24_filled, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Entrepôts & Magasins", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF1F2937))),
              Text("Gérez vos emplacements de stockage et vos stocks", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ])),
            FilledButton.icon(
              onPressed: () => _showWarehouseForm(context, ref),
              icon: const Icon(FluentIcons.add_24_regular, size: 18),
              label: const Text("NOUVEL EMPLACEMENT", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // ── STATS ROW ──
          warehousesAsync.when(
            loading: () => const SizedBox(height: 88, child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const SizedBox(height: 88),
            data: (warehouses) {
              final stores = warehouses.where((w) => w.type == 'STORE').length;
              final depots = warehouses.where((w) => w.type == 'WAREHOUSE' || w.type == 'DEPOT').length;
              return SizedBox(
                height: 88,
                child: Row(
                  children: [
                    Expanded(
                      child: _KpiTile(
                        icon: FluentIcons.building_multiple_24_regular,
                        label: "Total Emplacements",
                        value: "${warehouses.length}",
                        color: accent,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _KpiTile(
                        icon: FluentIcons.building_retail_24_regular,
                        label: "Magasins",
                        value: "$stores",
                        sub: "Points de vente",
                        color: const Color(0xFF10B981),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _KpiTile(
                        icon: FluentIcons.building_factory_24_regular,
                        label: "Dépôts & Entrepôts",
                        value: "$depots",
                        sub: "Stockage massif",
                        color: const Color(0xFF6366F1),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _KpiTile(
                        icon: FluentIcons.checkmark_circle_24_regular,
                        label: "Default",
                        value: warehouses.any((w) => w.isDefault) ? warehouses.firstWhere((w) => w.isDefault).name : "N/A",
                        color: Colors.orange,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // ── SEARCH BAR ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF16181D) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB)),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: "Rechercher un emplacement par nom...",
                prefixIcon: const Icon(FluentIcons.search_20_regular, size: 18),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),

          // ── WAREHOUSES LIST ──
          Expanded(
            child: warehousesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text("Erreur: $err")),
              data: (warehouses) {
                final filtered = warehouses.where((w) => w.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

                if (filtered.isEmpty) {
                  return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(FluentIcons.building_multiple_24_filled, size: 56, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text("Aucun emplacement trouvé", style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w600)),
                  ]));
                }

                return Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF2D3039) : const Color(0xFFF3F4F6)),
                      itemBuilder: (ctx, i) {
                        final w = filtered[i];
                        final typeColor = w.type == 'STORE' ? const Color(0xFF10B981) : (w.type == 'WAREHOUSE' ? const Color(0xFF6366F1) : const Color(0xFFF59E0B));
                        final typeIcon = w.type == 'STORE' ? FluentIcons.building_retail_24_regular : (w.type == 'WAREHOUSE' ? FluentIcons.building_factory_24_regular : FluentIcons.box_24_regular);

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showWarehouseForm(context, ref, warehouse: w),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              child: Row(children: [
                                // Icon
                                Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    color: typeColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(typeIcon, color: typeColor, size: 20),
                                ),
                                const SizedBox(width: 16),
                                // Info
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Text(w.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                                    if (w.isDefault) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: accent.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text("PAR DÉFAUT", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: accent, letterSpacing: 0.5)),
                                      ),
                                    ],
                                  ]),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${w.typeLabel}${w.address != null && w.address!.isNotEmpty ? ' · ${w.address}' : ''}",
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                  ),
                                ])),
                                // Actions
                                PopupMenuButton<String>(
                                  tooltip: '',
                                  icon: Icon(FluentIcons.more_vertical_24_regular, size: 18, color: Colors.grey.shade400),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(value: 'edit', child: Row(children: [
                                      Icon(FluentIcons.edit_20_regular, size: 18),
                                      SizedBox(width: 10),
                                      Text("Modifier"),
                                    ])),
                                    if (ref.watch(authServiceProvider).value?.isAdmin == true && !w.isDefault)
                                    PopupMenuItem(value: 'delete', child: Row(children: [
                                      Icon(FluentIcons.delete_20_regular, size: 18, color: Colors.red),
                                      const SizedBox(width: 10),
                                      Text("Supprimer", style: TextStyle(color: Colors.red)),
                                    ])),
                                  ],
                                  onSelected: (v) {
                                    if (v == 'edit') _showWarehouseForm(context, ref, warehouse: w);
                                    if (v == 'delete') _confirmDelete(context, ref, w);
                                  },
                                ),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showWarehouseForm(BuildContext context, WidgetRef ref, {Warehouse? warehouse}) {
    final isEdit = warehouse != null;
    final nameCtrl = TextEditingController(text: warehouse?.name ?? '');
    final addressCtrl = TextEditingController(text: warehouse?.address ?? '');
    String selectedType = warehouse?.type ?? 'STORE';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx2, setDialogState) {
          return EnterpriseWidgets.buildPremiumDialog(
            context,
            title: isEdit ? "Modifier l'emplacement" : "Nouvel Emplacement",
            icon: FluentIcons.building_factory_24_regular,
            width: 480,
            actions: const [],
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              EnterpriseWidgets.buildPremiumTextField(
                context, ctrl: nameCtrl, label: "NOM DE L'EMPLACEMENT", hint: "Ex: Dépôt Central", icon: FluentIcons.building_retail_24_regular,
              ),
              const SizedBox(height: 16),
              EnterpriseWidgets.buildPremiumTextField(
                context, ctrl: addressCtrl, label: "ADRESSE (OPTIONNEL)", hint: "Ex: Zone Industrielle, Bamako", icon: FluentIcons.location_24_regular,
              ),
              const SizedBox(height: 16),
              Text("TYPE D'EMPLACEMENT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.grey.shade500, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'STORE', label: Text('Magasin'), icon: Icon(FluentIcons.building_retail_24_regular, size: 16)),
                  ButtonSegment(value: 'WAREHOUSE', label: Text('Entrepôt'), icon: Icon(FluentIcons.building_factory_24_regular, size: 16)),
                  ButtonSegment(value: 'DEPOT', label: Text('Dépôt'), icon: Icon(FluentIcons.box_24_regular, size: 16)),
                ],
                selected: {selectedType},
                onSelectionChanged: (v) => setDialogState(() => selectedType = v.first),
                style: SegmentedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final w = Warehouse(
                      id: warehouse?.id ?? const Uuid().v4(),
                      name: nameCtrl.text.trim(),
                      address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                      type: selectedType,
                      isDefault: warehouse?.isDefault ?? false,
                      isActive: true,
                    );
                    if (isEdit) {
                      ref.read(warehouseListProvider.notifier).updateWarehouse(w);
                    } else {
                      ref.read(warehouseListProvider.notifier).add(w);
                    }
                    Navigator.pop(ctx);
                  },
                  child: Text(isEdit ? "Mettre à jour" : "Créer l'emplacement"),
                ),
              ]),
            ]),
          );
        });
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Warehouse warehouse) async {
    // 1. Check if warehouse contains stock
    final stock = await ref.read(warehouseStockProvider(warehouse.id).future);
    final hasStock = stock.any((item) => (item['quantity'] as num) > 0);

    if (hasStock) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible de supprimer un entrepôt contenant du stock. Veuillez d'abord transférer ou vider les produits."),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 2. Check if it's the last warehouse
    final allWarehouses = ref.read(warehouseListProvider).value ?? [];
    if (allWarehouses.length <= 1) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sécurité : Impossible de supprimer le dernier emplacement de stockage."),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!context.mounted) return;
    await EnterpriseWidgets.showPremiumConfirmDialog(
      context,
      title: "Supprimer cet emplacement ?",
      message: "L'emplacement \"${warehouse.name}\" sera supprimé définitivement. Cette action ne peut pas être annulée.",
      confirmText: "SUPPRIMER DÉFINITIVEMENT",
      isDestructive: true,
      onConfirm: () {
        ref.read(warehouseListProvider.notifier).delete(warehouse.id);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Components
// ─────────────────────────────────────────────────────────────────────────────

class _KpiTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Color color;
  final bool isDark;

  const _KpiTile({required this.icon, required this.label, required this.value, this.sub, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181D) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13), overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }
}
