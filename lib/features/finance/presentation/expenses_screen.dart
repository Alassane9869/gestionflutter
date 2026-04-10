import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/finance/domain/models/financial_account.dart';
import 'package:danaya_plus/features/finance/providers/treasury_provider.dart';
// import 'package:danaya_plus/core/utils/currency_formatter.dart'; // Retired
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/features/inventory/presentation/widgets/dashboard_widgets.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';


const List<String> kExpenseCategories = [
  'Loyer', 'Électricité', 'Eau', 'Transport', 
  'Fournitures', 'Salaires', 'Communication', 'Autre'
];

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String _selectedFilter = 'Tout';

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionHistoryProvider);
    final c = DashColors.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        title: Text("Dépenses Opérationnelles", style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: c.rose,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(FluentIcons.add_24_regular, size: 20),
              label: const Text("NOUVELLE DÉPENSE"),
              onPressed: () => _showAddExpenseDialog(context),
            ),
          ),
        ],
      ),
      body: transactionsAsync.when(
        data: (txs) {
          // Filtrer uniquement les EXPENSE manuels (exclure les PURCHASES fournisseurs)
          List<FinancialTransaction> expenses = txs.where((t) => t.category == TransactionCategory.EXPENSE).toList();
          
          // KPIs
          final now = DateTime.now();
          final thisMonthExpenses = expenses.where((e) => e.date.month == now.month && e.date.year == now.year).toList();
          final totalThisMonth = thisMonthExpenses.fold(0.0, (sum, e) => sum + e.amount);
          
          // Category Filter
          if (_selectedFilter != 'Tout') {
            expenses = expenses.where((e) {
              final isPurchase = e.description?.startsWith('Paiement Achat') ?? false;
              final cat = isPurchase ? 'Achat Fournisseur' : (e.referenceId ?? 'Autre');
              return cat == _selectedFilter;
            }).toList();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildKPISection(c, totalThisMonth, thisMonthExpenses.length, expenses.length),
              _buildCategoryFilters(c),
              Expanded(
                child: expenses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(FluentIcons.receipt_money_24_regular, size: 64, color: c.border),
                            const SizedBox(height: 16),
                            Text("Aucune dépense trouvée", style: TextStyle(color: c.textSecondary, fontSize: 16)),
                          ],
                        ),
                      )
                    : _ExpenseList(expenses: expenses),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text("Erreur: $e")),
      ),
    );
  }

  Widget _buildKPISection(DashColors c, double totalMonth, int countMonth, int totalCount) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: UltraKpiCard(
              label: "Dépenses ce mois",
              value: DateFormatter.formatNumber(totalMonth),
              icon: FluentIcons.money_24_regular,
              accent: c.rose,
              change: "$countMonth transactions",
              positive: false,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: UltraKpiCard(
              label: "Total Registre",
              value: "$totalCount",
              icon: FluentIcons.receipt_24_regular,
              accent: c.blue,
              change: "Toutes périodes confondues",
              positive: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters(DashColors c) {
    final filters = ['Tout', 'Achat Fournisseur', ...kExpenseCategories];
    
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;
          return ChoiceChip(
            label: Text(filter, style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
            selected: isSelected,
            onSelected: (val) {
              if (val) setState(() => _selectedFilter = filter);
            },
            selectedColor: c.rose,
            labelStyle: TextStyle(color: isSelected ? Colors.white : c.textSecondary),
            backgroundColor: c.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Colors.transparent : c.border)),
          );
        },
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    FinancialAccount? selectedAccount;
    String selectedCategory = kExpenseCategories.first;

    showDialog(
      context: context,
      builder: (context) {
        final accountsAsync = ref.watch(myTreasuryAccountsProvider);
        final settingsAsync = ref.watch(shopSettingsProvider);
        final settings = settingsAsync.value;
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Row(
              children: [
                Icon(FluentIcons.receipt_money_24_filled, color: Colors.pink),
                SizedBox(width: 8),
                Text("Enregistrer une Dépense"),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: accountsAsync.when(
                data: (accounts) {
                  if (accounts.isEmpty) return const Text("Veuillez créer un compte financier d'abord.");
                  selectedAccount ??= accounts.firstWhere((a) => a.isDefault, orElse: () => accounts.first);
                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        EnterpriseWidgets.buildPremiumTextField(
                          context, ctrl: amountCtrl, label: "Montant", icon: FluentIcons.money_24_regular, keyboardType: TextInputType.number,
                          onChanged: (val) => setStateDialog(() {}),
                        ),
                        const SizedBox(height: 16),
                        EnterpriseWidgets.buildPremiumDropdown<FinancialAccount>(
                          label: "Payer depuis",
                          value: selectedAccount,
                          icon: FluentIcons.building_bank_20_regular,
                          items: accounts,
                          itemLabel: (a) => "${a.name} (${DateFormatter.formatCurrency(a.balance, settings?.currency ?? 'F')})",
                          onChanged: (val) => setStateDialog(() => selectedAccount = val),
                        ),
                        const SizedBox(height: 16),
                        EnterpriseWidgets.buildPremiumDropdown<String>(
                          label: "Catégorie",
                          value: selectedCategory,
                          icon: FluentIcons.tag_20_regular,
                          items: kExpenseCategories,
                          itemLabel: (c) => c,
                          onChanged: (val) => setStateDialog(() => selectedCategory = val ?? kExpenseCategories.first),
                        ),
                        const SizedBox(height: 16),
                        EnterpriseWidgets.buildPremiumTextField(
                          context, ctrl: descCtrl, label: "Description (Optionnel)", icon: FluentIcons.text_description_20_regular, hint: "Facture N°...",
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Text("Erreur $e"),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
              StatefulBuilder(
                builder: (context, setBtnState) {
                  final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                  final isInsufficient = selectedAccount != null && selectedAccount!.balance < amount;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isInsufficient)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
                          child: Text(
                            "Solde insuffisant (${DateFormatter.formatCurrency(selectedAccount?.balance ?? 0, settings?.currency ?? 'F')})",
                            style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: isInsufficient ? Colors.grey : Colors.pink, 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                        ),
                        icon: const Icon(FluentIcons.checkmark_24_regular, size: 20),
                        label: const Text("VALIDER LA DÉPENSE"),
                        onPressed: isInsufficient || amount <= 0 || selectedAccount == null 
                          ? null 
                          : () async {
                            final tx = FinancialTransaction(
                              accountId: selectedAccount!.id,
                              type: TransactionType.OUT,
                              amount: amount,
                              category: TransactionCategory.EXPENSE,
                              description: descCtrl.text.isEmpty ? "Dépense $selectedCategory" : descCtrl.text,
                              date: DateTime.now(),
                              referenceId: selectedCategory,
                            );

                            await ref.read(treasuryProvider.notifier).addTransaction(tx);
                            if (!context.mounted) return;
                            Navigator.pop(context);
                          },
                      ),
                    ],
                  );
                }
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ExpenseList extends ConsumerWidget {
  final List<FinancialTransaction> expenses;
  const _ExpenseList({required this.expenses});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(shopSettingsProvider).value;
    final currency = settings?.currency ?? "CFA";
    final c = DashColors.of(context);

    // Map categories to icons/colors
    IconData getIconForCategory(String? category) {
      if (category == 'Achat Fournisseur') return FluentIcons.cart_24_regular;
      switch (category) {
        case 'Loyer': return FluentIcons.home_24_regular;
        case 'Électricité': return FluentIcons.flash_24_regular;
        case 'Eau': return FluentIcons.drop_24_regular;
        case 'Transport': return FluentIcons.vehicle_truck_profile_24_regular;
        case 'Salaires': return FluentIcons.people_money_24_regular;
        case 'Communication': return FluentIcons.phone_24_regular;
        default: return FluentIcons.receipt_24_regular;
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        final ex = expenses[index];
        final isPurchase = ex.description?.startsWith('Paiement Achat') ?? false;
        final cat = isPurchase ? 'Achat Fournisseur' : (ex.referenceId ?? 'Autre');

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.border),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: c.rose.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(getIconForCategory(cat), color: c.rose, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(cat, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: c.border.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(4)),
                          child: Text("DÉPENSE", style: TextStyle(color: c.textSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(ex.description ?? "", style: TextStyle(color: c.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(DateFormatter.formatPremium(ex.date), style: TextStyle(color: c.textSecondary.withValues(alpha: 0.7), fontSize: 10)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "- ${DateFormatter.formatCurrency(ex.amount, currency)}",
                    style: TextStyle(color: c.rose, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  SizedBox(
                    height: 28,
                    width: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(FluentIcons.delete_20_regular, color: c.rose.withValues(alpha: 0.4), size: 16),
                      onPressed: () => _confirmDelete(context, ref, ex),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, FinancialTransaction tx) {
    EnterpriseWidgets.showPremiumConfirmDialog(
      context,
      title: "Supprimer la dépense ?",
      message: "Cette action est irréversible. Le solde du compte sera ajusté en conséquence.",
      confirmText: "SUPPRIMER",
      isDestructive: true,
      onConfirm: () async {
        await ref.read(treasuryProvider.notifier).deleteTransaction(tx);
      },
    );
  }
}

