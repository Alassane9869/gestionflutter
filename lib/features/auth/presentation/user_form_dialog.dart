import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:danaya_plus/features/auth/domain/models/user.dart';
import 'package:danaya_plus/features/auth/providers/user_providers.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/features/inventory/presentation/widgets/dashboard_widgets.dart';
import 'package:danaya_plus/features/finance/providers/treasury_provider.dart';

class UserFormDialog extends ConsumerStatefulWidget {
  final User? user;

  const UserFormDialog({super.key, this.user});

  @override
  ConsumerState<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends ConsumerState<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _pinCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  DateTime? _birthDate;
  UserRole _role = UserRole.cashier;
  bool _isActive = true;
  late UserPermissions _permissions;
  List<String> _assignedAccounts = [];
  bool _showPin = false;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController(text: widget.user?.firstName);
    _lastNameCtrl = TextEditingController(text: widget.user?.lastName);
    _usernameCtrl = TextEditingController(text: widget.user?.username);
    _pinCtrl = TextEditingController(); 
    _emailCtrl = TextEditingController(text: widget.user?.email);
    _phoneCtrl = TextEditingController(text: widget.user?.phone);
    _addressCtrl = TextEditingController(text: widget.user?.address);
    _birthDate = widget.user?.birthDate;
    
    if (widget.user != null) {
      _role = widget.user!.role;
      _isActive = widget.user!.isActive;
      _permissions = widget.user!.permissions;
      
      // Auto-check default permissions for legacy users (created before permissions system)
      if (_permissions == const UserPermissions()) {
        _permissions = _getDefaultPermissions(_role);
      }
      
      _assignedAccounts = List<String>.from(widget.user!.assignedAccountIds);
    } else {
      _permissions = UserPermissions.cashier();
      _assignedAccounts = [];
    }
  }

  UserPermissions _getDefaultPermissions(UserRole role) {
    switch (role) {
      case UserRole.admin: return UserPermissions.admin();
      case UserRole.manager: return UserPermissions.manager();
      case UserRole.cashier: return UserPermissions.cashier();
      case UserRole.intern: return UserPermissions.intern();
      case UserRole.accountant: return UserPermissions.accountant();
      case UserRole.stockManager: return UserPermissions.stockManager();
      case UserRole.sales: return UserPermissions.sales();
      case UserRole.auditor: return UserPermissions.auditor();
      case UserRole.inventoryAgent: return UserPermissions.inventoryAgent();
      case UserRole.adminPlus: return UserPermissions.admin();
    }
  }

  void _updateRole(UserRole role) {
    setState(() {
      _role = role;
      _permissions = _getDefaultPermissions(role);
    });
  }

  void _updatePermission({
    bool? canRefund,
    bool? canChangePrice,
    bool? canViewReports,
    bool? canManageStock,
    bool? canManageUsers,
    bool? canAccessSettings,
    bool? canManageSuppliers,
    bool? canManageCustomers,
    bool? canAccessFinance,
    bool? canManageExpenses,
    bool? canManageHR,
  }) {
    setState(() {
      _permissions = _permissions.copyWith(
        canRefund: canRefund ?? _permissions.canRefund,
        canChangePrice: canChangePrice ?? _permissions.canChangePrice,
        canViewReports: canViewReports ?? _permissions.canViewReports,
        canManageStock: canManageStock ?? _permissions.canManageStock,
        canManageUsers: canManageUsers ?? _permissions.canManageUsers,
        canAccessSettings: canAccessSettings ?? _permissions.canAccessSettings,
        canManageSuppliers: canManageSuppliers ?? _permissions.canManageSuppliers,
        canManageCustomers: canManageCustomers ?? _permissions.canManageCustomers,
        canAccessFinance: canAccessFinance ?? _permissions.canAccessFinance,
        canManageExpenses: canManageExpenses ?? _permissions.canManageExpenses,
        canManageHR: canManageHR ?? _permissions.canManageHR,
      );
    });
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    _pinCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      final svc = ref.read(userManagementServiceProvider);
      
      String finalPinHash = widget.user?.pinHash ?? '';
      if (_pinCtrl.text.isNotEmpty) {
        final bytes = utf8.encode(_pinCtrl.text.trim());
        finalPinHash = sha256.convert(bytes).toString();
      }

      final newUser = User(
        id: widget.user?.id ?? const Uuid().v4(),
        username: _usernameCtrl.text.trim(),
        firstName: _firstNameCtrl.text.trim().isEmpty ? null : _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim().isEmpty ? null : _lastNameCtrl.text.trim(),
        pinHash: finalPinHash,
        role: _role,
        isActive: _isActive,
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        birthDate: _birthDate,
        permissions: _permissions,
        assignedAccountIds: _assignedAccounts,
      );

      try {
        if (widget.user == null) {
          await svc.createUser(newUser);
        } else {
          await svc.updateUser(newUser);
        }
        if (!mounted) return;
        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        String errorMsg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg), 
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMainAdmin = widget.user?.id == 'sysadmin';
    final c = DashColors.of(context);
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final bool useWideLayout = isLandscape && size.width > 700;

    return EnterpriseWidgets.buildPremiumDialog(
      context,
      title: widget.user == null ? "Nouveau Profil Employé" : "Modifier Profil Employé",
      icon: FluentIcons.person_add_24_regular,
      width: useWideLayout ? 800 : 550,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar Section - Plus compact en paysage
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    children: [
                      Container(
                        width: useWideLayout ? 60 : 80,
                        height: useWideLayout ? 60 : 80,
                        decoration: BoxDecoration(
                          color: c.blue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: c.blue.withValues(alpha: 0.2), width: 2),
                        ),
                        child: Icon(FluentIcons.person_48_regular, color: c.blue, size: useWideLayout ? 30 : 40),
                      ),
                      if (!isMainAdmin)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: c.blue, shape: BoxShape.circle),
                            child: const Icon(FluentIcons.camera_16_regular, color: Colors.white, size: 10),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              if (isMainAdmin)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(FluentIcons.warning_24_regular, color: Colors.orange, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Admin Principal : Seul le code PIN est modifiable.",
                          style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

              // GRID DES CHAMPS
              if (useWideLayout) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: EnterpriseWidgets.buildPremiumTextField(
                        context,
                        ctrl: _firstNameCtrl,
                        label: "Prénom",
                        hint: "Jean",
                        icon: FluentIcons.person_24_regular,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EnterpriseWidgets.buildPremiumTextField(
                        context,
                        ctrl: _lastNameCtrl,
                        label: "Nom",
                        hint: "Dupont",
                        icon: FluentIcons.person_24_regular,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: EnterpriseWidgets.buildPremiumTextField(
                        context,
                        ctrl: _usernameCtrl,
                        label: "Identifiant (Username)",
                        hint: "jdupont",
                        icon: FluentIcons.person_board_24_regular,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EnterpriseWidgets.buildPremiumTextField(
                        context,
                        ctrl: _pinCtrl,
                        label: widget.user == null ? "Code PIN" : "Nouveau PIN",
                        hint: "****",
                        icon: FluentIcons.password_24_regular,
                        keyboardType: TextInputType.number,
                        obscureText: !_showPin,
                        suffix: IconButton(
                          icon: Icon(
                            _showPin ? FluentIcons.eye_24_regular : FluentIcons.eye_off_24_regular,
                            size: 18,
                            color: c.textSecondary,
                          ),
                          onPressed: () => setState(() => _showPin = !_showPin),
                        ),
                        validator: (v) {
                          if (widget.user == null && (v == null || v.isEmpty)) return "Requis";
                          if (v != null && v.isNotEmpty && v.length < 4) return "4 chf. min";
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: EnterpriseWidgets.buildPremiumTextField(
                        context,
                        ctrl: _phoneCtrl,
                        label: "Téléphone",
                        hint: "+223 ...",
                        icon: FluentIcons.phone_24_regular,
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          if (v != null && v.isNotEmpty && v.length < 8) {
                            return "Numéro trop court";
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EnterpriseWidgets.buildPremiumTextField(
                        context,
                        ctrl: _emailCtrl,
                        label: "Email",
                        hint: "contact@danaya.com",
                        icon: FluentIcons.mail_24_regular,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v != null && v.isNotEmpty) {
                            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (!emailRegex.hasMatch(v)) return "Format email invalide";
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _birthDate ?? DateTime(1995),
                            firstDate: DateTime(1950),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) setState(() => _birthDate = date);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: c.border),
                          ),
                          child: Row(
                            children: [
                              Icon(FluentIcons.calendar_ltr_24_regular, color: c.blue, size: 20),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Date de naissance", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  Text(
                                    _birthDate != null ? DateFormatter.formatDate(_birthDate!) : "Non renseignée",
                                    style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EnterpriseWidgets.buildPremiumDropdown<UserRole>(
                        label: "Rôle de l'employé",
                        value: _role,
                        icon: FluentIcons.shield_24_regular,
                        items: UserRole.values,
                        itemLabel: _getRoleLabel,
                        onChanged: (v) {
                          if (!isMainAdmin && v != null) _updateRole(v);
                        },
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // MODE PORTRAIT CLASSIQUE
                EnterpriseWidgets.buildPremiumTextField(context, ctrl: _firstNameCtrl, label: "Prénom", icon: FluentIcons.person_24_regular),
                const SizedBox(height: 12),
                EnterpriseWidgets.buildPremiumTextField(context, ctrl: _lastNameCtrl, label: "Nom de famille", icon: FluentIcons.person_24_regular),
                const SizedBox(height: 12),
                EnterpriseWidgets.buildPremiumTextField(context, ctrl: _usernameCtrl, label: "Username", icon: FluentIcons.person_board_24_regular),
                const SizedBox(height: 12),
                EnterpriseWidgets.buildPremiumTextField(
                  context, 
                  ctrl: _pinCtrl, 
                  label: "Code PIN", 
                  icon: FluentIcons.password_24_regular, 
                  keyboardType: TextInputType.number,
                  obscureText: !_showPin,
                  suffix: IconButton(
                    icon: Icon(_showPin ? FluentIcons.eye_24_regular : FluentIcons.eye_off_24_regular, size: 18),
                    onPressed: () => setState(() => _showPin = !_showPin),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: EnterpriseWidgets.buildPremiumTextField(
                        context, 
                        ctrl: _phoneCtrl, 
                        label: "Tél", 
                        icon: FluentIcons.phone_24_regular,
                        validator: (v) => (v != null && v.isNotEmpty && v.length < 8) ? "Trop court" : null,
                      )
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EnterpriseWidgets.buildPremiumTextField(
                        context, 
                        ctrl: _emailCtrl, 
                        label: "Email", 
                        icon: FluentIcons.mail_24_regular,
                        validator: (v) {
                          if (v != null && v.isNotEmpty && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) return "Invalide";
                          return null;
                        },
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                EnterpriseWidgets.buildPremiumDropdown<UserRole>(label: "Rôle", value: _role, icon: FluentIcons.shield_24_regular, items: UserRole.values, itemLabel: _getRoleLabel, onChanged: (v) => v != null ? _updateRole(v) : null),
              ],

              const SizedBox(height: 12),
              EnterpriseWidgets.buildPremiumTextField(
                context,
                ctrl: _addressCtrl,
                label: "Adresse Résidentielle",
                hint: "Quartier, Rue, Porte",
                icon: FluentIcons.location_24_regular,
                maxLines: useWideLayout ? 1 : 2,
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("État du compte", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(
                        _isActive ? "Actif" : "Inactif",
                        style: TextStyle(fontSize: 11, color: _isActive ? Colors.green : Colors.red),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isActive,
                    onChanged: isMainAdmin ? null : (v) => setState(() => _isActive = v),
                    activeThumbColor: c.blue,
                  ),
                ],
              ),
              
              if (!isMainAdmin && _role != UserRole.admin && _role != UserRole.adminPlus) ...[
                const SizedBox(height: 16),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text("Permissions Détaillées", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: c.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Icon(FluentIcons.shield_keyhole_24_regular, color: c.blue, size: 18),
                    ),
                    children: [
                      if (useWideLayout) 
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          childAspectRatio: 5,
                          children: _getPermissionList().map((p) => _buildPermissionTile(p.title, p.value, p.onChanged)).toList(),
                        )
                      else
                        ..._getPermissionList().map((p) => _buildPermissionTile(p.title, p.value, p.onChanged)),
                    ],
                  ),
                ),
              ],
              
              if (!isMainAdmin && _role != UserRole.admin) ...[
                const SizedBox(height: 24),
                const Text("Accès aux Caisses de Trésorerie", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.border),
                  ),
                  child: ref.watch(treasuryProvider).when(
                    data: (accounts) {
                      if (accounts.isEmpty) {
                        return const Text("Aucune caisse disponible.", style: TextStyle(fontSize: 11));
                      }
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: accounts.map((acc) {
                          final isSelected = _assignedAccounts.contains(acc.id);
                          return FilterChip(
                            label: Text(acc.name, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : c.textPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                            selected: isSelected,
                            selectedColor: c.blue,
                            checkmarkColor: Colors.white,
                            backgroundColor: c.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: isSelected ? c.blue : c.border),
                            ),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _assignedAccounts.add(acc.id);
                                } else {
                                  _assignedAccounts.remove(acc.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())),
                    error: (e, _) => Text("Erreur: $e", style: const TextStyle(color: Colors.red)),
                  ),
                ),
                const SizedBox(height: 8),
                const Text("Ne cochez aucune caisse pour y restreindre tout accès.", style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
              ],
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
            backgroundColor: isMainAdmin ? Colors.orange : c.blue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("Enregistrer Profil"),
        ),
      ],
    );
  }

  String _getRoleLabel(UserRole r) => r.label;

  List<_PermissionItem> _getPermissionList() {
    return [
      _PermissionItem("Annulation / Retour", _permissions.canRefund, (v) => _updatePermission(canRefund: v)),
      _PermissionItem("Prix / Remises POS", _permissions.canChangePrice, (v) => _updatePermission(canChangePrice: v)),
      _PermissionItem("Inventaire & Articles", _permissions.canManageStock, (v) => _updatePermission(canManageStock: v)),
      _PermissionItem("Rapports & Stats", _permissions.canViewReports, (v) => _updatePermission(canViewReports: v)),
      _PermissionItem("Gérer Clients", _permissions.canManageCustomers, (v) => _updatePermission(canManageCustomers: v)),
      _PermissionItem("Gérer Fournisseurs", _permissions.canManageSuppliers, (v) => _updatePermission(canManageSuppliers: v)),
      _PermissionItem("Finance & Trésorerie", _permissions.canAccessFinance, (v) => _updatePermission(canAccessFinance: v)),
      _PermissionItem("Valider Dépenses", _permissions.canManageExpenses, (v) => _updatePermission(canManageExpenses: v)),
      _PermissionItem("Personnel (RH)", _permissions.canManageHR, (v) => _updatePermission(canManageHR: v)),
      _PermissionItem("Paramètres Système", _permissions.canAccessSettings, (v) => _updatePermission(canAccessSettings: v)),
    ];
  }

  Widget _buildPermissionTile(String title, bool value, Function(bool) onChanged) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      visualDensity: VisualDensity.compact,
      title: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      trailing: Transform.scale(
        scale: 0.65,
        child: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.blue,
        ),
      ),
    );
  }
}

class _PermissionItem {
  final String title;
  final bool value;
  final Function(bool) onChanged;
  _PermissionItem(this.title, this.value, this.onChanged);
}
