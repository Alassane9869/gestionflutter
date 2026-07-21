import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:uuid/uuid.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/hr/domain/models/employee_contract.dart';
import 'package:danaya_plus/features/hr/data/hr_repository.dart';
import 'package:danaya_plus/features/auth/providers/user_providers.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/features/inventory/presentation/widgets/dashboard_widgets.dart';


extension ContractTypeExt on ContractType {
  String get label {
    switch (this) {
      case ContractType.cdi: return "CDI";
      case ContractType.cdd: return "CDD";
      case ContractType.stage: return "Stage";
      case ContractType.essai: return "Essai";
      case ContractType.prestataire: return "Prestataire";
    }
  }
}

class ContractFormDialog extends ConsumerStatefulWidget {
  final String? userId;
  final EmployeeContract? contract;

  const ContractFormDialog({super.key, this.userId, this.contract});

  @override
  ConsumerState<ContractFormDialog> createState() => _ContractFormDialogState();
}

class _ContractFormDialogState extends ConsumerState<ContractFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late ContractType _contractType;
  late ContractStatus _contractStatus;
  late DateTime _startDate;
  DateTime? _endDate;
  late TextEditingController _positionCtrl;
  late TextEditingController _departmentCtrl;
  late TextEditingController _baseSalaryCtrl;
  late TextEditingController _transportAllowanceCtrl;
  late TextEditingController _mealAllowanceCtrl;
  late TextEditingController _schoolNameCtrl;
  late TextEditingController _supervisorIdCtrl;
  late TextEditingController _notesCtrl;
  String? _selectedUserId;

  @override
  void initState() {
    super.initState();
    final c = widget.contract;
    _contractType = c?.contractType ?? ContractType.cdi;
    _contractStatus = c?.status ?? ContractStatus.active;
    _startDate = c?.startDate ?? DateTime.now();
    _endDate = c?.endDate;
    _selectedUserId = widget.userId ?? c?.userId;
    _positionCtrl = TextEditingController(text: c?.position);
    _departmentCtrl = TextEditingController(text: c?.department);
    _baseSalaryCtrl = TextEditingController(text: c?.baseSalary.toInt().toString() ?? "");
    _transportAllowanceCtrl = TextEditingController(text: c?.transportAllowance.toInt().toString() ?? "");
    _mealAllowanceCtrl = TextEditingController(text: c?.mealAllowance.toInt().toString() ?? "");
    _schoolNameCtrl = TextEditingController(text: c?.schoolName);
    _supervisorIdCtrl = TextEditingController(text: c?.supervisorId);
    _notesCtrl = TextEditingController(text: c?.notes);
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Veuillez sélectionner un employé"), backgroundColor: Colors.orange));
        return;
      }
      
      final contract = EmployeeContract(
        id: widget.contract?.id ?? const Uuid().v4(),
        userId: _selectedUserId!,
        contractType: _contractType,
        startDate: _startDate,
        endDate: _endDate,
        baseSalary: double.tryParse(_baseSalaryCtrl.text) ?? 0,
        transportAllowance: double.tryParse(_transportAllowanceCtrl.text) ?? 0,
        mealAllowance: double.tryParse(_mealAllowanceCtrl.text) ?? 0,
        position: _positionCtrl.text.trim(),
        department: _departmentCtrl.text.trim(),
        schoolName: _contractType == ContractType.stage ? _schoolNameCtrl.text.trim() : null,
        supervisorId: _contractType == ContractType.stage ? _supervisorIdCtrl.text.trim() : null,
        status: _contractStatus,
        notes: _notesCtrl.text.trim(),
        createdAt: widget.contract?.createdAt ?? DateTime.now(),
      );
      final existingContracts = ref.read(allContractsProvider).value ?? [];
      
      // Règle de gestion : Un employé ne peut pas avoir deux contrats actifs en même temps
      final hasActiveContract = existingContracts.any(
        (c) => c.userId == _selectedUserId && 
               c.status == ContractStatus.active && 
               c.id != widget.contract?.id
      );

      if (hasActiveContract && _contractStatus == ContractStatus.active) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Cet employé a déjà un contrat actif. Clôturez-le avant d'en créer un nouveau."),
            backgroundColor: Colors.red,
          )
        );
        return;
      }

      try {
        await ref.read(hrRepositoryProvider).saveContract(contract);
        ref.invalidate(userContractsProvider(_selectedUserId!));
        ref.invalidate(allContractsProvider); // Refresh global list
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Contrat enregistré avec succès")));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(userListProvider);
    final settings = ref.watch(shopSettingsProvider).value;
    final currency = settings?.currency ?? "FCFA";
    final theme = Theme.of(context);
    final c = DashColors.of(context);
    final baseSalary = double.tryParse(_baseSalaryCtrl.text) ?? 0;
    final transport = double.tryParse(_transportAllowanceCtrl.text) ?? 0;
    final meal = double.tryParse(_mealAllowanceCtrl.text) ?? 0;
    final annualCost = (baseSalary + transport + meal) * 12;

    return EnterpriseWidgets.buildPremiumDialog(
      context,
      title: widget.contract == null ? "Nouveau Contrat" : "Détails du Contrat",
      icon: FluentIcons.document_add_24_regular,
      width: 700,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.userId == null && widget.contract == null) ...[
                usersAsync.when(
                  data: (users) => EnterpriseWidgets.buildPremiumDropdown<String>(
                    label: "Employé concerné",
                    value: _selectedUserId,
                    icon: FluentIcons.person_24_regular,
                    items: users.map((u) => u.id).toList(),
                    itemLabel: (id) => users.firstWhere((u) => u.id == id).username,
                    onChanged: (v) => setState(() => _selectedUserId = v),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text("Erreur users: $e"),
                ),
                const SizedBox(height: 24),
              ],
              
              _buildSectionHeader("Paramètres du Contrat", FluentIcons.settings_24_regular, c),
              Row(
                children: [
                  if (widget.contract != null) ...[
                    Expanded(
                      child: EnterpriseWidgets.buildPremiumDropdown<ContractStatus>(
                        label: "Statut du contrat",
                        value: _contractStatus,
                        icon: FluentIcons.presence_available_24_regular,
                        items: ContractStatus.values,
                        itemLabel: (s) => s == ContractStatus.active ? "Actif" : s == ContractStatus.terminated ? "Clôturé" : "Expiré",
                        onChanged: (v) => setState(() => _contractStatus = v!),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: EnterpriseWidgets.buildPremiumDropdown<ContractType>(
                      label: "Type de contrat",
                      value: _contractType,
                      icon: FluentIcons.document_text_24_regular,
                      items: ContractType.values,
                      itemLabel: (t) => t.label,
                      onChanged: (v) => setState(() => _contractType = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _buildSectionHeader("Affectation", FluentIcons.briefcase_24_regular, c),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: EnterpriseWidgets.buildPremiumTextField(
                      context,
                      ctrl: _positionCtrl,
                      label: "Poste / Titre de fonction",
                      hint: "ex: Directeur Commercial",
                      icon: FluentIcons.person_board_24_regular,
                      validator: (v) => v!.isEmpty ? "Requis" : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: EnterpriseWidgets.buildPremiumTextField(
                      context,
                      ctrl: _departmentCtrl,
                      label: "Département",
                      hint: "RH, Vente...",
                      icon: FluentIcons.organization_24_regular,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _buildSectionHeader("Durée", FluentIcons.calendar_clock_24_regular, c),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _buildDatePickerRow("Date de début", _startDate, (d) => setState(() => _startDate = d), c),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _contractType != ContractType.cdi
                        ? _buildDatePickerRow("Date de fin", _endDate ?? DateTime.now().add(const Duration(days: 365)), (d) => setState(() => _endDate = d), c)
                        : Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
                            child: Row(
                              children: [
                                Icon(Icons.all_inclusive_rounded, color: c.textSecondary, size: 20),
                                const SizedBox(width: 12),
                                Text("Durée Indéterminée", style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Salary Section Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: c.blue.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.blue.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(FluentIcons.money_calculator_24_filled, color: c.blue, size: 20),
                        const SizedBox(width: 8),
                        Text("PACK RÉMUNÉRATION", style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: c.blue, letterSpacing: 0.5)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    EnterpriseWidgets.buildPremiumTextField(
                      context,
                      ctrl: _baseSalaryCtrl,
                      label: "Salaire de base mensuel ($currency)",
                      icon: FluentIcons.money_24_regular,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: EnterpriseWidgets.buildPremiumTextField(
                            context,
                            ctrl: _transportAllowanceCtrl,
                            label: "Indemnité Transport",
                            icon: FluentIcons.vehicle_bus_24_regular,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: EnterpriseWidgets.buildPremiumTextField(
                            context,
                            ctrl: _mealAllowanceCtrl,
                            label: "Indemnité Repas",
                            icon: FluentIcons.food_24_regular,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Coût Annuel Total", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                            Text("Base + Indemnités × 12 mois", style: TextStyle(fontSize: 11, color: c.textSecondary)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: c.blue,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [BoxShadow(color: c.blue.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
                          ),
                          child: Text(
                            DateFormatter.formatCurrency(annualCost, currency),
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (_contractType == ContractType.stage) ...[
                const SizedBox(height: 24),
                _buildSectionHeader("Informations Stage", FluentIcons.hat_graduation_24_regular, c),
                EnterpriseWidgets.buildPremiumTextField(
                  context,
                  ctrl: _schoolNameCtrl,
                  label: "Établissement / École",
                  icon: FluentIcons.building_bank_24_regular,
                ),
              ],
              const SizedBox(height: 24),
              _buildSectionHeader("Autres", FluentIcons.note_24_regular, c),
              EnterpriseWidgets.buildPremiumTextField(
                context,
                ctrl: _notesCtrl,
                label: "Notes additionnelles",
                icon: FluentIcons.text_description_24_regular,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: c.blue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("Enregistrer Contrat"),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, DashColors c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.blue),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.blue)),
        ],
      ),
    );
  }

  Widget _buildDatePickerRow(String label, DateTime date, Function(DateTime) onPicked, DashColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              initialEntryMode: DatePickerEntryMode.input,
            );
            if (picked != null) onPicked(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Icon(FluentIcons.calendar_24_regular, color: c.blue, size: 20),
                const SizedBox(width: 12),
                Text(DateFormatter.formatDate(date), style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
