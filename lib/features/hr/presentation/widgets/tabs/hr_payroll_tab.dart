part of '../../hr_screen.dart';

extension _HrScreenPayroll on _HrScreenState {
  Widget _buildPayrollTab(ThemeData theme, DashColors c) {
    final payrollsAsync = ref.watch(allPayrollsProvider);
    return payrollsAsync.when(
      data: (payrolls) {
        if (payrolls.isEmpty) {
          return Center(child: Text("Aucun bulletin de paie généré", style: TextStyle(color: c.textSecondary)));
        }
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              color: c.surfaceElev,
              child: Row(
                children: [
                  const Expanded(flex: 3, child: Text("Collaborateur", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                  const Expanded(flex: 2, child: Text("Période", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                  const Expanded(flex: 2, child: Text("Date de paiement", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                  const Expanded(flex: 3, child: Text("Primes / Retenues", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                  const Expanded(flex: 2, child: Text("Net à Payer", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                  const SizedBox(width: 100, child: Text("Actions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey), textAlign: TextAlign.right)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: payrolls.length,
                itemBuilder: (context, index) {
                  final p = payrolls[index];
                  final users = ref.watch(userListProvider).value ?? [];
                  final user = users.where((u) => u.id == p.userId).firstOrNull;
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
                          child: Text(p.periodLabel, style: TextStyle(color: c.textSecondary, fontSize: 13)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            p.paymentDate != null ? DateFormatter.formatShortDate(p.paymentDate!) : "N/A",
                            style: TextStyle(color: c.textSecondary, fontSize: 13),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: p.extraLines.isEmpty
                              ? Text("—", style: TextStyle(color: c.textMuted, fontSize: 12))
                              : Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: p.extraLines.take(2).map((line) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (line.isAddition ? c.emerald : c.rose).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      "${line.isAddition ? '+' : '-'}${ref.fmt(line.amount)}",
                                      style: TextStyle(
                                        color: line.isAddition ? c.emerald : c.rose,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )).toList(),
                                ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            ref.fmt(p.netSalary),
                            style: TextStyle(fontWeight: FontWeight.bold, color: c.emerald, fontSize: 14),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(FluentIcons.print_20_regular),
                                color: c.emerald,
                                onPressed: () {
                                  if (user != null) {
                                    showDialog(
                                      context: context,
                                      builder: (_) => HrDocViewer(
                                        employee: user,
                                        payroll: p,
                                        initialType: "payroll",
                                      ),
                                    );
                                  }
                                },
                                tooltip: "Imprimer bulletin",
                              ),
                              IconButton(
                                icon: const Icon(FluentIcons.edit_20_regular),
                                color: c.textSecondary,
                                onPressed: () => showDialog(context: context, builder: (_) => PayrollFormDialog(userId: p.userId, payroll: p)),
                                tooltip: "Modifier",
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
