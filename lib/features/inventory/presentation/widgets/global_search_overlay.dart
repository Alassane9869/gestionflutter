import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/inventory/providers/global_search_provider.dart';
import 'package:danaya_plus/features/inventory/presentation/dashboard_screen.dart';
import 'package:danaya_plus/features/inventory/domain/models/product.dart';
import 'package:danaya_plus/features/clients/domain/models/client.dart';
import 'package:danaya_plus/features/inventory/presentation/product_form_dialog.dart';
import 'package:danaya_plus/features/clients/presentation/client_details_screen.dart';
import 'package:danaya_plus/features/pos/providers/sales_history_providers.dart';
import 'package:danaya_plus/features/srm/providers/supplier_providers.dart';

class GlobalSearchOverlay extends ConsumerWidget {
  final VoidCallback onResultClicked;

  const GlobalSearchOverlay({
    super.key,
    required this.onResultClicked,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchResultsAsync = ref.watch(globalSearchProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return searchResultsAsync.when(
      data: (results) {
        if (results.isEmpty) return const SizedBox.shrink();

        return Material(
          type: MaterialType.transparency,
          child: Container(
            width: 450, // Slightly wider to fit descriptions and details
            constraints: const BoxConstraints(maxHeight: 500),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  _buildCategory(context, "RACCOURCIS & ACTIONS", results.where((r) => r.type == SearchResultType.shortcut).toList(), ref),
                  _buildCategory(context, "PRODUITS", results.where((r) => r.type == SearchResultType.product).toList(), ref),
                  _buildCategory(context, "CLIENTS", results.where((r) => r.type == SearchResultType.client).toList(), ref),
                  _buildCategory(context, "FOURNISSEURS", results.where((r) => r.type == SearchResultType.supplier).toList(), ref),
                  _buildCategory(context, "VENTES & TICKETS", results.where((r) => r.type == SearchResultType.sale).toList(), ref),
                  _buildCategory(context, "DÉPENSES", results.where((r) => r.type == SearchResultType.expense).toList(), ref),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => Container(
        width: 400,
        height: 80,
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Container(
        width: 400,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text("Erreur: $e", style: const TextStyle(color: Colors.red, fontSize: 12)),
      ),
    );
  }

  Widget _buildCategory(BuildContext context, String title, List<GlobalSearchResult> items, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ),
        ...items.map((item) => _buildResultItem(context, item, ref)),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildResultItem(BuildContext context, GlobalSearchResult item, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color itemColor = Colors.blue;
    IconData itemIcon = FluentIcons.box_20_regular;

    switch (item.type) {
      case SearchResultType.product:
        itemColor = Colors.blue;
        itemIcon = FluentIcons.box_20_regular;
        break;
      case SearchResultType.client:
        itemColor = Colors.orange;
        itemIcon = FluentIcons.person_20_regular;
        break;
      case SearchResultType.sale:
        itemColor = Colors.green;
        itemIcon = FluentIcons.receipt_20_regular;
        break;
      case SearchResultType.supplier:
        itemColor = Colors.purple;
        itemIcon = FluentIcons.building_20_regular;
        break;
      case SearchResultType.expense:
        itemColor = Colors.red;
        itemIcon = FluentIcons.money_hand_20_regular;
        break;
      case SearchResultType.shortcut:
        itemColor = Colors.teal;
        if (item.original is SearchShortcut) {
          itemIcon = (item.original as SearchShortcut).icon;
        } else {
          itemIcon = FluentIcons.navigation_20_regular;
        }
        break;
    }

    return InkWell(
      onTap: () {
        _handleNavigation(item, ref, context);
        onResultClicked();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: itemColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                itemIcon,
                size: 18,
                color: itemColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  Text(
                    item.subtitle,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              FluentIcons.chevron_right_16_regular,
              size: 14,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  void _handleNavigation(GlobalSearchResult item, WidgetRef ref, BuildContext context) {
    if (item.type == SearchResultType.product) {
      // 1. Mettre à jour la recherche locale
      ref.read(searchSelectionProvider.notifier).set(item.title);
      // 2. Naviguer vers l'onglet produits
      ref.read(navigationProvider.notifier).setPage(1, ref);
      // 3. Ouvrir directement le formulaire d'édition
      if (item.original is Product) {
        showDialog(
          context: context,
          builder: (_) => ProductFormDialog(product: item.original as Product),
        );
      }
    } else if (item.type == SearchResultType.client) {
      // 1. Mettre à jour la recherche locale
      ref.read(searchSelectionProvider.notifier).set(item.title);
      // 2. Naviguer vers l'onglet clients
      ref.read(navigationProvider.notifier).setPage(7, ref);
      // 3. Ouvrir directement l'écran de détail
      if (item.original is Client) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClientDetailScreen(client: item.original as Client),
          ),
        );
      }
    } else if (item.type == SearchResultType.sale) {
      // 1. Mettre à jour la recherche historique des ventes
      ref.read(salesSearchQueryProvider.notifier).update(item.title);
      // 2. Naviguer vers l'onglet historique des ventes (page 4)
      ref.read(navigationProvider.notifier).setPage(4, ref);
    } else if (item.type == SearchResultType.supplier) {
      // 1. Mettre à jour le filtre de recherche des fournisseurs
      ref.read(suppliersSearchQueryProvider.notifier).update(item.title);
      // 2. Naviguer vers l'onglet fournisseurs (page 8)
      ref.read(navigationProvider.notifier).setPage(8, ref);
    } else if (item.type == SearchResultType.expense) {
      // Naviguer vers l'onglet dépenses (page 13)
      ref.read(navigationProvider.notifier).setPage(13, ref);
    } else if (item.type == SearchResultType.shortcut) {
      if (item.original is SearchShortcut) {
        final s = item.original as SearchShortcut;
        ref.read(navigationProvider.notifier).setPage(s.pageIndex, ref);
      }
    }
  }
}
