import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/features/inventory/domain/models/product.dart';
import 'package:danaya_plus/features/inventory/providers/product_providers.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/features/assistant/application/gemini_service.dart';
import 'package:danaya_plus/features/assistant/application/nlp_engine.dart';
import 'package:danaya_plus/features/srm/providers/supplier_providers.dart';
import 'package:danaya_plus/features/srm/domain/models/supplier.dart';

class InvoiceImportWizard extends ConsumerStatefulWidget {
  final List<int>? preloadedBytes;
  final String? preloadedMimeType;
  final String? preloadedName;

  const InvoiceImportWizard({
    super.key,
    this.preloadedBytes,
    this.preloadedMimeType,
    this.preloadedName,
  });

  @override
  ConsumerState<InvoiceImportWizard> createState() => _InvoiceImportWizardState();
}

class _InvoiceImportWizardState extends ConsumerState<InvoiceImportWizard> {
  int _currentStep = 0;
  bool _isLoading = false;
  String _loadingMessage = "";

  // Selected File details
  List<int>? _fileBytes;
  String? _fileName;
  String? _mimeType;

  // Extracted products
  List<Map<String, dynamic>> _extractedProducts = [];

  // Controllers for editing table
  final List<Map<String, TextEditingController>> _controllers = [];

  // Supplier details from OCR
  Map<String, dynamic>? _extractedSupplier;
  Supplier? _selectedSupplier;

  @override
  void initState() {
    super.initState();
    if (widget.preloadedBytes != null && widget.preloadedMimeType != null) {
      _fileBytes = widget.preloadedBytes;
      _mimeType = widget.preloadedMimeType;
      _fileName = widget.preloadedName ?? "Fichier_joint";
      _currentStep = 1;
      Future.microtask(() => _runOcrAnalysis());
    }
  }

  @override
  void dispose() {
    _clearControllers();
    super.dispose();
  }

  Supplier? _findMatchingSupplier(String name, String phone) {
    final suppliers = ref.read(supplierListProvider).value;
    if (suppliers == null || suppliers.isEmpty) return null;
    
    final cleanName = name.trim().toLowerCase();
    final cleanPhone = phone.trim().replaceAll(RegExp(r'[^\d]'), '');
    
    if (cleanPhone.isNotEmpty) {
      for (final s in suppliers) {
        final sp = s.phone?.replaceAll(RegExp(r'[^\d]'), '') ?? '';
        if (sp.isNotEmpty && sp == cleanPhone) {
          return s;
        }
      }
    }
    
    for (final s in suppliers) {
      if (s.name.trim().toLowerCase() == cleanName) {
        return s;
      }
    }
    
    Supplier? bestMatch;
    double bestScore = 0.0;
    for (final s in suppliers) {
      final sim = math.max(
        NlpEngine.similarity(cleanName, s.name.toLowerCase()),
        NlpEngine.phoneticSimilarity(cleanName, s.name.toLowerCase()),
      );
      if (sim > bestScore && sim >= 0.75) {
        bestScore = sim;
        bestMatch = s;
      }
    }
    
    return bestMatch;
  }

  Future<void> _createNewSupplierDirectly(String name, String phone, String address) async {
    final newSupplier = Supplier(
      id: const Uuid().v4(),
      name: name.trim(),
      phone: phone.trim().isEmpty ? 'N/A' : phone.trim(),
      address: address.trim().isEmpty ? 'N/A' : address.trim(),
      email: '',
    );
    
    try {
      await ref.read(supplierListProvider.notifier).addSupplier(newSupplier);
      setState(() {
        _selectedSupplier = newSupplier;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fournisseur '${newSupplier.name}' enregistré avec succès.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la création du fournisseur : $e")),
        );
      }
    }
  }

  Product? _findMatchingProduct(String name, String refCode) {
    final products = ref.read(productListProvider).value;
    if (products == null || products.isEmpty) return null;
    final cleanName = name.trim().toLowerCase();
    final cleanRef = refCode.trim().toLowerCase();

    // 1. Matcher par référence si renseignée
    if (cleanRef.isNotEmpty) {
      for (final p in products) {
        if (p.reference != null && p.reference!.trim().toLowerCase() == cleanRef) {
          return p;
        }
      }
    }

    // 2. Matcher par nom exact
    for (final p in products) {
      if (p.name.trim().toLowerCase() == cleanName) {
        return p;
      }
    }

    // 3. Matcher par similarité phonétique / orthographique
    Product? bestMatch;
    double bestScore = 0.0;
    for (final p in products) {
      final sim = math.max(
        NlpEngine.similarity(cleanName, p.name.toLowerCase()),
        NlpEngine.phoneticSimilarity(cleanName, p.name.toLowerCase()),
      );
      if (sim > bestScore && sim >= 0.75) {
        bestScore = sim;
        bestMatch = p;
      }
    }

    return bestMatch;
  }

  Map<String, dynamic>? _getPriceAlert(String name, String refCode, String newPurchasePriceStr) {
    final double? newPrice = double.tryParse(newPurchasePriceStr);
    if (newPrice == null || newPrice <= 0) return null;

    final match = _findMatchingProduct(name, refCode);
    if (match != null && match.purchasePrice > 0 && newPrice > match.purchasePrice) {
      final diffVal = newPrice - match.purchasePrice;
      final diffPercent = (diffVal / match.purchasePrice) * 100;
      return {
        'match': match,
        'oldPrice': match.purchasePrice,
        'diffVal': diffVal,
        'diffPercent': diffPercent,
      };
    }
    return null;
  }

  void _clearControllers() {
    for (var row in _controllers) {
      for (var ctrl in row.values) {
        ctrl.dispose();
      }
    }
    _controllers.clear();
  }

  void _initControllers() {
    _clearControllers();
    for (var prod in _extractedProducts) {
      _controllers.add({
        'name': TextEditingController(text: prod['name']?.toString() ?? ''),
        'reference': TextEditingController(text: prod['reference']?.toString() ?? ''),
        'quantity': TextEditingController(text: prod['quantity']?.toString() ?? '1.0'),
        'purchasePrice': TextEditingController(text: prod['purchase_price']?.toString() ?? '0.0'),
        'sellingPrice': TextEditingController(text: prod['selling_price']?.toString() ?? '0.0'),
        'category': TextEditingController(text: prod['category']?.toString() ?? 'Général'),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return EnterpriseWidgets.buildPremiumDialog(
      context,
      title: "Saisie de Facture par Intelligence Artificielle",
      icon: FluentIcons.sparkle_24_filled,
      width: 900,
      actions: _buildActions(),
      child: _buildBody(),
    );
  }

  List<Widget> _buildActions() {
    if (_isLoading) return [];

    if (_currentStep == 0) {
      return [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Fermer")),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _pickInvoiceFile,
          icon: const Icon(FluentIcons.document_search_24_regular, size: 18),
          label: const Text("Sélectionner Facture (PDF / Image)"),
        ),
      ];
    }

    if (_currentStep == 2) {
      return [
        TextButton(
          onPressed: () {
            setState(() {
              _currentStep = 0;
              _extractedProducts.clear();
              _clearControllers();
            });
          },
          child: const Text("Recommencer"),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _importProductsToInventory,
          icon: const Icon(FluentIcons.arrow_down_24_filled, size: 18),
          label: Text("Enregistrer les ${_controllers.length} articles"),
        ),
      ];
    }

    // Result step or error
    return [
      FilledButton(
        onPressed: () {
          ref.read(productListProvider.notifier).refresh();
          Navigator.pop(context);
        },
        child: const Text("Terminer"),
      ),
    ];
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 3),
            const SizedBox(height: 24),
            Text(
              _loadingMessage,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "Extraction multimodale de votre reçu en cours...",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    switch (_currentStep) {
      case 0: return _buildStepFileSelection();
      case 1: return const Center(child: CircularProgressIndicator());
      case 2: return _buildStepEditTable();
      case 3: return _buildStepResult();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildStepFileSelection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14161E) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF2C2F3D) : const Color(0xFFE5E7EB),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                FluentIcons.scan_camera_28_regular, 
                size: 52, 
                color: theme.colorScheme.primary.withValues(alpha: 0.8)
              ),
              const SizedBox(height: 16),
              const Text(
                "Importation de Factures & Reçus par IA", 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)
              ),
              const SizedBox(height: 8),
              const Text(
                "Sélectionnez un document PDF, une image, un fichier Excel ou CSV de votre facture.\n"
                "L'IA extraira instantanément tous les articles pour les ajouter au stock.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _pickInvoiceFile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(FluentIcons.folder_open_20_regular),
                label: const Text("Parcourir vos fichiers"),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildFeatureCard(
                FluentIcons.text_description_24_regular,
                "Extraction Intelligente",
                "Lit les noms, prix d'achat, de vente et quantités."
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFeatureCard(
                FluentIcons.sparkle_24_regular,
                "Recommandation Catégorielle",
                "L'IA attribue automatiquement des catégories logiques."
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String desc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF11121A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF232533) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.purple, size: 20),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 11, height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildStepEditTable() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final extractedName = _extractedSupplier?['name']?.toString() ?? '';
    final extractedPhone = _extractedSupplier?['phone']?.toString() ?? '';
    final extractedAddress = _extractedSupplier?['address']?.toString() ?? '';

    Widget? supplierWidget;

    if (extractedName.isNotEmpty) {
      final existingMatch = _findMatchingSupplier(extractedName, extractedPhone);
      
      if (existingMatch != null) {
        _selectedSupplier ??= existingMatch;
        supplierWidget = Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(FluentIcons.contact_card_group_24_filled, color: Colors.blue, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Fournisseur identifié sur la facture :",
                      style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "${existingMatch.name} ${existingMatch.phone?.isNotEmpty == true ? '(Tél: ${existingMatch.phone})' : ''}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(FluentIcons.checkmark_circle_20_filled, color: Colors.green, size: 20),
            ],
          ),
        );
      } else {
        supplierWidget = Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(FluentIcons.contact_card_group_24_regular, color: Colors.purple, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Nouveau fournisseur détecté sur la facture :",
                      style: TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "$extractedName ${extractedPhone.isNotEmpty ? '(Tél: $extractedPhone)' : ''}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (_selectedSupplier == null)
                ElevatedButton.icon(
                  onPressed: () => _createNewSupplierDirectly(extractedName, extractedPhone, extractedAddress),
                  icon: const Icon(FluentIcons.add_16_regular, size: 14),
                  label: const Text("Créer la fiche", style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                )
              else
                const Row(
                  children: [
                    Text("Créé", style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 11)),
                    SizedBox(width: 6),
                    Icon(FluentIcons.checkmark_circle_20_filled, color: Colors.purple, size: 16),
                  ],
                ),
            ],
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (supplierWidget != null) supplierWidget,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Articles détectés sur votre facture", 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)
                ),
                const SizedBox(height: 2),
                Text(
                  "Fichier analysé : $_fileName. Ajustez les données avant l'importation.",
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _controllers.add({
                    'name': TextEditingController(text: 'Nouvel article'),
                    'reference': TextEditingController(text: ''),
                    'quantity': TextEditingController(text: '1.0'),
                    'purchasePrice': TextEditingController(text: '0.0'),
                    'sellingPrice': TextEditingController(text: '0.0'),
                    'category': TextEditingController(text: 'Général'),
                  });
                });
              },
              icon: const Icon(FluentIcons.add_16_regular),
              label: const Text("Ajouter une ligne"),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 380,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF11121A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF232533) : const Color(0xFFE5E7EB),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ListView.separated(
              itemCount: _controllers.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final row = _controllers[index];
                final alert = _getPriceAlert(
                  row['name']!.text,
                  row['reference']!.text,
                  row['purchasePrice']!.text,
                );

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Numéro
                          CircleAvatar(
                            radius: 11,
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                            child: Text(
                              "${index + 1}", 
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // Nom Produit
                          Expanded(
                            flex: 3,
                            child: _buildTableCellField("Nom du produit *", row['name']!),
                          ),
                          const SizedBox(width: 10),

                          // Référence
                          Expanded(
                            flex: 2,
                            child: _buildTableCellField("Réf/SKU", row['reference']!),
                          ),
                          const SizedBox(width: 10),

                          // Catégorie
                          Expanded(
                            flex: 2,
                            child: _buildTableCellField("Catégorie", row['category']!),
                          ),
                          const SizedBox(width: 10),

                          // Quantité
                          SizedBox(
                            width: 75,
                            child: _buildTableCellField("Qté *", row['quantity']!, isNumeric: true),
                          ),
                          const SizedBox(width: 10),

                          // Prix Achat
                          SizedBox(
                            width: 95,
                            child: _buildTableCellField("P. Achat *", row['purchasePrice']!, isNumeric: true),
                          ),
                          const SizedBox(width: 10),

                          // Prix Vente
                          SizedBox(
                            width: 95,
                            child: _buildTableCellField("P. Vente *", row['sellingPrice']!, isNumeric: true),
                          ),
                          const SizedBox(width: 10),

                          // Delete Button
                          IconButton(
                            icon: const Icon(FluentIcons.delete_16_regular, color: Colors.redAccent, size: 16),
                            onPressed: () {
                              setState(() {
                                for (var ctrl in row.values) {
                                  ctrl.dispose();
                                }
                                _controllers.removeAt(index);
                              });
                            },
                            tooltip: "Supprimer la ligne",
                          ),
                        ],
                      ),
                      if (alert != null) ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 34),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(FluentIcons.warning_16_filled, color: Colors.amber, size: 14),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    "Hausse de prix détectée pour '${alert['match'].name}' : l'ancien prix d'achat était de ${alert['oldPrice'].toStringAsFixed(0)} FCFA (hausse de +${alert['diffPercent'].toStringAsFixed(1)}% / +${alert['diffVal'].toStringAsFixed(0)} FCFA)",
                                    style: const TextStyle(
                                      color: Colors.amber, 
                                      fontSize: 11, 
                                      fontWeight: FontWeight.bold
                                    ),
                                  ),
                                ),
                                if (alert['match'].sellingPrice > 0 && alert['match'].purchasePrice > 0) ...[
                                  const SizedBox(width: 12),
                                  Builder(
                                    builder: (context) {
                                      final double ratio = alert['match'].sellingPrice / alert['match'].purchasePrice;
                                      final double newPrice = double.tryParse(row['purchasePrice']!.text) ?? 0.0;
                                      final double suggestedSelling = (newPrice * ratio).roundToDouble();
                                      return TextButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            row['sellingPrice']!.text = suggestedSelling.toStringAsFixed(0);
                                          });
                                        },
                                        icon: const Icon(FluentIcons.sparkle_16_regular, color: Colors.amber, size: 14),
                                        label: Text(
                                          "Conserver marge (${suggestedSelling.toStringAsFixed(0)} FCFA)",
                                          style: const TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold),
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          backgroundColor: Colors.amber.withValues(alpha: 0.15),
                                        ),
                                      );
                                    }
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableCellField(String label, TextEditingController controller, {bool isNumeric = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      onChanged: (val) {
        setState(() {});
      },
      keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        filled: true,
        fillColor: isDark ? const Color(0xFF161822) : Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1),
        ),
      ),
    );
  }

  Widget _buildStepResult() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          FluentIcons.checkmark_circle_32_filled,
          size: 72,
          color: Colors.green,
        ),
        const SizedBox(height: 16),
        const Text(
          "Importation terminée avec succès !",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          "Vos ${_extractedProducts.length} articles ont été insérés dans votre stock.",
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withValues(alpha: 0.15)),
          ),
          child: const Row(
            children: [
              Icon(FluentIcons.sparkle_20_filled, color: Colors.green),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "L'IA a calculé le coût et a suggéré une marge par défaut de 25% pour les produits n'ayant pas de prix de vente explicite sur le reçu.",
                  style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- LOGIC FUNCTIONS ---

  String _convertExcelToText(List<int> bytes) {
    try {
      final excel = Excel.decodeBytes(bytes);
      final buffer = StringBuffer();
      for (final table in excel.tables.keys) {
        buffer.writeln("--- Feuille: $table ---");
        final sheet = excel.tables[table];
        if (sheet == null) continue;
        final rowsToProcess = sheet.rows.take(150);
        for (final row in rowsToProcess) {
          final rowText = row.map((cell) => cell?.value?.toString() ?? "").join(" | ");
          buffer.writeln(rowText);
        }
      }
      return buffer.toString();
    } catch (e) {
      return "Erreur lors de la lecture du fichier Excel: $e";
    }
  }

  String _convertCsvToText(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      try {
        return latin1.decode(bytes);
      } catch (_) {
        return String.fromCharCodes(bytes);
      }
    }
  }

  Future<void> _pickInvoiceFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'xlsx', 'csv'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final file = File(path);
        final bytes = await file.readAsBytes();
        
        setState(() {
          _fileBytes = bytes;
          _fileName = result.files.single.name;
          _currentStep = 1;
          
          final ext = path.split('.').last.toLowerCase();
          if (ext == 'pdf') {
            _mimeType = 'application/pdf';
          } else if (ext == 'png') {
            _mimeType = 'image/png';
          } else if (ext == 'xlsx') {
            _mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          } else if (ext == 'csv') {
            _mimeType = 'text/csv';
          } else {
            _mimeType = 'image/jpeg';
          }
        });

        _runOcrAnalysis();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Impossible de lire le fichier : $e")),
        );
      }
    }
  }

  Future<void> _runOcrAnalysis() async {
    if (_fileBytes == null || _mimeType == null) return;

    setState(() {
      _isLoading = true;
      _loadingMessage = "Analyse de la facture par l'IA en cours...";
    });

    try {
      final settings = ref.read(shopSettingsProvider).value;
      final apiKey = settings?.geminiApiKey ?? '';
      
      if (apiKey.isEmpty) {
        throw Exception("Clé API Danaya VIP non configurée dans Paramètres -> Automatisation & IA.");
      }

      final gemini = GeminiService(apiKey: apiKey);
      
      final ext = _fileName?.split('.').last.toLowerCase();
      final Map<String, dynamic> result;
      
      if (ext == 'xlsx' || ext == 'csv') {
        final String textData = ext == 'xlsx'
            ? _convertExcelToText(_fileBytes!)
            : _convertCsvToText(_fileBytes!);
        result = await gemini.analyzeInvoiceText(textData);
      } else {
        result = await gemini.analyzeInvoiceImage(_fileBytes!, _mimeType!);
      }
      
      final supplier = result['supplier'] as Map<String, dynamic>?;
      final List<Map<String, dynamic>> products = List<Map<String, dynamic>>.from(result['products'] as List);

      setState(() {
        _extractedSupplier = supplier;
        _extractedProducts = products;
        _initControllers();
        _isLoading = false;
        _currentStep = 2;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Erreur d'analyse"),
            content: Text(e.toString().replaceAll("Exception: ", "")),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _currentStep = 0);
                },
                child: const Text("Fermer"),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _importProductsToInventory() async {
    // Valider
    for (var i = 0; i < _controllers.length; i++) {
      final row = _controllers[i];
      if (row['name']!.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Le nom du produit à la ligne ${i + 1} est obligatoire.")),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = "Importation des articles en cours...";
    });

    try {
      final listNotifier = ref.read(productListProvider.notifier);
      final String reason = _selectedSupplier != null
          ? "Importation facture - Fournisseur: ${_selectedSupplier!.name}"
          : "Création du produit / Stock initial via OCR";

      for (var row in _controllers) {
        final double qty = double.tryParse(row['quantity']!.text) ?? 1.0;
        final double pPrice = double.tryParse(row['purchasePrice']!.text) ?? 0.0;
        final double sPrice = double.tryParse(row['sellingPrice']!.text) ?? 0.0;

        final newProduct = Product(
          id: const Uuid().v4(),
          name: row['name']!.text.trim(),
          reference: row['reference']!.text.trim().isEmpty ? null : row['reference']!.text.trim(),
          quantity: qty,
          purchasePrice: pPrice,
          sellingPrice: sPrice,
          alertThreshold: 5.0,
          category: row['category']!.text.trim().isEmpty ? "Général" : row['category']!.text.trim(),
          weightedAverageCost: pPrice,
        );

        await listNotifier.addProduct(newProduct, reason: reason);
      }

      setState(() {
        _isLoading = false;
        _currentStep = 3;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'enregistrement : $e")),
        );
      }
    }
  }
}
