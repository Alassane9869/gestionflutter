import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/inventory/providers/global_search_provider.dart';
import 'package:danaya_plus/features/inventory/presentation/dashboard_screen.dart';
import 'package:danaya_plus/features/inventory/domain/models/product.dart';
import 'package:danaya_plus/features/clients/domain/models/client.dart';
import 'package:danaya_plus/features/inventory/presentation/product_form_dialog.dart';
import 'package:danaya_plus/features/clients/presentation/client_details_screen.dart';

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
            width: 400,
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
                _buildCategory(context, "PRODUITS", results.where((r) => r.type == SearchResultType.product).toList(), ref),
                _buildCategory(context, "CLIENTS", results.where((r) => r.type == SearchResultType.client).toList(), ref),
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
                color: (item.type == SearchResultType.product ? Colors.blue : Colors.orange).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                item.type == SearchResultType.product ? FluentIcons.box_20_regular : FluentIcons.person_20_regular,
                size: 18,
                color: item.type == SearchResultType.product ? Colors.blue : Colors.orange,
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
    }
  }
}
