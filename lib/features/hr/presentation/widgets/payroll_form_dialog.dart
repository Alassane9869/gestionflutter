import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:uuid/uuid.dart';
import 'package:danaya_plus/features/hr/domain/models/payroll.dart';
import 'package:danaya_plus/features/finance/providers/treasury_provider.dart';
import 'package:danaya_plus/features/finance/domain/models/financial_account.dart';
import 'package:danaya_plus/features/hr/data/hr_repository.dart';
import 'package:danaya_plus/features/auth/providers/user_providers.dart';
import 'package:danaya_plus/features/hr/domain/models/employee_contract.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/features/inventory/presentation/widgets/dashboard_widgets.dart';

extension PayrollStatusExt on PayrollStatus {
  String get label {
    switch (this) {
      case PayrollStatus.draft: return "Brouillon";
      case PayrollStatus.validated: return "Validé";
      case PayrollStatus.paid: return "Payé";
    }
  }
}

class PayrollFormDialog extends ConsumerStatefulWidget {
  final String? userId;
  final EmployeeContract? activeContract;
  final Payroll? payroll;

  const PayrollFormDialog({super.key, this.userId, this.activeContract, this.payroll});

  @override
  ConsumerState<PayrollFormDialog> createState() => _PayrollFormDialogState();
}

class _PayrollFormDialogState extends ConsumerState<PayrollFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late int _month;
  late int _year;
  late TextEditingController _baseSalaryCtrl;
  late List<PayrollLine> _extraLines;
  late TextEditingController _notesCtrl;
  String? _selectedUserId;
  EmployeeContract? _selectedContract;
  String? _selectedAccountId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.payroll;
    final now = DateTime.now();
    
    _month = p?.month ?? now.month;
    _year = p?.year ?? now.year;
    _selectedUserId = widget.userId ?? p?.userId;
    _selectedContract = widget.activeContract;
    _baseSalaryCtrl = TextEditingController(text: p?.baseSalary.toString() ?? _selectedContract?.baseSalary.toString() ?? "0");
    _extraLines = p != null ? List.from(p.extraLines) : [];
    _notesCtrl = TextEditingController(text: p?.notes);
  }

  void _addExtraLine() {
    setState(() {
      _extraLines.add(PayrollLine(label: "Prime/Déduction", amount: 0, isAddition: true));
    });
  }

  void _removeExtraLine(int index) {
    setState(() {
      _extraLines.removeAt(index);
    });
  }

  double get _totalAdditions => _extraLines.where((e) => e.isAddition).fold(0, (sum, e) => sum + e.amount);
  double get _totalDeductions => _extraLines.where((e) => !e.isAddition).fold(0, (sum, e) => sum + e.amount);
  double get _netSalary => (double.tryParse(_baseSalaryCtrl.text) ?? 0) + _totalAdditions - _totalDeductions;

  void _save() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Veuillez sélectionner un employé"), backgroundColor: Colors.orange));
        return;
      }

      final payroll = Payroll(
        id: widget.payroll?.id ?? const Uuid().v4(),
        userId: _selectedUserId!,
        month: _month,
        year: _year,
        baseSalary: double.tryParse(_baseSalaryCtrl.text) ?? 0,
        extraLines: _extraLines,
        paymentDate: widget.payroll?.paymentDate ?? DateTime.now(),
        status: widget.payroll?.status ?? PayrollStatus.paid,
        notes: _notesCtrl.text.trim(),
        createdAt: widget.payroll?.createdAt ?? DateTime.now(),
      );

      try {
        if (_selectedAccountId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Veuillez choisir un compte de paiement"), backgroundColor: Colors.orange),
          );
          return;
        }

      setState(() => _isLoading = true); // Set loading state

      await ref.read(hrRepositoryProvider).savePayrollWithTreasury(
        payroll: payroll,
        accountId: _selectedAccountId!,
      );

      ref.invalidate(userPayrollsProvider(_selectedUserId!));
      ref.invalidate(allPayrollsProvider);
      ref.invalidate(treasuryProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Paie enregistrée et trésorerie mise à jour")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(shopSettingsProvider).value;
    final currency = settings?.currency ?? "FCFA";
    String currencyFormat(num val) => DateFormatter.formatCurrency(val, currency);
    final usersAsync = ref.watch(userListProvider);
    final contractsAsync = _selectedUserId != null ? ref.watch(userContractsProvider(_selectedUserId!)) : null;

    final theme = Theme.of(context);
    final c = DashColors.of(context);
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final bool useWideLayout = isLandscape && size.width > 750;

    return EnterpriseWidgets.buildPremiumDialog(
      context,
      title: "Bulletin de Paie",
      icon: FluentIcons.payment_24_regular,
      width: useWideLayout ? 850 : 600,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- SELECTION EMPLOYÉ & DATE ---
              if (useWideLayout) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.userId == null) 
                      Expanded(
                        child: usersAsync.when(
                          data: (users) => EnterpriseWidgets.buildPremiumDropdown<String>(
                            label: "EMPLOYÉ",
                            value: _selectedUserId,
                            icon: FluentIcons.person_24_regular,
                            items: users.map((u) => u.id).toList(),
                            itemLabel: (id) => users.firstWhere((u) => u.id == id).username,
                            onChanged: (v) => setState(() => _selectedUserId = v),
                          ),
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text("Erreur: $e"),
                        ),
                      )
                    else 
                      const Expanded(child: SizedBox.shrink()),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: EnterpriseWidgets.buildPremiumDropdown<int>(
                              label: "MOIS",
                              value: _month,
                              icon: FluentIcons.calendar_month_24_regular,
                              items: List.generate(12, (i) => i + 1),
                              itemLabel: (m) => DateFormatter.formatMonth(DateTime(2024, m)),
                              onChanged: (v) => setState(() => _month = v!),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: EnterpriseWidgets.buildPremiumDropdown<int>(
                              label: "ANNÉE",
                              value: _year,
                              icon: FluentIcons.calendar_24_regular,
                              items: List.generate(5, (i) => 2024 + i),
                              itemLabel: (y) => "$y",
                              onChanged: (v) => setState(() => _year = v!),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                if (widget.userId == null)
                  usersAsync.when(
                    data: (users) => EnterpriseWidgets.buildPremiumDropdown<String>(
                      label: "EMPLOYÉ",
                      value: _selectedUserId,
                      icon: FluentIcons.person_24_regular,
                      items: users.map((u) => u.id).toList(),
                      itemLabel: (id) => users.firstWhere((u) => u.id == id).username,
                      onChanged: (v) => setState(() => _selectedUserId = v),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text("Erreur: $e"),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: EnterpriseWidgets.buildPremiumDropdown<int>(
                        label: "MOIS",
                        value: _month,
                        items: List.generate(12, (i) => i + 1),
                        itemLabel: (m) => DateFormatter.formatMonth(DateTime(2024, m)),
                        onChanged: (v) => setState(() => _month = v!),
                        icon: FluentIcons.calendar_month_24_regular,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EnterpriseWidgets.buildPremiumDropdown<int>(
                        label: "ANNÉE",
                        value: _year,
                        items: List.generate(5, (i) => 2024 + i),
                        itemLabel: (y) => "$y",
                        onChanged: (v) => setState(() => _year = v!),
                        icon: FluentIcons.calendar_24_regular,
                      ),
                    ),
                  ],
                ),
              ],
              
              if (contractsAsync != null)
                contractsAsync.when(
                  data: (contracts) {
                    final active = contracts.where((c) => c.status == ContractStatus.active).firstOrNull;
                    if (active != null && _selectedContract == null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() {
                          _selectedContract = active;
                          _baseSalaryCtrl.text = active.baseSalary.toString();
                        });
                      });
                    }
                    return const SizedBox.shrink();
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) => const SizedBox.shrink(),
                ),

              const SizedBox(height: 12),
              
              if (useWideLayout)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: EnterpriseWidgets.buildPremiumTextField(
                        context,
                        ctrl: _baseSalaryCtrl,
                        label: "SALAIRE BASE ($currency)",
                        icon: FluentIcons.money_24_regular,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ref.watch(myTreasuryAccountsProvider).when(
                        data: (accounts) {
                          final payableAccounts = accounts.where(
                            (a) => a.type == AccountType.CASH || a.type == AccountType.BANK || a.type == AccountType.MOBILE_MONEY,
                          ).toList();
                          if (_selectedAccountId == null && payableAccounts.isNotEmpty) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => _selectedAccountId = payableAccounts.first.id);
                            });
                          }
                          return EnterpriseWidgets.buildPremiumDropdown<String>(
                            label: "COMPTE PAIEMENT",
                            value: _selectedAccountId,
                            icon: FluentIcons.wallet_24_regular,
                            items: payableAccounts.map((a) => a.id).toList(),
                            itemLabel: (id) => payableAccounts.firstWhere((a) => a.id == id).name,
                            onChanged: (v) => setState(() => _selectedAccountId = v),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text("Erreur comptes: $e"),
                      ),
                    ),
                  ],
                )
              else ...[
                EnterpriseWidgets.buildPremiumTextField(
                  context,
                  ctrl: _baseSalaryCtrl,
                  label: "SALAIRE BASE ($currency)",
                  icon: FluentIcons.money_24_regular,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                ref.watch(myTreasuryAccountsProvider).when(
                  data: (accounts) {
                    final payableAccounts = accounts.where(
                      (a) => a.type == AccountType.CASH || a.type == AccountType.BANK || a.type == AccountType.MOBILE_MONEY,
                    ).toList();
                    return EnterpriseWidgets.buildPremiumDropdown<String>(
                      label: "COMPTE PAIEMENT",
                      value: _selectedAccountId,
                      icon: FluentIcons.wallet_24_regular,
                      items: payableAccounts.map((a) => a.id).toList(),
                      itemLabel: (id) => payableAccounts.firstWhere((a) => a.id == id).name,
                      onChanged: (v) => setState(() => _selectedAccountId = v),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text("Erreur"),
                ),
              ],

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("PRIMES ET DÉDUCTIONS", style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, fontSize: 10, color: c.blue)),
                  IconButton(
                    onPressed: _addExtraLine,
                    icon: Icon(FluentIcons.add_circle_20_regular, color: c.blue, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              ..._extraLines.asMap().entries.map((entry) {
                 final i = entry.key;
                 final line = entry.value;
                 return Padding(
                   padding: const EdgeInsets.only(bottom: 8.0),
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                     decoration: BoxDecoration(
                       color: theme.colorScheme.surface,
                       borderRadius: BorderRadius.circular(10),
                       border: Border.all(color: c.border),
                     ),
                     child: Row(
                       children: [
                         Expanded(
                           flex: 3,
                           child: TextFormField(
                             initialValue: line.label,
                             style: const TextStyle(fontSize: 12),
                             decoration: const InputDecoration(hintText: "Libellé", border: InputBorder.none, isDense: true),
                             onChanged: (v) => _extraLines[i] = _extraLines[i].copyWith(label: v),
                           ),
                         ),
                         const SizedBox(width: 8),
                         Expanded(
                           flex: 2,
                           child: TextFormField(
                             initialValue: line.amount.toString(),
                             style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                             keyboardType: TextInputType.number,
                             textAlign: TextAlign.right,
                             decoration: InputDecoration(hintText: "0", border: InputBorder.none, isDense: true, suffixText: " $currency", suffixStyle: const TextStyle(fontSize: 10)),
                             onChanged: (v) => setState(() => _extraLines[i] = _extraLines[i].copyWith(amount: double.tryParse(v) ?? 0)),
                           ),
                         ),
                         IconButton(
                           icon: Icon(line.isAddition ? FluentIcons.add_16_regular : FluentIcons.subtract_16_regular, color: line.isAddition ? Colors.green : Colors.red, size: 16),
                           onPressed: () => setState(() => _extraLines[i] = _extraLines[i].copyWith(isAddition: !line.isAddition)),
                         ),
                         IconButton(
                           onPressed: () => _removeExtraLine(i),
                           icon: const Icon(FluentIcons.delete_20_regular, color: Colors.grey, size: 16),
                         ),
                       ],
                     ),
                   ),
                 );
              }),

              const SizedBox(height: 16),
              // Final Summary (Compact)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c.blue.withValues(alpha: 0.08), c.blue.withValues(alpha: 0.03)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.blue.withValues(alpha: 0.15)),
                ),
                child: Column(
                  children: [
                    _summaryRow("Salaire de Base", double.tryParse(_baseSalaryCtrl.text) ?? 0, currencyFormat, c),
                    _summaryRow("Primes (+)", _totalAdditions, currencyFormat, c, color: Colors.green),
                    _summaryRow("Déductions (-)", _totalDeductions, currencyFormat, c, color: Colors.red),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("NET À PAYER", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                        Text(
                          currencyFormat(_netSalary),
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: c.blue, letterSpacing: -0.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              EnterpriseWidgets.buildPremiumTextField(
                context,
                ctrl: _notesCtrl,
                label: "NOTES",
                hint: "Commentaires...",
                icon: FluentIcons.note_24_regular,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _isLoading ? null : _save,
          icon: _isLoading 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Icon(widget.payroll == null ? FluentIcons.checkmark_24_regular : FluentIcons.save_20_regular, size: 18),
          label: Text(widget.payroll == null ? "Valider la Paie" : "Enregistrer"),
          style: FilledButton.styleFrom(
            backgroundColor: c.blue,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, double amount, String Function(num) format, DashColors c, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
          Text(format(amount), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
        ],
      ),
    );
  }
}
