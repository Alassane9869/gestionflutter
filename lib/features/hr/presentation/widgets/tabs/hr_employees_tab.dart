part of '../../hr_screen.dart';

extension _HrScreenEmployees on _HrScreenState {
  Widget _buildEmployeesTab(ThemeData theme, DashColors c) {
    final usersAsync = ref.watch(userListProvider);
    final query = _searchCtrl.text.toLowerCase();

    return usersAsync.when(
      data: (users) {
        final filtered = users.where((u) {
          final nameMatch = u.fullName.toLowerCase().contains(query);
          final userMatch = u.username.toLowerCase().contains(query);
          final roleMatch = u.role.name.toLowerCase().contains(query);
          return nameMatch || userMatch || roleMatch;
        }).toList();

        if (filtered.isEmpty) {
          return Center(child: Text("Aucun employé trouvé", style: TextStyle(color: c.textSecondary)));
        }

        if (_isListView) {
          return Column(
            children: [
              _buildEmployeesTableHeader(c),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _EmployeeTableRow(
                    user: filtered[index],
                    onTap: () => _showEmployeeDetail(filtered[index]),
                  ),
                ),
              ),
            ],
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 380,
            mainAxisExtent: 220,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) => _ClassicEmployeeCard(
            user: filtered[index],
            onTap: () => _showEmployeeDetail(filtered[index]),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("Erreur: $e", style: TextStyle(color: c.rose))),
    );
  }

  Widget _buildEmployeesTableHeader(DashColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: c.surfaceElev,
      child: Row(
        children: [
          const SizedBox(width: 40, child: Text("Photo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
          const SizedBox(width: 16),
          const Expanded(flex: 3, child: Text("Nom complet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
          const Expanded(flex: 2, child: Text("Identifiant", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
          const Expanded(flex: 2, child: Text("Rôle", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
          const Expanded(flex: 2, child: Text("Téléphone", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
          const SizedBox(width: 100, child: Text("État", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
          const SizedBox(width: 150, child: Text("Actions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _EmployeeTableRow extends ConsumerWidget {
  final User user;
  final VoidCallback onTap;
  const _EmployeeTableRow({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = DashColors.of(context);
    final theme = Theme.of(context);
    final (roleLabel, roleColor) = _getRoleStyle(user.role);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.border)),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: roleColor.withValues(alpha: 0.2)),
              ),
              child: Center(
                child: Text(
                  user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : "?",
                  style: TextStyle(fontWeight: FontWeight.bold, color: roleColor, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Text(user.fullName, style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary, fontSize: 14)),
            ),
            Expanded(
              flex: 2,
              child: Text("@${user.username}", style: TextStyle(color: c.textSecondary, fontSize: 13, fontFamily: 'monospace')),
            ),
            Expanded(
              flex: 2,
              child: UnconstrainedBox(
                alignment: Alignment.centerLeft,
                child: StatusBadge(text: roleLabel.toUpperCase(), color: roleColor),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(user.phone ?? "Non renseigné", style: TextStyle(color: c.textSecondary, fontSize: 13)),
            ),
            SizedBox(
              width: 100,
              child: Row(
                children: [
                  _StatusIndicator(isActive: user.isActive),
                  const SizedBox(width: 8),
                  Text(
                    user.isActive ? "Actif" : "Inactif",
                    style: TextStyle(color: user.isActive ? c.emerald : c.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 150,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(FluentIcons.eye_20_regular),
                    onPressed: onTap,
                    tooltip: "Détails",
                    color: theme.colorScheme.primary,
                  ),
                  IconButton(
                    icon: const Icon(FluentIcons.edit_20_regular),
                    onPressed: () => showDialog(context: context, builder: (_) => UserFormDialog(user: user)),
                    tooltip: "Modifier",
                    color: c.textSecondary,
                  ),
                  if (!user.isAdmin && user.isActive && !ref.watch(authServiceProvider.notifier).isImpersonating)
                    IconButton(
                      icon: const Icon(FluentIcons.incognito_20_regular),
                      onPressed: () {
                        EnterpriseWidgets.showPremiumConfirmDialog(
                          context,
                          title: "Incarner l'utilisateur ?",
                          message: "Voulez-vous agir en tant que ${user.fullName} ?",
                          confirmText: "Incarner",
                          onConfirm: () => ref.read(authServiceProvider.notifier).impersonate(user),
                        );
                      },
                      tooltip: "Incarner",
                      color: Colors.orange,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassicEmployeeCard extends ConsumerWidget {
  final User user;
  final VoidCallback onTap;
  const _ClassicEmployeeCard({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = DashColors.of(context);
    final theme = Theme.of(context);
    final (roleLabel, roleColor) = _getRoleStyle(user.role);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: roleColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: roleColor.withValues(alpha: 0.2), width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : "?",
                        style: TextStyle(fontWeight: FontWeight.bold, color: roleColor, fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "@${user.username}",
                          style: TextStyle(color: c.textSecondary, fontSize: 11, fontFamily: 'monospace'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Rôle", style: TextStyle(color: c.textMuted, fontSize: 11)),
                      StatusBadge(text: roleLabel.toUpperCase(), color: roleColor),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Téléphone", style: TextStyle(color: c.textMuted, fontSize: 11)),
                      Text(user.phone ?? "Non spécifié", style: TextStyle(color: c.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Statut", style: TextStyle(color: c.textMuted, fontSize: 11)),
                      Row(
                        children: [
                          _StatusIndicator(isActive: user.isActive),
                          const SizedBox(width: 6),
                          Text(user.isActive ? "Actif" : "Inactif", style: TextStyle(color: user.isActive ? c.emerald : c.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            const Divider(height: 1),
            Container(
              color: c.surfaceElev,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: onTap,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    child: const Text("Détails", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(FluentIcons.edit_20_regular, size: 16),
                    onPressed: () => showDialog(context: context, builder: (_) => UserFormDialog(user: user)),
                    tooltip: "Modifier",
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  if (!user.isAdmin && user.isActive && !ref.watch(authServiceProvider.notifier).isImpersonating)
                    IconButton(
                      icon: const Icon(FluentIcons.incognito_20_regular, size: 16),
                      onPressed: () {
                        EnterpriseWidgets.showPremiumConfirmDialog(
                          context,
                          title: "Incarner l'utilisateur ?",
                          message: "Voulez-vous agir en tant que ${user.fullName} ?",
                          confirmText: "Incarner",
                          onConfirm: () => ref.read(authServiceProvider.notifier).impersonate(user),
                        );
                      },
                      tooltip: "Incarner",
                      color: Colors.orange,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
