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
  
  // Nouveaux champs v42
  bool _isService = false;
  String? _selectedUnit;

  // Liste des unités standardisées
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
    
    // Si on n'est pas en édition, on tente de récupérer l'entrepôt du filtre global.
    // S'il est à null (Tous les entrepôts), on le garde à null pour l'instant et on gérera le fallback dans le builder.
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
      quantity: (double.tryParse(_quantityController.text) ?? 0.0).abs(),
      purchasePrice: (double.tryParse(_purchasePriceController.text) ?? 0.0).abs(),
      sellingPrice: (double.tryParse(_sellingPriceController.text) ?? 0.0).abs(),
      alertThreshold: (double.tryParse(_alertThresholdController.text) ?? 5.0).abs(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      imagePath: _imagePath,
      location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      isService: _isService,
      unit: _selectedUnit,
    );

    _performSave(product);
  }

  Future<void> _performSave(Product product) async {
    try {
      final settings = ref.read(shopSettingsProvider).value;
      String? finalImagePath = _imagePath;

      // Si on a une image locale (pas encore sur le serveur) et qu'on est en mode client/serveur
      if (_imagePath != null && 
          File(_imagePath!).existsSync() && 
          settings?.networkMode != NetworkMode.solo) {
        
        // Upload vers le serveur
        final fileName = await ref.read(clientSyncProvider).uploadImage(File(_imagePath!));
        if (fileName != null) {
          finalImagePath = fileName; // On stocke juste le nom de fichier
        }
      }

      final updatedProduct = product.copyWith(imagePath: finalImagePath);

      if (isEditing) {
        await ref.read(productListProvider.notifier).updateProduct(updatedProduct);
      } else {
        await ref.read(productListProvider.notifier).addProduct(updatedProduct, warehouseId: _selectedWarehouseId);
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
              // --- TYPE SELECTOR (Plus discret) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        label: Text("Physique", style: TextStyle(fontSize: 12)),
                        icon: Icon(FluentIcons.box_20_regular, size: 16),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text("Service", style: TextStyle(fontSize: 12)),
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
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // IMAGE (Compacte)
                  Column(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: useWideLayout ? 100 : 90,
                          height: useWideLayout ? 100 : 90,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                            image: _imagePath != null
                                ? DecorationImage(
                                    image: ImageResolver.getProductImage(_imagePath, settings), 
                                    fit: BoxFit.cover
                                  )
                                : null,
                          ),
                          child: _imagePath == null
                              ? const Icon(FluentIcons.image_add_24_regular, color: Colors.grey, size: 24)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(FluentIcons.image_edit_20_regular, size: 16),
                          label: const Text("MODIFIER PHOTO", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  
                  // BASIC INFO
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: EnterpriseWidgets.buildPremiumTextField(
                                context,
                                ctrl: _nameController,
                                label: "NOM ARTICLE *",
                                hint: "Ex: Peinture VIP",
                                icon: FluentIcons.tag_24_regular,
                                validator: (v) => v == null || v.trim().isEmpty ? "Requis" : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: EnterpriseWidgets.buildPremiumDropdown<String>(
                                label: "UNITÉ",
                                value: _selectedUnit,
                                icon: FluentIcons.ruler_24_regular,
                                items: _standardUnits,
                                itemLabel: (u) => u,
                                onChanged: (val) => setState(() => _selectedUnit = val),
                              ),
                            ),
                          ],
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
                                    hint: "Ex: Alimentation...",
                                    icon: FluentIcons.grid_24_regular,
                                    onChanged: (val) => _categoryController.text = val,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: EnterpriseWidgets.buildPremiumTextField(
                                context,
                                ctrl: _barcodeController,
                                label: "CODE BARRES",
                                icon: FluentIcons.barcode_scanner_24_regular,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- ROW: PRICES (Compact) ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: EnterpriseWidgets.buildPremiumTextField(
                      context,
                      ctrl: _purchasePriceController,
                      label: "ACHAT ($currency)",
                      icon: FluentIcons.money_hand_24_regular,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: EnterpriseWidgets.buildPremiumTextField(
                      context,
                      ctrl: _sellingPriceController,
                      label: "VENTE ($currency)",
                      icon: FluentIcons.money_24_regular,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: EnterpriseWidgets.buildPremiumTextField(
                      context,
                      ctrl: _referenceController,
                      label: "SKU / RÉF.",
                      icon: FluentIcons.number_symbol_24_regular,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- STOCK SECTION ---
              if (!_isService) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: EnterpriseWidgets.buildPremiumTextField(
                        context,
                        ctrl: _quantityController,
                        label: "STOCK",
                        icon: FluentIcons.box_24_regular,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EnterpriseWidgets.buildPremiumTextField(
                        context,
                        ctrl: _alertThresholdController,
                        label: "SEUIL",
                        icon: FluentIcons.warning_24_regular,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EnterpriseWidgets.buildPremiumTextField(
                        context,
                        ctrl: _locationController,
                        label: "RANGEMENT",
                        hint: "A2",
                        icon: FluentIcons.location_28_regular,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!isEditing) 
                  ref.watch(warehouseListProvider).when(
                    data: (warehouses) {
                      if (warehouses.isNotEmpty) {
                        if (_selectedWarehouseId == null || !warehouses.any((w) => w.id == _selectedWarehouseId)) {
                           _selectedWarehouseId = warehouses.first.id;
                        }
                      }
                      
                      return EnterpriseWidgets.buildPremiumDropdown<String>(
                        label: "ENTREPÔT",
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
              ],
              
              const SizedBox(height: 12),
              EnterpriseWidgets.buildPremiumTextField(
                context,
                ctrl: _descriptionController,
                label: "DESCRIPTION",
                icon: FluentIcons.text_description_24_regular,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Annuler"),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: Icon(isEditing ? FluentIcons.save_20_regular : FluentIcons.add_20_regular, size: 18),
          label: Text(isEditing ? "Enregistrer" : "Ajouter", style: const TextStyle(fontSize: 13)),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }
}
