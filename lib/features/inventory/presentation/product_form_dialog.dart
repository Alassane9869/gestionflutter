import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/inventory/domain/models/product.dart';
import 'package:danaya_plus/features/inventory/providers/product_providers.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/features/inventory/providers/warehouse_providers.dart';
import 'package:danaya_plus/features/inventory/data/product_repository.dart';
import 'package:danaya_plus/core/network/client_sync_service.dart';
import 'package:danaya_plus/core/utils/image_resolver.dart';
import 'package:danaya_plus/features/inventory/application/inventory_automation_service.dart';
import 'widgets/label_printing_utils.dart';

class ProductFormDialog extends ConsumerStatefulWidget {
  final Product? product;

  const ProductFormDialog({super.key, this.product});

  @override
  ConsumerState<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends ConsumerState<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _referenceController;
  late final TextEditingController _categoryController;
  late final TextEditingController _locationController;
  late final TextEditingController _quantityController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _alertThresholdController;
  late final TextEditingController _descriptionController;
  String? _imagePath;
  String? _selectedWarehouseId;
  List<String> _existingCategories = [];
  
  bool _isService = false;
  String? _selectedUnit;

  static const List<String> _standardUnits = [
    'Pièce', 'kg', 'g', 'Litre', 'ml', 'Mètre', 'cm', 'm²', 'm³', 
    'Sac', 'Boîte', 'Carton', 'Palette', 'Paquet', 'Heure', 'Jour', 'Forfait', 'Unité'
  ];

  bool get isEditing => widget.product != null;

  String _formatNumber(double? value, {String fallback = "0"}) {
    if (value == null) return fallback;
    return value == value.toInt() ? value.toInt().toString() : value.toString();
  }

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? "");
    _barcodeController = TextEditingController(text: p?.barcode ?? "");
    _referenceController = TextEditingController(text: p?.reference ?? "");
    _categoryController = TextEditingController(text: p?.category ?? "");
    _locationController = TextEditingController(text: p?.location ?? "");
    _quantityController = TextEditingController(text: _formatNumber(p?.quantity, fallback: "0"));
    _purchasePriceController = TextEditingController(text: _formatNumber(p?.purchasePrice, fallback: "0"));
    _sellingPriceController = TextEditingController(text: _formatNumber(p?.sellingPrice, fallback: "0"));
    _alertThresholdController = TextEditingController(text: _formatNumber(p?.alertThreshold, fallback: "5"));
    _descriptionController = TextEditingController(text: p?.description ?? "");
    _imagePath = p?.imagePath;
    _isService = p?.isService ?? false;
    _selectedUnit = p?.unit;
    
    if (!isEditing) {
      _selectedWarehouseId = ref.read(selectedWarehouseIdProvider);
    }
    
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await ref.read(productRepositoryProvider).getCategories();
    if (mounted) {
      setState(() {
        _existingCategories = categories;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final appDir = await getApplicationSupportDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'product_images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      
      final fileName = '${const Uuid().v4()}${p.extension(pickedFile.path)}';
      final savedImage = await File(pickedFile.path).copy(p.join(imagesDir.path, fileName));
      
      setState(() {
        _imagePath = savedImage.path;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _referenceController.dispose();
    _categoryController.dispose();
    _locationController.dispose();
    _quantityController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _alertThresholdController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final product = Product(
      id: widget.product?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
      reference: _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
      category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
      quantity: _isService ? 0.0 : (double.tryParse(_quantityController.text) ?? 0.0),
      purchasePrice: double.tryParse(_purchasePriceController.text) ?? 0.0,
      sellingPrice: double.tryParse(_sellingPriceController.text) ?? 0.0,
      alertThreshold: double.tryParse(_alertThresholdController.text) ?? 5.0,
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      imagePath: _imagePath,
      location: _isService ? null : (_locationController.text.trim().isEmpty ? null : _locationController.text.trim()),
      isService: _isService,
      unit: _selectedUnit,
    );

    _performSave(product);
  }

  Future<void> _performSave(Product product) async {
    try {
      final settings = ref.read(shopSettingsProvider).value;
      String? finalImagePath = _imagePath;

      if (_imagePath != null && 
          File(_imagePath!).existsSync() && 
          settings?.networkMode != NetworkMode.solo) {
        
        final fileName = await ref.read(clientSyncProvider).uploadImage(File(_imagePath!));
        if (fileName != null) {
          finalImagePath = fileName;
        }
      }

      final updatedProduct = product.copyWith(imagePath: finalImagePath);

      if (isEditing) {
        await ref.read(productListProvider.notifier).updateProduct(updatedProduct);
      } else {
        await ref.read(productListProvider.notifier).addProduct(updatedProduct, warehouseId: _selectedWarehouseId);
      }

      // Ultra Pro: UI-Driven Auto-Print Validation
      if (mounted) {
        if (!isEditing && settings?.autoPrintLabelsOnStockIn == true && updatedProduct.quantity > 0) {
          // One-shot check for newly added quantity
          final List<Product> printQueue = List.generate(updatedProduct.quantity.ceil(), (_) => updatedProduct);
          
          await LabelPrintingUtils.confirmAndPrintLabels(
            context,
            ref,
            products: printQueue,
            sourceAction: "Création du produit ${updatedProduct.name}",
          );
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEditing ? "Article modifié !" : "Article ajouté !"),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Oups ! Une erreur est survenue lors de l'enregistrement : $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAdjustmentDialog() {
    final ctrl = TextEditingController(text: _quantityController.text);
    String reason = "Erreur de saisie / Correction";
    final reasons = ["Casse / Perte", "Don / Échantillon", "Erreur de saisie / Correction", "Retour Client", "Inventaire Physique"];

    showDialog(
      context: context,
      builder: (context) => EnterpriseWidgets.buildPremiumDialog(
        context,
        title: "Ajuster le Stock",
        icon: FluentIcons.box_edit_24_regular,
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EnterpriseWidgets.buildPremiumTextField(
              context,
              ctrl: ctrl,
              label: "NOUVELLE QUANTITÉ",
              icon: FluentIcons.box_24_regular,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            EnterpriseWidgets.buildPremiumDropdown<String>(
              label: "RAISON DU CHANGEMENT",
              value: reason,
              icon: FluentIcons.info_24_regular,
              items: reasons,
              itemLabel: (r) => r,
              onChanged: (val) => reason = val!,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          FilledButton(
            onPressed: () {
              setState(() {
                _quantityController.text = ctrl.text;
              });
              Navigator.pop(context);
            },
            child: const Text("Confirmer"),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Divider(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(shopSettingsProvider).value;
    final currency = settings?.currency ?? 'FCFA';
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final bool useWideLayout = isLandscape && size.width > 800;

    return EnterpriseWidgets.buildPremiumDialog(
      context,
      title: isEditing ? "Modifier l'article" : "Nouvel Article",
      icon: FluentIcons.box_24_regular,
      width: useWideLayout ? 900 : 550,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        label: Text("PRODUIT PHYSIQUE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        icon: Icon(FluentIcons.box_20_regular, size: 16),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text("SERVICE / MAIN D'ŒUVRE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        icon: Icon(FluentIcons.wrench_20_regular, size: 16),
                      ),
                    ],
                    selected: {_isService},
                    onSelectionChanged: (Set<bool> newSelection) {
                      setState(() {
                        _isService = newSelection.first;
                      });
                    },
                  ),
                ],
              ),

              _buildSectionHeader("Identification de l'article", FluentIcons.contact_card_group_24_regular),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: useWideLayout ? 110 : 100,
                          height: useWideLayout ? 110 : 100,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                            image: _imagePath != null
                                ? DecorationImage(
                                    image: ImageResolver.getProductImage(_imagePath, settings), 
                                    fit: BoxFit.cover
                                  )
                                : null,
                          ),
                          child: _imagePath == null
                              ? const Icon(FluentIcons.image_add_24_regular, color: Colors.grey, size: 28)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: useWideLayout ? 110 : 100,
                        child: OutlinedButton(
                          onPressed: _pickImage,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text("PHOTO", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: Column(
                      children: [
                        EnterpriseWidgets.buildPremiumTextField(
                          context,
                          ctrl: _nameController,
                          label: "DÉSIGNATION / NOM ARTICLE *",
                          hint: "Ex: Samsung Galaxy S23",
                          icon: FluentIcons.tag_24_regular,
                          validator: (v) => v == null || v.trim().isEmpty ? "Nom requis" : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Autocomplete<String>(
                                initialValue: TextEditingValue(text: _categoryController.text),
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) return _existingCategories;
                                  return _existingCategories.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                },
                                onSelected: (String selection) => _categoryController.text = selection,
                                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                  return EnterpriseWidgets.buildPremiumTextField(
                                    context,
                                    ctrl: controller,
                                    focusNode: focusNode,
                                    label: "CATÉGORIE",
                                    hint: "Ex: Smartphones...",
                                    icon: FluentIcons.grid_24_regular,
                                    onChanged: (val) => _categoryController.text = val,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Stack(
                                alignment: Alignment.centerRight,
                                children: [
                                  EnterpriseWidgets.buildPremiumTextField(
                                    context,
                                    ctrl: _barcodeController,
                                    label: "CODE BARRES / EAN",
                                    icon: FluentIcons.barcode_scanner_24_regular,
                                    hint: "Scanner ou générer...",
                                  ),
                                  Positioned(
                                    right: 4,
                                    top: 24,
                                    child: IconButton(
                                      icon: Icon(FluentIcons.flash_24_regular, color: Theme.of(context).colorScheme.primary, size: 18),
                                      tooltip: "Générer un code unique",
                                      onPressed: () async {
                                        final code = await ref.read(inventoryAutomationServiceProvider).generateUniqueBarcode();
                                        setState(() => _barcodeController.text = code);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              _buildSectionHeader("Finances & Tarification", FluentIcons.money_hand_24_regular),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: EnterpriseWidgets.buildPremiumTextField(
                      context,
                      ctrl: _purchasePriceController,
                      label: "PRIX D'ACHAT HT ($currency)",
                      icon: FluentIcons.money_hand_24_regular,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: EnterpriseWidgets.buildPremiumTextField(
                      context,
                      ctrl: _sellingPriceController,
                      label: "PRIX DE VENTE ($currency)",
                      icon: FluentIcons.money_24_regular,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder(
                valueListenable: _sellingPriceController,
                builder: (context, sell, _) {
                  return ValueListenableBuilder(
                    valueListenable: _purchasePriceController,
                    builder: (context, buy, _) {
                      final s = double.tryParse(sell.text) ?? 0.0;
                      final b = double.tryParse(buy.text) ?? 0.0;
                      if (s > 0 && b > 0) {
                        final margin = s - b;
                        final isLoss = margin < 0;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (isLoss ? Colors.red : Colors.green).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: (isLoss ? Colors.red : Colors.green).withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            children: [
                              Icon(isLoss ? FluentIcons.warning_24_regular : FluentIcons.checkmark_circle_24_regular, 
                                color: isLoss ? Colors.red : Colors.green, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  isLoss 
                                    ? "ALERTE : Vente à perte ! Votre marge est de ${margin.toStringAsFixed(0)} $currency"
                                    : "PROFIT ESTIMÉ : Votre marge brute est de ${margin.toStringAsFixed(0)} $currency par unité.",
                                  style: TextStyle(
                                    color: isLoss ? Colors.red.shade800 : Colors.green.shade800, 
                                    fontSize: 12, 
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  );
                },
              ),

              _buildSectionHeader("Logistique & Gestion Stock", FluentIcons.box_edit_24_regular),
              Row(
                children: [
                  Expanded(
                    child: EnterpriseWidgets.buildPremiumTextField(
                      context,
                      ctrl: _referenceController,
                      label: "RÉFÉRENCE INTERNE (SKU)",
                      icon: FluentIcons.number_symbol_24_regular,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: EnterpriseWidgets.buildPremiumDropdown<String>(
                      label: "UNITÉ DE MESURE",
                      value: _selectedUnit,
                      icon: FluentIcons.ruler_24_regular,
                      items: _standardUnits,
                      itemLabel: (u) => u,
                      onChanged: (val) => setState(() => _selectedUnit = val),
                    ),
                  ),
                ],
              ),
              
              if (!_isService) ...[
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Stack(
                        alignment: Alignment.centerRight,
                        children: [
                          EnterpriseWidgets.buildPremiumTextField(
                            context,
                            ctrl: _quantityController,
                            label: "QUANTITÉ EN STOCK",
                            icon: FluentIcons.box_24_regular,
                            readOnly: isEditing,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            suffix: isEditing ? Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(_selectedUnit ?? "", style: TextStyle(color: Theme.of(context).hintColor, fontSize: 10, fontWeight: FontWeight.bold)),
                            ) : null,
                          ),
                          if (isEditing)
                            Positioned(
                              right: 4,
                              top: 24,
                              child: IconButton(
                                icon: Icon(FluentIcons.edit_settings_24_regular, color: Theme.of(context).colorScheme.primary, size: 18),
                                tooltip: "Ajuster le stock manuellement",
                                onPressed: () => _showAdjustmentDialog(),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EnterpriseWidgets.buildPremiumTextField(
                        context,
                        ctrl: _alertThresholdController,
                        label: "SEUIL D'ALERTE",
                        icon: FluentIcons.warning_24_regular,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        tooltip: "Le système vous alertera quand le stock sera inférieur à cette valeur.",
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: EnterpriseWidgets.buildPremiumTextField(
                        context,
                        ctrl: _locationController,
                        label: "LOCALISATION (MAGASIN / RAYON)",
                        hint: "Ex: Rayon A, Étagère 3",
                        icon: FluentIcons.location_24_regular,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (!isEditing) 
                      Expanded(
                        child: ref.watch(warehouseListProvider).when(
                          data: (warehouses) {
                            if (warehouses.isNotEmpty && 
                                (_selectedWarehouseId == null || !warehouses.any((w) => w.id == _selectedWarehouseId))) {
                              final defaultId = warehouses.first.id;
                              if (_selectedWarehouseId != defaultId) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) setState(() => _selectedWarehouseId = defaultId);
                                });
                              }
                            }
                            
                            return EnterpriseWidgets.buildPremiumDropdown<String>(
                              label: "STOCKER DANS",
                              value: _selectedWarehouseId,
                              icon: FluentIcons.building_shop_24_regular,
                              items: warehouses.map((w) => w.id).toList(),
                              itemLabel: (id) => warehouses.firstWhere((w) => w.id == id).name,
                              onChanged: (val) => setState(() => _selectedWarehouseId = val),
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => const Text("Erreur"),
                        ),
                      ),
                  ],
                ),
              ],
              
              _buildSectionHeader("Informations Complémentaires", FluentIcons.text_description_24_regular),
              EnterpriseWidgets.buildPremiumTextField(
                context,
                ctrl: _descriptionController,
                label: "DESCRIPTION / NOTES",
                hint: "Détails techniques, composition, ou notes internes...",
                icon: FluentIcons.text_description_24_regular,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      actions: [
        if (isEditing)
          TextButton.icon(
            onPressed: () => _confirmDelete(),
            icon: const Icon(FluentIcons.delete_20_regular, color: Colors.red, size: 18),
            label: const Text("Supprimer / Archiver", style: TextStyle(color: Colors.red)),
          ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Annuler"),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: Icon(isEditing ? FluentIcons.save_20_regular : FluentIcons.add_20_regular, size: 18),
          label: Text(isEditing ? "Enregistrer les modifications" : "Ajouter au stock", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
      ],
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => EnterpriseWidgets.buildPremiumDialog(
        context,
        title: "Confirmer la suppression",
        icon: FluentIcons.warning_24_regular,
        width: 400,
        child: const Text(
          "Voulez-vous supprimer cet article ?\n\nNote : Si l'article possède un historique de vente, il sera automatiquement ARCHIVÉ pour préserver vos rapports comptables.",
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ref.read(productListProvider.notifier).deleteProduct(widget.product!.id);
              if (!context.mounted) return;
              Navigator.pop(context); // Ferme le dialogue de confirmation
              Navigator.pop(context); // Ferme le formulaire produit
            },
            child: const Text("Confirmer"),
          ),
        ],
      ),
    );
  }
}
