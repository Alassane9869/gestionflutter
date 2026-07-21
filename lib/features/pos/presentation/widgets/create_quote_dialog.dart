import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/pos/services/quote_service.dart';
import 'package:danaya_plus/features/pos/providers/quote_providers.dart';
import 'package:danaya_plus/features/clients/providers/client_providers.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/inventory/providers/product_providers.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/features/clients/domain/models/client.dart';
import 'package:danaya_plus/features/assistant/application/assistant_service.dart';

class CreateQuoteDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? quote; // For edit mode
  final String? initialClientName;

  const CreateQuoteDialog({super.key, this.quote, this.initialClientName});

  @override
  ConsumerState<CreateQuoteDialog> createState() => _CreateQuoteDialogState();
}

class _CreateQuoteDialogState extends ConsumerState<CreateQuoteDialog> {
  final List<QuoteItem> _items = [];
  String? _selectedClientId;
  late DateTime _validUntil;

  late final TextEditingController _validityDaysCtrl;
  final _customNameCtrl = TextEditingController();
  final _customPriceCtrl = TextEditingController();
  final _customQtyCtrl = TextEditingController(text: '1');
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  dynamic _assistantNotifier;

  double get _subtotal => _items.fold(0, (sum, item) => sum + item.lineTotal);
  double get _total => _subtotal;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(shopSettingsProvider).value;
    final defaultDays = settings?.quoteValidityDays ?? 30;
    _validityDaysCtrl = TextEditingController(text: defaultDays.toString());
    _validUntil = DateTime.now().add(Duration(days: defaultDays));

    if (widget.quote != null) {
      _selectedClientId = widget.quote!['client_id'];
      if (widget.quote!['valid_until'] != null) {
        _validUntil = DateTime.parse(widget.quote!['valid_until']);
        _validityDaysCtrl.text = _validUntil.difference(DateTime.now()).inDays.clamp(0, 365).toString();
      }
      final itemsData = widget.quote!['items'] as List;
      for (var i in itemsData) {
        _items.add(
          QuoteItemWithId(
            name: i['custom_name'] ?? 'Article',
            qty: (i['quantity'] as num).toDouble(),
            unitPrice: (i['unit_price'] as num).toDouble(),
            unit: i['unit']?.toString(),
            description: i['description']?.toString(),
            discountAmount: (i['discount_amount'] as num?)?.toDouble() ?? 0.0,
            productId: i['product_id'],
          ),
        );
      }
    }

    if (widget.initialClientName != null && widget.initialClientName!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final clients = await ref.read(clientListProvider.future);
        final cleanName = widget.initialClientName!.trim().toLowerCase();
        Client? match;
        for (final c in clients) {
          if (c.name.trim().toLowerCase() == cleanName) {
            match = c;
            break;
          }
        }
        if (match == null) {
          for (final c in clients) {
            if (c.name.toLowerCase().contains(cleanName)) {
              match = c;
              break;
            }
          }
        }
        if (match != null && mounted) {
          setState(() {
            _selectedClientId = match!.id;
          });
        }
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _assistantNotifier = ref.read(assistantProvider.notifier);
        _assistantNotifier.setActiveDialog(
          widget.quote != null ? 'Modification Devis' : 'Création Devis'
        );
        _assistantNotifier.onAddProductToActiveQuote = (product, qty) {
          if (mounted) {
            _addItem(QuoteItemWithId(
              name: product.name,
              qty: qty,
              unitPrice: product.sellingPrice,
              unit: product.unit,
              productId: product.id,
            ));
          }
        };
        _assistantNotifier.onSelectClientInActiveQuote = (client) {
          if (mounted) {
            setState(() {
              _selectedClientId = client.id;
            });
          }
        };
        _assistantNotifier.onSaveActiveQuote = () {
          if (mounted) {
            _saveQuote();
          }
        };
        _assistantNotifier.onGetActiveQuoteCart = () {
          return _items.map((e) {
            if (e is QuoteItemWithId) {
              return {
                'name': e.name,
                'quantity': e.qty,
                'unit_price': e.unitPrice,
                'total': e.lineTotal,
                'product_id': e.productId,
              };
            }
            return {
              'name': e.name,
              'quantity': e.qty,
              'unit_price': e.unitPrice,
              'total': e.lineTotal,
            };
          }).toList();
        };
      }
    });
  }

  @override
  void dispose() {
    _validityDaysCtrl.dispose();
    _customNameCtrl.dispose();
    _customPriceCtrl.dispose();
    _customQtyCtrl.dispose();
    _searchCtrl.dispose();
    if (_assistantNotifier != null) {
      _assistantNotifier.setActiveDialog(null);
      _assistantNotifier.onAddProductToActiveQuote = null;
      _assistantNotifier.onSelectClientInActiveQuote = null;
      _assistantNotifier.onSaveActiveQuote = null;
      _assistantNotifier.onGetActiveQuoteCart = null;
    }
    super.dispose();
  }

  void _addItem(QuoteItem item) {
    setState(() {
      final existingIndex = _items.indexWhere((i) {
        if (i is QuoteItemWithId && item is QuoteItemWithId) {
          return i.productId == item.productId && i.productId != null;
        }
        return i.name.toLowerCase() == item.name.toLowerCase();
      });

      if (existingIndex != -1) {
        _items[existingIndex] = _items[existingIndex].copyWith(
          qty: _items[existingIndex].qty + item.qty,
        );
      } else {
        _items.add(item);
      }
    });
  }

  void _updateQuantity(int index, double delta) {
    setState(() {
      final item = _items[index];
      final newQty = item.qty + delta;
      if (newQty > 0) {
        _items[index] = item.copyWith(qty: newQty);
      } else if (newQty <= 0) {
        _items.removeAt(index);
      }
    });
  }

  Future<void> _editItemDetails(int index, String currency) async {
    final item = _items[index];
    final priceCtrl = TextEditingController(text: item.unitPrice.toString());
    final qtyCtrl = TextEditingController(text: item.qty.toString());
    final discCtrl = TextEditingController(text: item.discountAmount.toString());
    final descCtrl = TextEditingController(text: item.description ?? "");
    final unitCtrl = TextEditingController(text: item.unit ?? "");

    final result = await showDialog<QuoteItem>(
      context: context,
      builder: (ctx) => EnterpriseWidgets.buildPremiumDialog(
        ctx,
        title: "Détails de l'article",
        icon: FluentIcons.edit_24_regular,
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              EnterpriseWidgets.buildPremiumTextField(
                ctx,
                ctrl: priceCtrl,
                label: "PRIX UNITAIRE ($currency)",
                icon: FluentIcons.money_24_regular,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              EnterpriseWidgets.buildPremiumTextField(
                ctx,
                ctrl: qtyCtrl,
                label: "QUANTITÉ",
                icon: FluentIcons.number_row_24_regular,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              EnterpriseWidgets.buildPremiumTextField(
                ctx,
                ctrl: discCtrl,
                label: "REMISE (MONTANT)",
                icon: FluentIcons.tag_24_regular,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              EnterpriseWidgets.buildPremiumTextField(
                ctx,
                ctrl: unitCtrl,
                label: "UNITÉ (KG, PIÈCE, ETC.)",
                hint: "Ex: Pièce, kg...",
                icon: FluentIcons.box_24_regular,
              ),
              const SizedBox(height: 12),
              EnterpriseWidgets.buildPremiumTextField(
                ctx,
                ctrl: descCtrl,
                label: "NOTE / DESCRIPTION",
                maxLines: 2,
                icon: FluentIcons.note_24_regular,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler"),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () {
              final updated = item.copyWith(
                unitPrice: double.tryParse(priceCtrl.text) ?? item.unitPrice,
                qty: double.tryParse(qtyCtrl.text) ?? item.qty,
                discountAmount: double.tryParse(discCtrl.text) ?? 0.0,
                description: descCtrl.text.isEmpty ? null : descCtrl.text,
                unit: unitCtrl.text.isEmpty ? null : unitCtrl.text,
              );
              Navigator.pop(ctx, updated);
            },
            child: const Text("Valider"),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _items[index] = result;
      });
    }
  }

  void _removeAt(int index) {
    setState(() => _items.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(shopSettingsProvider).value;
    final currency = settings?.currency ?? 'FCFA';
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        backgroundColor: Colors.transparent,
        child: Container(
          width: 1200,
          height: MediaQuery.of(context).size.height * 0.92,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                blurRadius: 50,
                offset: const Offset(0, 20),
              ),
            ],
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
              width: 1.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildHeader(theme),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Pane: Search/Inventory and Manual Add
                    Expanded(
                      flex: 45,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF10121D) : const Color(0xFFF8FAFC),
                          border: Border(
                            right: BorderSide(
                              color: theme.dividerColor.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildClientSelection(theme),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1A1D2B) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  if (!isDark)
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                ],
                                border: Border.all(
                                  color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: TabBar(
                                tabs: const [
                                  Tab(text: "PRODUITS DU STOCK"),
                                  Tab(text: "SAISIE MANUELLE"),
                                ],
                                labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
                                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                indicator: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                indicatorSize: TabBarIndicatorSize.tab,
                                dividerColor: Colors.transparent,
                                labelColor: Colors.white,
                                unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  _buildInventoryTab(theme, currency),
                                  _buildManualTab(theme, currency),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Right Pane: Quote Review/Summary Sheet
                    Expanded(
                      flex: 55,
                      child: _buildQuoteReview(theme, currency),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141724) : Colors.white,
        border: Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.quote == null ? FluentIcons.document_add_24_filled : FluentIcons.document_edit_24_filled,
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.quote == null ? "Nouveau Devis" : "Modifier le Devis ${widget.quote!['quote_number']}",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
              const SizedBox(height: 2),
              Text(
                widget.quote == null ? "Générez une offre commerciale" : "Édition des détails du devis",
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B1E2E) : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(FluentIcons.dismiss_20_regular),
              color: isDark ? Colors.white70 : Colors.black87,
              iconSize: 18,
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(8),
                hoverColor: Colors.red.withValues(alpha: 0.1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientSelection(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181B28) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FluentIcons.person_info_20_filled, color: theme.colorScheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                "INFORMATIONS DU CLIENT",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: ref.watch(clientListProvider).when(
                  loading: () => const Center(child: LinearProgressIndicator()),
                  error: (_, __) => const SizedBox(),
                  data: (clients) {
                    final clientIds = <String?>[null, ...clients.map((c) => c.id)];
                    return EnterpriseWidgets.buildPremiumDropdown<String?>(
                      label: "CLIENT DESTINATAIRE",
                      value: _selectedClientId,
                      icon: FluentIcons.person_24_regular,
                      items: clientIds,
                      itemLabel: (id) => id == null
                          ? "Client de passage"
                          : (clients.firstWhere((c) => c.id == id, orElse: () => const Client(id: '', name: 'Client inconnu')).name),
                      onChanged: (v) => setState(() => _selectedClientId = v),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: EnterpriseWidgets.buildPremiumTextField(
                  context,
                  ctrl: _validityDaysCtrl,
                  label: "VALIDITÉ (JOURS)",
                  icon: FluentIcons.calendar_clock_24_regular,
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    final days = int.tryParse(val);
                    if (days != null && days >= 0) {
                      setState(() => _validUntil = DateTime.now().add(Duration(days: days)));
                    }
                  },
                  suffix: IconButton(
                    icon: Icon(FluentIcons.calendar_24_regular, size: 20, color: theme.colorScheme.primary),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _validUntil,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          _validUntil = picked;
                          _validityDaysCtrl.text = picked.difference(DateTime.now()).inDays.clamp(0, 365).toString();
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Icon(FluentIcons.info_16_regular, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  "Le devis expirera le ",
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                ),
                Text(
                  DateFormatter.formatDate(_validUntil),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryTab(ThemeData theme, String currency) {
    final productsAsync = ref.watch(productListProvider);
    final isDark = theme.brightness == Brightness.dark;

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, __) => Center(child: Text("Erreur: $e")),
      data: (products) {
        final categories = products.map((p) => p.category ?? "Général").toSet().toList()..sort();
        final filtered = products.where((p) {
          final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                               (p.reference?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
          final matchesCat = _selectedCategory == null || p.category == _selectedCategory;
          return matchesSearch && matchesCat;
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141724) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: "Rechercher par nom ou référence...",
                    hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    prefixIcon: Icon(FluentIcons.search_20_regular, size: 20, color: theme.colorScheme.primary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text("Tous"),
                      selected: _selectedCategory == null,
                      onSelected: (_) => setState(() => _selectedCategory = null),
                      selectedColor: theme.colorScheme.primary,
                      backgroundColor: isDark ? const Color(0xFF141724) : Colors.white,
                      labelStyle: TextStyle(
                        color: _selectedCategory == null ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: _selectedCategory == null ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 12,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: _selectedCategory == null 
                              ? theme.colorScheme.primary 
                              : (isDark ? const Color(0xFF2D3039) : const Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                  ),
                  ...categories.map((cat) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: _selectedCategory == cat,
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                      selectedColor: theme.colorScheme.primary,
                      backgroundColor: isDark ? const Color(0xFF141724) : Colors.white,
                      labelStyle: TextStyle(
                        color: _selectedCategory == cat ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: _selectedCategory == cat ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 12,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: _selectedCategory == cat 
                              ? theme.colorScheme.primary 
                              : (isDark ? const Color(0xFF2D3039) : const Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF141724) : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(FluentIcons.box_search_24_regular, size: 48, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                      ),
                      const SizedBox(height: 16),
                      Text("Aucun produit trouvé", style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 15, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final p = filtered[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF141724) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            p.isService ? FluentIcons.wrench_24_regular : FluentIcons.box_24_regular,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Text(
                                DateFormatter.formatCurrency(p.sellingPrice, currency),
                                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w800, fontSize: 12),
                              ),
                              if (p.unit != null)
                                Text(
                                  " / ${p.unit}",
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (p.quantity <= 0 && !p.isService) ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  p.isService ? "Service" : "Stock: ${p.quantity.toStringAsFixed(0)}",
                                  style: TextStyle(
                                    color: (p.quantity <= 0 && !p.isService) ? Colors.red : Colors.green,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: FilledButton.icon(
                          onPressed: () async {
                            if (p.quantity <= 0 && !p.isService) {
                              final addAnyway = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => EnterpriseWidgets.buildPremiumDialog(
                                  ctx,
                                  title: "Stock Épuisé",
                                  icon: FluentIcons.warning_24_regular,
                                  width: 400,
                                  child: Text("Le produit ${p.name} est en rupture de stock. Voulez-vous quand même l'ajouter au devis ?"),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Non")),
                                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Oui")),
                                  ],
                                ),
                              );
                              if (addAnyway != true) return;
                            }
                            
                            _addItem(QuoteItemWithId(
                              name: p.name,
                              qty: 1.0,
                              unitPrice: p.sellingPrice,
                              productId: p.id,
                              unit: p.unit,
                            ));
                          },
                          icon: const Icon(FluentIcons.add_16_filled, size: 14),
                          label: const Text("Ajouter"),
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                            foregroundColor: theme.colorScheme.primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildManualTab(ThemeData theme, String currency) {
    final isDark = theme.brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141724) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
          ],
          border: Border.all(
            color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(FluentIcons.keyboard_24_regular, color: theme.colorScheme.secondary, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Créer un article sur mesure",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            EnterpriseWidgets.buildPremiumTextField(
              context,
              ctrl: _customNameCtrl,
              label: "DÉSIGNATION / PRESTATION DE SERVICE",
              hint: "Ex: Main d'œuvre technique, Forfait d'installation...",
              icon: FluentIcons.text_field_20_regular,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: EnterpriseWidgets.buildPremiumTextField(
                    context,
                    ctrl: _customPriceCtrl,
                    label: "PRIX UNITAIRE ($currency)",
                    hint: "0",
                    icon: FluentIcons.money_24_regular,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: EnterpriseWidgets.buildPremiumTextField(
                    context,
                    ctrl: _customQtyCtrl,
                    label: "QUANTITÉ",
                    hint: "1",
                    icon: FluentIcons.number_row_24_regular,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: () {
                  final name = _customNameCtrl.text.trim();
                  final price = double.tryParse(_customPriceCtrl.text) ?? 0;
                  final qty = double.tryParse(_customQtyCtrl.text) ?? 1.0;
                  if (name.isNotEmpty && price > 0) {
                    _addItem(QuoteItem(name: name, qty: qty, unitPrice: price));
                    _customNameCtrl.clear();
                    _customPriceCtrl.clear();
                    _customQtyCtrl.text = '1';
                  }
                },
                icon: const Icon(FluentIcons.add_24_filled, size: 20),
                label: const Text("AJOUTER L'ARTICLE AU DEVIS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  backgroundColor: theme.colorScheme.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteReview(ThemeData theme, String currency) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF141724) : Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(FluentIcons.clipboard_task_list_ltr_24_regular, color: theme.colorScheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "APERÇU DU DEVIS",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              if (_items.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${_items.length} Article(s)",
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF10121D) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE2E8F0),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF141724) : Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                if (!isDark)
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                              ],
                            ),
                            child: Icon(FluentIcons.document_text_24_regular, size: 64, color: Colors.grey.shade400),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Ce devis est encore vide",
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Ajoutez des articles depuis le stock\nou saisissez-les manuellement à gauche.",
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      separatorBuilder: (context, index) => Divider(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                        height: 16,
                      ),
                      itemBuilder: (ctx, i) {
                        final item = _items[i];
                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1B1E2E) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () => _editItemDetails(i, currency),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              DateFormatter.formatCurrency(item.unitPrice, currency),
                                              style: TextStyle(
                                                color: theme.colorScheme.primary,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13,
                                              ),
                                            ),
                                            if (item.unit != null)
                                              Text(
                                                " / ${item.unit}",
                                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                                              ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              FluentIcons.edit_16_regular,
                                              size: 14,
                                              color: Colors.grey,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (item.discountAmount > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          "Remise unitaire: -${DateFormatter.formatCurrency(item.discountAmount, currency)}",
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    if (item.description != null && item.description!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          item.description!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontStyle: FontStyle.italic,
                                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF141724) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(FluentIcons.subtract_16_regular, size: 14),
                                      onPressed: () => _updateQuantity(i, -1.0),
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      constraints: const BoxConstraints(minWidth: 24),
                                      child: Text(
                                        DateFormatter.formatQuantity(item.qty),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(FluentIcons.add_16_regular, size: 14),
                                      onPressed: () => _updateQuantity(i, 1.0),
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              SizedBox(
                                width: 100,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "Total Ligne",
                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormatter.formatCurrency(item.lineTotal, currency),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(FluentIcons.delete_20_regular, size: 20),
                                onPressed: () => _removeAt(i),
                                color: Colors.red.shade400,
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.red.withValues(alpha: 0.05),
                                  hoverColor: Colors.red.withValues(alpha: 0.1),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B1E2E) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "MONTANT TOTAL",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: isDark ? Colors.grey.shade400 : theme.colorScheme.primary, letterSpacing: 1.0),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Hors Taxes (HT)",
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    Text(
                      DateFormatter.formatCurrency(_total, currency),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : theme.colorScheme.primary,
                        letterSpacing: -1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _items.isEmpty ? null : _saveQuote,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    icon: const Icon(FluentIcons.save_24_regular, size: 22),
                    label: Text(
                      widget.quote == null ? "ENREGISTRER LE NOUVEAU DEVIS" : "SAUVEGARDER LES MODIFICATIONS",
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveQuote() async {
    final userId = ref.read(authServiceProvider).value?.id ?? 'admin';
    final repo = ref.read(quoteRepositoryProvider);

    if (widget.quote == null) {
      await repo.createQuote(
        clientId: _selectedClientId,
        items: _items,
        subtotal: _subtotal,
        totalAmount: _total,
        userId: userId,
        validUntil: _validUntil,
      );
    } else {
      await repo.updateQuote(
        quoteId: widget.quote!['id'],
        clientId: _selectedClientId,
        items: _items,
        subtotal: _subtotal,
        totalAmount: _total,
        validUntil: _validUntil,
      );
    }

    ref.invalidate(quoteListProvider);
    if (!mounted) return;
    Navigator.pop(context);
  }
}
