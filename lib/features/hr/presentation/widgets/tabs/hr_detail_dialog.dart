part of '../../hr_screen.dart';

class _EmployeeDetailDialog extends ConsumerStatefulWidget {
  final User user;
  const _EmployeeDetailDialog({required this.user});

  @override
  ConsumerState<_EmployeeDetailDialog> createState() => _EmployeeDetailDialogState();
}

class _EmployeeDetailDialogState extends ConsumerState<_EmployeeDetailDialog> with SingleTickerProviderStateMixin {
  late TabController _detailTabController;

  @override
  void initState() {
    super.initState();
    _detailTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _detailTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = DashColors.of(context);
    final contractsAsync = ref.watch(userContractsProvider(widget.user.id));
    final payrollsAsync = ref.watch(userPayrollsProvider(widget.user.id));
    final settings = ref.watch(shopSettingsProvider).value ?? const ShopSettings();
    final (roleLabel, roleColor) = _getRoleStyle(widget.user.role);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
          width: 1.5,
        ),
      ),
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: theme.colorScheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 920,
          maxHeight: 650,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Pane: Profile Card
            Container(
              width: 300,
              decoration: BoxDecoration(
                color: c.surfaceElev,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                ),
                border: Border(right: BorderSide(color: c.border)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: roleColor, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        widget.user.fullName.isNotEmpty ? widget.user.fullName[0].toUpperCase() : "?",
                        style: TextStyle(fontWeight: FontWeight.w900, color: roleColor, fontSize: 32),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.user.fullName,
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: c.textPrimary, letterSpacing: -0.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "@${widget.user.username}",
                    style: TextStyle(color: c.textSecondary, fontSize: 13, fontFamily: 'monospace'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      StatusBadge(text: roleLabel.toUpperCase(), color: roleColor),
                      StatusBadge(
                        text: widget.user.isActive ? "ACTIF" : "INACTIF",
                        color: widget.user.isActive ? c.emerald : c.textSecondary,
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  _buildQuickContactRow(FluentIcons.mail_20_regular, widget.user.email ?? "Pas d'email", c),
                  const SizedBox(height: 10),
                  _buildQuickContactRow(FluentIcons.phone_20_regular, widget.user.phone ?? "Pas de tél", c),
                  const SizedBox(height: 10),
                  _buildQuickContactRow(FluentIcons.location_20_regular, widget.user.address ?? "Pas d'adresse", c),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => _printProfessionalAttestation(context, widget.user, settings, ref),
                    icon: const Icon(FluentIcons.hat_graduation_24_regular, size: 16),
                    label: const Text("Attestation Pro."),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _printPassation(context, widget.user, settings, ref),
                    icon: const Icon(FluentIcons.document_copy_24_regular, size: 16),
                    label: const Text("Passation de Service"),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.user.id != 'sysadmin' && widget.user.id != ref.read(authServiceProvider).value?.id)
                    OutlinedButton.icon(
                      onPressed: () => _confirmDeleteAccount(context, ref, widget.user),
                      icon: const Icon(FluentIcons.delete_24_regular, size: 16, color: Colors.red),
                      label: const Text("Supprimer le Compte", style: TextStyle(color: Colors.red, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                ],
              ),
            ),
            // Right Pane: Tabs & History
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 20, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Fiche de Collaborateur",
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(FluentIcons.dismiss_24_regular, color: Colors.grey.shade500, size: 20),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TabBar(
                      controller: _detailTabController,
                      indicatorColor: theme.colorScheme.primary,
                      labelColor: theme.colorScheme.primary,
                      unselectedLabelColor: c.textSecondary,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                      dividerColor: c.border,
                      tabs: const [
                        Tab(text: "Contrats"),
                        Tab(text: "Bulletins de Paie"),
                        Tab(text: "Actions & Congés"),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: TabBarView(
                        controller: _detailTabController,
                        children: [
                          _buildDetailContractsTab(contractsAsync, settings, c, theme),
                          _buildDetailPayrollTab(payrollsAsync, settings, c, theme),
                          _buildDetailActionsTab(contractsAsync, c, theme),
                        ],
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

  Widget _buildQuickContactRow(IconData icon, String label, DashColors c) {
    return Row(
      children: [
        Icon(icon, color: c.textSecondary, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: c.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailContractsTab(
      AsyncValue<List<EmployeeContract>> contractsAsync,
      ShopSettings settings,
      DashColors c,
      ThemeData theme) {
    return contractsAsync.when(
      data: (contracts) {
        if (contracts.isEmpty) {
          return Center(child: Text("Aucun contrat enregistré", style: TextStyle(color: c.textSecondary, fontSize: 13)));
        }
        return ListView.builder(
          itemCount: contracts.length,
          itemBuilder: (context, index) {
            final con = contracts[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: c.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.border)),
              child: ListTile(
                title: Text(con.position ?? "Poste NC", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${con.contractTypeLabel} • Débute le ${DateFormatter.formatShortDate(con.startDate)}", style: TextStyle(color: c.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    _buildContractStatusBadge(con.status),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(FluentIcons.print_20_regular),
                      color: theme.colorScheme.primary,
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => HrDocViewer(
                            employee: widget.user,
                            contract: con,
                            initialType: "contract",
                          ),
                        );
                      },
                      tooltip: "Imprimer ce contrat",
                    ),
                    IconButton(
                      icon: const Icon(FluentIcons.edit_20_regular),
                      color: c.textSecondary,
                      onPressed: () => showDialog(context: context, builder: (_) => ContractFormDialog(userId: widget.user.id, contract: con)),
                      tooltip: "Modifier le contrat",
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text("Erreur: $err")),
    );
  }

  Widget _buildContractStatusBadge(ContractStatus status) {
    Color color;
    String text;
    switch (status) {
      case ContractStatus.active:
        color = Colors.green;
        text = "Actif";
        break;
      case ContractStatus.terminated:
        color = Colors.grey;
        text = "Clôturé";
        break;
      case ContractStatus.expired:
        color = Colors.red;
        text = "Expiré";
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDetailPayrollTab(
      AsyncValue<List<Payroll>> payrollsAsync,
      ShopSettings settings,
      DashColors c,
      ThemeData theme) {
    return payrollsAsync.when(
      data: (payrolls) {
        if (payrolls.isEmpty) {
          return Center(child: Text("Aucun bulletin de paie généré", style: TextStyle(color: c.textSecondary, fontSize: 13)));
        }
        return ListView.builder(
          itemCount: payrolls.length,
          itemBuilder: (context, index) {
            final p = payrolls[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: c.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.border)),
              child: ListTile(
                title: Text("Bulletin ${p.periodLabel}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text("Payé le ${p.paymentDate != null ? DateFormatter.formatShortDate(p.paymentDate!) : 'N/A'}", style: TextStyle(color: c.textSecondary, fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ref.fmt(p.netSalary),
                      style: TextStyle(fontWeight: FontWeight.bold, color: c.emerald, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(FluentIcons.print_20_regular),
                      color: c.emerald,
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => HrDocViewer(
                            employee: widget.user,
                            payroll: p,
                            initialType: "payroll",
                          ),
                        );
                      },
                      tooltip: "Imprimer ce bulletin",
                    ),
                    IconButton(
                      icon: const Icon(FluentIcons.edit_20_regular),
                      color: c.textSecondary,
                      onPressed: () => showDialog(context: context, builder: (_) => PayrollFormDialog(userId: widget.user.id, payroll: p)),
                      tooltip: "Modifier le bulletin",
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text("Erreur: $e", style: TextStyle(color: c.rose))),
    );
  }

  Widget _buildDetailActionsTab(
      AsyncValue<List<EmployeeContract>> contractsAsync,
      DashColors c,
      ThemeData theme) {
    final leavesAsync = ref.watch(allLeavesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("ACTIONS DU MANAGER", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c.textMuted, letterSpacing: 0.5)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  final activeContract = contractsAsync.value?.where((con) => con.status == ContractStatus.active).firstOrNull;
                  showDialog(context: context, builder: (_) => PayrollFormDialog(userId: widget.user.id, activeContract: activeContract));
                },
                icon: const Icon(FluentIcons.money_24_regular, size: 16),
                label: const Text("Créer Paie", style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.emerald,
                  side: BorderSide(color: c.emerald.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => showDialog(context: context, builder: (_) => LeaveFormDialog(userId: widget.user.id)),
                icon: const Icon(FluentIcons.calendar_24_regular, size: 16),
                label: const Text("Créer Congé", style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.amber,
                  side: BorderSide(color: c.amber.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => showDialog(context: context, builder: (_) => UserFormDialog(user: widget.user)),
                icon: const Icon(FluentIcons.edit_24_regular, size: 16),
                label: const Text("Modifier Profil", style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            if (!widget.user.isAdmin && widget.user.isActive && !ref.watch(authServiceProvider.notifier).isImpersonating) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    EnterpriseWidgets.showPremiumConfirmDialog(
                      context,
                      title: "Incarner l'utilisateur ?",
                      message: "Voulez-vous agir en tant que ${widget.user.fullName} ?",
                      confirmText: "Incarner",
                      onConfirm: () {
                        ref.read(authServiceProvider.notifier).impersonate(widget.user);
                        Navigator.pop(context);
                      },
                    );
                  },
                  icon: const Icon(FluentIcons.incognito_24_regular, size: 16),
                  label: const Text("Incarner", style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: BorderSide(color: Colors.orange.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
        const Divider(height: 32),
        Text("HISTORIQUE DES CONGÉS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c.textMuted, letterSpacing: 0.5)),
        const SizedBox(height: 12),
        Expanded(
          child: leavesAsync.when(
            data: (allLeaves) {
              final userLeaves = allLeaves.where((l) => l.userId == widget.user.id).toList();
              if (userLeaves.isEmpty) {
                return Center(child: Text("Aucune demande de congé enregistrée", style: TextStyle(color: c.textSecondary, fontSize: 13)));
              }
              return ListView.builder(
                itemCount: userLeaves.length,
                itemBuilder: (context, index) {
                  final l = userLeaves[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: c.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.border)),
                    child: ListTile(
                      title: Text(l.leaveTypeLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text("${l.durationInDays} jours • du ${DateFormatter.formatShortDate(l.startDate)} au ${DateFormatter.formatShortDate(l.endDate)}", style: TextStyle(color: c.textSecondary, fontSize: 11)),
                      trailing: StatusBadge(
                        text: l.status.name.toUpperCase(),
                        color: l.status == LeaveStatus.approved ? c.emerald : (l.status == LeaveStatus.pending ? c.amber : c.rose),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text("Erreur: $e", style: TextStyle(color: c.rose))),
          ),
        ),
      ],
    );
  }

  void _printProfessionalAttestation(BuildContext context, User user, ShopSettings settings, WidgetRef ref) async {
    final contracts = await ref.read(hrRepositoryProvider).getContractsForUser(user.id);
    final lastContract = contracts.isNotEmpty ? contracts.first : null;
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => HrDocViewer(
        employee: user,
        contract: lastContract,
        initialType: "attestation",
      ),
    );
  }

  void _printPassation(BuildContext context, User user, ShopSettings settings, WidgetRef ref) async {
    final contracts = await ref.read(hrRepositoryProvider).getContractsForUser(user.id);
    final lastContract = contracts.isNotEmpty ? contracts.first : null;
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => HrDocViewer(
        employee: user,
        contract: lastContract,
        initialType: "passation",
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref, User targetUser) {
    EnterpriseWidgets.showPremiumConfirmDialog(
      context,
      title: "Supprimer le compte ?",
      message: "Voulez-vous supprimer définitivement l'accès de ${targetUser.fullName} ?\n\nNote: La suppression échouera si cet utilisateur possède des archives (ventes, achats).",
      confirmText: "SUPPRIMER",
      isDestructive: true,
      onConfirm: () async {
        try {
          await ref.read(userManagementServiceProvider).deleteUser(targetUser.id);
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Utilisateur supprimé')),
            );
          }
        } catch (e) {
          if (context.mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
          }
        }
      },
    );
  }

}
