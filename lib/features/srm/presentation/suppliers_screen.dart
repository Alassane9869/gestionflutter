import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/srm/providers/supplier_providers.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/srm/presentation/supplier_form_dialog.dart';
import 'package:danaya_plus/features/srm/presentation/purchase_screen.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/core/theme/app_theme.dart';
import 'package:danaya_plus/features/inventory/presentation/dashboard_screen.dart';
import 'package:danaya_plus/core/widgets/access_denied_screen.dart';
import 'package:danaya_plus/core/database/database_service.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final asyncSuppliers = ref.watch(supplierListProvider);
    
    final user = ref.watch(authServiceProvider).value;
    if (user == null || !user.canManageSuppliers) {
      return const AccessDeniedScreen(
        message: "Module SRM Restreint",
        subtitle: "Vous n'avez pas l'autorisation de gérer les fournisseurs.",
      );
    }

    // Log access once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).logActivity(
        userId: user.id,
        actionType: 'VIEW_SUPPLIERS',
        description: 'Consultation du réseau fournisseurs par ${user.username}',
      );
    });
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── COMPACT HEADER ──
          EnterpriseWidgets.buildPremiumHeader(
            context,
            title: "Réseau Fournisseurs",
            subtitle: "Gestion simplifiée des partenaires.",
            icon: FluentIcons.building_24_regular,
            onBack: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                ref.read(navigationProvider.notifier).setPage(0, ref);
              }
            },
            trailing: FilledButton.icon(
              onPressed: () => showDialog(context: context, builder: (_) => const SupplierFormDialog()),
              icon: const Icon(FluentIcons.person_add_20_regular, size: 16),
              label: const Text("NOUVEAU", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── KPI ROW ──
          asyncSuppliers.when(
            loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator())),
            error: (err, _) => const SizedBox(height: 0),
            data: (suppliers) {
              final totalDebt = suppliers.fold(0.0, (sum, s) => sum + s.outstandingDebt);
              final totalPurchases = suppliers.fold(0.0, (sum, s) => sum + s.totalPurchases);

              return Row(
                children: [
                  Expanded(
                    child: EnterpriseWidgets.buildStatCard(
                      context, 
                      title: "Partenaires", 
                      value: "${suppliers.length}", 
                      icon: FluentIcons.building_retail_more_24_regular, 
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: EnterpriseWidgets.buildStatCard(
                      context, 
                      title: "Achats", 
                      value: ref.fmt(totalPurchases), 
                      icon: FluentIcons.receipt_24_regular, 
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: EnterpriseWidgets.buildStatCard(
                      context, 
                      title: "Dettes", 
                      value: ref.fmt(totalDebt), 
                      icon: FluentIcons.money_hand_24_regular, 
                      color: AppTheme.errorClr,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),

          EnterpriseWidgets.buildPremiumTextField(
            context,
            ctrl: _searchController,
            label: "RECHERCHE",
            onChanged: (v) => setState(() => _searchQuery = v),
            hint: "Rechercher un fournisseur...",
            icon: FluentIcons.search_24_regular,
          ),
          const SizedBox(height: 8),

          // ── SUPPLIERS LIST ──
          Expanded(
            child: asyncSuppliers.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Erreur: $err')),
              data: (suppliers) {
                final filtered = suppliers.where((s) {
                  final nameMatch = s.name.toLowerCase().contains(_searchQuery.toLowerCase());
                  final detailsMatch = (s.contactName ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) || 
                                       (s.phone ?? '').contains(_searchQuery);
                  return nameMatch || detailsMatch;
                }).toList();

                if (filtered.isEmpty) {
                  return _buildEmptyState(isDark);
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (ctx, i) {
                    final s = filtered[i];
                    return _buildSupplierCard(s, isDark, theme);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierCard(dynamic s, bool isDark, ThemeData theme) {
    final hasDebt = s.outstandingDebt > 0;
    final accent = theme.colorScheme.primary;

    return EnterpriseWidgets.buildSectionContainer(
      context,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent.withValues(alpha: 0.2), accent.withValues(alpha: 0.05)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withValues(alpha: 0.1)),
            ),
            child: Icon(FluentIcons.building_24_filled, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: -0.2)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (s.contactName != null) ...[
                      const Icon(FluentIcons.person_board_16_regular, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(s.contactName!, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.normal)),
                      const SizedBox(width: 10),
                    ],
                    const Icon(FluentIcons.phone_16_regular, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(s.phone ?? 'Direct', style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.normal)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ref.fmt(s.totalPurchases), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF10B981))),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: hasDebt ? AppTheme.errorClr.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  hasDebt ? "Dette: ${ref.fmt(s.outstandingDebt)}" : "À jour",
                  style: TextStyle(
                    color: hasDebt ? AppTheme.errorClr : Colors.grey, 
                    fontWeight: FontWeight.bold, fontSize: 9, letterSpacing: 0.2
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PurchaseScreen(supplier: s))),
            icon: const Icon(FluentIcons.cart_24_regular, size: 18),
            tooltip: "Achat",
            style: IconButton.styleFrom(
              backgroundColor: accent.withValues(alpha: 0.1),
              foregroundColor: accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.all(8),
            ),
          ),
          const SizedBox(width: 4),
          _buildActionMenu(s),
        ],
      ),
    );
  }

  Widget _buildActionMenu(dynamic s) {
    return PopupMenuButton<String>(
      icon: Icon(FluentIcons.more_horizontal_24_regular, color: Colors.grey.shade400, size: 18),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(FluentIcons.edit_20_regular, size: 16), SizedBox(width: 12), Text("Modifier", style: TextStyle(fontSize: 13))])),
        if (ref.read(authServiceProvider).value?.isAdmin == true)
          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(FluentIcons.delete_20_regular, size: 16, color: Colors.red), SizedBox(width: 12), Text("Supprimer", style: TextStyle(color: Colors.red, fontSize: 13))])),
      ],
      onSelected: (v) {
        if (v == 'edit') showDialog(context: context, builder: (_) => SupplierFormDialog(supplier: s));
        if (v == 'delete') _confirmSupplierDelete(context, ref, s);
      },
    );
  }

  void _confirmSupplierDelete(BuildContext context, WidgetRef ref, dynamic s) async {
    if (s.outstandingDebt > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Impossible de supprimer un fournisseur avec une dette active (${ref.fmt(s.outstandingDebt)})"),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await EnterpriseWidgets.showPremiumConfirmDialog(
      context,
      title: "Supprimer le fournisseur",
      message: "Voulez-vous vraiment supprimer ${s.name} ? Cette action est irréversible et supprimera tout l'historique associé.",
      confirmText: "SUPPRIMER",
      isDestructive: true,
      onConfirm: () async {
        try {
          await ref.read(supplierListProvider.notifier).deleteSupplier(s.id);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.toString().replaceAll('Exception: ', '')),
                backgroundColor: Colors.red.shade600,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey.shade50, shape: BoxShape.circle),
            child: Icon(FluentIcons.people_search_24_regular, size: 60, color: isDark ? Colors.white10 : Colors.grey.shade200),
          ),
          const SizedBox(height: 16),
          Text("Aucun fournisseur", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white24 : Colors.grey.shade300)),
        ],
      ),
    );
  }
}
