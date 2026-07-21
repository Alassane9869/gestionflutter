part of '../../hr_screen.dart';

extension _HrScreenLeaves on _HrScreenState {
  Widget _buildLeavesTab(ThemeData theme, DashColors c) {
    final leavesAsync = ref.watch(allLeavesProvider);
    return leavesAsync.when(
      data: (leaves) {
        if (leaves.isEmpty) {
          return Center(child: Text("Aucune demande de congé enregistrée", style: TextStyle(color: c.textSecondary)));
        }
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              color: c.surfaceElev,
              child: Row(
                children: [
                  const Expanded(flex: 3, child: Text("Collaborateur", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                  const Expanded(flex: 2, child: Text("Type de congé", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                  const Expanded(flex: 2, child: Text("Période", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                  const Expanded(flex: 2, child: Text("Durée", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                  const Expanded(flex: 2, child: Text("Statut", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                  const SizedBox(width: 100, child: Text("Actions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey), textAlign: TextAlign.right)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: leaves.length,
                itemBuilder: (context, index) {
                  final l = leaves[index];
                  final users = ref.watch(userListProvider).value ?? [];
                  final user = users.where((u) => u.id == l.userId).firstOrNull;
                  final userName = user?.fullName ?? "Employé inconnu";

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(userName, style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary, fontSize: 14)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(l.leaveTypeLabel, style: TextStyle(color: c.textSecondary, fontSize: 13)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            "${DateFormatter.formatShortDate(l.startDate)} au ${DateFormatter.formatShortDate(l.endDate)}",
                            style: TextStyle(color: c.textSecondary, fontSize: 13),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            "${l.durationInDays} jours",
                            style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary, fontSize: 13),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: UnconstrainedBox(
                            alignment: Alignment.centerLeft,
                            child: StatusBadge(
                              text: l.status.name.toUpperCase(),
                              color: l.status == LeaveStatus.approved ? c.emerald : (l.status == LeaveStatus.pending ? c.amber : c.rose),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(FluentIcons.edit_20_regular),
                                color: theme.colorScheme.primary,
                                onPressed: () => showDialog(context: context, builder: (_) => LeaveFormDialog(userId: l.userId, request: l)),
                                tooltip: "Gérer la demande",
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text("Erreur: $e", style: TextStyle(color: c.rose))),
    );
  }
}
