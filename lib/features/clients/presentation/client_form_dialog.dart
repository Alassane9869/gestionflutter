import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/clients/domain/models/client.dart';
import 'package:danaya_plus/features/clients/providers/client_providers.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/core/widgets/address_autocomplete_field.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/assistant/application/assistant_service.dart';

class ClientFormDialog extends ConsumerStatefulWidget {
  final Client? client;
  final String? initialName;
  final String? initialPhone;

  const ClientFormDialog({super.key, this.client, this.initialName, this.initialPhone});

  @override
  ConsumerState<ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends ConsumerState<ClientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _maxCreditController;
  late final TextEditingController _loyaltyPointsController;
  DateTime? _birthDate;

  bool get isEditing => widget.client != null;

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    _nameController = TextEditingController(text: c?.name ?? widget.initialName ?? "");
    _phoneController = TextEditingController(text: c?.phone ?? widget.initialPhone ?? "");
    _emailController = TextEditingController(text: c?.email ?? "");
    _addressController = TextEditingController(text: c?.address ?? "");
    _maxCreditController = TextEditingController(text: c?.maxCredit.toStringAsFixed(0) ?? "50000");
    _loyaltyPointsController = TextEditingController(text: c?.loyaltyPoints.toString() ?? "0");
    _birthDate = c?.birthDate;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(assistantProvider.notifier).setActiveDialog(
          widget.client != null ? 'Modification Client' : 'Création Client'
        );
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _maxCreditController.dispose();
    _loyaltyPointsController.dispose();
    try {
      ref.read(assistantProvider.notifier).setActiveDialog(null);
    } catch (_) {}
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final double maxCredit = double.tryParse(_maxCreditController.text.trim()) ?? 50000.0;
    final int loyaltyPoints = int.tryParse(_loyaltyPointsController.text.trim()) ?? 0;

    final client = Client(
      id: widget.client?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      maxCredit: maxCredit,
      loyaltyPoints: loyaltyPoints,
      birthDate: _birthDate,
      totalPurchases: widget.client?.totalPurchases ?? 0,
      totalSpent: widget.client?.totalSpent ?? 0.0,
      credit: widget.client?.credit ?? 0.0,
      lastPurchaseDate: widget.client?.lastPurchaseDate,
      lastMarketingReminderDate: widget.client?.lastMarketingReminderDate,
    );

    if (isEditing) {
      ref.read(clientListProvider.notifier).updateClient(client);
    } else {
      ref.read(clientListProvider.notifier).addClient(client);
    }

    Navigator.pop(context, client);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEditing ? "Client modifié avec succès !" : "Client ajouté avec succès !"),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    // Default to 30 years ago to ease year selection scrolling
    final DateTime initial = _birthDate ?? DateTime(now.year - 30, now.month, now.day);
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.input,
      helpText: "CHOISIR DATE DE NAISSANCE",
      cancelText: "ANNULER",
      confirmText: "SÉLECTIONNER",
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              onSurface: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _birthDate) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Colors.grey.shade500,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return EnterpriseWidgets.buildPremiumDialog(
      context,
      title: isEditing ? "Modifier la Fiche Client" : "Nouveau Client",
      icon: FluentIcons.person_add_24_regular,
      width: 580,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader("Informations Personnelles", FluentIcons.person_20_regular),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: EnterpriseWidgets.buildPremiumTextField(
                      context,
                      ctrl: _nameController,
                      label: "NOM COMPLET *",
                      hint: "Ex: Jean Dupont",
                      icon: FluentIcons.person_24_regular,
                      validator: (v) => v == null || v.trim().isEmpty ? "Champ requis" : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "DATE DE NAISSANCE",
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade700,
                            fontSize: 12,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _selectBirthDate(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 52, // Match height of premium text field
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF2D3039)
                                    : const Color(0xFFE5E7EB),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(FluentIcons.calendar_24_regular, size: 20, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _birthDate != null
                                        ? "${DateFormatter.formatDate(_birthDate!)} (${DateTime.now().year - _birthDate!.year} ans)"
                                        : "Sélectionner une date",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _birthDate != null
                                          ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)
                                          : Colors.grey.shade500,
                                      fontWeight: _birthDate != null ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_birthDate != null)
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(FluentIcons.dismiss_16_regular, size: 16, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _birthDate = null;
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              
              _buildSectionHeader("Coordonnées", FluentIcons.contact_card_group_24_regular),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: EnterpriseWidgets.buildPremiumTextField(
                      context,
                      ctrl: _phoneController,
                      label: "NUMÉRO DE TÉLÉPHONE",
                      hint: "Ex: +223 70 00 00 00",
                      icon: FluentIcons.phone_24_regular,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: EnterpriseWidgets.buildPremiumTextField(
                      context,
                      ctrl: _emailController,
                      label: "ADRESSE E-MAIL",
                      hint: "Ex: client@email.com",
                      icon: FluentIcons.mail_24_regular,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AddressAutocompleteField(
                controller: _addressController,
                label: "ADRESSE DE LIVRAISON / PHYSIQUE",
                hint: "Ex: Badalabougou, Rue 123, Bamako",
              ),
              const SizedBox(height: 14),

              _buildSectionHeader("Finances & Fidélisation", FluentIcons.money_hand_20_regular),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: EnterpriseWidgets.buildPremiumTextField(
                      context,
                      ctrl: _maxCreditController,
                      label: "PLAFOND DE CRÉDIT (FCFA)",
                      hint: "Ex: 50000",
                      icon: FluentIcons.money_24_regular,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: EnterpriseWidgets.buildPremiumTextField(
                      context,
                      ctrl: _loyaltyPointsController,
                      label: "POINTS DE FIDÉLITÉ INITIAL",
                      hint: "Ex: 0",
                      icon: FluentIcons.star_24_regular,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("Annuler"),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _save,
          icon: Icon(isEditing ? FluentIcons.save_24_regular : FluentIcons.add_24_regular),
          label: Text(isEditing ? "Enregistrer" : "Créer la fiche"),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
