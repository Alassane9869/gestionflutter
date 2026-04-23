import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/inventory/domain/models/product.dart';
import 'package:danaya_plus/features/inventory/providers/product_providers.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'product_form_dialog.dart';
import 'product_detail_dialog.dart';
import 'package:danaya_plus/features/inventory/presentation/dashboard_screen.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/features/inventory/providers/warehouse_providers.dart';
import 'transfer_stock_dialog.dart';
import 'barcode_labels_dialog.dart';
import 'package:danaya_plus/features/inventory/data/product_repository.dart';
import 'package:danaya_plus/features/inventory/application/inventory_automation_service.dart';
import 'package:danaya_plus/features/inventory/providers/global_search_provider.dart';
import 'package:danaya_plus/core/utils/image_resolver.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'product_movement_dialog.dart';
import 'widgets/excel_import_wizard.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final _searchController = TextEditingController();
  String _stockFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyGlobalSearch(String query) {
    _searchController.text = query;
    ref.read(productListProvider.notifier).search(query);
    // Nettoyer après application
    Future.microtask(() => ref.read(searchSelectionProvider.notifier).set(null));
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productListProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Écouter la sélection de recherche globale pour les changements futurs
    ref.listen<String?>(searchSelectionProvider, (previous, next) {
      if (next != null) {
        _applyGlobalSearch(next);
      }
    });

    // Mettre l'état de la recherche initiale (s'il y en a un) de manière asynchrone DANS un Future.microtask
    // et ne le faire qu'une seule fois si possible pour ne pas boucler.
    final pendingSearch = ref.read(searchSelectionProvider);
    if (pendingSearch != null) {
        Future.microtask(() => _applyGlobalSearch(pendingSearch));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EnterpriseWidgets.buildPremiumHeader(
                context,
                title: "GESTION PRODUITS",
                subtitle: "Référentiel global de vos articles, stocks et alertes.",
                icon: FluentIcons.box_24_regular,
                onBack: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    ref.read(navigationProvider.notifier).setPage(0, ref);
                  }
                },
                trailing: Row(
                  children: [
                    Tooltip(
                      message: "Télécharger un fichier Excel prêt à l'emploi",
                      child: FilledButton.icon(
                        onPressed: () => _handleExportModele(context),
                        icon: const Icon(FluentIcons.document_table_24_regular, size: 18),
                        label: const Text("Modèle Excel"),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                          foregroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFF10B981))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Tooltip(
                      message: "Importer vos données depuis Excel",
                      child: FilledButton.icon(
                        onPressed: () => _handleImport(context),
                        icon: const Icon(FluentIcons.arrow_upload_24_regular, size: 18),
                        label: const Text("Importer"),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                          foregroundColor: theme.colorScheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: theme.colorScheme.primary)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Tooltip(
                      message: "Générer et imprimer des codes-barres",
                      child: FilledButton.icon(
                        onPressed: () => _handleBarcodeLabels(context),
                        icon: const Icon(FluentIcons.barcode_scanner_24_regular, size: 18),
                        label: const Text("Étiquettes"),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.orange.withValues(alpha: 0.1),
                          foregroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.orange)),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: "Transférer du stock entre entrepôts",
                      child: FilledButton.icon(
                        onPressed: () => _handleTransferGlobal(context),
                        icon: const Icon(FluentIcons.arrow_swap_24_regular, size: 18),
                        label: const Text("Transfert"),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                          foregroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.blue)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => _showProductForm(context),
                      icon: const Icon(FluentIcons.add_24_filled, size: 18),
                      label: const Text("Nouvel Article"),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              productsAsync.when(
                data: (products) {
                  final val = products.fold(0.0, (sum, p) => sum + (p.stockValue));
                  final lowStock = products.where((p) => p.isLowStock || p.isOutOfStock).length;
                  return Row(
                    children: [
                      Expanded(
                        child: EnterpriseStatCard(
                          title: "Articles Référencés",
                          value: "${products.length}",
                          icon: FluentIcons.box_24_regular,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: EnterpriseStatCard(
                          title: "Valeur Totale Stock",
                          value: ref.fmt(val),
                          icon: FluentIcons.money_24_regular,
                          color: const Color(0xFF10B981),
                          trendLabel: "Optimisé",
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: EnterpriseStatCard(
                          title: "Alertes Rupture",
                          value: "$lowStock",
                          icon: FluentIcons.warning_24_regular,
                          color: theme.colorScheme.error,
                          isPositiveTrend: false,
                          trendLabel: lowStock > 0 ? "Action requise" : "Sain",
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (e, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1D24) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB)),
                  boxShadow: isDark ? [] : [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (q) => ref.read(productListProvider.notifier).search(q),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            decoration: InputDecoration(
                              hintText: "Rechercher par nom, référence ou code-barres...",
                              prefixIcon: Icon(FluentIcons.search_24_regular, size: 20, color: theme.colorScheme.primary),
                              border: InputBorder.none,
                              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        _buildWarehouseSelector(context, ref),
                        const SizedBox(width: 12),
                        _buildFilterBtn(context, FluentIcons.filter_24_regular, "Rayons"),
                        const SizedBox(width: 12),
                        _buildFilterBtn(context, FluentIcons.arrow_sort_24_regular, "Trier"),
                      ],
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    productsAsync.when(
                      data: (products) {
                        final allCount = products.length;
                        final inStockCount = products.where((p) => !p.isLowStock && !p.isOutOfStock).length;
                        final lowCount = products.where((p) => p.isLowStock).length;
                        final outCount = products.where((p) => p.isOutOfStock).length;
                        return Row(
                          children: [
                            Text("FILTRER : ", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey.shade500, letterSpacing: 1.2)),
                            const SizedBox(width: 12),
                            _buildStockChip('all', 'Tous ($allCount)', isDark),
                            const SizedBox(width: 8),
                            _buildStockChip('inStock', 'En stock ($inStockCount)', isDark),
                            const SizedBox(width: 8),
                            _buildStockChip('lowStock', 'Stock bas ($lowCount)', isDark),
                            const SizedBox(width: 8),
                            _buildStockChip('outOfStock', 'Rupture ($outCount)', isDark),
                          ],
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB)),
                  ),
                  child: productsAsync.when(
                    data: (products) {
                      final filtered = _stockFilter == 'all'
                          ? products
                          : _stockFilter == 'inStock'
                              ? products.where((p) => !p.isLowStock && !p.isOutOfStock).toList()
                              : _stockFilter == 'lowStock'
                                  ? products.where((p) => p.isLowStock).toList()
                                  : products.where((p) => p.isOutOfStock).toList();
                      final user = ref.watch(authServiceProvider).value;
                      if (filtered.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(FluentIcons.box_dismiss_24_regular, size: 48, color: Colors.grey),
                              SizedBox(height: 16),
                              Text("Aucun article trouvé", style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        );
                      }
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _InventoryDataTablePremium(
                          products: filtered,
                          onDetail: (p) => _showProductDetail(context, p),
                          onEdit: (p) => _showProductForm(context, product: p),
                          onDelete: user?.isAdmin == true ? (p) => _confirmDelete(context, p) : null,
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text("Erreur : $e")),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockChip(String value, String label, bool isDark) {
    final isSelected = _stockFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
      selected: isSelected,
      onSelected: (_) => setState(() => _stockFilter = value),
      selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
      backgroundColor: isDark ? const Color(0xFF1E2028) : const Color(0xFFF3F4F6),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildFilterBtn(BuildContext context, IconData icon, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF282828) : Colors.white,
        border: Border.all(color: isDark ? const Color(0xFF383838) : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _handleExportModele(BuildContext context) async {
    try {
      final bytes = await ref.read(inventoryAutomationServiceProvider).generateTemplate();
      if (bytes == null) return;

      final settings = ref.read(shopSettingsProvider).value;
      final shopName = settings?.name.replaceAll(RegExp(r'[^\w\s-]'), '_') ?? 'Danaya';
      
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer le modèle d\'importation',
        fileName: 'Modele_Import_$shopName.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (path != null) {
        // Ensure extension is present (platform specific behavior)
        String finalPath = path;
        if (!finalPath.toLowerCase().endsWith('.xlsx')) {
          finalPath += '.xlsx';
        }
        
        final file = File(finalPath);
        await file.writeAsBytes(bytes);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Modèle Excel enregistré avec succès !"),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur lors de la génération : $e")));
    }
  }

  void _handleImport(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const ExcelImportWizard(),
    );
  }

  void _showProductForm(BuildContext context, {Product? product}) {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!context.mounted) return;
      showDialog(context: context, builder: (_) => ProductFormDialog(product: product));
    });
  }

  void _showProductDetail(BuildContext context, Product product) {
    showDialog(
      context: context, 
      builder: (_) => ProductDetailDialog(product: product),
    );
  }

  void _handleBarcodeLabels(BuildContext context) async {
    final products = await ref.read(productRepositoryProvider).getAll();
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => BarcodeLabelsDialog(initialProducts: products),
    );
  }

  void _handleTransferGlobal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const TransferStockDialog(),
    );
  }

  void _confirmDelete(BuildContext context, Product product) {
    if (product.quantity > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Impossible de supprimer un article encore en stock (${DateFormatter.formatQuantity(product.quantity)} restant(s))."),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Future.delayed(const Duration(milliseconds: 50), () {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("Supprimer le produit ?"),
          content: Text("Voulez-vous vraiment retirer \"${product.name}\" du stock ?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () {
                ref.read(productListProvider.notifier).deleteProduct(product.id);
                Navigator.pop(ctx);
              },
              child: const Text("Supprimer"),
            ),
          ],
        ),
      );
    });
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

class _InventoryDataTablePremium extends ConsumerStatefulWidget {
  final List<Product> products;
  final ValueChanged<Product> onDetail;
  final ValueChanged<Product> onEdit;
  final ValueChanged<Product>? onDelete;

  const _InventoryDataTablePremium({required this.products, required this.onDetail, required this.onEdit, required this.onDelete});

  @override
  ConsumerState<_InventoryDataTablePremium> createState() => _InventoryDataTablePremiumState();
}

class _InventoryDataTablePremiumState extends ConsumerState<_InventoryDataTablePremium> {
  late final ScrollController _verticalController;
  late final ScrollController _horizontalController;

  @override
  void initState() {
    super.initState();
    _verticalController = ScrollController();
    _horizontalController = ScrollController();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  void _showMovementHistory(BuildContext context, Product product) {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (_) => ProductMovementHistoryDialog(product: product),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Scrollbar(
        controller: _verticalController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _verticalController,
          scrollDirection: Axis.vertical,
          physics: const BouncingScrollPhysics(),
          child: Scrollbar(
            controller: _horizontalController,
            notificationPredicate: (n) => n.depth == 0, // Uniquement ce SingleChildScrollView
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Theme(
                data: theme.copyWith(
                  dataTableTheme: const DataTableThemeData(
                    headingRowColor: WidgetStatePropertyAll(Colors.transparent),
                    dividerThickness: 1,
                  ),
                ),
                child: DataTable(
                  showCheckboxColumn: false,
                  dataRowMaxHeight: 64,
                  dataRowMinHeight: 58,
                  headingRowHeight: 44,
                  columnSpacing: 24,
                  horizontalMargin: 24,
                  columns: [
                    _buildCol(""), // Colonne pour le bouton Info
                    _buildCol("ARTICLE"),
                    _buildCol("RÉFÉRENCE"),
                    _buildCol("STATUT"),
                    _buildCol("PRIX VENTE"),
                    _buildCol("STOCK"),
                    _buildCol("ACTIONS"),
                  ],
                  rows: widget.products.map((p) {
                    return DataRow(
                      key: ValueKey(p.id),
                      onSelectChanged: (_) => widget.onDetail(p),
                      cells: [
                        DataCell(
                          IconButton(
                            icon: const Icon(FluentIcons.info_20_regular, color: Colors.blue),
                            onPressed: () => widget.onDetail(p),
                            tooltip: "Détails rapides",
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.blue.withValues(alpha: 0.05),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        DataCell(Row(
                          children: [
                            Container(
                              width: 38, height: 38,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF282828) : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
                                image: p.imagePath != null
                                    ? DecorationImage(
                                        image: ImageResolver.getProductImage(p.imagePath, ref.watch(shopSettingsProvider).value), 
                                        fit: BoxFit.cover
                                      )
                                    : null,
                              ),
                              child: p.imagePath == null
                                  ? const Icon(FluentIcons.image_24_regular, color: Colors.grey, size: 20)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(p.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textTheme.bodyLarge?.color)),
                                  Text(p.category ?? "Général", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        )),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF282828) : Colors.grey.shade200, 
                            borderRadius: BorderRadius.circular(4)
                          ),
                          child: Text(p.barcode ?? "—", style: TextStyle(fontSize: 11, color: isDark ? Colors.grey : Colors.grey.shade700, fontWeight: FontWeight.bold)),
                        )),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: p.isOutOfStock ? Colors.red.withValues(alpha: 0.1) : (p.isLowStock ? Colors.orange.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            p.isOutOfStock ? "RUPTURE" : (p.isLowStock ? "BAS" : "OK"),
                            style: TextStyle(
                              color: p.isOutOfStock ? Colors.red : (p.isLowStock ? Colors.orange : Colors.green),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        )),
                        DataCell(Text(ref.fmt(p.sellingPrice), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        DataCell(Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ref.qty(p.quantity), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: theme.textTheme.bodyLarge?.color)),
                            if (p.unit != null) Text(p.unit!, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        )),
                        DataCell(Row(
                          children: [
                            Tooltip(message: "Modifier l'article", child: IconButton(icon: const Icon(FluentIcons.edit_16_regular, size: 18, color: Colors.grey), onPressed: () => widget.onEdit(p))),
                            Tooltip(
                              message: "Transférer du stock",
                              child: IconButton(
                                icon: const Icon(FluentIcons.arrow_swap_16_regular, size: 18, color: Colors.grey),
                                onPressed: () {
                                  Future.delayed(const Duration(milliseconds: 50), () {
                                    if (!context.mounted) return;
                                    showDialog(context: context, builder: (_) => TransferStockDialog(initialProduct: p));
                                  });
                                },
                              ),
                            ),
                            Tooltip(
                               message: "Historique des mouvements", 
                               child: IconButton(
                                 icon: const Icon(FluentIcons.history_16_regular, size: 18, color: Colors.grey), 
                                 onPressed: () => _showMovementHistory(context, p),
                               ),
                             ),
                            if (ref.watch(authServiceProvider).value?.isAdmin ?? false)
                              Tooltip(message: "Supprimer définitivement", child: IconButton(icon: const Icon(FluentIcons.delete_16_regular, size: 18, color: Colors.red), onPressed: widget.onDelete != null ? () => widget.onDelete!(p) : null)),
                          ],
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  DataColumn _buildCol(String label) {
    return DataColumn(
      label: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey)),
    );
  }
}
