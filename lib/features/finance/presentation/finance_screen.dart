import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/core/widgets/access_denied_screen.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/finance/providers/treasury_provider.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/features/finance/domain/models/financial_account.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/inventory/presentation/dashboard_screen.dart';


class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    
    final treasuryAsync = ref.watch(myTreasuryAccountsProvider);
    final historyAsync = ref.watch(transactionHistoryProvider);
    final statsAsync = ref.watch(financialStatsProvider);
    
    final user = ref.watch(authServiceProvider).value;
    if (user == null || !user.canAccessFinance) {
      return const AccessDeniedScreen(
        message: "Accès Finance Restreint",
        subtitle: "Seuls les administrateurs et comptables peuvent consulter la trésorerie.",
      );
    }

    // Log access once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).logActivity(
        userId: user.id,
        actionType: 'VIEW_FINANCE',
        description: 'Consultation de la trésorerie par ${user.username}',
      );
    });
    
    // Removed local fmt logic, now using ref.fmt extension
    // final settings = ref.watch(shopSettingsProvider).value;
    // final currency = settings?.currency ?? 'FCFA';
    // final removeDecimals = settings?.removeDecimals ?? true;
    // String fmt(double val) => CurrencyFormatter.format(val, currency: currency, removeDecimals: removeDecimals);

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HEADER ──
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            if (Navigator.canPop(context) || ref.watch(navigationProvider) != 0)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: IconButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      ref.read(navigationProvider.notifier).setPage(0, ref);
                    }
                  },
                  icon: const Icon(FluentIcons.chevron_left_24_regular),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.7)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(FluentIcons.building_bank_24_filled, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Trésorerie & Finance", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF1F2937))),
              Text("Suivi de vos caisses, banques et flux financiers", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ])),
            OutlinedButton.icon(
              onPressed: () => _showAddAccountDialog(context, ref),
              icon: const Icon(FluentIcons.add_circle_20_regular, size: 18),
              label: const Text("Nouveau Compte", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () {
                final accounts = treasuryAsync.value ?? [];
                if (accounts.isNotEmpty) {
                  _showTransactionDialog(context, ref, accounts);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Créez d'abord un compte.")));
                }
              },
              icon: const Icon(FluentIcons.money_hand_20_regular, size: 18),
              label: const Text("Transaction", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // ── KPI ROW (Global Stats) ──
          statsAsync.when(
            loading: () => const SizedBox(height: 88, child: Center(child: CircularProgressIndicator())),
            error: (err, _) => const SizedBox(height: 88),
            data: (stats) {
              final totalBalance = (stats['in'] ?? 0) - (stats['out'] ?? 0);
              final totalIn = stats['in'] ?? 0;
              final totalOut = stats['out'] ?? 0;
              return SizedBox(
                height: 96,
                child: Row(children: [
                  _buildPremiumKpi(accent, FluentIcons.money_24_filled, "Solde Total", ref.fmt(totalBalance), isDark),
                  const SizedBox(width: 12),
                  _buildPremiumKpi(const Color(0xFF10B981), FluentIcons.arrow_right_24_regular, "Entrées", ref.fmt(totalIn), isDark),
                  const SizedBox(width: 12),
                  _buildPremiumKpi(theme.colorScheme.error, FluentIcons.arrow_left_24_regular, "Sorties", ref.fmt(totalOut), isDark),
                  const SizedBox(width: 12),
                  _buildPremiumKpi(Colors.orange, FluentIcons.building_bank_24_regular, "Nb Comptes", "${treasuryAsync.value?.length ?? 0}", isDark),
                ]),
              );
            },
          ),
          const SizedBox(height: 20),

          Expanded(
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── ACCOUNTS LIST ──
                Text("VOS COMPTES", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade500, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 170,
                  child: treasuryAsync.when(
                    data: (accounts) {
                      if (accounts.isEmpty) return const Center(child: Text("Aucun compte créé"));
                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: accounts.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (_, i) => _AccountCard(account: accounts[i], fmtBalance: ref.fmt(accounts[i].balance)),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),

                const SizedBox(height: 24),

                // ── TRANSACTIONS LIST ──
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text("DERNIERS MOUVEMENTS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade500, letterSpacing: 1.2)),
                  const Spacer(),
                  // Simple search for transactions
                  Container(
                    width: 250,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2128) : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: "Filtrer mouvements...",
                        prefixIcon: const Icon(FluentIcons.search_16_regular, size: 14),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB)),
                  ),
                  child: historyAsync.when(
                    data: (txs) {
                      final filtered = txs.where((t) => (t.description ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) || t.category.label.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                      if (filtered.isEmpty) return const Center(child: Text("Aucun mouvement trouvé", style: TextStyle(color: Colors.grey)));
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length > 15 ? 15 : filtered.length,
                        separatorBuilder: (_, __) => Divider(height: 24, color: isDark ? const Color(0xFF2D3039) : const Color(0xFFF3F4F6)),
                        itemBuilder: (_, i) => _TransactionItem(tx: filtered[i], fmt: ref.fmt),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const Text("Erreur de chargement"),
                  ),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── DIALOGS ──

  void _showTransactionDialog(BuildContext context, WidgetRef ref, List<FinancialAccount> accounts) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    TransactionType type = TransactionType.OUT;
    TransactionCategory category = TransactionCategory.EXPENSE;
    FinancialAccount? selectedAccount = accounts.firstOrNull;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final amount = (double.tryParse(amountCtrl.text) ?? 0.0).abs();
          final isInsufficient = type == TransactionType.OUT && selectedAccount != null && selectedAccount!.balance < amount;

          return EnterpriseWidgets.buildPremiumDialog(
            context,
            title: "Nouvelle Transaction",
            icon: FluentIcons.money_hand_24_regular,
            width: 500,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Annuler"),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: isInsufficient || amount <= 0 || selectedAccount == null 
                  ? null 
                  : () async {
                    final tx = FinancialTransaction(
                      accountId: selectedAccount!.id,
                      type: type,
                      amount: amount,
                      category: category,
                      description: descCtrl.text,
                      date: DateTime.now(),
                    );
                    await ref.read(treasuryProvider.notifier).addTransaction(tx);
                    if (context.mounted) Navigator.pop(context);
                  },
                style: FilledButton.styleFrom(
                  backgroundColor: isInsufficient ? Colors.grey : null,
                ),
                child: const Text("Enregistrer"),
              ),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                    child: EnterpriseWidgets.buildPremiumDropdown<TransactionType>(
                      label: "TYPE D'OPÉRATION",
                      value: type,
                      icon: type == TransactionType.IN ? FluentIcons.money_24_regular : FluentIcons.money_dismiss_24_regular,
                      items: TransactionType.values,
                      itemLabel: (t) => t.label,
                      onChanged: (v) => setDialogState(() => type = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: EnterpriseWidgets.buildPremiumDropdown<TransactionCategory>(
                      label: "CATÉGORIE",
                      value: category,
                      icon: FluentIcons.tag_24_regular,
                      items: TransactionCategory.values,
                      itemLabel: (c) => c.label,
                      onChanged: (v) => setDialogState(() => category = v!),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                EnterpriseWidgets.buildPremiumDropdown<FinancialAccount>(
                  label: "COMPTE SOURCE",
                  value: selectedAccount,
                  icon: FluentIcons.building_bank_24_regular,
                  items: accounts,
                  itemLabel: (a) => "${a.name} (${ref.fmt(a.balance)})",
                  onChanged: (v) => setDialogState(() => selectedAccount = v),
                ),
                const SizedBox(height: 16),
                EnterpriseWidgets.buildPremiumTextField(
                  context, 
                  ctrl: amountCtrl, 
                  label: "MONTANT", 
                  hint: "0.00", 
                  icon: FluentIcons.money_24_regular, 
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setDialogState(() {}),
                ),
                if (isInsufficient)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        const Icon(FluentIcons.warning_16_filled, color: Colors.red, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          "Solde insuffisant (Dispo: ${ref.fmt(selectedAccount?.balance ?? 0)})",
                          style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                EnterpriseWidgets.buildPremiumTextField(
                  context, 
                  ctrl: descCtrl, 
                  label: "DESCRIPTION", 
                  hint: "Détails de l'opération...", 
                  icon: FluentIcons.text_description_24_regular,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController();
    AccountType selectedType = AccountType.CASH;
    String? selectedOperator;
    bool isDefault = false;

    final mobileOperators = ['Wave', 'Orange Money', 'MTN Money', 'Moov Money', 'Free Money', 'Autre'];
    final bankOptions = ['Ecobank', 'BOA', 'UBA', 'SGBCI', 'BICICI', 'BNI', 'NSIA', 'Autre'];

    IconData iconForType(AccountType t) {
      switch (t) {
        case AccountType.CASH: return FluentIcons.wallet_24_filled;
        case AccountType.BANK: return FluentIcons.building_bank_24_filled;
        case AccountType.MOBILE_MONEY: return FluentIcons.phone_24_filled;
      }
    }

    Color colorForType(AccountType t) {
      switch (t) {
        case AccountType.CASH: return const Color(0xFF10B981);
        case AccountType.BANK: return const Color(0xFF3B82F6);
        case AccountType.MOBILE_MONEY: return Colors.orange;
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDS) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          final typeColor = colorForType(selectedType);

          return EnterpriseWidgets.buildPremiumDialog(
            context,
            title: "Nouveau Compte",
            icon: iconForType(selectedType),
            width: 500,
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(FluentIcons.checkmark_24_regular, size: 18),
                label: const Text("CRÉER LE COMPTE", style: TextStyle(fontWeight: FontWeight.w900)),
                style: FilledButton.styleFrom(
                  backgroundColor: typeColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  if (nameCtrl.text.isNotEmpty) {
                    final initBalance = double.tryParse(balanceCtrl.text) ?? 0.0;
                    await ref.read(treasuryProvider.notifier).createAccount(
                      nameCtrl.text,
                      selectedType,
                      balance: initBalance,
                      operator: selectedOperator,
                      isDefault: isDefault,
                    );
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ],
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── TYPE SELECTOR (Visual Cards) ──
                  const Text("TYPE DE COMPTE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
                  const SizedBox(height: 12),
                  Row(
                    children: AccountType.values.map((t) {
                      final selected = selectedType == t;
                      final c = colorForType(t);
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setDS(() {
                            selectedType = t;
                            selectedOperator = null;
                            if (t == AccountType.CASH && nameCtrl.text.isEmpty) nameCtrl.text = 'Caisse';
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: EdgeInsets.only(right: t != AccountType.MOBILE_MONEY ? 8 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selected ? c : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected ? c : (isDark ? Colors.white12 : Colors.grey.shade200),
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(iconForType(t), size: 20, color: selected ? Colors.white : c),
                                const SizedBox(height: 4),
                                Text(
                                  t == AccountType.CASH ? 'Espèces' : (t == AccountType.BANK ? 'Banque' : 'Mobile'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  if (selectedType == AccountType.MOBILE_MONEY) ...[
                    const Text("OPÉRATEUR", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: mobileOperators.map((op) {
                        final sel = selectedOperator == op;
                        return GestureDetector(
                          onTap: () => setDS(() {
                            selectedOperator = op;
                            if (nameCtrl.text.isEmpty || mobileOperators.contains(nameCtrl.text)) nameCtrl.text = op;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: sel ? Colors.orange : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: sel ? Colors.orange : (isDark ? Colors.white12 : Colors.grey.shade200)),
                            ),
                            child: Text(
                              op,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sel ? Colors.white : (isDark ? Colors.white70 : Colors.black87)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (selectedType == AccountType.BANK) ...[
                    const Text("BANQUE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: bankOptions.map((bank) {
                        final sel = selectedOperator == bank;
                        return GestureDetector(
                          onTap: () => setDS(() {
                            selectedOperator = bank;
                            if (nameCtrl.text.isEmpty || bankOptions.contains(nameCtrl.text)) nameCtrl.text = bank;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: sel ? const Color(0xFF3B82F6) : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: sel ? const Color(0xFF3B82F6) : (isDark ? Colors.white12 : Colors.grey.shade200)),
                            ),
                            child: Text(
                              bank,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sel ? Colors.white : (isDark ? Colors.white70 : Colors.black87)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  EnterpriseWidgets.buildPremiumTextField(context, ctrl: nameCtrl, label: "NOM DU COMPTE", hint: "Ex: Caisse Principale...", icon: FluentIcons.rename_24_regular),
                  const SizedBox(height: 16),
                  EnterpriseWidgets.buildPremiumTextField(context, ctrl: balanceCtrl, label: "SOLDE INITIAL", hint: "0", icon: FluentIcons.money_24_regular, keyboardType: TextInputType.number),
                  const SizedBox(height: 16),

                  // Default Toggle
                  GestureDetector(
                    onTap: () => setDS(() => isDefault = !isDefault),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDefault ? typeColor.withValues(alpha: 0.05) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDefault ? typeColor.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          Icon(FluentIcons.star_24_filled, size: 18, color: isDefault ? typeColor : Colors.grey),
                          const SizedBox(width: 12),
                          const Expanded(child: Text("Utiliser par défaut", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          Switch(
                            value: isDefault,
                            onChanged: (v) => setDS(() => isDefault = v),
                            activeColor: typeColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPremiumKpi(Color color, IconData icon, String label, String value, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16181D) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Components
// ─────────────────────────────────────────────────────────────────────────────

class _AccountCard extends ConsumerWidget {
  final FinancialAccount account;
  final String fmtBalance;
  const _AccountCard({required this.account, required this.fmtBalance});

  Color _gradientStart() {
    final op = (account.operator ?? '').toLowerCase();
    switch (account.type) {
      case AccountType.CASH:
        return const Color(0xFF065F46);
      case AccountType.BANK:
        if (op.contains('boa')) return const Color(0xFF1B4D3E);
        if (op.contains('ecobank')) return const Color(0xFF003366);
        if (op.contains('uba')) return const Color(0xFF8B0000);
        return const Color(0xFF1E3A8A);
      case AccountType.MOBILE_MONEY:
        if (op.contains('wave')) return const Color(0xFF1A237E);
        if (op.contains('orange')) return const Color(0xFF7C2D12);
        if (op.contains('mtn')) return const Color(0xFF827717);
        if (op.contains('moov')) return const Color(0xFF1B5E20);
        return const Color(0xFF4A148C);
    }
  }

  Color _gradientEnd() {
    final op = (account.operator ?? '').toLowerCase();
    switch (account.type) {
      case AccountType.CASH:
        return const Color(0xFF10B981);
      case AccountType.BANK:
        if (op.contains('boa')) return const Color(0xFF2E8B57);
        if (op.contains('ecobank')) return const Color(0xFF4169E1);
        if (op.contains('uba')) return const Color(0xFFCD5C5C);
        return const Color(0xFF3B82F6);
      case AccountType.MOBILE_MONEY:
        if (op.contains('wave')) return const Color(0xFF42A5F5);
        if (op.contains('orange')) return Colors.orange;
        if (op.contains('mtn')) return const Color(0xFFFFEB3B);
        if (op.contains('moov')) return const Color(0xFF4CAF50);
        return const Color(0xFF9C27B0);
    }
  }

  IconData _icon() {
    switch (account.type) {
      case AccountType.CASH: return FluentIcons.wallet_24_filled;
      case AccountType.BANK: return FluentIcons.building_bank_24_filled;
      case AccountType.MOBILE_MONEY: return FluentIcons.phone_24_filled;
    }
  }

  String _typeLabel() {
    switch (account.type) {
      case AccountType.CASH: return 'ESPÈCES';
      case AccountType.BANK: return 'BANQUE';
      case AccountType.MOBILE_MONEY: return 'MOBILE';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c1 = _gradientStart();
    final c2 = _gradientEnd();

    return GestureDetector(
      onSecondaryTapDown: (details) {
        _showContextMenu(context, ref, details.globalPosition);
      },
      onLongPress: () {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final offset = box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2));
        _showContextMenu(context, ref, offset);
      },
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [c1, c2],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: c2.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5)),
            BoxShadow(color: c1.withValues(alpha: 0.2), blurRadius: 25, offset: const Offset(0, 10)),
          ],
        ),
        child: Stack(
          children: [
            // Background decoration
            Positioned(right: -15, top: -15, child: Icon(FluentIcons.sparkle_48_filled, size: 80, color: Colors.white.withValues(alpha: 0.04))),
            Positioned(left: -20, bottom: -20, child: Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.03),
              ),
            )),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Icon + Type Badge + Default
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_icon(), color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _typeLabel(),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
                    ),
                    const Spacer(),
                    if (account.isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(FluentIcons.star_24_filled, color: Colors.amber, size: 11),
                            SizedBox(width: 4),
                            Text("PAR DÉFAUT", style: TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                  ],
                ),
                const Spacer(),

                // Operator name (if any)
                if (account.operator != null && account.operator!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      account.operator!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),

                // Account name
                Text(
                  account.name.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // Balance
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    fmtBalance,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, WidgetRef ref, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        if (!account.isDefault)
          PopupMenuItem(
            onTap: () => ref.read(treasuryProvider.notifier).setDefaultAccount(account.id),
            child: const Row(children: [
              Icon(FluentIcons.star_24_regular, size: 18, color: Colors.orange),
              SizedBox(width: 10),
              Text("Définir par défaut", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ),
        PopupMenuItem(
          onTap: () => _showEditAccountDialog(context, ref, account),
          child: const Row(children: [
            Icon(FluentIcons.edit_24_regular, size: 18),
            SizedBox(width: 10),
            Text("Modifier le nom", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
        PopupMenuItem(
          onTap: () async {
            if (account.balance != 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Impossible de supprimer un compte avec un solde non nul (${ref.fmt(account.balance)})"),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            
            await EnterpriseWidgets.showPremiumConfirmDialog(
              context,
              title: "Supprimer ce compte ?",
              message: "Le compte '${account.name}' sera supprimé définitivement. Cette action est irréversible.",
              confirmText: "SUPPRIMER",
              isDestructive: true,
              onConfirm: () async {
                try {
                  await ref.read(treasuryProvider.notifier).deleteAccount(account.id);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString().replaceAll('Exception: ', '')),
                        backgroundColor: Colors.red.shade600,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                }
              },
            );
          },
          child: Row(children: [
            Icon(FluentIcons.delete_24_regular, size: 18, color: Colors.red.shade400),
            const SizedBox(width: 10),
            Text("Supprimer", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.red.shade400)),
          ]),
        ),
      ],
    );
  }

  void _showEditAccountDialog(BuildContext context, WidgetRef ref, FinancialAccount account) {
    final nameCtrl = TextEditingController(text: account.name);
    showDialog(
      context: context,
      builder: (ctx) => EnterpriseWidgets.buildPremiumDialog(
        context,
        title: "Modifier le compte",
        icon: FluentIcons.edit_24_regular,
        width: 450,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                ref.read(treasuryProvider.notifier).updateAccountName(account.id, nameCtrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text("Enregistrer les modifications"),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EnterpriseWidgets.buildPremiumTextField(
              context,
              ctrl: nameCtrl,
              label: "NOM DU COMPTE",
              hint: "Saisissez le nouveau nom...",
              icon: FluentIcons.rename_24_regular,
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final FinancialTransaction tx;
  final String Function(double) fmt;
  const _TransactionItem({required this.tx, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final isIn = tx.type == TransactionType.IN;
    final color = isIn ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    
    IconData getIcon() {
      switch (tx.category) {
        case TransactionCategory.SALE: return FluentIcons.cart_24_regular;
        case TransactionCategory.EXPENSE: return FluentIcons.receipt_24_regular;
        case TransactionCategory.TRANSFER: return FluentIcons.arrow_swap_24_regular;
        case TransactionCategory.REFUND: return FluentIcons.arrow_undo_24_regular;
        default: return FluentIcons.money_24_regular;
      }
    }

    return Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
        child: Icon(getIcon(), color: color, size: 20),
      ),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tx.description?.isNotEmpty == true ? tx.description! : tx.category.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        Row(children: [
          Text(DateFormatter.formatDayMonthTime(tx.date), style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(width: 4, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(tx.category.label, style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w700)),
        ]),
      ])),
      const SizedBox(width: 12),
      Text("${isIn ? '+' : '-'}${fmt(tx.amount)}", style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 15)),
    ]);
  }
}


// _DropdownTile removed
