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

class CreateQuoteDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? quote; // For edit mode

  const CreateQuoteDialog({super.key, this.quote});

  @override
  ConsumerState<CreateQuoteDialog> createState() => _CreateQuoteDialogState();
}

class _CreateQuoteDialogState extends ConsumerState<CreateQuoteDialog> {
  final List<QuoteItem> _items = [];
  String? _selectedClientId;
  DateTime _validUntil = DateTime.now().add(const Duration(days: 30));

  final _validityDaysCtrl = TextEditingController(text: '30');
  final _customNameCtrl = TextEditingController();
  final _customPriceCtrl = TextEditingController();
  final _customQtyCtrl = TextEditingController(text: '1');
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;

  double get _subtotal => _items.fold(0, (sum, item) => sum + item.lineTotal);
  double get _total => _subtotal;

  @override
  void initState() {
    super.initState();
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
      builder: (ctx) => AlertDialog(
        title: Text("Détails : ${item.name}"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: "Prix Unitaire ($currency)", border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: "Quantité", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: discCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: "Remise (Montant)", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: unitCtrl,
                decoration: const InputDecoration(labelText: "Unité (kg, Pièce, etc.)", border: OutlineInputBorder(), hintText: "Pièce"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: "Note / Description", border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
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

    return DefaultTabController(
      length: 2,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 1000,
          height: MediaQuery.of(context).size.height * 0.9,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              _buildHeader(theme),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 45,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: theme.dividerColor.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildClientSelection(theme),
                            TabBar(
                              tabs: const [
                                Tab(text: "GESTION PRODUITS", icon: Icon(FluentIcons.box_20_regular, size: 20)),
                                Tab(text: "SAISIE LIBRE", icon: Icon(FluentIcons.form_20_regular, size: 20)),
                              ],
                              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              indicatorColor: theme.colorScheme.primary,
                              labelColor: theme.colorScheme.primary,
                              unselectedLabelColor: Colors.grey,
                            ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        border: Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(8)),
            child: Icon(
              widget.quote == null ? FluentIcons.document_add_20_filled : FluentIcons.edit_20_filled,
              color: Colors.white, size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            widget.quote == null ? "Nouveau Devis PRO" : "Modifier le Devis ${widget.quote!['quote_number']}",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          const Spacer(),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(FluentIcons.dismiss_20_regular)),
        ],
      ),
    );
  }

  Widget _buildClientSelection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: ref.watch(clientListProvider).when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox(),
              data: (clients) => DropdownButtonFormField<String>(
                initialValue: _selectedClientId,
                items: [
                  const DropdownMenuItem(value: null, child: Text("Client de passage")),
                  ...clients.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                ],
                onChanged: (v) => setState(() => _selectedClientId = v),
                decoration: InputDecoration(
                  prefixIcon: const Icon(FluentIcons.person_24_regular, size: 18),
                  hintText: "Client",
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () async {
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
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
                color: theme.colorScheme.surface,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(FluentIcons.calendar_20_regular, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 50,
                    child: TextField(
                      controller: _validityDaysCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                      ),
                      onChanged: (val) {
                        final days = int.tryParse(val);
                        if (days != null && days >= 0) {
                          setState(() => _validUntil = DateTime.now().add(Duration(days: days)));
                        }
                      },
                    ),
                  ),
                  const Text(" Jours", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            "Expire: ${DateFormatter.formatDate(_validUntil)}",
            style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
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
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: "Rechercher par nom ou réf...",
                  prefixIcon: const Icon(FluentIcons.search_20_regular),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text("Touts"),
                      selected: _selectedCategory == null,
                      onSelected: (_) => setState(() => _selectedCategory = null),
                    ),
                  ),
                  ...categories.map((cat) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: _selectedCategory == cat,
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty 
              ? Center(child: Text("Aucun produit trouvé", style: TextStyle(color: Colors.grey.shade500)))
              : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final p = filtered[i];
                  return ListTile(
                    dense: true,
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${DateFormatter.formatCurrency(p.sellingPrice, currency)} • Stock: ${p.quantity}"),
                    trailing: const Icon(FluentIcons.add_circle_20_filled, color: Colors.green),
                    onTap: () async {
                      if (p.quantity <= 0 && !p.isService) {
                        final addAnyway = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Stock Épuisé"),
                            content: Text("Le produit ${p.name} est en rupture de stock. Voulez-vous quand même l'ajouter ?"),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("DÉSIGNATION / SERVICE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(
            controller: _customNameCtrl,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Ex : Main d'oeuvre, Article spécial..."),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("PRIX UNITAIRE ($currency)", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _customPriceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("QTÉ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _customQtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
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
              icon: const Icon(FluentIcons.add_20_filled),
              label: const Text("Ajouter au Devis"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteReview(ThemeData theme, String currency) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("RÉSUMÉ DU DEVIS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey)),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
              ),
              child: _items.isEmpty
                  ? Center(child: Text("Aucun article ajouté", style: TextStyle(color: Colors.grey.shade400)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final item = _items[i];
                        return ListTile(
                          dense: true,
                          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: InkWell(
                            onTap: () => _editItemDetails(i, currency),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(DateFormatter.formatCurrency(item.unitPrice, currency), style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                                      if (item.unit != null) Text(" / ${item.unit}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                      const SizedBox(width: 4),
                                      const Icon(FluentIcons.edit_16_regular, size: 14, color: Colors.grey),
                                    ],
                                  ),
                                  if (item.discountAmount > 0) 
                                    Text("Remise: -${DateFormatter.formatCurrency(item.discountAmount, currency)}", style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                                  if (item.description != null)
                                    Text(item.description!, style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.blueGrey), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(FluentIcons.subtract_20_regular, size: 16),
                                      onPressed: () => _updateQuantity(i, -1.0),
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      padding: EdgeInsets.zero,
                                    ),
                                    Text(item.qty.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    IconButton(
                                      icon: const Icon(FluentIcons.add_20_regular, size: 16),
                                      onPressed: () => _updateQuantity(i, 1.0),
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  DateFormatter.formatCurrency(item.lineTotal, currency), 
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(FluentIcons.delete_20_regular, color: Colors.red, size: 18),
                                onPressed: () => _removeAt(i),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("TOTAL HT", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    Text(
                      DateFormatter.formatCurrency(_total, currency),
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: theme.colorScheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _items.isEmpty ? null : _saveQuote,
                    icon: const Icon(FluentIcons.save_20_filled),
                    label: Text(
                      widget.quote == null ? "VALIDER LE DEVIS" : "ENREGISTRER LES MODIFICATIONS",
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
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
