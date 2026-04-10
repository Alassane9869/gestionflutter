import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/clients/providers/client_providers.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/core/widgets/access_denied_screen.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/clients/presentation/client_form_dialog.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/core/theme/app_theme.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/features/clients/presentation/client_details_screen.dart';
import 'package:danaya_plus/features/inventory/providers/global_search_provider.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'name'; // name, credit, spent
  bool _onlyDebtors = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyGlobalSearch(String query) {
    _searchController.text = query;
    setState(() => _searchQuery = query);
    // Nettoyer après application
    Future.microtask(() => ref.read(searchSelectionProvider.notifier).set(null));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final asyncClients = ref.watch(clientListProvider);

    final user = ref.watch(authServiceProvider).value;
    if (user == null || !user.canManageCustomers) {
      return const AccessDeniedScreen(
        message: "Module Clients Restreint",
        subtitle: "Vous n'avez pas l'autorisation de gérer la base clients.",
      );
    }

    // Log access
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).logActivity(
            userId: user.id,
            actionType: 'VIEW_CLIENTS',
            description: 'Consultation de la base clients par ${user.username}',
          );
    });

    // Écouter la sélection de recherche globale
    ref.listen<String?>(searchSelectionProvider, (previous, next) {
      if (next != null) {
        _applyGlobalSearch(next);
      }
    });

    // Sélection initiale (navigation directe)
    final pendingSearch = ref.read(searchSelectionProvider);
    if (pendingSearch != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyGlobalSearch(pendingSearch);
      });
    }
    
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
              child: const Icon(FluentIcons.people_community_24_filled, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Fidélité & Clients", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF1F2937))),
              Text("Gérez vos relations clients et le suivi des crédits", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ])),
            FilledButton.icon(
              onPressed: () => showDialog(context: context, builder: (_) => const ClientFormDialog()),
              icon: const Icon(FluentIcons.person_add_24_regular, size: 18),
              label: const Text("Nouveau client", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // ── KPI ROW ──
          asyncClients.when(
            loading: () => const SizedBox(height: 88, child: Center(child: CircularProgressIndicator())),
            error: (err, _) => const SizedBox(height: 88),
            data: (clients) {
              final totalCredit = clients.fold(0.0, (sum, c) => sum + c.credit);
              final debtorsCount = clients.where((c) => c.credit > 0).length;
              final topClient = clients.isNotEmpty 
                  ? clients.reduce((a, b) => a.totalSpent > b.totalSpent ? a : b)
                  : null;

              return SizedBox(
                height: 88,
                child: Row(children: [
                  Expanded(
                    child: EnterpriseKpiTile(
                      icon: FluentIcons.people_24_regular,
                      label: "Total Clients",
                      value: "${clients.length}",
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: EnterpriseKpiTile(
                      icon: FluentIcons.money_24_regular,
                      label: "Encours Crédits",
                      value: ref.fmt(totalCredit),
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: EnterpriseKpiTile(
                      icon: FluentIcons.warning_24_regular,
                      label: "Débiteurs Actifs",
                      value: "$debtorsCount",
                      sub: "sur ${clients.length} clients",
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: EnterpriseKpiTile(
                      icon: FluentIcons.star_24_regular,
                      label: "Meilleur Client",
                      value: topClient?.name ?? "–",
                      sub: topClient != null ? "CA: ${ref.fmt(topClient.totalSpent)}" : null,
                      color: AppTheme.successClr,
                    ),
                  ),
                ]),
              );
            },
          ),
          const SizedBox(height: 16),

          // ── SEARCH & FILTERS ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF16181D) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB)),
            ),
            child: Row(children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: "Rechercher par nom ou téléphone...",
                    prefixIcon: const Icon(FluentIcons.search_20_regular, size: 18),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              _VertDivider(isDark: isDark),
              // Debtor Filter
              _FilterPill(
                label: "Débiteurs",
                isSelected: _onlyDebtors,
                color: theme.colorScheme.error,
                onTap: () => setState(() => _onlyDebtors = !_onlyDebtors),
              ),
              _VertDivider(isDark: isDark),
              // Sort dropdown
              PopupMenuButton<String>(
                onSelected: (v) => setState(() => _sortBy = v),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'name', child: Text("Trier par Nom")),
                  const PopupMenuItem(value: 'credit', child: Text("Trier par Dette")),
                  const PopupMenuItem(value: 'spent', child: Text("Trier par CA total")),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    Icon(FluentIcons.arrow_sort_24_regular, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      _sortBy == 'name' ? "Nom" : (_sortBy == 'credit' ? "Dette" : "CA Total"),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade600),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── CLIENT LIST ──
          asyncClients.when(
            loading: () => const Expanded(child: Center(child: CircularProgressIndicator())),
            error: (err, _) => Expanded(child: Center(child: Text('Erreur: $err'))),
            data: (clients) {
              var filtered = clients.where((c) {
                final matchQ = c.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                              (c.phone?.contains(_searchQuery) ?? false);
                final matchDebtor = !_onlyDebtors || c.credit > 0;
                return matchQ && matchDebtor;
              }).toList();

              // Sorting
              if (_sortBy == 'name') filtered.sort((a, b) => a.name.compareTo(b.name));
              if (_sortBy == 'credit') filtered.sort((a, b) => b.credit.compareTo(a.credit));
              if (_sortBy == 'spent') filtered.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));

              if (filtered.isEmpty) {
                return Expanded(
                  child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(FluentIcons.people_24_regular, size: 56, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text("Aucun client trouvé", style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w600)),
                  ])),
                );
              }

              return Expanded(
                child: Container(
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
                        final c = filtered[i];
                        final hasCredit = c.credit > 0;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClientDetailScreen(client: c))),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              child: Row(children: [
                                // Avatar
                                Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [accent.withValues(alpha: 0.1), accent.withValues(alpha: 0.05)]),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    c.name.substring(0, 1).toUpperCase(),
                                    style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 16),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Info
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                  const SizedBox(height: 3),
                                  Row(children: [
                                    Icon(FluentIcons.phone_16_regular, size: 12, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(c.phone ?? 'Sans numéro', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                    const SizedBox(width: 12),
                                    Text("${c.totalPurchases} achats", style: TextStyle(color: accent.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w700)),
                                  ]),
                                ])),
                                // Stats
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text(ref.fmt(c.totalSpent), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if ((ref.watch(shopSettingsProvider).value?.loyaltyEnabled ?? false) && c.loyaltyPoints > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          margin: const EdgeInsets.only(right: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(FluentIcons.star_16_filled, size: 10, color: Colors.amber),
                                              const SizedBox(width: 3),
                                              Text("${c.loyaltyPoints} pts", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w800, fontSize: 10)),
                                            ],
                                          ),
                                        ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: hasCredit ? theme.colorScheme.error.withValues(alpha: 0.1) : const Color(0xFF10B981).withValues(alpha: 0.06),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          hasCredit ? "Dette: ${ref.fmt(c.credit)}" : "À jour",
                                          style: TextStyle(color: hasCredit ? theme.colorScheme.error : const Color(0xFF10B981), fontWeight: FontWeight.w800, fontSize: 10),
                                        ),
                                      ),
                                    ],
                                  ),
                                ]),
                                const SizedBox(width: 16),
                                // Actions popup
                                if (ref.watch(authServiceProvider).value?.isAdmin == true)
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
                                    PopupMenuItem(value: 'delete', child: Row(children: [
                                      Icon(FluentIcons.delete_20_regular, size: 18, color: Colors.red),
                                      const SizedBox(width: 10),
                                      Text("Supprimer", style: TextStyle(color: Colors.red)),
                                    ])),
                                  ],
                                  onSelected: (v) {
                                    if (v == 'edit') showDialog(context: context, builder: (_) => ClientFormDialog(client: c));
                                    if (v == 'delete') _confirmDelete(context, ref, c);
                                  },
                                ),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, dynamic client) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer le client"),
        content: Text("Voulez-vous vraiment supprimer la fiche de ${client.name} ? Cette action est irréversible."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Supprimer", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (!context.mounted) return;
    if (confirm == true) {
      if (client.credit > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Impossible de supprimer un client avec une dette active (${ref.fmt(client.credit)})"),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      ref.read(clientListProvider.notifier).deleteClient(client.id);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper Widgets (Same as in Reports for consistency)
// ─────────────────────────────────────────────────────────────────────────────


class _FilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterPill({required this.label, required this.isSelected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label, style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          )),
        ),
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  final bool isDark;
  const _VertDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1, height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB),
    );
  }
}
