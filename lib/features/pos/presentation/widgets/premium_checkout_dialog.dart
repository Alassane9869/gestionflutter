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
    final totalDiscountPercent = widget.subtotal > 0 ? (_globalDiscount / widget.subtotal) * 100 : 0.0;

    if (settings != null && totalDiscountPercent > settings.maxDiscountThreshold) {
      final authorized = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PinPadDialog(correctPin: settings.managerPin),
      );
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
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 1000,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c.border.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08), blurRadius: 40, offset: const Offset(0, 16)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(c, accent, isDark),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT: Config (Client, Discount)
                    Expanded(
                      flex: 35,
                      child: _buildDetailsColumn(c, accent, isDark, currency, settings),
                    ),
                    const SizedBox(width: 24),
                    // RIGHT: Payment, Treasury & Validation
                    Expanded(
                      flex: 65,
                      child: Column(
                        children: [
                          _buildPaymentMatrix(c, accent, isDark, currency, accounts),
                          const SizedBox(height: 24),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        border: Border(bottom: BorderSide(color: c.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(widget.isCredit ? FluentIcons.shield_24_regular : FluentIcons.payment_24_filled, color: accent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isCredit ? "STATION CRÉDIT & DÉLAI" : "BORNE D'ENCAISSEMENT",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: c.textPrimary, letterSpacing: 1.5),
                ),
                Text("Finalisation sécurisée du panier", style: TextStyle(fontSize: 12, color: c.textMuted)),
              ],
            ),
          ),
          if (_processing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: c.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.blue)),
                  const SizedBox(width: 8),
                  Text("TRAITEMENT...", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c.blue)),
                ],
              ),
            ),
          const SizedBox(width: 16),
          IconButton.filledTonal(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(FluentIcons.dismiss_20_regular),
            tooltip: "Annuler",
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LEFT COLUMN: DETAILS (CLIENT + DISCOUNT)
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
                  showDialog(context: context, builder: (_) => PosClientSearchDialog(onSelected: (id) => _onClientSelected(id)));
                }),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _selectedClientId != null ? accent.withValues(alpha: 0.1) : c.surfaceElev,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _selectedClientId != null ? accent.withValues(alpha: 0.3) : c.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _selectedClientId != null ? accent : c.border,
                        radius: 18,
                        child: Icon(FluentIcons.person_20_regular, color: _selectedClientId != null ? Colors.white : Colors.grey, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedClientId == null ? "Passant Anonyme" : (_selectedClientName ?? "Chargement..."),
                              style: TextStyle(fontWeight: FontWeight.w900, color: c.textPrimary, fontSize: 13),
                            ),
                            if (_selectedClientId != null)
                              Text("Enregistré au registre", style: TextStyle(fontSize: 10, color: accent, fontWeight: FontWeight.bold))
                            else
                              Text("Cliquez pour identifier", style: TextStyle(fontSize: 10, color: c.textMuted)),
                          ],
                        ),
                      ),
                      if (_selectedClientId != null)
                        IconButton(icon: const Icon(Icons.close_rounded, size: 16), onPressed: () => setState(() {
                          _selectedClientId = null;
                          _selectedClientName = null;
                        }))
                      else
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: Icon(FluentIcons.search_20_regular, color: accent, size: 16),
                        ),
                    ],
                  ),
                ),
              ),
              if (settings?.loyaltyEnabled == true && _selectedClientId != null && !widget.isCredit) ...[
                const SizedBox(height: 16),
                _buildLoyaltyZone(c, accent, isDark, settings!),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // BENTO: DISCOUNT
        _bentoCard(
          c, isDark,
          icon: FluentIcons.tag_24_filled,
          title: "REMISE EXCEPTIONNELLE",
          subtitle: "Ajustement du prix final",
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: c.surfaceElev,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.border),
                  ),
                  child: TextField(
                    controller: _discountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: c.textPrimary),
                    decoration: InputDecoration(
                      hintText: "0.00",
                      suffixText: _isPercentageDiscount ? "%" : currency,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _toggleModeBtn(c, isSelected: _isPercentageDiscount, label: "%", onTap: () => setState(() => _isPercentageDiscount = true)),
              _toggleModeBtn(c, isSelected: !_isPercentageDiscount, label: currency, onTap: () => setState(() => _isPercentageDiscount = false)),
            ],
          ),
        ),

        // CREDIT: DUE DATE
        if (widget.isCredit) ...[
          const SizedBox(height: 16),
          _bentoCard(
            c, isDark,
            icon: FluentIcons.calendar_clock_24_filled,
            title: "ÉCHÉANCE",
            subtitle: "Date limite de remboursement",
            child: InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _dueDate = d);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.surfaceElev,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    Icon(FluentIcons.calendar_20_regular, size: 18, color: accent),
                    const SizedBox(width: 12),
                    Text(
                      _dueDate == null ? "Sélectionner une date" : DateFormat('dd/MM/yyyy').format(_dueDate!),
                      style: TextStyle(fontWeight: FontWeight.w900, color: accent),
                    ),
                    const Spacer(),
                    Icon(Icons.edit_calendar_rounded, size: 16, color: accent.withValues(alpha: 0.4)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoyaltyZone(DashColors c, Color accent, bool isDark, ShopSettings settings) {
    final clients = ref.watch(clientListProvider).value ?? [];
    final client = clients.where((cl) => cl.id == _selectedClientId).firstOrNull;
    final availablePoints = client?.loyaltyPoints ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("FIDÉLITÉ ($availablePoints pts)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: accent)),
              if (availablePoints > 0)
                InkWell(
                  onTap: () => setState(() => _pointsToRedeemCtrl.text = availablePoints.toString()),
                  child: Text("UTILISER TOUT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: accent)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 40,
            decoration: BoxDecoration(color: c.surfaceElev, borderRadius: BorderRadius.circular(8)),
            child: TextField(
              controller: _pointsToRedeemCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(fontWeight: FontWeight.w900, color: accent),
              decoration: InputDecoration(
                hintText: "0",
                suffixText: "pts",
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) {
                final pts = int.tryParse(v) ?? 0;
                if (pts > availablePoints) _pointsToRedeemCtrl.text = availablePoints.toString();
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Gain immédiat:", style: TextStyle(fontSize: 11, color: c.textMuted)),
              Text("- ${ref.fmt((int.tryParse(_pointsToRedeemCtrl.text) ?? 0) * settings.amountPerPoint)}",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: accent)),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RIGHT: PAYMENT MATRIX
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPaymentMatrix(DashColors c, Color accent, bool isDark, String currency, List<FinancialAccount> accounts) {
    return _bentoCard(
      c, isDark,
      icon: FluentIcons.wallet_24_filled,
      title: "MATRICE D'ENCAISSEMENT",
      subtitle: "Source des fonds",
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text("Paiement Multiple", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.textPrimary))),
              Switch.adaptive(
                value: _isMixedPayment,
                onChanged: (v) => setState(() {
                  _isMixedPayment = v;
                  _mixedPaymentAmounts.clear();
                  if (!widget.isCredit) {
                    _paidCtrl.text = DateFormatter.formatNumber(_effectiveTotal.round());
                  } else {
                    _paidCtrl.text = "0";
                  }
                }),
                activeTrackColor: accent.withValues(alpha: 0.5),
                activeThumbColor: accent,
              ),
            ],
          ),
          const Divider(height: 24),
          if (_isMixedPayment)
            ...accounts.map((acc) => _buildMixedPaymentLine(acc, c, accent, isDark))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.2,
              ),
              itemCount: accounts.length,
              itemBuilder: (context, idx) {
                final acc = accounts[idx];
                final isSelected = _selectedAccountId == acc.id;
                return InkWell(
                  onTap: () => setState(() {
                    _selectedAccountId = acc.id;
                    _selectedPaymentMethod = _getPaymentName(acc);
                  }),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? accent.withValues(alpha: 0.1) : c.surfaceElev,
                      border: Border.all(color: isSelected ? accent : c.border, width: isSelected ? 2 : 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_accountIcon(acc), color: isSelected ? accent : Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            acc.name.toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                              color: isSelected ? accent : c.textSecondary,
                            ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: currentVal > 0 ? accent.withValues(alpha: 0.05) : c.surfaceElev,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: currentVal > 0 ? accent.withValues(alpha: 0.3) : c.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: (currentVal > 0 ? accent : Colors.grey).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(_accountIcon(acc), size: 16, color: currentVal > 0 ? accent : Colors.grey),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(acc.name.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: currentVal > 0 ? accent : c.textPrimary))),
            SizedBox(
              width: 150,
              height: 40,
              child: TextField(
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: currentVal > 0 ? accent : c.textPrimary),
                decoration: InputDecoration(
                  hintText: "0",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: isDark ? Colors.black26 : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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
          // Amount input LED
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c.surfaceElev, c.surfaceElev.withValues(alpha: 0.5)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isCredit ? "ACOMPTE REÇU (Optionnel)" : "MONTANT REÇU PAR LE CLIENT",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: c.textMuted),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _paidCtrl,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        textAlign: TextAlign.left,
                        style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: c.textPrimary, letterSpacing: -2),
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
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(currency, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: c.textMuted)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!widget.isCredit && quickAmounts.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: quickAmounts.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: OutlinedButton(
                        onPressed: () => _setAmount(_effectiveTotal),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: accent.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: accent.withValues(alpha: 0.5)),
                        ),
                        child: Text("Exact", style: TextStyle(fontWeight: FontWeight.w900, color: accent)),
                      ),
                    );
                  }
                  final amt = quickAmounts[index - 1];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: OutlinedButton(
                      onPressed: () => _setAmount(amt),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: c.surfaceElev,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: c.border),
                      ),
                      child: Text(DateFormatter.formatNumber(amt), style: TextStyle(fontWeight: FontWeight.w900, color: c.textPrimary)),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],

        // RECAP TOTAL
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("NET À PAYER", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  Text(ref.fmt(_effectiveTotal), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                ],
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Colors.white24, height: 1)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.isCredit ? "RESTE À SOUFFRIR" : "MONNAIE À RENDRE", style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  Text(
                    widget.isCredit ? ref.fmt((_effectiveTotal - _paid).clamp(0.0, double.infinity)) : ref.fmt(_change),
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                  ),
                ],
              ),
              if (widget.isCredit && _paid >= _effectiveTotal && _effectiveTotal > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Expanded(child: Text("L'acompte ne peut couvrir la totalité. Utilisez vente comptant.", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: (_canPay && !_processing) ? _confirmCheckout : null,
                  icon: Icon(_processing ? Icons.hourglass_empty : FluentIcons.checkmark_circle_24_regular, color: _canPay ? Colors.blueGrey.shade900 : Colors.grey),
                  label: Text(
                    _processing ? "TRAITEMENT..." : (widget.isCredit ? "ENREGISTRER LE CRÉDIT" : "VALIDER L'ENCAISSEMENT"),
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.5, color: _canPay ? Colors.blueGrey.shade900 : Colors.grey),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white54,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? c.surfaceElev : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: c.textMuted),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1, color: c.textPrimary)),
                  Text(subtitle, style: TextStyle(fontSize: 10, color: c.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _toggleModeBtn(DashColors c, {required bool isSelected, required String label, required VoidCallback onTap}) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withValues(alpha: 0.1) : c.surfaceElev,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? primaryColor.withValues(alpha: 0.5) : c.border),
        ),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w900, color: isSelected ? primaryColor : c.textMuted)),
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
    final c = DashColors.of(context);

    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Icon(FluentIcons.person_search_24_filled, color: Theme.of(context).colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Text("Sélection Client", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.textPrimary)),
                const Spacer(),
                FilledButton.icon(
                  icon: const Icon(FluentIcons.person_add_20_regular, size: 16),
                  label: const Text("Nouveau"),
                  onPressed: () {
                    showDialog(context: context, builder: (_) => _PosQuickCreateClientDialog(onCreated: (client) {
                      widget.onSelected(client.id);
                      Navigator.pop(context); // Close Quick Create
                      Navigator.pop(context); // Close Search Dialog
                    }));
                  },
                ),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Nom ou téléphone...",
                prefixIcon: const Icon(FluentIcons.search_20_regular),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  if (mounted) setState(() => _query = v);
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: clientsAsync.when(
                data: (clients) {
                  final filtered = clients.where((cl) => cl.name.toLowerCase().contains(_query.toLowerCase()) || (cl.phone ?? '').contains(_query)).toList();
                  if (filtered.isEmpty) return const Center(child: Text("Aucun client trouvé."));

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final cl = filtered[index];
                      return ListTile(
                        leading: CircleAvatar(child: Text(cl.name[0].toUpperCase())),
                        title: Text(cl.name, style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary)),
                        subtitle: Text(cl.phone ?? "Sans téléphone", style: TextStyle(color: c.textMuted)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("${cl.loyaltyPoints} pts", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                            if (cl.credit > 0)
                              Text("Débiteur", style: TextStyle(color: c.rose, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
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
