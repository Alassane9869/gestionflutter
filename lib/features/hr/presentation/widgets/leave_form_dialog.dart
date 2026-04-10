import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:uuid/uuid.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/hr/domain/models/leave_request.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/features/inventory/presentation/widgets/dashboard_widgets.dart';
import 'package:danaya_plus/features/hr/data/hr_repository.dart';
import 'package:danaya_plus/features/auth/providers/user_providers.dart';

extension LeaveTypeExt on LeaveType {
  String get label {
    switch (this) {
      case LeaveType.annual: return "Congé Annuel";
      case LeaveType.sick: return "Congé Maladie";
      case LeaveType.permission: return "Permission";
      case LeaveType.unpaid: return "Congé Sans Solde";
      case LeaveType.other: return "Autre";
    }
  }
}

class LeaveFormDialog extends ConsumerStatefulWidget {
  final String? userId;
  final LeaveRequest? request;

  const LeaveFormDialog({super.key, this.userId, this.request});

  @override
  ConsumerState<LeaveFormDialog> createState() => _LeaveFormDialogState();
}

class _LeaveFormDialogState extends ConsumerState<LeaveFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late LeaveType _type;
  late DateTime _startDate;
  late DateTime _endDate;
  late TextEditingController _reasonCtrl;
  String? _selectedUserId;

  @override
  void initState() {
    super.initState();
    final r = widget.request;
    _type = r?.leaveType ?? LeaveType.annual;
    _startDate = r?.startDate ?? DateTime.now();
    _endDate = r?.endDate ?? DateTime.now().add(const Duration(days: 1));
    _selectedUserId = widget.userId ?? r?.userId;
    _reasonCtrl = TextEditingController(text: r?.reason);
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Veuillez sélectionner un employé"), backgroundColor: Colors.orange));
        return;
      }
      if (_endDate.isBefore(_startDate)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("La date de fin doit être après la date de début"), backgroundColor: Colors.orange));
        return;
      }

      final request = LeaveRequest(
        id: widget.request?.id ?? const Uuid().v4(),
        userId: _selectedUserId!,
        leaveType: _type,
        startDate: _startDate,
        endDate: _endDate,
        reason: _reasonCtrl.text.trim(),
        status: widget.request?.status ?? LeaveStatus.approved, // Admin creation = auto approved
        createdAt: widget.request?.createdAt ?? DateTime.now(),
      );

      try {
        await ref.read(hrRepositoryProvider).saveLeaveRequest(request);
        ref.invalidate(userLeavesProvider(_selectedUserId!));
        ref.invalidate(allLeavesProvider);
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Congé/Permission enregistré")));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(userListProvider);
    final c = DashColors.of(context);
    final duration = _endDate.difference(_startDate).inDays + 1;

    return EnterpriseWidgets.buildPremiumDialog(
      context,
      title: widget.request == null ? "Demande de Congé" : "Modifier Demande",
      icon: FluentIcons.calendar_clock_24_regular,
      width: 550,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.userId == null && widget.request == null) ...[
                usersAsync.when(
                  data: (users) => EnterpriseWidgets.buildPremiumDropdown<String>(
                    label: "Employé",
                    value: _selectedUserId,
                    icon: FluentIcons.person_24_regular,
                    items: users.map((u) => u.id).toList(),
                    itemLabel: (id) => users.firstWhere((u) => u.id == id).username,
                    onChanged: (v) => setState(() => _selectedUserId = v),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text("Erreur users: $e"),
                ),
                const SizedBox(height: 16),
              ],

              EnterpriseWidgets.buildPremiumDropdown<LeaveType>(
                label: "Type de congé",
                value: _type,
                icon: FluentIcons.calendar_star_24_regular,
                items: LeaveType.values,
                itemLabel: (t) => t.label,
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: _buildDatePickerRow("Du", _startDate, (d) => setState(() => _startDate = d), c),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDatePickerRow("Au", _endDate, (d) => setState(() => _endDate = d), c),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: c.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(FluentIcons.clock_24_regular, color: c.blue, size: 18),
                    const SizedBox(width: 12),
                    Text(
                      "Durée totale : $duration jour${duration > 1 ? 's' : ''}",
                      style: TextStyle(fontWeight: FontWeight.bold, color: c.blue, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              EnterpriseWidgets.buildPremiumTextField(
                context,
                ctrl: _reasonCtrl,
                label: "Motif de la demande",
                hint: "ex: Congés annuels, Raison familiale...",
                icon: FluentIcons.text_description_24_regular,
                maxLines: 3,
                validator: (v) => v!.isEmpty ? "Motif requis" : null,
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
          child: const Text("Soumettre Demande"),
        ),
      ],
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
            final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
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
