import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/clients/domain/models/client.dart';
import 'package:danaya_plus/features/clients/providers/client_providers.dart';
import 'package:uuid/uuid.dart';

class ClientFormDialog extends ConsumerStatefulWidget {
  final Client? client;

  const ClientFormDialog({super.key, this.client});

  @override
  ConsumerState<ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends ConsumerState<ClientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _maxCreditCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.client?.name ?? '');
    _phoneCtrl = TextEditingController(text: widget.client?.phone ?? '');
    _emailCtrl = TextEditingController(text: widget.client?.email ?? '');
    _addressCtrl = TextEditingController(text: widget.client?.address ?? '');
    _maxCreditCtrl = TextEditingController(text: widget.client != null ? widget.client!.maxCredit.toInt().toString() : '50000');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _maxCreditCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.client != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(isEdit ? FluentIcons.edit_24_regular : FluentIcons.person_add_24_regular, 
               color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Text(isEdit ? "Modifier le client" : "Nouveau client", 
               style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField(
                  controller: _nameCtrl,
                  label: "Nom Complet",
                  icon: FluentIcons.person_24_regular,
                  validator: (v) => v == null || v.isEmpty ? "Requis" : null,
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _phoneCtrl,
                  label: "Téléphone",
                  icon: FluentIcons.phone_24_regular,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _emailCtrl,
                  label: "Email",
                  icon: FluentIcons.mail_24_regular,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _addressCtrl,
                  label: "Adresse",
                  icon: FluentIcons.location_24_regular,
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _maxCreditCtrl,
                  label: "Plafond de Crédit Autorisé",
                  icon: FluentIcons.money_24_regular,
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Annuler"),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEdit ? "Enregistrer" : "Créer"),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final maxCreditVal = double.tryParse(_maxCreditCtrl.text.trim()) ?? 50000.0;

    final client = widget.client?.copyWith(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      maxCredit: maxCreditVal,
    ) ?? Client(
      id: const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      maxCredit: maxCreditVal,
    );

    if (widget.client != null) {
      await ref.read(clientListProvider.notifier).updateClient(client);
    } else {
      await ref.read(clientListProvider.notifier).addClient(client);
    }

    if (mounted) Navigator.pop(context, client);
  }
}
