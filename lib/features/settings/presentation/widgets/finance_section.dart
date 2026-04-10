import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/widgets/premium_settings_widgets.dart';
import '../../../inventory/presentation/widgets/dashboard_widgets.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/shop_settings_models.dart';

class FinanceSettingsSection extends ConsumerWidget {
  const FinanceSettingsSection({
    super.key,
    required this.legalFormCtrl,
    required this.capitalCtrl,
    required this.rcCtrl,
    required this.nifCtrl,
    required this.bankAccountCtrl,
    required this.warrantyCtrl,
    required this.returnsCtrl,
    required this.paymentsPolicyCtrl,
    required this.validityCtrl,
    required this.legalNoteCtrl,
    required this.currency,
    required this.onCurrencyChanged,
    required this.removeDecimals,
    required this.onRemoveDecimalsChanged,
    required this.useTax,
    required this.onUseTaxChanged,
    required this.taxNameCtrl,
    required this.taxRateCtrl,
    required this.managerPinCtrl,
    required this.maxDiscountThresholdCtrl,
    required this.vipThresholdCtrl,
    required this.loyaltyEnabled,
    required this.onLoyaltyEnabledChanged,
    required this.pointsPerAmountCtrl,
    required this.amountPerPointCtrl,
    required this.onSaveDebounced,
    this.isFinanceOnly = false,
    this.isLoyaltyOnly = false,
    this.isPolicyOnly = false,
    required this.templateFiscalSettings,
    required this.onTemplateFiscalSettingChanged,
    required this.labelHTCtrl,
    required this.labelTTCCtrl,
    required this.showTaxOnTickets,
    required this.onShowTaxOnTicketsChanged,
    required this.showTaxOnInvoices,
    required this.onShowTaxOnInvoicesChanged,
    required this.showTaxOnQuotes,
    required this.onShowTaxOnQuotesChanged,
    required this.showTaxOnDeliveryNotes,
    required this.onShowTaxOnDeliveryNotesChanged,
    required this.useDetailedTaxOnTickets,
    required this.onUseDetailedTaxOnTicketsChanged,
    required this.useDetailedTaxOnInvoices,
    required this.onUseDetailedTaxOnInvoicesChanged,
    required this.useDetailedTaxOnQuotes,
    required this.onUseDetailedTaxOnQuotesChanged,
    required this.useDetailedTaxOnDeliveryNotes,
    required this.onUseDetailedTaxOnDeliveryNotesChanged,
  });

  final TextEditingController legalFormCtrl;
  final TextEditingController capitalCtrl;
  final TextEditingController rcCtrl;
  final TextEditingController nifCtrl;
  final TextEditingController bankAccountCtrl;
  final TextEditingController warrantyCtrl;
  final TextEditingController returnsCtrl;
  final TextEditingController paymentsPolicyCtrl;
  final TextEditingController validityCtrl;
  final TextEditingController legalNoteCtrl;
  final String currency;
  final ValueChanged<String?> onCurrencyChanged;
  final bool removeDecimals;
  final ValueChanged<bool> onRemoveDecimalsChanged;
  final bool useTax;
  final ValueChanged<bool> onUseTaxChanged;
  final TextEditingController taxNameCtrl;
  final TextEditingController taxRateCtrl;
  final TextEditingController managerPinCtrl;
  final TextEditingController maxDiscountThresholdCtrl;
  final TextEditingController vipThresholdCtrl;
  final bool loyaltyEnabled;
  final ValueChanged<bool> onLoyaltyEnabledChanged;
  final TextEditingController pointsPerAmountCtrl;
  final TextEditingController amountPerPointCtrl;
  final VoidCallback onSaveDebounced;
  final bool isFinanceOnly;
  final bool isLoyaltyOnly;
  final bool isPolicyOnly;
  final Map<String, dynamic> templateFiscalSettings;
  final Function(String type, String template, String field, bool val)
      onTemplateFiscalSettingChanged;
  final TextEditingController labelHTCtrl;
  final TextEditingController labelTTCCtrl;

  final bool showTaxOnTickets;
  final ValueChanged<bool> onShowTaxOnTicketsChanged;
  final bool showTaxOnInvoices;
  final ValueChanged<bool> onShowTaxOnInvoicesChanged;
  final bool showTaxOnQuotes;
  final ValueChanged<bool> onShowTaxOnQuotesChanged;
  final bool showTaxOnDeliveryNotes;
  final ValueChanged<bool> onShowTaxOnDeliveryNotesChanged;
  final bool useDetailedTaxOnTickets;
  final ValueChanged<bool> onUseDetailedTaxOnTicketsChanged;
  final bool useDetailedTaxOnInvoices;
  final ValueChanged<bool> onUseDetailedTaxOnInvoicesChanged;
  final bool useDetailedTaxOnQuotes;
  final ValueChanged<bool> onUseDetailedTaxOnQuotesChanged;
  final bool useDetailedTaxOnDeliveryNotes;
  final ValueChanged<bool> onUseDetailedTaxOnDeliveryNotesChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = DashColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isLoyaltyOnly && !isPolicyOnly) ...[
          PremiumSettingsWidgets.buildSectionHeader(
            context,
            icon: FluentIcons.gavel_24_filled,
            title: "Conformité Légale",
            subtitle: "Registre du commerce, fiscalité et banque",
            color: c.amber,
          ),
          const SizedBox(height: 12),
          PremiumSettingsWidgets.buildCard(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: PremiumSettingsWidgets.buildCompactField(
                        context,
                        controller: legalFormCtrl,
                        label: "Forme juridique",
                        icon: FluentIcons.building_16_regular,
                        hint: "SARL, SA, Ets...",
                        color: c.amber,
                        onChanged: onSaveDebounced,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 3,
                      child: PremiumSettingsWidgets.buildCompactField(
                        context,
                        controller: capitalCtrl,
                        label: "Capital Social ($currency)",
                        icon: FluentIcons.money_16_regular,
                        hint: "1.000.000",
                        color: c.amber,
                        isNumber: true,
                        onChanged: onSaveDebounced,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: PremiumSettingsWidgets.buildCompactField(
                        context,
                        controller: rcCtrl,
                        label: "R.C.C.M",
                        icon: FluentIcons.clipboard_task_16_regular,
                        hint: "BAM-2024-B-...",
                        color: c.amber,
                        onChanged: onSaveDebounced,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: PremiumSettingsWidgets.buildCompactField(
                        context,
                        controller: nifCtrl,
                        label: "N.I.F",
                        icon: FluentIcons.tag_16_regular,
                        hint: "0812345...",
                        color: c.amber,
                        onChanged: onSaveDebounced,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                PremiumSettingsWidgets.buildCompactField(
                  context,
                  controller: bankAccountCtrl,
                  label: "Coordonnées Bancaires (RIB/IBAN)",
                  icon: FluentIcons.building_bank_16_regular,
                  hint: "Code Banque / Agence / Compte",
                  color: c.amber,
                  onChanged: onSaveDebounced,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        if (isFinanceOnly) ...[
          PremiumSettingsWidgets.buildSectionHeader(
            context,
            icon: FluentIcons.building_bank_24_filled,
            title: "Comptes & Devises",
            subtitle: "Gérez vos caisses et formats de devises",
            color: c.blue,
          ),
          const SizedBox(height: 12),
          PremiumSettingsWidgets.buildCard(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: PremiumSettingsWidgets.buildCompactDropdown<String>(
                        context,
                        label: "Devise par défaut",
                        value: currency,
                        items: ['FCFA', 'EUR', 'USD', 'GNF', 'XOF'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))).toList(),
                        onChanged: (v) => onCurrencyChanged(v),
                        color: c.blue,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: PremiumSettingsWidgets.buildCompactSwitch(
                        context,
                        title: "Masquer les centimes",
                        subtitle: "Affiche des montants ronds",
                        value: removeDecimals,
                        onChanged: onRemoveDecimalsChanged,
                        activeColor: c.blue,
                        icon: FluentIcons.money_16_regular,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                PremiumSettingsWidgets.buildInfoBox(
                  context,
                  text: "La gestion détaillée de vos comptes s'effectue directement dans le module 'Finance' de l'application.",
                  color: c.blue,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        if (!isLoyaltyOnly && !isFinanceOnly) ...[
          PremiumSettingsWidgets.buildSectionHeader(
            context,
            icon: FluentIcons.document_text_24_filled,
            title: "Politiques & Conditions",
            subtitle: "Ces clauses sont imprimées sur les documents",
            color: c.violet,
          ),
          const SizedBox(height: 12),
          PremiumSettingsWidgets.buildCard(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PremiumSettingsWidgets.buildCompactField(
                  context,
                  controller: warrantyCtrl,
                  label: "Clause de garantie",
                  icon: FluentIcons.shield_checkmark_16_regular,
                  hint: "Ex: Échange standard sous 48h.",
                  maxLines: 2,
                  color: c.violet,
                  onChanged: onSaveDebounced,
                ),
                const SizedBox(height: 14),
                PremiumSettingsWidgets.buildCompactField(
                  context,
                  controller: returnsCtrl,
                  label: "Politique de retour",
                  icon: FluentIcons.arrow_undo_16_regular,
                  hint: "Ex: Avoir valable 30 jours, aucun remboursement.",
                  maxLines: 2,
                  color: c.violet,
                  onChanged: onSaveDebounced,
                ),
                const SizedBox(height: 14),
                PremiumSettingsWidgets.buildCompactField(
                  context,
                  controller: paymentsPolicyCtrl,
                  label: "Conditions de règlement",
                  icon: FluentIcons.payment_16_regular,
                  hint: "Ex: Règlement à réception de la facture.",
                  maxLines: 2,
                  color: c.violet,
                  onChanged: onSaveDebounced,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: PremiumSettingsWidgets.buildCompactField(
                        context,
                        controller: validityCtrl,
                        label: "Validité d'un devis (Jours)",
                        icon: FluentIcons.calendar_clock_16_regular,
                        hint: "30",
                        color: c.violet,
                        isNumber: true,
                        onChanged: onSaveDebounced,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(child: SizedBox()), // Placeholder
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        if (!isLoyaltyOnly && !isPolicyOnly) ...[
          PremiumSettingsWidgets.buildSectionHeader(
            context,
            icon: FluentIcons.calculator_24_filled,
            title: "Fiscalité & Taxes",
            subtitle: "Gestion du taux de taxe général et répartition",
            color: c.emerald,
          ),
          const SizedBox(height: 12),
          PremiumSettingsWidgets.buildCard(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PremiumSettingsWidgets.buildCompactSwitch(
                  context,
                  title: "Application de la Taxe (TVA/TPS)",
                  subtitle: "Active le calcul des taxes sur les ventes",
                  value: useTax,
                  onChanged: onUseTaxChanged,
                  activeColor: c.emerald,
                  icon: FluentIcons.receipt_16_regular,
                ),
                if (useTax) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: PremiumSettingsWidgets.buildCompactField(
                          context,
                          controller: taxNameCtrl,
                          label: "Libellé de la taxe",
                          icon: FluentIcons.text_16_regular,
                          hint: "TVA",
                          color: c.emerald,
                          onChanged: onSaveDebounced,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: PremiumSettingsWidgets.buildCompactField(
                          context,
                          controller: taxRateCtrl,
                          label: "Valeur (%)",
                          icon: FluentIcons.calculator_16_regular,
                          hint: "18",
                          color: c.emerald,
                          isNumber: true,
                          onChanged: onSaveDebounced,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildEliteTaxMatrix(context, c),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        if (!isFinanceOnly && !isLoyaltyOnly) ...[
          PremiumSettingsWidgets.buildSectionHeader(
            context,
            icon: FluentIcons.lock_shield_24_filled,
            title: "Autorisations & Remises",
            subtitle: "Contrôle des réductions maximales",
            color: c.cyan,
          ),
          const SizedBox(height: 12),
          PremiumSettingsWidgets.buildCard(
            context,
            child: Row(
              children: [
                Expanded(
                  child: PremiumSettingsWidgets.buildCompactField(
                    context,
                    controller: managerPinCtrl,
                    label: "PIN Manager (Approbations)",
                    icon: FluentIcons.password_16_regular,
                    hint: "1234",
                    color: c.cyan,
                    isPassword: true,
                    isNumber: true,
                    onChanged: onSaveDebounced,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: PremiumSettingsWidgets.buildCompactField(
                    context,
                    controller: maxDiscountThresholdCtrl,
                    label: "Remise automatique max (%)",
                    icon: FluentIcons.record_16_regular,
                    hint: "10",
                    color: c.cyan,
                    isNumber: true,
                    onChanged: onSaveDebounced,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        if (!isFinanceOnly && !isPolicyOnly) ...[
          PremiumSettingsWidgets.buildSectionHeader(
            context,
            icon: FluentIcons.person_star_24_filled,
            title: "Programme de Fidélité",
            subtitle: "Configuration des seuils VIP et avantages",
            color: c.amber,
          ),
          const SizedBox(height: 12),
          PremiumSettingsWidgets.buildCard(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PremiumSettingsWidgets.buildCompactField(
                  context,
                  controller: vipThresholdCtrl,
                  label: "Seuil de dépenses pour Statut VIP ($currency)",
                  icon: FluentIcons.star_16_regular,
                  hint: "1.000.000",
                  color: c.amber,
                  isNumber: true,
                  onChanged: onSaveDebounced,
                ),
                const SizedBox(height: 20),
                PremiumSettingsWidgets.buildCompactSwitch(
                  context,
                  title: "Activer les points de fidélité",
                  subtitle: "Récompensez vos clients avec des points",
                  value: loyaltyEnabled,
                  onChanged: onLoyaltyEnabledChanged,
                  activeColor: c.amber,
                  icon: FluentIcons.gift_16_regular,
                ),
                if (loyaltyEnabled) ...[
                  const SizedBox(height: 14),
                  PremiumSettingsWidgets.buildInfoBox(
                    context,
                    text: "Système de points : Vos clients accumulent des points lors de leurs achats, qu'ils peuvent ensuite dépenser sous forme de remise.",
                    color: c.amber,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: PremiumSettingsWidgets.buildCompactField(
                          context,
                          controller: pointsPerAmountCtrl,
                          label: "Dépense requise pour 1 point ($currency)",
                          icon: FluentIcons.money_16_regular,
                          hint: "1000",
                          color: c.amber,
                          isNumber: true,
                          onChanged: onSaveDebounced,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: PremiumSettingsWidgets.buildCompactField(
                          context,
                          controller: amountPerPointCtrl,
                          label: "Valeur d'utilisation de 1 point ($currency)",
                          icon: FluentIcons.ticket_diagonal_16_regular,
                          hint: "10",
                          color: c.amber,
                          isNumber: true,
                          onChanged: onSaveDebounced,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildLoyaltySim(c, Theme.of(context).brightness == Brightness.dark),
                ],
              ],
            ),
          ),
        ],
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildEliteTaxMatrix(BuildContext context, DashColors c) {
    return Container(
      decoration: BoxDecoration(
        color: c.isDark ? Colors.black.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                PremiumSettingsWidgets.buildIconBadge(icon: FluentIcons.table_settings_16_regular, color: c.emerald),
                const SizedBox(width: 10),
                Expanded(
                  child: Text("Matrice d'impression des taxes", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: c.textPrimary)),
                ),
                _buildGlobalActionBtns(c),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: PremiumSettingsWidgets.buildCompactField(
                    context,
                    controller: labelHTCtrl,
                    label: "Label Hors Taxe",
                    icon: FluentIcons.text_16_regular,
                    hint: "HT",
                    color: c.emerald,
                    onChanged: onSaveDebounced,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PremiumSettingsWidgets.buildCompactField(
                    context,
                    controller: labelTTCCtrl,
                    label: "Label Toute Taxe Comprise",
                    icon: FluentIcons.text_16_regular,
                    hint: "TTC",
                    color: c.emerald,
                    onChanged: onSaveDebounced,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: c.border.withValues(alpha: 0.1),
            child: Row(
              children: [
                Expanded(flex: 4, child: Text("DOCUMENTS", style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: c.textMuted))),
                Expanded(flex: 2, child: Center(child: Text("AFFICHER TAXE", style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: c.textMuted)))),
              ],
            ),
          ),
          const Divider(height: 1),
          _compactItems(c, "TICKETS DE CAISSE", ReceiptTemplate.values.map((t) => t.name).toList(), 'ticket'),
          _compactItems(c, "FACTURES A4", InvoiceTemplate.values.map((t) => t.name).toList(), 'invoice'),
          _compactItems(c, "DEVIS & PROFORMAS", QuoteTemplate.values.map((t) => t.name).toList(), 'quote'),
          _compactItems(c, "BONS DE LIVRAISON", InvoiceTemplate.values.map((t) => t.name).toList(), 'delivery'),
        ],
      ),
    );
  }

  Widget _buildGlobalActionBtns(DashColors c) {
    return Row(
      children: [
        Tooltip(
          message: "Tout Activer",
          child: InkWell(
            onTap: () => _toggleAll(true),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(FluentIcons.checkmark_circle_20_regular, color: c.emerald, size: 18),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Tooltip(
          message: "Tout Désactiver",
          child: InkWell(
            onTap: () => _toggleAll(false),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(FluentIcons.dismiss_circle_20_regular, color: c.textSecondary, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  void _toggleAll(bool val) {
    final types = ['ticket', 'invoice', 'quote', 'delivery'];
    for (final type in types) {
      final templates = type == 'ticket'
          ? ReceiptTemplate.values.map((t) => t.name)
          : (type == 'invoice' || type == 'delivery'
              ? InvoiceTemplate.values.map((t) => t.name)
              : QuoteTemplate.values.map((t) => t.name));
      for (final t in templates) {
        onTemplateFiscalSettingChanged(type, t, 'show', val);
        onTemplateFiscalSettingChanged(type, t, 'detailed', val);
      }
    }
  }

  Widget _compactItems(DashColors c, String groupLabel, List<String> templates, String type) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: c.emerald.withValues(alpha: 0.05),
          child: Text(groupLabel, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: c.emerald.withValues(alpha: 0.8), letterSpacing: 0.5)),
        ),
        ...templates.map((t) {
          final showKey = '${t}_show';
          final showVal = templateFiscalSettings[type]?[showKey] ?? true;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border, width: 0.5))),
            child: Row(
              children: [
                Expanded(flex: 4, child: Text(t.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c.textPrimary))),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Transform.scale(
                      scale: 0.75,
                      child: Switch.adaptive(
                        value: showVal,
                        onChanged: (v) {
                          onTemplateFiscalSettingChanged(type, t, 'show', v);
                          onTemplateFiscalSettingChanged(type, t, 'detailed', v);
                        },
                        activeColor: c.emerald,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLoyaltySim(DashColors c, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Text("SIMULATION RAPIDE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: c.textSecondary)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniSim("Dépense 10.000", "+${(10000 / (double.tryParse(pointsPerAmountCtrl.text) ?? 1000)).floor()} pts", c.amber),
              Icon(FluentIcons.arrow_right_16_regular, size: 14, color: c.textMuted),
              _buildMiniSim("100 pts utilisés", "-${(100 * (double.tryParse(amountPerPointCtrl.text) ?? 10)).floor()} $currency", AppTheme.successClr),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniSim(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }
}
