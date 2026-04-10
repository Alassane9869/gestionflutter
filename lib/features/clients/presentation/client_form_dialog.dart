import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/clients/domain/models/client.dart';
import 'package:danaya_plus/features/clients/providers/client_providers.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';

class ClientFormDialog extends ConsumerStatefulWidget {
  final Client? client;

  const ClientFormDialog({super.key, this.client});

  @override
  ConsumerState<ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends ConsumerState<ClientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  bool get isEditing => widget.client != null;

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    _nameController = TextEditingController(text: c?.name ?? "");
    _phoneController = TextEditingController(text: c?.phone ?? "");
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final client = Client(
      id: widget.client?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      totalPurchases: widget.client?.totalPurchases ?? 0,
      totalSpent: widget.client?.totalSpent ?? 0.0,
      credit: widget.client?.credit ?? 0.0,
    );

    if (isEditing) {
      ref.read(clientListProvider.notifier).updateClient(client);
    } else {
      ref.read(clientListProvider.notifier).addClient(client);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEditing ? "Client modifié avec succès !" : "Client ajouté avec succès !"),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EnterpriseWidgets.buildPremiumDialog(
      context,
      title: isEditing ? "Modifier la Fiche Client" : "Nouveau Client",
      icon: FluentIcons.person_add_24_regular,
      width: 450,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            EnterpriseWidgets.buildPremiumTextField(
              context,
              ctrl: _nameController,
              label: "NOM COMPLET *",
              hint: "Ex: Jean Dupont",
              icon: FluentIcons.person_24_regular,
              validator: (v) => v == null || v.trim().isEmpty ? "Champ requis" : null,
            ),
            const SizedBox(height: 24),
            EnterpriseWidgets.buildPremiumTextField(
              context,
              ctrl: _phoneController,
              label: "NUMÉRO DE TÉLÉPHONE",
              hint: "Ex: +223 00 00 00 00",
              icon: FluentIcons.phone_24_regular,
              keyboardType: TextInputType.phone,
            ),
          ],
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
