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

class CreateQuoteDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? quote; // For edit mode

  const CreateQuoteDialog({super.key, this.quote});

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
  }

  @override
  void dispose() {
    _validityDaysCtrl.dispose();
    _customNameCtrl.dispose();
    _customPriceCtrl.dispose();
    _customQtyCtrl.dispose();
    _searchCtrl.dispose();
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: ref.watch(clientListProvider).when(
              loading: () => const Center(child: LinearProgressIndicator()),
              error: (_, __) => const SizedBox(),
              data: (clients) {
                final clientIds = <String?>[null, ...clients.map((c) => c.id)];
                return EnterpriseWidgets.buildPremiumDropdown<String?>(
                  label: "CLIENT",
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
          const SizedBox(width: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _validUntil,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialEntryMode: DatePickerEntryMode.input,
              );
              if (picked != null) {
                setState(() {
                  _validUntil = picked;
                  _validityDaysCtrl.text = picked.difference(DateTime.now()).inDays.clamp(0, 365).toString();
                });
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.surface,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(FluentIcons.calendar_20_regular, size: 18, color: Colors.blue),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 35,
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
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              "Expire: ${DateFormatter.formatDate(_validUntil)}",
              style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.1),
                  ),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: const InputDecoration(
                    hintText: "Rechercher par nom ou réf...",
                    prefixIcon: Icon(FluentIcons.search_20_regular, size: 18),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
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
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.05),
                      ),
                    ),
                    color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(
                        "${DateFormatter.formatCurrency(p.sellingPrice, currency)} • Stock: ${p.quantity}",
                        style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 11),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(FluentIcons.add_16_filled, color: Colors.green, size: 16),
                      ),
                      onTap: () async {
                        if (p.quantity <= 0 && !p.isService) {
                          final addAnyway = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => EnterpriseWidgets.buildPremiumDialog(
                              ctx,
                              title: "Stock Épuisé",
                              icon: FluentIcons.warning_24_regular,
                              width: 400,
                              child: Text("Le produit ${p.name} est en rupture de stock. Voulez-vous quand même l'ajouter ?"),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EnterpriseWidgets.buildPremiumTextField(
            context,
            ctrl: _customNameCtrl,
            label: "DÉSIGNATION / SERVICE",
            hint: "Ex : Main d'oeuvre, Article spécial...",
            icon: FluentIcons.text_field_20_regular,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: EnterpriseWidgets.buildPremiumTextField(
                  context,
                  ctrl: _customPriceCtrl,
                  label: "PRIX UNITAIRE ($currency)",
                  hint: "0",
                  icon: FluentIcons.money_20_regular,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: EnterpriseWidgets.buildPremiumTextField(
                  context,
                  ctrl: _customQtyCtrl,
                  label: "QTÉ",
                  hint: "1",
                  icon: FluentIcons.number_row_20_regular,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
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
              icon: const Icon(FluentIcons.add_20_filled, size: 18),
              label: const Text("AJOUTER AU DEVIS", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteReview(ThemeData theme, String currency) {
    final isDark = theme.brightness == Brightness.dark;

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
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _items.length,
                      itemBuilder: (ctx, i) {
                        final item = _items[i];
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.01) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.dividerColor.withValues(alpha: 0.05),
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
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    InkWell(
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
                                                Text(
                                                  DateFormatter.formatCurrency(item.unitPrice, currency),
                                                  style: TextStyle(
                                                    color: theme.colorScheme.primary,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                if (item.unit != null)
                                                  Text(
                                                    " / ${item.unit}",
                                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                                  ),
                                                const SizedBox(width: 6),
                                                const Icon(
                                                  FluentIcons.edit_16_regular,
                                                  size: 12,
                                                  color: Colors.grey,
                                                ),
                                              ],
                                            ),
                                            if (item.discountAmount > 0)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 2),
                                                child: Text(
                                                  "Remise: -${DateFormatter.formatCurrency(item.discountAmount, currency)}",
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.red,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            if (item.description != null)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 2),
                                                child: Text(
                                                  item.description!,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontStyle: FontStyle.italic,
                                                    color: Colors.blueGrey,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Qty modifier
                              Container(
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(FluentIcons.subtract_12_regular, size: 12),
                                      onPressed: () => _updateQuantity(i, -1.0),
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                      padding: EdgeInsets.zero,
                                    ),
                                    Text(
                                      DateFormatter.formatQuantity(item.qty),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                    IconButton(
                                      icon: const Icon(FluentIcons.add_12_regular, size: 12),
                                      onPressed: () => _updateQuantity(i, 1.0),
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Total
                              SizedBox(
                                width: 85,
                                child: Text(
                                  DateFormatter.formatCurrency(item.lineTotal, currency),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(FluentIcons.delete_16_regular, color: Colors.red, size: 16),
                                onPressed: () => _removeAt(i),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(6),
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
