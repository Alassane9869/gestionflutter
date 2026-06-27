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
  String _filterType = 'ALL'; // 'ALL', 'IN', 'OUT'

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
              final totalBalance = treasuryAsync.value?.fold<double>(0, (sum, a) => sum + a.balance) ?? 0;
              final totalIn = stats['in'] ?? 0;
              final totalOut = stats['out'] ?? 0;
              return SizedBox(
                height: 84,
                child: Row(children: [
                  _buildPremiumKpi(accent, FluentIcons.money_24_filled, "Solde Global", ref.fmt(totalBalance), isDark),
                  const SizedBox(width: 16),
                  _buildPremiumKpi(const Color(0xFF10B981), FluentIcons.arrow_right_24_regular, "Entrées", ref.fmt(totalIn), isDark),
                  const SizedBox(width: 16),
                  _buildPremiumKpi(theme.colorScheme.error, FluentIcons.arrow_left_24_regular, "Sorties", ref.fmt(totalOut), isDark),
                  const SizedBox(width: 16),
                  _buildPremiumKpi(Colors.orange, FluentIcons.building_bank_24_regular, "Comptes", "${treasuryAsync.value?.length ?? 0}", isDark),
                ]),
              );
            },
          ),
          const SizedBox(height: 28),

          Expanded(
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── ACCOUNTS LIST ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "COMPTES DE TRÉSORERIE",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      "${treasuryAsync.value?.length ?? 0} actif(s)",
                      style: TextStyle(
                        fontSize: 11,
                        color: accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 180,
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

                const SizedBox(height: 32),

                // ── TRANSACTIONS LIST (Ledger Header with Tabs and Search) ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "MOUVEMENTS DE CAISSE",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    
                    // Premium Tab Filter Pills
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? theme.colorScheme.surface : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildFilterTab("Tous", 'ALL', isDark),
                          _buildFilterTab("Entrées", 'IN', isDark),
                          _buildFilterTab("Sorties", 'OUT', isDark),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Beautiful search field
                    Container(
                      width: 260,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark ? theme.colorScheme.surface : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: "Rechercher une opération...",
                          prefixIcon: const Icon(FluentIcons.search_20_regular, size: 16),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE5E7EB)),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.015),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                  ),
                  child: historyAsync.when(
                    data: (txs) {
                      final filtered = txs.where((t) {
                        final queryMatch = (t.description ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
                            t.category.label.toLowerCase().contains(_searchQuery.toLowerCase());
                        
                        if (_filterType == 'ALL') return queryMatch;
                        if (_filterType == 'IN') return queryMatch && t.type == TransactionType.IN;
                        return queryMatch && t.type == TransactionType.OUT;
                      }).toList();

                      if (filtered.isEmpty) {
                        return SizedBox(
                          height: 160,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(FluentIcons.clipboard_search_24_regular, size: 40, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  "Aucun mouvement trouvé",
                                  style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length > 20 ? 20 : filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _TransactionItem(tx: filtered[i], fmt: ref.fmt),
                      );
                    },
                    loading: () => const SizedBox(
                      height: 160,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => const SizedBox(
                      height: 160,
                      child: Center(child: Text("Erreur de chargement")),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
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
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          final accent = type == TransactionType.IN ? const Color(0xFF10B981) : theme.colorScheme.error;

          final amount = (double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0).abs();
          final isInsufficient = type == TransactionType.OUT && selectedAccount != null && selectedAccount!.balance < amount;

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 500,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141418) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // HEADER
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [accent.withValues(alpha: 0.8), accent]),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(type == TransactionType.IN ? FluentIcons.arrow_down_24_filled : FluentIcons.arrow_up_24_filled, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "NOUVELLE TRANSACTION",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                "Enregistrez une entrée ou sortie d'argent",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: 20, color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1, thickness: 1),
                  ),

                  // BODY
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // TYPE TABS
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
                          ),
                          child: Row(
                            children: TransactionType.values.map((t) {
                              final sel = type == t;
                              final c = t == TransactionType.IN ? const Color(0xFF10B981) : theme.colorScheme.error;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () => setDialogState(() => type = t),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: sel ? c : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: sel ? [BoxShadow(color: c.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))] : [],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(t == TransactionType.IN ? FluentIcons.arrow_down_24_regular : FluentIcons.arrow_up_24_regular, size: 16, color: sel ? Colors.white : (isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
                                        const SizedBox(width: 6),
                                        Text(
                                          t.label.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: sel ? Colors.white : (isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),

                        Row(children: [
                          Expanded(
                            child: EnterpriseWidgets.buildPremiumDropdown<FinancialAccount>(
                              label: "COMPTE SOURCE",
                              value: selectedAccount,
                              icon: FluentIcons.building_bank_24_regular,
                              items: accounts,
                              itemLabel: (a) => "${a.name} (${ref.fmt(a.balance)})",
                              onChanged: (v) => setDialogState(() => selectedAccount = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: EnterpriseWidgets.buildPremiumDropdown<TransactionCategory>(
                              label: "CATÉGORIE",
                              value: category,
                              icon: FluentIcons.tag_24_regular,
                              items: TransactionType.IN == type 
                                  ? [TransactionCategory.SALE, TransactionCategory.TRANSFER, TransactionCategory.ADJUSTMENT, TransactionCategory.REFUND, TransactionCategory.DEBT_REPAYMENT]
                                  : [TransactionCategory.EXPENSE, TransactionCategory.PURCHASE, TransactionCategory.TRANSFER, TransactionCategory.ADJUSTMENT, TransactionCategory.REFUND],
                              itemLabel: (c) => c.label,
                              onChanged: (v) => setDialogState(() => category = v!),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        EnterpriseWidgets.buildPremiumTextField(
                          context, 
                          ctrl: amountCtrl, 
                          label: "MONTANT", 
                          hint: "0.00", 
                          icon: FluentIcons.money_24_regular, 
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                  ),
                  const SizedBox(height: 24),

                  // ACTIONS
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(
                                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              "ANNULER",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 1,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
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
                            icon: const Icon(FluentIcons.save_24_regular, size: 18, color: Colors.white),
                            label: const Text(
                              "ENREGISTRER",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 1,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              disabledBackgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
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

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 500,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141418) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // HEADER
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [typeColor.withValues(alpha: 0.8), typeColor]),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: typeColor.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(iconForType(selectedType), color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "NOUVEAU COMPTE",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                "Créez une caisse ou associez une banque",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: 20, color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1, thickness: 1),
                  ),

                  // BODY
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // TYPE SELECTOR
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
                          EnterpriseWidgets.buildPremiumTextField(context, ctrl: balanceCtrl, label: "SOLDE INITIAL", hint: "0", icon: FluentIcons.money_24_regular, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
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
                                    activeThumbColor: typeColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ACTIONS
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(
                                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              "ANNULER",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 1,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              if (nameCtrl.text.isNotEmpty) {
                                final initBalance = double.tryParse(balanceCtrl.text.replaceAll(',', '.')) ?? 0.0;
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
                            icon: const Icon(FluentIcons.save_24_regular, size: 18, color: Colors.white),
                            label: const Text(
                              "CRÉER LE COMPTE",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 1,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: typeColor,
                              disabledBackgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
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
    );
  }

  Widget _buildPremiumKpi(Color color, IconData icon, String label, String value, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : color.withValues(alpha: 0.15),
            width: 1.2,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String label, String type, bool isDark) {
    final selected = _filterType == type;
    return GestureDetector(
      onTap: () => setState(() => _filterType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w900 : FontWeight.bold,
            color: selected
                ? (isDark ? Colors.white : Colors.black87)
                : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
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
        return const Color(0xFF000000); // OLED black
      case AccountType.BANK:
        if (op.contains('boa')) return const Color(0xFF022C22); // Deep green
        if (op.contains('ecobank')) return const Color(0xFF0F172A); // Deep blue/slate
        if (op.contains('uba')) return const Color(0xFF7F1D1D); // Deep red
        return const Color(0xFF111827);
      case AccountType.MOBILE_MONEY:
        if (op.contains('wave')) return const Color(0xFF0F172A); // Deep blue
        if (op.contains('orange')) return const Color(0xFF1C0A00); // Deep orange/rust
        if (op.contains('mtn')) return const Color(0xFF1C1900); // Deep gold/amber
        if (op.contains('moov')) return const Color(0xFF14532D); // Deep green
        return const Color(0xFF4C1D95); // Deep purple
    }
  }

  Color _gradientEnd() {
    final op = (account.operator ?? '').toLowerCase();
    switch (account.type) {
      case AccountType.CASH:
        return const Color(0xFF0C0C0F);
      case AccountType.BANK:
        if (op.contains('boa')) return const Color(0xFF059669);
        if (op.contains('ecobank')) return const Color(0xFF2563EB);
        if (op.contains('uba')) return const Color(0xFFDC2626);
        return const Color(0xFF374151);
      case AccountType.MOBILE_MONEY:
        if (op.contains('wave')) return const Color(0xFF3B82F6);
        if (op.contains('orange')) return const Color(0xFFEA580C);
        if (op.contains('mtn')) return const Color(0xFFCA8A04);
        if (op.contains('moov')) return const Color(0xFF16A34A);
        return const Color(0xFF7C3AED);
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

  Widget _buildCardChip() {
    return Container(
      width: 38,
      height: 28,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFEF08A), // Gold chip color shades
            Color(0xFFFBBF24),
            Color(0xFFD97706),
            Color(0xFFCA8A04),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 3,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black.withValues(alpha: 0.25), width: 0.5),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Center(
            child: Container(
              height: 0.5,
              color: Colors.black.withValues(alpha: 0.25),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(left: 10),
              width: 0.5,
              height: 28,
              color: Colors.black.withValues(alpha: 0.25),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              width: 0.5,
              height: 28,
              color: Colors.black.withValues(alpha: 0.25),
            ),
          ),
          Center(
            child: Container(
              width: 10,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFFFBBF24),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: Colors.black.withValues(alpha: 0.15), width: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c1 = _gradientStart();
    final c2 = _gradientEnd();
    final isCash = account.type == AccountType.CASH;

    final lastFour = account.id.hashCode.abs().toString().padRight(4, '0').substring(0, 4);
    final cardNumber = isCash ? "••••  ••••  ••••  CASH" : "••••  ••••  ••••  $lastFour";

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
        width: 320,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c1, c2],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCash 
                ? const Color(0xFFD97706).withValues(alpha: 0.35) 
                : Colors.white.withValues(alpha: 0.15), 
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: c1.withValues(alpha: 0.35),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Opacity(
                opacity: 0.15,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 24,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 16,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCardChip(),
                    const SizedBox(width: 8),
                    const Icon(FluentIcons.wifi_1_20_regular, color: Colors.white60, size: 16),
                    const Spacer(),
                    if (account.isDefault)
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(FluentIcons.star_16_filled, color: Colors.amber, size: 12),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  account.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      cardNumber,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontFamily: 'monospace',
                        letterSpacing: 1.5,
                      ),
                    ),
                    if (account.operator != null && account.operator!.isNotEmpty)
                      Text(
                        account.operator!.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      )
                    else
                      Text(
                        _typeLabel(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "SOLDE DISPONIBLE",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              fmtBalance,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(_icon(), color: Colors.white54, size: 18),
                  ],
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C0C0E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(getIcon(), color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description?.isNotEmpty == true ? tx.description! : tx.category.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      DateFormatter.formatDayMonthTime(tx.date),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tx.category.label.toUpperCase(),
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.grey.shade500,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
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
            children: [
              Text(
                "${isIn ? '+' : '-'}${fmt(tx.amount)}",
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isIn ? 'ENTRÉE' : 'SORTIE',
                  style: TextStyle(
                    color: color,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


// _DropdownTile removed
