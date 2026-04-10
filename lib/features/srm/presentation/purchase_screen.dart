import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/theme/app_theme.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/features/srm/domain/models/supplier.dart';
import 'package:danaya_plus/features/srm/domain/models/purchase_order.dart';
import 'package:danaya_plus/features/srm/providers/supplier_providers.dart';
import 'package:danaya_plus/features/srm/providers/srm_service.dart';
import 'package:danaya_plus/features/inventory/providers/product_providers.dart';
import 'package:danaya_plus/features/finance/providers/treasury_provider.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/features/inventory/domain/models/product.dart';
import 'package:danaya_plus/features/srm/application/purchase_pdf_service.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/features/srm/presentation/widgets/purchase_detail_dialog.dart';
import 'package:danaya_plus/core/widgets/access_denied_screen.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/inventory/presentation/dashboard_screen.dart';

class PurchaseScreen extends ConsumerStatefulWidget {
  final Supplier? supplier;
  const PurchaseScreen({super.key, this.supplier});

  @override
  ConsumerState<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends ConsumerState<PurchaseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Supplier? _selectedSupplier;
  final List<_PurchaseItemDraft> _items = [];
  String? _selectedAccountId;
  final _searchCtrl = TextEditingController();
  final _paidAmountCtrl = TextEditingController(text: "0");
  final _discountCtrl = TextEditingController(text: "0");
  final _taxCtrl = TextEditingController(text: "0");
  final _shippingCtrl = TextEditingController(text: "0");
  final _referenceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final Map<String, TextEditingController> _priceCtrls = {};
  bool _isCredit = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedSupplier = widget.supplier;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _paidAmountCtrl.dispose();
    _discountCtrl.dispose();
    _taxCtrl.dispose();
    _shippingCtrl.dispose();
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    _searchCtrl.dispose();
    for (var ctrl in _priceCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _addItem(Product p) {
    setState(() {
      final existingIndex = _items.indexWhere((item) => item.productId == p.id);
      if (existingIndex >= 0) {
        _items[existingIndex] = _items[existingIndex].copyWith(qty: _items[existingIndex].qty + 1.0);
      } else {
        _items.add(_PurchaseItemDraft(
          productId: p.id,
          productName: p.name,
          qty: 1.0,
          unitCost: p.purchasePrice,
        ));
        _priceCtrls[p.id] = TextEditingController(text: p.purchasePrice.toStringAsFixed(0));
      }
      _searchCtrl.clear();
    });
  }

  void _updateQty(int index, double newQty) {
    if (newQty <= 0) return;
    setState(() {
      _items[index] = _items[index].copyWith(qty: newQty);
    });
  }

  void _updatePrice(int index, double newPrice) {
    if (newPrice < 0) return;
    setState(() {
      _items[index] = _items[index].copyWith(unitCost: newPrice);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).value;

    if (user == null || !user.canManageSuppliers) {
      return const AccessDeniedScreen(
        message: "Achats Restreints",
        subtitle: "Seuls les administrateurs et managers peuvent gérer les commandes fournisseurs.",
      );
    }

    // Log access once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).logActivity(
        userId: user.id,
        actionType: 'VIEW_PURCHASES',
        description: 'Consultation des achats par ${user.username}',
      );
    });

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1115) : const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // ── PREMIUM TOP BAR WITH TABS ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF16181D) : Colors.white,
              border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    EnterpriseWidgets.buildPremiumHeader(
                      context,
                      title: "Achats",
                      subtitle: "Flux stock.",
                      icon: FluentIcons.cart_20_regular,
                      onBack: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          ref.read(navigationProvider.notifier).setPage(0, ref);
                        }
                      },
                    ),
                    const Spacer(),
                    Container(
                      width: 280,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        dividerColor: Colors.transparent,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.grey,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                        tabs: const [
                          Tab(text: "SAISIE"),
                          Tab(text: "LISTE"),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCreateTab(context, isDark, theme),
                _buildHistoryTab(context, isDark, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB: CREATE PURCHASE ───
  Widget _buildCreateTab(BuildContext context, bool isDark, ThemeData theme) {
    final productsAsync = ref.watch(productListProvider);
    final settingsAsync = ref.watch(shopSettingsProvider);
    final accountsAsync = ref.watch(myTreasuryAccountsProvider);
    final suppliersAsync = ref.watch(supplierListProvider);
    
    final settings = settingsAsync.value;
    final currency = settings?.currency ?? "CFA";
    final subtotal = _items.fold(0.0, (sum, item) => sum + (item.qty * item.unitCost));
    final disc = double.tryParse(_discountCtrl.text) ?? 0.0;
    final tax = double.tryParse(_taxCtrl.text) ?? 0.0;
    final ship = double.tryParse(_shippingCtrl.text) ?? 0.0;
    final total = (subtotal - disc) + tax + ship;

    return Row(
      children: [
        // LEFT PANEL (ITEMS)
        Expanded(
          flex: 7,
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF16181D) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                  ),
                  child: productsAsync.when(
                    data: (products) => Autocomplete<Product>(
                      displayStringForOption: (p) => p.name,
                      optionsBuilder: (text) => products.where((p) => 
                        p.name.toLowerCase().contains(text.text.toLowerCase()) || 
                        (p.barcode?.contains(text.text) ?? false)
                      ),
                      onSelected: _addItem,
                      fieldViewBuilder: (ctx, ctrl, focus, onSubmitted) {
                        return TextField(
                          controller: ctrl,
                          focusNode: focus,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: "Produit ou code-barres...",
                            prefixIcon: const Icon(FluentIcons.search_20_filled, color: Colors.blue, size: 14),
                            suffixIcon: const Icon(FluentIcons.barcode_scanner_20_regular, color: Colors.blue, size: 14),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        );
                      },
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox(),
                  ),
                ),
              ),

              // Items Table Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Row(
                  children: [
                    _buildHeaderLabel("ARTICLE", flex: 3),
                    _buildHeaderLabel("QTÉ", width: 80, alignment: Alignment.center),
                    _buildHeaderLabel("PU", width: 100, alignment: Alignment.center),
                    _buildHeaderLabel("TOTAL", width: 100, alignment: Alignment.center),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              Expanded(
                child: _items.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                        itemBuilder: (context, index) => _buildPurchaseItemRow(_items[index], index, isDark, currency),
                      ),
              ),
            ],
          ),
        ),

        // RIGHT PANEL (SUMMARY)
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF16181D) : Colors.white,
            border: Border(left: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
          ),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("RÈGLEMENT", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      
                      suppliersAsync.when(
                        data: (suppliers) => EnterpriseWidgets.buildPremiumDropdown<Supplier>(
                          label: "FOURNISSEUR",
                          value: _selectedSupplier,
                          icon: FluentIcons.building_20_regular,
                          items: suppliers,
                          itemLabel: (s) => s.name,
                          onChanged: (s) => setState(() => _selectedSupplier = s),
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const Text("Erreur"),
                      ),
                      const SizedBox(height: 8),
                      EnterpriseWidgets.buildPremiumTextField(
                        context, ctrl: _referenceCtrl, label: "RÉF", icon: FluentIcons.receipt_20_regular, hint: "BL-001",
                      ),
                      const SizedBox(height: 8),
                      EnterpriseWidgets.buildPremiumTextField(
                        context,
                        ctrl: TextEditingController(text: DateFormatter.formatLongDate(_selectedDate)),
                        label: "DATE D'ACHAT",
                        icon: FluentIcons.calendar_20_regular,
                        readOnly: true,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(DateTime.now().year - 2),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setState(() => _selectedDate = picked);
                        },
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(),
                      ),

                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          dense: true,
                          title: const Text("À crédit", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          value: _isCredit,
                          onChanged: (v) => setState(() => _isCredit = v),
                        ),
                      ),
                      const SizedBox(height: 8),
                      accountsAsync.when(
                        data: (accounts) => EnterpriseWidgets.buildPremiumDropdown<String>(
                          label: "COMPTE",
                          value: _selectedAccountId,
                          icon: FluentIcons.building_bank_20_regular,
                          items: accounts.map((a) => a.id).toList(),
                          itemLabel: (id) => accounts.firstWhere((a) => a.id == id).name,
                          onChanged: (v) => setState(() => _selectedAccountId = v),
                        ),
                        loading: () => const SizedBox(),
                        error: (_, __) => const SizedBox(),
                      ),
                      const SizedBox(height: 8),
                      _buildPremiumFinancialInput("Acompte", _paidAmountCtrl, FluentIcons.money_hand_20_regular),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(),
                      ),

                      Row(
                        children: [
                          Expanded(child: _buildPremiumFinancialInput("Remise", _discountCtrl, FluentIcons.tag_20_regular)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildPremiumFinancialInput("Taxes", _taxCtrl, FluentIcons.receipt_20_regular)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildPremiumFinancialInput("Transport", _shippingCtrl, FluentIcons.vehicle_truck_profile_20_regular),
                      const SizedBox(height: 8),
                      EnterpriseWidgets.buildPremiumTextField(
                        context, ctrl: _notesCtrl, label: "Notes / Commentaires", icon: FluentIcons.text_description_20_regular, hint: "Détails supplémentaires...",
                      ),
                    ],
                  ),
                ),
              ),
              _buildModernSummary(total, currency, theme, isDark),
            ],
          ),
        ),
      ],
    );
  }

  // ─── TAB: HISTORY (ULTRA COMPACT TABLE) ───
  Widget _buildHistoryTab(BuildContext context, bool isDark, ThemeData theme) {
    final historyAsync = ref.watch(purchaseListProvider);
    final suppliersAsync = ref.watch(supplierListProvider);

    return historyAsync.when(
      data: (orders) {
        if (orders.isEmpty) return _buildEmptyState(isDark, message: "Aucun bon d'achat.");
        
        return Column(
          children: [
            // Header Tableau
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50,
              child: Row(
                children: [
                  _buildHeaderLabel("RÉFÉRENCE", width: 120),
                  _buildHeaderLabel("FOURNISSEUR", flex: 3),
                  _buildHeaderLabel("TOTAL", width: 120, alignment: Alignment.centerRight),
                  _buildHeaderLabel("DATE", width: 140, alignment: Alignment.centerRight),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: orders.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return suppliersAsync.when(
                    data: (suppliers) {
                      final supplier = suppliers.firstWhere((s) => s.id == order.supplierId, orElse: () => Supplier(id: "??", name: "Inconnu"));
                      return _buildHistoryRow(order, supplier, isDark, theme);
                    },
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, __) => Center(child: Text("Erreur historique: $e")),
    );
  }

  Widget _buildHistoryRow(PurchaseOrder order, Supplier supplier, bool isDark, ThemeData theme) {
    return InkWell(
      onTap: () => showDialog(context: context, builder: (_) => PurchaseDetailDialog(order: order)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(order.reference, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.blue)),
            ),
            Expanded(
              flex: 3,
              child: Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
            ),
            SizedBox(
              width: 120,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(ref.fmt(order.totalAmount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.green)),
              ),
            ),
            SizedBox(
              width: 140,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(DateFormatter.formatDateTime(order.date), style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ),
            ),
            const SizedBox(width: 16),
            Icon(FluentIcons.chevron_right_12_regular, color: Colors.grey.withValues(alpha: 0.3), size: 12),
          ],
        ),
      ),
    );
  }

  // ─── COMMON WIDGETS ───
  Widget _buildHeaderLabel(String text, {double? width, int? flex, Alignment alignment = Alignment.centerLeft}) {
    return flex != null 
      ? Expanded(flex: flex, child: Align(alignment: alignment, child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.8)))) 
      : SizedBox(width: width, child: Align(alignment: alignment, child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.8))));
  }

  Widget _buildPurchaseItemRow(_PurchaseItemDraft item, int index, bool isDark, String currency) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                Text("Réf: ${item.productId.substring(0, 8)}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildQuantityBtn(FluentIcons.subtract_16_filled, () => _updateQty(index, item.qty - 1.0), isDark),
                SizedBox(
                  width: 28, 
                  child: Center(
                    child: Text(
                      ref.qty(item.qty), 
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)
                    )
                  )
                ),
                _buildQuantityBtn(FluentIcons.add_16_filled, () => _updateQty(index, item.qty + 1.0), isDark),
              ],
            ),
          ),
          SizedBox(
            width: 100,
            child: Center(
              child: IntrinsicWidth(
                child: TextField(
                  controller: _priceCtrls[item.productId] ?? TextEditingController(text: item.unitCost.toStringAsFixed(0)),
                  onChanged: (v) => _updatePrice(index, double.tryParse(v) ?? 0.0),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.green),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.green.withValues(alpha: 0.2))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.green.withValues(alpha: 0.1))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Colors.green, width: 1.5)),
                    isDense: true,
                    suffixText: " $currency",
                    suffixStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 100, child: Center(child: Text(ref.fmt(item.qty * item.unitCost), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)))),
          IconButton(
            onPressed: () {
              setState(() {
                final removedItem = _items.removeAt(index);
                final ctrl = _priceCtrls.remove(removedItem.productId);
                ctrl?.dispose();
              });
            },
            icon: const Icon(FluentIcons.delete_20_regular, color: Colors.redAccent, size: 16),
            style: IconButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.05),
              padding: EdgeInsets.zero,
              minimumSize: const Size(28, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityBtn(IconData icon, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 14, color: Colors.blue),
      ),
    );
  }

  Widget _buildPremiumFinancialInput(String label, TextEditingController ctrl, IconData icon) {
    return EnterpriseWidgets.buildPremiumTextField(
      context, ctrl: ctrl, label: label, icon: icon, hint: "0",
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildModernSummary(double total, String currency, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1F26) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("TOTAL À RÉGLER", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5)),
                  Text(ref.fmt(total), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: theme.colorScheme.primary, letterSpacing: -0.5)),
                ],
              ),
              if (_items.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text("${_items.length} ITEMS", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: FilledButton.icon(
              onPressed: _canSubmit ? _submitPurchase : null,
              icon: const Icon(FluentIcons.checkmark_circle_16_filled, size: 16),
              label: const Text("VALIDER", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, {String? message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FluentIcons.shopping_bag_24_regular, size: 80, color: isDark ? Colors.white10 : Colors.grey.shade200),
          const SizedBox(height: 20),
          Text(message ?? "Panier vide", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white24 : Colors.grey.shade300)),
        ],
      ),
    );
  }

  bool get _canSubmit {
    if (_selectedSupplier == null || _items.isEmpty) return false;
    if (!_isCredit && _selectedAccountId == null) return false;
    return true;
  }

  void _submitPurchase() async {
    final paidAmount = double.tryParse(_paidAmountCtrl.text) ?? 0.0;
    final discount = double.tryParse(_discountCtrl.text) ?? 0.0;
    final tax = double.tryParse(_taxCtrl.text) ?? 0.0;
    final shipping = double.tryParse(_shippingCtrl.text) ?? 0.0;
    
    String paymentMethod = "Dette/Crédit";
    if (!_isCredit && _selectedAccountId != null) {
      final accounts = ref.read(treasuryProvider).asData?.value;
      if (accounts != null) {
        final acc = accounts.firstWhere((a) => a.id == _selectedAccountId);
        paymentMethod = acc.name;
      }
    }

    try {
      final order = await ref.read(srmServiceProvider).processPurchase(
        supplierId: _selectedSupplier!.id,
        accountId: _selectedAccountId,
        amountPaid: paidAmount,
        isCredit: _isCredit,
        discountAmount: discount,
        taxAmount: tax,
        shippingFees: shipping,
        reference: _referenceCtrl.text.isEmpty ? null : _referenceCtrl.text,
        paymentMethod: paymentMethod,
        date: _selectedDate,
        items: _items.map((i) => PurchaseOrderItem(
          productId: i.productId,
          quantity: i.qty,
          unitPrice: i.unitCost,
        )).toList(),
      );

      if (mounted) {
        final itemsToPrint = List<_PurchaseItemDraft>.from(_items);
        final supplierToPrint = _selectedSupplier;
        
        _showSuccessDialog(order, itemsToPrint, supplierToPrint);
        setState(() {
          for (var ctrl in _priceCtrls.values) {
            ctrl.dispose();
          }
          _priceCtrls.clear();
          _items.clear();
          _paidAmountCtrl.text = "0";
          _discountCtrl.text = "0";
          _taxCtrl.text = "0";
          _shippingCtrl.text = "0";
          _referenceCtrl.clear();
          _notesCtrl.clear();
          _selectedSupplier = null;
          _isCredit = false;
        });
        ref.invalidate(purchaseListProvider);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: AppTheme.errorClr));
    }
  }

  void _showSuccessDialog(PurchaseOrder order, List<_PurchaseItemDraft> items, Supplier? supplier) {
    showDialog(
      context: context,
      builder: (context) => EnterpriseWidgets.buildPremiumDialog(
        context,
        title: "Achat Enregistré",
        icon: FluentIcons.checkmark_circle_24_regular,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("FERMER"),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () async {
              final settings = ref.read(shopSettingsProvider).value;
              if (settings != null && supplier != null) {
                await PurchasePdfService.generateAndPrint(PurchasePdfData(
                  order: order,
                  supplier: supplier,
                  settings: settings,
                  items: items.map((i) => PurchasePdfItem(productName: i.productName, quantity: i.qty, unitCost: i.unitCost)).toList(),
                ));
              }
            },
            icon: const Icon(FluentIcons.print_24_regular), 
            label: const Text("IMPRIMER LE BON"),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Le bon d'achat ${order.reference} a été validé avec succès.",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "Les stocks des articles concernés ont été automatiquement mis à jour. Vous pouvez maintenant imprimer le justificatif ou fermer cette fenêtre.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseItemDraft {
  final String productId;
  final String productName;
  final double qty;
  final double unitCost;
  _PurchaseItemDraft({required this.productId, required this.productName, required this.qty, required this.unitCost});
  _PurchaseItemDraft copyWith({double? qty, double? unitCost}) => _PurchaseItemDraft(productId: productId, productName: productName, qty: qty ?? this.qty, unitCost: unitCost ?? this.unitCost);
}
