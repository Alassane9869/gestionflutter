part of '../../hr_screen.dart';

extension _HrScreenContracts on _HrScreenState {
  Widget _buildContractsTab(ThemeData theme, DashColors c) {
    final contractsAsync = ref.watch(allContractsProvider);
    return contractsAsync.when(
      data: (contracts) {
        if (contracts.isEmpty) {
          return Center(child: Text("Aucun contrat enregistré", style: TextStyle(color: c.textSecondary)));
        }
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              color: c.surfaceElev,
              child: Row(
                children: [
                  const Expanded(flex: 3, child: Text("Collaborateur", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                  const Expanded(flex: 2, child: Text("Poste", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                  const Expanded(flex: 2, child: Text("Type de contrat", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                  const Expanded(flex: 2, child: Text("Dates", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                  const Expanded(flex: 2, child: Text("Salaire de base", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                  const SizedBox(width: 100, child: Text("État", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                  const SizedBox(width: 140, child: Text("Actions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey), textAlign: TextAlign.right)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: contracts.length,
                itemBuilder: (context, index) {
                  final con = contracts[index];
                  final users = ref.watch(userListProvider).value ?? [];
                  final user = users.where((u) => u.id == con.userId).firstOrNull;
                  final userName = user?.fullName ?? "Employé inconnu";

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                child: Text(userName.substring(0, 1).toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(userName, style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary, fontSize: 14), overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(con.position ?? "Poste NC", style: TextStyle(color: c.textSecondary, fontSize: 13)),
                        ),
                        Expanded(
                          flex: 2,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: StatusBadge(
                              text: con.contractType.name.toUpperCase(),
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            "${DateFormatter.formatShortDate(con.startDate)} - ${con.endDate != null ? DateFormatter.formatShortDate(con.endDate!) : 'CDI'}",
                            style: TextStyle(color: c.textSecondary, fontSize: 13),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            ref.fmt(con.baseSalary),
                            style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary, fontSize: 13),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: StatusBadge(
                              text: con.status == ContractStatus.active ? "ACTIF" : (con.status == ContractStatus.terminated ? "CLÔTURÉ" : "EXPIRÉ"),
                              color: con.status == ContractStatus.active ? c.emerald : (con.status == ContractStatus.terminated ? c.textSecondary : c.amber),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 140,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(FluentIcons.print_20_regular),
                                color: theme.colorScheme.primary,
                                onPressed: () {
                                  if (user != null) {
                                    showDialog(
                                      context: context,
                                      builder: (_) => HrDocViewer(
                                        employee: user,
                                        contract: con,
                                        initialType: "contract",
                                      ),
                                    );
                                  }
                                },
                                tooltip: "Imprimer",
                              ),
                              IconButton(
                                icon: const Icon(FluentIcons.edit_20_regular),
                                color: c.textSecondary,
                                onPressed: () => showDialog(context: context, builder: (_) => ContractFormDialog(userId: con.userId, contract: con)),
                                tooltip: "Modifier",
                              ),
                              IconButton(
                                icon: const Icon(FluentIcons.delete_20_regular),
                                color: c.rose,
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Row(
                                        children: [
                                          Icon(FluentIcons.warning_24_filled, color: c.amber),
                                          const SizedBox(width: 12),
                                          const Text("Supprimer le contrat"),
                                        ],
                                      ),
                                      content: const Text("Êtes-vous sûr de vouloir supprimer définitivement ce contrat ? Cette action est irréversible."),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text("Annuler", style: TextStyle(color: Colors.grey)),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          style: ElevatedButton.styleFrom(backgroundColor: c.rose, foregroundColor: Colors.white),
                                          child: const Text("Supprimer", style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );
                                  
                                  if (confirm == true) {
                                    await ref.read(hrRepositoryProvider).deleteContract(con.id);
                                    ref.invalidate(allContractsProvider);
                                    ref.invalidate(hrStatsProvider);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Contrat supprimé avec succès.")));
                                    }
                                  }
                                },
                                tooltip: "Supprimer",
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
