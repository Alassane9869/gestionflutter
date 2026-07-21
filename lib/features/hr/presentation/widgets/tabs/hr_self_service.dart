part of '../../hr_screen.dart';

extension _HrScreenSelfService on _HrScreenState {
  Widget _buildEmployeeSelfService(ThemeData theme, DashColors c, User user) {
    return Container(
      color: c.bg,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSelfServiceHeader(theme, c, user),
          const SizedBox(height: 16),
          Expanded(child: _buildSelfServiceWorkspace(theme, c, user)),
        ],
      ),
    );
  }

  Widget _buildSelfServiceHeader(ThemeData theme, DashColors c, User user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary.withValues(alpha: 0.15), theme.colorScheme.primary.withValues(alpha: 0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(FluentIcons.person_24_filled, color: theme.colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Mon Espace RH",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c.textPrimary, letterSpacing: -0.5),
                ),
                Text(
                  "Consultez vos contrats, bulletins de paie et gérez vos congés",
                  style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (_tabController.index == 3)
            FilledButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => LeaveFormDialog(userId: user.id),
                );
              },
              icon: const Icon(FluentIcons.calendar_add_24_regular, size: 16),
              label: const Text("Nouvelle Demande", style: TextStyle(fontSize: 13)),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelfServiceWorkspace(ThemeData theme, DashColors c, User user) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSelfServiceTabBar(theme, c),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSelfProfileTab(theme, c, user),
                _buildSelfContractsTab(theme, c, user),
                _buildSelfPayrollTab(theme, c, user),
                _buildSelfLeavesTab(theme, c, user),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelfServiceTabBar(ThemeData theme, DashColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: theme.colorScheme.primary,
        indicatorWeight: 3,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: c.textSecondary,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: "Mon Profil"),
          Tab(text: "Mes Contrats"),
          Tab(text: "Mes Bulletins"),
          Tab(text: "Mes Congés & Permissions"),
        ],
      ),
    );
  }

  Widget _buildSelfProfileTab(ThemeData theme, DashColors c, User user) {
    final (roleLabel, roleColor) = _getRoleStyle(user.role);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: c.surfaceElev,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: roleColor, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : "?",
                      style: TextStyle(fontWeight: FontWeight.w900, color: roleColor, fontSize: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: c.textPrimary, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "@${user.username}",
                        style: TextStyle(color: c.textSecondary, fontSize: 13, fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          StatusBadge(text: roleLabel.toUpperCase(), color: roleColor),
                          StatusBadge(
                            text: user.isActive ? "ACTIF" : "INACTIF",
                            color: user.isActive ? c.emerald : c.textSecondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final contracts = await ref.read(hrRepositoryProvider).getContractsForUser(user.id);
                    final lastContract = contracts.isNotEmpty ? contracts.first : null;
                    if (!mounted) return;
                    showDialog(
                      context: context,
                      builder: (_) => HrDocViewer(
                        employee: user,
                        contract: lastContract,
                        initialType: "attestation",
                      ),
                    );
                  },
                  icon: const Icon(FluentIcons.hat_graduation_24_regular, size: 16),
                  label: const Text("Attestation Pro."),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text("COORDONNÉES & INFORMATIONS PERSONNELLES", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c.textMuted, letterSpacing: 0.5)),
          const SizedBox(height: 16),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              mainAxisExtent: 70,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            children: [
              _buildProfileDetailItem("Email", user.email ?? "Non spécifié", FluentIcons.mail_24_regular, c),
              _buildProfileDetailItem("Téléphone", user.phone ?? "Non spécifié", FluentIcons.phone_24_regular, c),
              _buildProfileDetailItem("Adresse", user.address ?? "Non spécifiée", FluentIcons.location_24_regular, c),
              _buildProfileDetailItem("Date d'embauche", user.hireDate != null ? DateFormatter.formatDate(user.hireDate!) : "Non spécifiée", FluentIcons.calendar_ltr_24_regular, c),
              _buildProfileDetailItem("Nationalité", user.nationality ?? "Non spécifiée", FluentIcons.flag_24_regular, c),
              _buildProfileDetailItem("Date de naissance", user.birthDate != null ? DateFormatter.formatDate(user.birthDate!) : "Non spécifiée", FluentIcons.calendar_clock_24_regular, c),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetailItem(String label, String value, IconData icon, DashColors c) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceElev,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: Colors.blue, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelfContractsTab(ThemeData theme, DashColors c, User user) {
    final contractsAsync = ref.watch(userContractsProvider(user.id));

    return contractsAsync.when(
      data: (contracts) {
        if (contracts.isEmpty) {
          return Center(child: Text("Aucun contrat enregistré", style: TextStyle(color: c.textSecondary)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: contracts.length,
          itemBuilder: (context, index) {
            final con = contracts[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: c.surfaceElev,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.border)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                title: Text(con.position ?? "Poste NC", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      "${con.contractTypeLabel}  •  Débute le : ${DateFormatter.formatShortDate(con.startDate)}  •  Fin : ${con.endDate != null ? DateFormatter.formatShortDate(con.endDate!) : 'CDI'}", 
                      style: TextStyle(color: c.textSecondary, fontSize: 12)
                    ),
                    const SizedBox(height: 4),
                    Text("Salaire de base : ${ref.fmt(con.baseSalary)}", style: TextStyle(fontWeight: FontWeight.bold, color: c.emerald, fontSize: 13)),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusBadge(
                      text: con.status.name.toUpperCase(),
                      color: con.status == ContractStatus.active ? c.emerald : c.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(FluentIcons.print_20_regular),
                      color: theme.colorScheme.primary,
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => HrDocViewer(
                            employee: user,
                            contract: con,
                            initialType: "contract",
                          ),
                        );
                      },
                      tooltip: "Imprimer ce contrat",
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

  Widget _buildSelfPayrollTab(ThemeData theme, DashColors c, User user) {
    final payrollsAsync = ref.watch(userPayrollsProvider(user.id));

    return payrollsAsync.when(
      data: (payrolls) {
        if (payrolls.isEmpty) {
          return Center(child: Text("Aucun bulletin de paie disponible", style: TextStyle(color: c.textSecondary)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: payrolls.length,
          itemBuilder: (context, index) {
            final p = payrolls[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: c.surfaceElev,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.border)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                title: Text("Bulletin de paie — ${p.periodLabel}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      "Période : ${p.month}/${p.year}  •  Paiement : ${p.paymentDate != null ? DateFormatter.formatShortDate(p.paymentDate!) : 'N/A'}", 
                      style: TextStyle(color: c.textSecondary, fontSize: 12)
                    ),
                    if (p.extraLines.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: p.extraLines.map((line) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (line.isAddition ? c.emerald : c.rose).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "${line.label} (${line.isAddition ? '+' : '-'}${ref.fmt(line.amount)})",
                            style: TextStyle(
                              color: line.isAddition ? c.emerald : c.rose,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ref.fmt(p.netSalary),
                      style: TextStyle(fontWeight: FontWeight.bold, color: c.emerald, fontSize: 16),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(FluentIcons.print_20_regular),
                      color: c.emerald,
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => HrDocViewer(
                            employee: user,
                            payroll: p,
                            initialType: "payroll",
                          ),
                        );
                      },
                      tooltip: "Imprimer ce bulletin",
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

  Widget _buildSelfLeavesTab(ThemeData theme, DashColors c, User user) {
    final myLeavesAsync = ref.watch(userLeavesProvider(user.id));

    return myLeavesAsync.when(
      data: (leaves) {
        if (leaves.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Aucune demande de congé enregistrée", style: TextStyle(color: c.textSecondary)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => LeaveFormDialog(userId: user.id),
                    );
                  },
                  icon: const Icon(FluentIcons.calendar_add_24_regular, size: 16),
                  label: const Text("Faire une demande"),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: leaves.length,
          itemBuilder: (context, index) {
            final l = leaves[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: c.surfaceElev,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.border)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                title: Text(l.leaveTypeLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      "Du ${DateFormatter.formatShortDate(l.startDate)} au ${DateFormatter.formatShortDate(l.endDate)}  •  Durée : ${l.durationInDays} jours", 
                      style: TextStyle(color: c.textSecondary, fontSize: 12)
                    ),
                    const SizedBox(height: 4),
                    Text("Motif : ${l.reason}", style: TextStyle(color: c.textPrimary, fontSize: 12)),
                    if (l.status != LeaveStatus.pending && l.reviewerNote != null && l.reviewerNote!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text("Note manager : ${l.reviewerNote}", style: TextStyle(color: c.textSecondary, fontSize: 11, fontStyle: FontStyle.italic)),
                    ],
                  ],
                ),
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
    );
  }
}
