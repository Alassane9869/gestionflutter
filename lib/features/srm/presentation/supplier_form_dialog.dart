import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/srm/domain/models/supplier.dart';
import 'package:danaya_plus/features/srm/providers/supplier_providers.dart';

import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';

class SupplierFormDialog extends ConsumerStatefulWidget {
  final Supplier? supplier;

  const SupplierFormDialog({super.key, this.supplier});

  @override
  ConsumerState<SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends ConsumerState<SupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _contactCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _addressCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.supplier?.name);
    _contactCtrl = TextEditingController(text: widget.supplier?.contactName);
    _phoneCtrl = TextEditingController(text: widget.supplier?.phone);
    _emailCtrl = TextEditingController(text: widget.supplier?.email);
    _addressCtrl = TextEditingController(text: widget.supplier?.address);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      final supplier = Supplier(
        id: widget.supplier?.id,
        name: _nameCtrl.text.trim(),
        contactName: _contactCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        totalPurchases: widget.supplier?.totalPurchases ?? 0.0,
        outstandingDebt: widget.supplier?.outstandingDebt ?? 0.0,
      );

      if (widget.supplier == null) {
        await ref.read(supplierListProvider.notifier).addSupplier(supplier);
      } else {
        await ref.read(supplierListProvider.notifier).updateSupplier(supplier);
      }
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final bool useWideLayout = isLandscape && size.width > 700;

    return EnterpriseWidgets.buildPremiumDialog(
      context,
      title: widget.supplier == null ? "Nouveau Fournisseur" : "Éditer Fournisseur",
      icon: FluentIcons.building_retail_24_regular,
      width: useWideLayout ? 750 : 500,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (useWideLayout) ...[
                Row(
                  children: [
                    Expanded(
                      child: EnterpriseWidgets.buildPremiumTextField(
                        context,
                        ctrl: _nameCtrl,
                        label: "NOM ENTREPRISE *",
                        hint: "Ex: SARL West Africa Supply",
                        icon: FluentIcons.building_24_regular,
                        validator: (v) => v == null || v.trim().isEmpty ? "Champ requis" : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EnterpriseWidgets.buildPremiumTextField(
                        context,
                        ctrl: _contactCtrl,
                        label: "NOM DU CONTACT",
                        hint: "Ex: M. Soumaré",
                        icon: FluentIcons.person_24_regular,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                EnterpriseWidgets.buildPremiumTextField(
                  context,
                  ctrl: _nameCtrl,
                  label: "NOM ENTREPRISE *",
                  icon: FluentIcons.building_24_regular,
                  validator: (v) => v == null || v.trim().isEmpty ? "Champ requis" : null,
                ),
                const SizedBox(height: 12),
                EnterpriseWidgets.buildPremiumTextField(
                  context,
                  ctrl: _contactCtrl,
                  label: "NOM DU CONTACT",
                  icon: FluentIcons.person_24_regular,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: EnterpriseWidgets.buildPremiumTextField(
                      context,
                      ctrl: _phoneCtrl,
                      label: "TÉLÉPHONE",
                      hint: "Ex: 76...",
                      icon: FluentIcons.phone_24_regular,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: EnterpriseWidgets.buildPremiumTextField(
                      context,
                      ctrl: _emailCtrl,
                      label: "EMAIL",
                      hint: "Ex: contact@...",
                      icon: FluentIcons.mail_24_regular,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              EnterpriseWidgets.buildPremiumTextField(
                context,
                ctrl: _addressCtrl,
                label: "ADRESSE GÉOGRAPHIQUE",
                hint: "Ex: Bamako, Mali",
                icon: FluentIcons.location_24_regular,
                maxLines: useWideLayout ? 1 : 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Annuler"),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _save,
          icon: Icon(widget.supplier == null ? FluentIcons.add_20_regular : FluentIcons.save_20_regular, size: 18),
          label: Text(widget.supplier == null ? "Créer" : "Sauvegarder", style: const TextStyle(fontSize: 13)),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
