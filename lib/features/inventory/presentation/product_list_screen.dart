import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/inventory/domain/models/product.dart';
import 'package:danaya_plus/features/inventory/providers/product_providers.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
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
import 'widgets/invoice_import_wizard.dart';

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

    final searchQuery = ref.watch(productsSearchQueryProvider);
    _stockFilter = ref.watch(productsStockFilterProvider);

    // Sync search query if changed from voice/global state
    if (_searchController.text != searchQuery) {
      _searchController.text = searchQuery;
      Future.microtask(() => ref.read(productListProvider.notifier).search(searchQuery));
    }

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
              // ==========================================
              // NOUVEAU HEADER ULTRA-COMPACT ET MODERNE
              // ==========================================
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? theme.colorScheme.surface : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
                    width: 1.5,
                  ),
                  boxShadow: isDark ? [] : [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 24, offset: const Offset(0, 8))
                  ],
                ),
                child: Column(
                  children: [
                    // LIGNE 1 : Titre + Stats compactes + Boutons
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Bouton Retour
                        if (Navigator.canPop(context)) ...[
                          IconButton(
                            onPressed: () {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              } else {
                                ref.read(navigationProvider.notifier).setPage(0, ref);
                              }
                            },
                            icon: const Icon(FluentIcons.arrow_left_24_regular, size: 20),
                            style: IconButton.styleFrom(
                              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // Icône et Titre
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(FluentIcons.box_24_filled, color: theme.colorScheme.primary, size: 22),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Gestion Produits", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                              Text("Référentiel global de vos articles", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        
                        // STATS ULTRA COMPACTES (Pilules)
                        productsAsync.when(
                          data: (products) {
                            final val = products.fold(0.0, (sum, p) => sum + (p.stockValue));
                            final lowStock = products.where((p) => p.isLowStock || p.isOutOfStock).length;
                            return Expanded(
                              flex: 3,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _buildMiniStat(isDark, "${products.length}", "Articles", FluentIcons.box_20_regular, Colors.blue),
                                  const SizedBox(width: 8),
                                  _buildMiniStat(isDark, ref.fmt(val), "Stock", FluentIcons.money_20_regular, Colors.green),
                                  if (lowStock > 0) ...[
                                    const SizedBox(width: 8),
                                    _buildMiniStat(isDark, "$lowStock", "Alertes", FluentIcons.warning_20_regular, Colors.red),
                                  ]
                                ],
                              ),
                            );
                          },
                          loading: () => const Spacer(),
                          error: (_, __) => const Spacer(),
                        ),
                        const SizedBox(width: 24),

                        // BOUTONS D'ACTION
                        PopupMenuButton<int>(
                          tooltip: "Options avancées",
                          offset: const Offset(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200),
                          ),
                          color: isDark ? theme.colorScheme.surface : Colors.white,
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(FluentIcons.grid_dots_20_regular, size: 16, color: theme.textTheme.bodyLarge?.color),
                                const SizedBox(width: 8),
                                Text("Gérer", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                              ],
                            ),
                          ),
                          onSelected: (val) {
                            switch (val) {
                              case 0: _handleExportModele(context); break;
                              case 1: _handleImport(context); break;
                              case 2: _handleBarcodeLabels(context); break;
                              case 3: _handleTransferGlobal(context); break;
                              case 4: _handleInvoiceImport(context); break;
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(value: 0, child: Row(children: [const Icon(FluentIcons.document_table_20_regular, color: Colors.green, size: 18), const SizedBox(width: 12), const Text("Modèle Excel")])),
                            PopupMenuItem(value: 1, child: Row(children: [Icon(FluentIcons.arrow_upload_20_regular, color: theme.colorScheme.primary, size: 18), const SizedBox(width: 12), const Text("Importer via Excel")])),
                            const PopupMenuDivider(),
                            PopupMenuItem(value: 4, child: Row(children: [const Icon(FluentIcons.sparkle_20_regular, color: Colors.purple, size: 18), const SizedBox(width: 12), const Text("Saisir via Facture IA")])),
                            const PopupMenuDivider(),
                            PopupMenuItem(value: 2, child: Row(children: [const Icon(FluentIcons.barcode_scanner_20_regular, color: Colors.orange, size: 18), const SizedBox(width: 12), const Text("Générer Étiquettes")])),
                            PopupMenuItem(value: 3, child: Row(children: [const Icon(FluentIcons.arrow_swap_20_regular, color: Colors.blue, size: 18), const SizedBox(width: 12), const Text("Transfert Global")])),
                          ],
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: () => _showProductForm(context),
                          icon: const Icon(FluentIcons.add_20_filled, size: 16),
                          label: const Text("Nouvel Article", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                            minimumSize: const Size(0, 40),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),

                      // LIGNE 2 : RECHERCHE ET FILTRES
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(FluentIcons.search_20_regular, size: 18, color: Colors.grey.shade400),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (q) => ref.read(productsSearchQueryProvider.notifier).update(q),
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87),
                                    decoration: InputDecoration(
                                      hintText: "Rechercher par nom, réf ou code-barres...",
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Filtres dynamiques intégrés
                        productsAsync.when(
                          data: (products) {
                            final allCount = products.length;
                            final inStockCount = products.where((p) => !p.isLowStock && !p.isOutOfStock).length;
                            final lowCount = products.where((p) => p.isLowStock).length;
                            final outCount = products.where((p) => p.isOutOfStock).length;
                            return Row(
                              children: [
                                _buildStockChip('all', 'Tous ($allCount)', isDark),
                                const SizedBox(width: 6),
                                _buildStockChip('inStock', 'En stock ($inStockCount)', isDark),
                                const SizedBox(width: 6),
                                _buildStockChip('lowStock', 'Bas ($lowCount)', isDark),
                                const SizedBox(width: 6),
                                _buildStockChip('outOfStock', 'Rupture ($outCount)', isDark),
                              ],
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                        
                        const SizedBox(width: 16),
                        _buildWarehouseSelector(context, ref),
                        const SizedBox(width: 8),
                        _buildFilterBtn(context, FluentIcons.arrow_sort_20_regular, "Trier"),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? theme.colorScheme.surface : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
                      width: 1.5,
                    ),
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

  Widget _buildMiniStat(bool isDark, String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            value, 
            style: TextStyle(
              fontSize: 13, 
              fontWeight: FontWeight.w900, 
              color: isDark ? Colors.white : Colors.black87
            )
          ),
          const SizedBox(width: 4),
          Text(
            label, 
            style: TextStyle(
              fontSize: 11, 
              fontWeight: FontWeight.w600, 
              color: color
            )
          ),
        ],
      ),
    );
  }

  Widget _buildStockChip(String value, String label, bool isDark) {
    final isSelected = _stockFilter == value;
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(
        label, 
        style: TextStyle(
          fontSize: 11, 
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected 
              ? (isDark ? Colors.white : theme.colorScheme.primary)
              : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
        ),
      ),
      selected: isSelected,
      onSelected: (_) => ref.read(productsStockFilterProvider.notifier).update(value),
      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF3F4F6),
      side: BorderSide(
        color: isSelected 
            ? theme.colorScheme.primary.withValues(alpha: 0.4) 
            : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      showCheckmark: false,
    );
  }

  Widget _buildFilterBtn(BuildContext context, IconData icon, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
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

  void _handleInvoiceImport(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const InvoiceImportWizard(),
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
    final theme = Theme.of(context);

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade300,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: warehousesAsync.when(
          data: (warehouses) => DropdownButton<String?>(
            value: selectedWarehouseId,
            hint: const Text("Tous les entrepôts", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            onChanged: (id) => ref.read(selectedWarehouseIdProvider.notifier).setId(id),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text("🌍 Tous les entrepôts", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              ...warehouses.map((w) => DropdownMenuItem<String?>(
                value: w.id,
                child: Text(
                  "${w.isDefault ? '🏠 ' : '📦 '}${w.name}", 
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              )),
            ],
            icon: const Icon(FluentIcons.chevron_down_20_regular, size: 16),
            dropdownColor: isDark ? const Color(0xFF0A0A0A) : theme.colorScheme.surface,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          loading: () => const SizedBox(width: 100, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))),
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
      borderRadius: BorderRadius.circular(16),
      child: Scrollbar(
        controller: _verticalController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _verticalController,
          scrollDirection: Axis.vertical,
          physics: const BouncingScrollPhysics(),
          child: Scrollbar(
            controller: _horizontalController,
            notificationPredicate: (n) => n.depth == 0,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Theme(
                data: theme.copyWith(
                  cardColor: isDark ? theme.colorScheme.surface : Colors.white,
                  dividerColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                  dataTableTheme: DataTableThemeData(
                    headingRowColor: WidgetStatePropertyAll(isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50),
                    dividerThickness: 1,
                  ),
                ),
                child: DataTable(
                  showCheckboxColumn: false,
                  dataRowMaxHeight: 68,
                  dataRowMinHeight: 60,
                  headingRowHeight: 46,
                  columnSpacing: 24,
                  horizontalMargin: 24,
                  columns: [
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
                        DataCell(Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF070709) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade300,
                                  width: 1,
                                ),
                                image: p.imagePath != null
                                    ? DecorationImage(
                                        image: ImageResolver.getProductImage(p.imagePath, ref.watch(shopSettingsProvider).value), 
                                        fit: BoxFit.cover
                                      )
                                    : null,
                              ),
                              child: p.imagePath == null
                                  ? Icon(FluentIcons.image_24_regular, color: isDark ? Colors.grey.shade700 : Colors.grey.shade400, size: 20)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    p.name, 
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold, 
                                      fontSize: 14, 
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    p.category ?? "Général", 
                                    style: TextStyle(
                                      fontSize: 11, 
                                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade100, 
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade300),
                          ),
                          child: Text(
                            p.barcode ?? "—", 
                            style: TextStyle(
                              fontSize: 11, 
                              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700, 
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        )),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: p.isOutOfStock 
                                ? const Color(0xFFEF4444).withValues(alpha: 0.1) 
                                : (p.isLowStock ? const Color(0xFFF59E0B).withValues(alpha: 0.1) : const Color(0xFF10B981).withValues(alpha: 0.1)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: p.isOutOfStock 
                                  ? const Color(0xFFEF4444).withValues(alpha: 0.25) 
                                  : (p.isLowStock ? const Color(0xFFF59E0B).withValues(alpha: 0.25) : const Color(0xFF10B981).withValues(alpha: 0.25)),
                            ),
                          ),
                          child: Text(
                            p.isOutOfStock ? "RUPTURE" : (p.isLowStock ? "STOCK BAS" : "DISPONIBLE"),
                            style: TextStyle(
                              color: p.isOutOfStock 
                                  ? const Color(0xFFEF4444) 
                                  : (p.isLowStock ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        )),
                        DataCell(Text(
                          ref.fmt(p.sellingPrice), 
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        )),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ref.qty(p.quantity), 
                              style: TextStyle(
                                fontWeight: FontWeight.w900, 
                                fontSize: 15, 
                                color: p.isOutOfStock 
                                    ? const Color(0xFFEF4444) 
                                    : (p.isLowStock ? const Color(0xFFF59E0B) : (isDark ? Colors.white : Colors.black)),
                              ),
                            ),
                            if (p.unit != null) ...[
                              const SizedBox(width: 4),
                              Text(
                                p.unit!, 
                                style: TextStyle(fontSize: 10, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                              ),
                            ],
                          ],
                        )),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message: "Modifier l'article", 
                              child: IconButton(
                                icon: const Icon(FluentIcons.edit_16_regular, size: 16, color: Colors.blue), 
                                onPressed: () => widget.onEdit(p),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              )
                            ),
                            const SizedBox(width: 8),
                            PopupMenuButton<int>(
                              icon: const Icon(FluentIcons.more_vertical_20_regular, size: 18, color: Colors.grey),
                              tooltip: "Options",
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
                                  width: 1,
                                ),
                              ),
                              color: isDark ? theme.colorScheme.surface : Colors.white,
                              onSelected: (val) {
                                switch(val) {
                                  case 0: widget.onDetail(p); break;
                                  case 1: _showMovementHistory(context, p); break;
                                  case 2: 
                                    Future.delayed(const Duration(milliseconds: 50), () {
                                      if (!context.mounted) return;
                                      showDialog(context: context, builder: (_) => TransferStockDialog(initialProduct: p));
                                    });
                                    break;
                                  case 3: 
                                    if (widget.onDelete != null) widget.onDelete!(p);
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 0, child: Row(children: [Icon(FluentIcons.info_20_regular, size: 18, color: Colors.grey), SizedBox(width: 12), Text("Détails complets")])),
                                const PopupMenuItem(value: 1, child: Row(children: [Icon(FluentIcons.history_20_regular, size: 18, color: Colors.grey), SizedBox(width: 12), Text("Historique stock")])),
                                const PopupMenuItem(value: 2, child: Row(children: [Icon(FluentIcons.arrow_swap_20_regular, size: 18, color: Colors.grey), SizedBox(width: 12), Text("Transférer")])),
                                if (ref.watch(authServiceProvider).value?.isAdmin ?? false) ...[
                                  const PopupMenuDivider(),
                                  const PopupMenuItem(value: 3, child: Row(children: [Icon(FluentIcons.delete_20_regular, size: 18, color: Colors.red), SizedBox(width: 12), Text("Supprimer", style: TextStyle(color: Colors.red))])),
                                ],
                              ],
                            ),
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
