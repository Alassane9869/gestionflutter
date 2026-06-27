import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:uuid/uuid.dart';

import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';

import 'package:danaya_plus/core/widgets/pin_pad_dialog.dart';
import 'package:danaya_plus/features/inventory/providers/product_providers.dart';
import 'package:danaya_plus/features/inventory/presentation/widgets/dashboard_widgets.dart'; // DashColors
import 'package:danaya_plus/features/pos/providers/pos_providers.dart'; // PosCartItem

import 'package:danaya_plus/core/utils/safe_math.dart';
import 'package:danaya_plus/features/finance/domain/models/financial_account.dart';
import 'package:danaya_plus/features/finance/providers/treasury_provider.dart';
import 'package:danaya_plus/features/clients/providers/client_providers.dart';
import 'package:danaya_plus/features/clients/domain/models/client.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';


// ─────────────────────────────────────────────────────────────────────────────
// PREMIUM CHECKOUT DIALOG (BENTO & GLASS DESIGN)
// ─────────────────────────────────────────────────────────────────────────────

class PremiumCheckoutDialog extends ConsumerStatefulWidget {
  final List<PosCartItem> cart;
  final double subtotal;
  final double discount;
  final double total;
  final bool isCredit;
  final String? clientId;
  final String? clientName;
  final String? clientPhone;
  final String cashierName;
  final Future<void> Function(
    double paid,
    double change,
    double totalAmount,
    String paymentMethod,
    String? selectedAccountId,
    ReceiptTemplate? receipt,
    InvoiceTemplate? invoice,
    int pointsToRedeem,
    double discountAmount,
    List<Map<String, dynamic>>? multiPayments,
    DateTime? dueDate,
  ) onConfirmed;

  const PremiumCheckoutDialog({
    super.key,
    required this.cart,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.isCredit,
    this.clientId,
    this.clientName,
    this.clientPhone,
    required this.cashierName,
    required this.onConfirmed,
  });

  @override
  ConsumerState<PremiumCheckoutDialog> createState() => _PremiumCheckoutDialogState();
}

class _PremiumCheckoutDialogState extends ConsumerState<PremiumCheckoutDialog> {
  final _paidCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _pointsToRedeemCtrl = TextEditingController(text: '0');

  final ReceiptTemplate _receipt = ReceiptTemplate.modern;
  final InvoiceTemplate? _invoice = null;

  bool _processing = false;
  String? _selectedPaymentMethod;
  DateTime? _dueDate;

  bool _isMixedPayment = false;
  final Map<String, double> _mixedPaymentAmounts = {};
  final Map<String, String> _mixedPaymentAccounts = {};
  bool _isPercentageDiscount = true;

  String? _selectedAccountId;
  String? _selectedClientId;
  String? _selectedClientName;

  double get _globalDiscount {
    final val = (double.tryParse(_discountCtrl.text.replaceAll(',', '.')) ?? 0.0).abs();
    if (_isPercentageDiscount) {
      final cartTotal = widget.cart.fold(0.0, (sum, item) => sum + item.lineTotal);
      return SafeMath.round2(cartTotal * (val / 100).clamp(0.0, 1.0));
    }
    return SafeMath.round2(val);
  }

  double get _effectiveTotal {
    final cartTotal = widget.cart.fold(0.0, (sum, item) => sum + item.lineTotal);
    final settings = ref.read(shopSettingsProvider).value;
    double loyaltyDiscount = 0;
    if (settings != null && settings.loyaltyEnabled && !widget.isCredit) {
      final points = int.tryParse(_pointsToRedeemCtrl.text) ?? 0;
      loyaltyDiscount = SafeMath.round2(points * settings.amountPerPoint);
    }
    return (SafeMath.round2(cartTotal - _globalDiscount - loyaltyDiscount)).clamp(0.0, double.infinity);
  }

  double get _paid => _isMixedPayment
      ? SafeMath.round2(_mixedPaymentAmounts.values.fold(0.0, (sum, amt) => sum + amt))
      : SafeMath.round2(double.tryParse(_paidCtrl.text.replaceAll(',', '.').replaceAll(' ', '')) ?? 0.0);

  double get _change => SafeMath.round2((_paid - _effectiveTotal).clamp(0.0, double.infinity));

  bool get _canPay {
    if (widget.isCredit) {
      return _paid < _effectiveTotal || _effectiveTotal == 0.0;
    }
    return _paid >= _effectiveTotal;
  }

  @override
  void initState() {
    super.initState();
    _selectedClientId = widget.clientId;
    _selectedClientName = widget.clientName;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final treasury = ref.read(treasuryProvider.notifier);
        final defaultAcc = await treasury.getDefaultAccount(AccountType.CASH);
        if (defaultAcc != null && mounted) {
          setState(() {
            _selectedAccountId = defaultAcc.id;
            _selectedPaymentMethod = _getPaymentName(defaultAcc);
          });
        }
      } catch (e) {
        debugPrint('⚠️ Erreur pré-sélection caisse: $e');
      }
    });

    if (!widget.isCredit) {
      _paidCtrl.text = _effectiveTotal.round().toString();
    } else {
      _dueDate = DateTime.now().add(const Duration(days: 30));
    }
  }

  @override
  void dispose() {
    _paidCtrl.dispose();
    _discountCtrl.dispose();
    _pointsToRedeemCtrl.dispose();
    super.dispose();
  }

  void _setAmount(double amount) {
    setState(() {
      _paidCtrl.text = amount.round().toString();
    });
  }

  List<double> _smartQuickAmounts(double total) {
    final amounts = <double>{};
    final steps = [500, 1000, 2000, 5000, 10000, 25000, 50000, 100000];
    for (final step in steps) {
      double rounded(double v, double m) => (v / m).ceil() * m;
      final r = rounded(total, step.toDouble());
      if (r > total) amounts.add(r);
      if (amounts.length >= 4) break;
    }
    return amounts.toList()..sort();
  }

  void _onClientSelected(String id) {
    final clients = ref.read(clientListProvider).value ?? [];
    final client = clients.where((c) => c.id == id).firstOrNull;
    if (client != null) {
      setState(() {
        _selectedClientId = client.id;
        _selectedClientName = client.name;
      });
    }
  }

  Future<void> _confirmCheckout() async {
    final settings = ref.read(shopSettingsProvider).value;

    // 1. Check for sale at a loss (individual item discount or global discount)
    final products = ref.read(productListProvider).value ?? [];
    bool hasLossItem = false;
    double totalCost = 0.0;

    for (final item in widget.cart) {
      if (item.productId == 'custom') continue;
      final product = products.where((p) => p.id == item.productId).firstOrNull;
      if (product != null) {
        final cost = product.weightedAverageCost > 0 ? product.weightedAverageCost : product.purchasePrice;
        totalCost += cost * item.qty;

        final netUnitPrice = item.unitPrice * (1 - item.discountPercent / 100);
        if (cost > 0 && netUnitPrice < cost) {
          hasLossItem = true;
        }
      }
    }

    final isOverallLoss = _effectiveTotal < totalCost;

    if (settings != null && (hasLossItem || isOverallLoss)) {
      final authorized = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PinPadDialog(
          correctPin: settings.managerPin,
          title: "Vente à perte détectée",
        ),
      );
      if (!mounted) return;
      if (authorized != true) return;
    }

    if (!mounted) return;

    // 2. Check for max discount threshold
    final totalDiscountPercent = widget.subtotal > 0 ? (_globalDiscount / widget.subtotal) * 100 : 0.0;

    if (settings != null && totalDiscountPercent > settings.maxDiscountThreshold) {
      final authorized = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PinPadDialog(
          correctPin: settings.managerPin,
          title: "Remise max dépassée",
        ),
      );
      if (!mounted) return;
      if (authorized != true) return;
    }

    if (_isMixedPayment) {
      if (_paid < _effectiveTotal && !widget.isCredit) {
        _showSnack("Le montant total n'est pas couvert.", Colors.orange);
        return;
      }
      bool missingAccount = false;
      _mixedPaymentAmounts.forEach((method, amount) {
        if (amount > 0 && (_mixedPaymentAccounts[method] == null || _mixedPaymentAccounts[method]!.isEmpty)) {
          missingAccount = true;
        }
      });
      if (missingAccount) {
        _showSnack("Compte de trésorerie manquant pour un des modes.", Colors.red);
        return;
      }
    }

    if (!mounted) return;
    setState(() => _processing = true);

    List<Map<String, dynamic>>? multi;
    if (_isMixedPayment) {
      multi = [];
      _mixedPaymentAmounts.forEach((accId, amount) {
        if (amount > 0) {
          final accName = _mixedPaymentAccounts[accId];
          multi!.add({
            'accountId': accId,
            'amount': amount,
            'method': accName ?? 'Paiement Multiple',
          });
        }
      });
    }

    Navigator.pop(context);
    await widget.onConfirmed(
      _paid,
      _change,
      _effectiveTotal,
      _selectedPaymentMethod ?? 'Espèces',
      _selectedAccountId,
      _receipt,
      _invoice,
      int.tryParse(_pointsToRedeemCtrl.text) ?? 0,
      _globalDiscount,
      multi,
      _dueDate,
    );
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, showCloseIcon: true),
    );
  }

  String _getPaymentName(FinancialAccount acc) {
    if (acc.type == AccountType.CASH) return "ESPÈCES";
    if (acc.operator != null && acc.operator!.isNotEmpty) return acc.operator!.toUpperCase();
    switch (acc.type) {
      case AccountType.BANK: return "CARTE/BANQUE";
      case AccountType.MOBILE_MONEY: return "MOBILE MONEY";
      default: return acc.name.toUpperCase();
    }
  }

  IconData _accountIcon(FinancialAccount acc) {
    switch (acc.type) {
      case AccountType.CASH: return FluentIcons.wallet_24_filled;
      case AccountType.BANK: return FluentIcons.building_bank_24_filled;
      case AccountType.MOBILE_MONEY: return FluentIcons.phone_24_filled;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = widget.isCredit ? theme.colorScheme.error : theme.colorScheme.primary;
    final settings = ref.read(shopSettingsProvider).value;
    final accounts = ref.watch(myTreasuryAccountsProvider).value ?? [];
    final currency = settings?.currency ?? 'FCFA';
    final quickAmounts = _smartQuickAmounts(_effectiveTotal);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        width: 860, // Sleek, modern, and compact width
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : c.border.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.08),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(c, accent, isDark),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT: Config (Client, Discount, Due Date)
                    Expanded(
                      flex: 38,
                      child: _buildDetailsColumn(c, accent, isDark, currency, settings),
                    ),
                    const SizedBox(width: 20),
                    // RIGHT: Payment, Treasury & Validation
                    Expanded(
                      flex: 62,
                      child: Column(
                        children: [
                          _buildPaymentMatrix(c, accent, isDark, currency, accounts),
                          const SizedBox(height: 20),
                          _buildRecapAndValidation(c, accent, isDark, currency, quickAmounts),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(DashColors c, Color accent, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.08 : 0.04),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : c.border.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              widget.isCredit ? FluentIcons.shield_24_regular : FluentIcons.payment_24_filled,
              color: accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isCredit ? "STATION CRÉDIT & DÉLAI" : "BORNE D'ENCAISSEMENT",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : c.textPrimary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Finalisation sécurisée du panier",
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade400 : c.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (_processing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: c.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "TRAITEMENT...",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: c.blue,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(FluentIcons.dismiss_20_regular, size: 18),
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            tooltip: "Annuler",
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LEFT COLUMN: DETAILS (CLIENT + DISCOUNT + DUE DATE)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDetailsColumn(DashColors c, Color accent, bool isDark, String currency, ShopSettings? settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // BENTO: CLIENT
        _bentoCard(
          c, isDark,
          icon: FluentIcons.person_24_filled,
          title: "CLIENT",
          subtitle: "Affectation du ticket",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => Future.delayed(const Duration(milliseconds: 50), () {
                  if (!mounted) return;
                  showDialog(
                    context: context,
                    builder: (_) => PosClientSearchDialog(onSelected: (id) => _onClientSelected(id)),
                  );
                }),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _selectedClientId != null
                        ? accent.withValues(alpha: isDark ? 0.15 : 0.08)
                        : (isDark ? const Color(0xFF0E0E10) : c.surfaceElev),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedClientId != null
                          ? accent.withValues(alpha: 0.4)
                          : (isDark ? Colors.white12 : c.border),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _selectedClientId != null
                                ? [accent, accent.withValues(alpha: 0.7)]
                                : [Colors.grey.shade400, Colors.grey.shade600],
                          ),
                        ),
                        child: const Icon(
                          FluentIcons.person_20_regular,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedClientId == null ? "Passant Anonyme" : (_selectedClientName ?? "Chargement..."),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : c.textPrimary,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              _selectedClientId != null ? "Client Identifié" : "Associer un client",
                              style: TextStyle(
                                fontSize: 10,
                                color: _selectedClientId != null ? accent : (isDark ? Colors.grey.shade400 : c.textMuted),
                                fontWeight: _selectedClientId != null ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_selectedClientId != null)
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: 16, color: isDark ? Colors.white70 : Colors.black54),
                          style: IconButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(24, 24)),
                          onPressed: () => setState(() {
                            _selectedClientId = null;
                            _selectedClientName = null;
                          }),
                        )
                      else
                        Icon(
                          FluentIcons.chevron_right_12_regular,
                          color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                          size: 14,
                        ),
                    ],
                  ),
                ),
              ),
              if (settings?.loyaltyEnabled == true && _selectedClientId != null && !widget.isCredit) ...[
                const SizedBox(height: 12),
                _buildLoyaltyZone(c, accent, isDark, settings!),
              ],
            ],
          ),
        ),

        const SizedBox(height: 14),

        // BENTO: DISCOUNT
        _bentoCard(
          c, isDark,
          icon: FluentIcons.tag_24_filled,
          title: "REMISE EXCEPTIONNELLE",
          subtitle: "Ajustement du prix final",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0E0E10) : c.surfaceElev,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? Colors.white12 : c.border),
                      ),
                      child: TextField(
                        controller: _discountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: isDark ? Colors.white : c.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: "0.00",
                          suffixText: _isPercentageDiscount ? "%" : currency,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 40,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0E0E10) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        _buildDiscountTypeTab("%", _isPercentageDiscount, isDark, accent),
                        _buildDiscountTypeTab(currency, !_isPercentageDiscount, isDark, accent),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // CREDIT: DUE DATE
        if (widget.isCredit) ...[
          const SizedBox(height: 14),
          _bentoCard(
            c, isDark,
            icon: FluentIcons.calendar_clock_24_filled,
            title: "ÉCHÉANCE DE CRÉDIT",
            subtitle: "Date limite de règlement",
            child: InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialEntryMode: DatePickerEntryMode.input,
                );
                if (d != null) setState(() => _dueDate = d);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0E0E10) : c.surfaceElev,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.white12 : c.border),
                ),
                child: Row(
                  children: [
                    Icon(FluentIcons.calendar_20_regular, size: 16, color: accent),
                    const SizedBox(width: 10),
                    Text(
                      _dueDate == null ? "Sélectionner une date" : DateFormat('dd/MM/yyyy').format(_dueDate!),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: accent,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      FluentIcons.chevron_right_12_regular,
                      size: 14,
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDiscountTypeTab(String label, bool isSelected, bool isDark, Color accent) {
    return GestureDetector(
      onTap: () => setState(() => _isPercentageDiscount = label == "%"),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? accent.withValues(alpha: 0.25) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isSelected && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: isSelected
                ? (isDark ? accent : Colors.black87)
                : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
        ),
      ),
    );
  }

  Widget _buildLoyaltyZone(DashColors c, Color accent, bool isDark, ShopSettings settings) {
    final clients = ref.watch(clientListProvider).value ?? [];
    final client = clients.where((cl) => cl.id == _selectedClientId).firstOrNull;
    final availablePoints = client?.loyaltyPoints ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "FIDÉLITÉ ($availablePoints pts)",
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: accent, letterSpacing: 0.5),
              ),
              if (availablePoints > 0)
                InkWell(
                  onTap: () => setState(() => _pointsToRedeemCtrl.text = availablePoints.toString()),
                  child: Text(
                    "UTILISER TOUT",
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: accent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0C0C0E) : c.surfaceElev,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
            ),
            child: TextField(
              controller: _pointsToRedeemCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(fontWeight: FontWeight.w900, color: accent, fontSize: 13),
              decoration: const InputDecoration(
                hintText: "0",
                suffixText: "pts",
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              onChanged: (v) {
                final pts = int.tryParse(v) ?? 0;
                if (pts > availablePoints) _pointsToRedeemCtrl.text = availablePoints.toString();
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Gain immédiat:",
                style: TextStyle(fontSize: 10, color: isDark ? Colors.grey.shade400 : c.textMuted),
              ),
              Text(
                "- ${ref.fmt((int.tryParse(_pointsToRedeemCtrl.text) ?? 0) * settings.amountPerPoint)}",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: accent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RIGHT: PAYMENT MATRIX
  // ─────────────────────────────────────────────────────────────────────────

  Color _getAccGradStart(FinancialAccount acc, Color accent) {
    final op = (acc.operator ?? '').toLowerCase();
    switch (acc.type) {
      case AccountType.CASH:
        return accent; // Utilize the theme accent color instead of hardcoded slate
      case AccountType.BANK:
        if (op.contains('boa')) return const Color(0xFF064E3B);
        if (op.contains('ecobank')) return const Color(0xFF1E3A8A);
        if (op.contains('uba')) return const Color(0xFF7F1D1D);
        return const Color(0xFF1E293B);
      case AccountType.MOBILE_MONEY:
        if (op.contains('wave')) return const Color(0xFF1E3A8A);
        if (op.contains('orange')) return const Color(0xFF7C2D12);
        if (op.contains('mtn')) return const Color(0xFF713F12);
        if (op.contains('moov')) return const Color(0xFF14532D);
        return const Color(0xFF4C1D95);
    }
  }

  Color _getAccGradEnd(FinancialAccount acc, Color accent) {
    final op = (acc.operator ?? '').toLowerCase();
    switch (acc.type) {
      case AccountType.CASH:
        return accent.withValues(alpha: 0.7); // Gradient of the accent color
      case AccountType.BANK:
        if (op.contains('boa')) return const Color(0xFF10B981);
        if (op.contains('ecobank')) return const Color(0xFF3B82F6);
        if (op.contains('uba')) return const Color(0xFFEF4444);
        return const Color(0xFF4B5563);
      case AccountType.MOBILE_MONEY:
        if (op.contains('wave')) return const Color(0xFF60A5FA);
        if (op.contains('orange')) return const Color(0xFFF97316);
        if (op.contains('mtn')) return const Color(0xFFEAB308);
        if (op.contains('moov')) return const Color(0xFF22C55E);
        return const Color(0xFFA855F7);
    }
  }

  Widget _buildPaymentMatrix(DashColors c, Color accent, bool isDark, String currency, List<FinancialAccount> accounts) {
    return _bentoCard(
      c, isDark,
      icon: FluentIcons.wallet_24_filled,
      title: "MATRICE D'ENCAISSEMENT",
      subtitle: "Source des fonds et mode de règlement",
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Paiement Multi-modes",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : c.textPrimary,
                ),
              ),
              Switch.adaptive(
                value: _isMixedPayment,
                onChanged: (v) => setState(() {
                  _isMixedPayment = v;
                  _mixedPaymentAmounts.clear();
                  if (!widget.isCredit) {
                    _paidCtrl.text = _effectiveTotal.round().toString();
                  } else {
                    _paidCtrl.text = "0";
                  }
                }),
                activeTrackColor: accent.withValues(alpha: 0.4),
                activeThumbColor: accent,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100, height: 1),
          const SizedBox(height: 14),
          if (_isMixedPayment)
            ...accounts.map((acc) => _buildMixedPaymentLine(acc, c, accent, isDark))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.1,
              ),
              itemCount: accounts.length,
              itemBuilder: (context, idx) {
                final acc = accounts[idx];
                final isSelected = _selectedAccountId == acc.id;
                final c1 = _getAccGradStart(acc, accent);
                final c2 = _getAccGradEnd(acc, accent);

                return InkWell(
                  onTap: () => setState(() {
                    _selectedAccountId = acc.id;
                    _selectedPaymentMethod = _getPaymentName(acc);
                  }),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [c1, c2],
                            )
                          : null,
                      color: isSelected
                          ? null
                          : (isDark ? const Color(0xFF0C0C0E) : c.surfaceElev),
                      border: Border.all(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.4)
                            : (isDark ? Colors.white.withValues(alpha: 0.05) : c.border),
                        width: isSelected ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: c1.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : [],
                    ),
                    child: Stack(
                      children: [
                        // Glass shine inside card
                        if (isSelected)
                          Positioned(
                            right: -10,
                            top: -10,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(
                                    _accountIcon(acc),
                                    color: isSelected ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                    size: 16,
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      FluentIcons.checkmark_circle_16_filled,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    acc.name.toUpperCase(),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                      color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : c.textSecondary),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  Text(
                                    acc.operator?.toUpperCase() ?? _getPaymentName(acc),
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white.withValues(alpha: 0.7) : (isDark ? Colors.grey.shade500 : c.textMuted),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMixedPaymentLine(FinancialAccount acc, DashColors c, Color accent, bool isDark) {
    final currentVal = _mixedPaymentAmounts[acc.id] ?? 0.0;
    final c1 = _getAccGradStart(acc, accent);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: currentVal > 0
              ? c1.withValues(alpha: isDark ? 0.2 : 0.06)
              : (isDark ? const Color(0xFF0C0C0E) : c.surfaceElev),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: currentVal > 0
                ? c1.withValues(alpha: 0.4)
                : (isDark ? Colors.white12 : c.border),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (currentVal > 0 ? c1 : Colors.grey).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _accountIcon(acc),
                size: 14,
                color: currentVal > 0 ? (isDark ? Colors.white : c1) : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    acc.name.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: currentVal > 0 ? (isDark ? Colors.white : c1) : (isDark ? Colors.grey.shade300 : c.textPrimary),
                    ),
                  ),
                  Text(
                    acc.operator?.toUpperCase() ?? "COMPTE DE TRÉSORERIE",
                    style: TextStyle(
                      fontSize: 8,
                      color: isDark ? Colors.grey.shade400 : c.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 140,
              height: 34,
              child: TextField(
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: currentVal > 0 ? (isDark ? Colors.white : c1) : (isDark ? Colors.grey.shade300 : c.textPrimary),
                ),
                decoration: InputDecoration(
                  hintText: "0",
                  hintStyle: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.black26 : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onChanged: (v) {
                  final amt = double.tryParse(v) ?? 0.0;
                  setState(() {
                    if (amt > 0) {
                      _mixedPaymentAmounts[acc.id] = amt;
                      _mixedPaymentAccounts[acc.id] = _getPaymentName(acc);
                    } else {
                      _mixedPaymentAmounts.remove(acc.id);
                      _mixedPaymentAccounts.remove(acc.id);
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RECAP & VALIDATION
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildRecapAndValidation(DashColors c, Color accent, bool isDark, String currency, List<double> quickAmounts) {
    return Column(
      children: [
        if (!_isMixedPayment) ...[
          // Amount input LED card (Highly styled, glassy, and much less bulky)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF08080A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : c.border),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isCredit ? "ACOMPTE ENCAISSÉ (FACULTATIF)" : "MONTANT REÇU DU CLIENT",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: isDark ? Colors.grey.shade400 : c.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _paidCtrl,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          fontSize: 34, // Cleaned up massive size to look premium and neat
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : c.textPrimary,
                          letterSpacing: -1,
                        ),
                        inputFormatters: [
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            if (newValue.text.isEmpty) return newValue;
                            String digitsOnly = newValue.text.replaceAll(RegExp(r'\s+'), '');
                            String formatted = '';
                            int count = 0;
                            for (int i = digitsOnly.length - 1; i >= 0; i--) {
                              formatted = digitsOnly[i] + formatted;
                              count++;
                              if (count % 3 == 0 && i > 0) formatted = ' $formatted';
                            }
                            return TextEditingValue(
                              text: formatted,
                              selection: TextSelection.collapsed(offset: formatted.length),
                            );
                          }),
                        ],
                        decoration: const InputDecoration(
                          hintText: "0",
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        currency,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.grey.shade300 : c.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!widget.isCredit && quickAmounts.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: quickAmounts.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: OutlinedButton(
                        onPressed: () => _setAmount(_effectiveTotal),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: accent.withValues(alpha: isDark ? 0.15 : 0.08),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(color: accent.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: Text(
                          "Exact",
                          style: TextStyle(fontWeight: FontWeight.w900, color: accent, fontSize: 12),
                        ),
                      ),
                    );
                  }
                  final amt = quickAmounts[index - 1];
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: OutlinedButton(
                      onPressed: () => _setAmount(amt),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF0E0E10) : c.surfaceElev,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: isDark ? Colors.white12 : c.border),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: Text(
                        DateFormatter.formatNumber(amt),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.grey.shade300 : c.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 18),
        ],

        // RECAP TOTAL LEDGER SHEET (Gorgeous frosted digital receipt pane)
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF08080A) : c.surfaceElev,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : c.border),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    )
                  ],
          ),
          child: Column(
            children: [
              // Digital Tear Lines top decorator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "NET À PAYER",
                          style: TextStyle(
                            color: isDark ? Colors.grey : c.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          ref.fmt(_effectiveTotal),
                          style: TextStyle(
                            color: isDark ? Colors.white : c.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, isDark ? Colors.white12 : c.border, Colors.transparent],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.isCredit ? "RESTE À PAYER" : "MONNAIE À RENDRE",
                          style: TextStyle(
                            color: widget.isCredit ? Colors.red.shade500 : accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          widget.isCredit
                              ? ref.fmt((_effectiveTotal - _paid).clamp(0.0, double.infinity))
                              : ref.fmt(_change),
                          style: TextStyle(
                            color: widget.isCredit ? Colors.red.shade500 : accent,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.isCredit && _paid >= _effectiveTotal && _effectiveTotal > 0)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 14),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "L'acompte ne peut couvrir la totalité. Utilisez vente comptant.",
                          style: TextStyle(color: Colors.orange, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              // Action trigger section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.02) : accent.withValues(alpha: 0.03),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border(
                    top: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : c.border),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: (_canPay && !_processing) ? _confirmCheckout : null,
                    icon: Icon(
                      _processing ? FluentIcons.spinner_ios_16_regular : FluentIcons.checkmark_circle_20_filled,
                      color: _canPay ? Colors.white : Colors.grey.shade500,
                      size: 18,
                    ),
                    label: Text(
                      _processing
                          ? "TRAITEMENT EN COURS..."
                          : (widget.isCredit ? "ENREGISTRER LE CRÉDIT" : "VALIDER L'ENCAISSEMENT"),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 1.2,
                        color: _canPay ? Colors.white : Colors.grey.shade500,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.isCredit ? Colors.red.shade500 : accent,
                      disabledBackgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SHARED WIDGETS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _bentoCard(DashColors c, bool isDark, {required IconData icon, required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C0C0E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : c.border),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : c.textPrimary).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: isDark ? Colors.grey.shade300 : c.textMuted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: isDark ? Colors.white : c.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 8.5,
                        color: isDark ? Colors.grey.shade400 : c.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }


}

// ─────────────────────────────────────────────────────────────────────────────
// CLIENT SEARCH DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class PosClientSearchDialog extends ConsumerStatefulWidget {
  final Function(String id) onSelected;
  const PosClientSearchDialog({super.key, required this.onSelected});

  @override
  ConsumerState<PosClientSearchDialog> createState() => _PosClientSearchDialogState();
}

class _PosClientSearchDialogState extends ConsumerState<PosClientSearchDialog> {
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: isDark ? theme.colorScheme.surface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: Container(
        width: 520,
        height: 620,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(FluentIcons.person_search_24_filled, color: theme.colorScheme.primary, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    "Sélection Client",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                FilledButton.icon(
                  icon: const Icon(FluentIcons.person_add_20_regular, size: 16, color: Colors.white),
                  label: const Text(
                    "Nouveau",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    showDialog(context: context, builder: (_) => _PosQuickCreateClientDialog(onCreated: (client) {
                      widget.onSelected(client.id);
                      Navigator.pop(context); // Close Quick Create
                      Navigator.pop(context); // Close Search Dialog
                    }));
                  },
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(FluentIcons.dismiss_20_regular),
                  style: IconButton.styleFrom(
                    hoverColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              autofocus: true,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: "Nom ou téléphone...",
                hintStyle: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.grey.shade400, fontSize: 14),
                prefixIcon: Icon(FluentIcons.search_20_regular, color: theme.colorScheme.primary),
                filled: true,
                fillColor: isDark ? const Color(0xFF070709) : Colors.grey.shade50,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (v) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  if (mounted) setState(() => _query = v);
                });
              },
            ),
            const SizedBox(height: 18),
            Expanded(
              child: clientsAsync.when(
                data: (clients) {
                  final filtered = clients.where((cl) => cl.name.toLowerCase().contains(_query.toLowerCase()) || (cl.phone ?? '').contains(_query)).toList();
                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(FluentIcons.person_question_mark_24_regular, size: 48, color: isDark ? Colors.grey.shade700 : Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            "Aucun client trouvé.",
                            style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final cl = filtered[index];
                      return _ClientItemTile(
                        cl: cl,
                        isDark: isDark,
                        onTap: () {
                          widget.onSelected(cl.id);
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, __) => Center(child: Text("Erreur: $e")),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientItemTile extends StatefulWidget {
  final Client cl;
  final bool isDark;
  final VoidCallback onTap;

  const _ClientItemTile({
    required this.cl,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_ClientItemTile> createState() => _ClientItemTileState();
}

class _ClientItemTileState extends State<_ClientItemTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cl = widget.cl;
    final isDark = widget.isDark;
    final char = cl.name.isNotEmpty ? cl.name[0].toUpperCase() : '?';

    // Gradients based on client name hash code
    final colors = [
      [const Color(0xFFEC4899), const Color(0xFFF43F5E)],
      [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
      [const Color(0xFF10B981), const Color(0xFF059669)],
      [const Color(0xFFF59E0B), const Color(0xFFD97706)],
      [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
    ];
    final colorPair = colors[cl.name.hashCode.abs() % colors.length];

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _hovered
              ? (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50)
              : (isDark ? Colors.white.withValues(alpha: 0.01) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hovered
                ? (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey.shade300)
                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: colorPair,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorPair[0].withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    char,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        cl.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            FluentIcons.phone_16_regular,
                            size: 13,
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            cl.phone ?? "Sans téléphone",
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            FluentIcons.star_16_filled,
                            color: Color(0xFFFBBF24),
                            size: 11,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${cl.loyaltyPoints} pts",
                            style: const TextStyle(
                              color: Color(0xFFFBBF24),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (cl.credit > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              FluentIcons.warning_16_filled,
                              color: const Color(0xFFEF4444),
                              size: 10,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              "Débiteur",
                              style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK CREATE CLIENT DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _PosQuickCreateClientDialog extends ConsumerStatefulWidget {
  final Function(Client) onCreated;
  const _PosQuickCreateClientDialog({required this.onCreated});

  @override
  ConsumerState<_PosQuickCreateClientDialog> createState() => _PosQuickCreateClientDialogState();
}

class _PosQuickCreateClientDialogState extends ConsumerState<_PosQuickCreateClientDialog> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _loading = true);
    try {
      final client = Client(
        id: const Uuid().v4(),
        name: name,
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      );

      await ref.read(clientListProvider.notifier).addClient(client);
      widget.onCreated(client);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = DashColors.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: c.surface,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(FluentIcons.person_add_24_filled, color: Theme.of(context).colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("NOUVEAU CLIENT", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: c.textPrimary)),
                      Text("Ajout express au répertoire", style: TextStyle(fontSize: 10, color: c.textMuted)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 32),
            _buildField("Nom complet *", _nameCtrl, FluentIcons.person_20_regular, c, isDark, autofocus: true),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildField("Téléphone", _phoneCtrl, FluentIcons.phone_20_regular, c, isDark)),
                const SizedBox(width: 16),
                Expanded(child: _buildField("Email", _emailCtrl, FluentIcons.mail_20_regular, c, isDark)),
              ],
            ),
            const SizedBox(height: 20),
            _buildField("Adresse de résidence", _addressCtrl, FluentIcons.location_20_regular, c, isDark),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _loading
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : const Text("ENREGISTRER LE CLIENT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon, DashColors c, bool isDark, {bool autofocus = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: c.textMuted, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          autofocus: autofocus,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.textPrimary),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: c.textMuted),
            isDense: true,
            filled: true,
            fillColor: c.surfaceElev,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
          ),
        ),
      ],
    );
  }
}
