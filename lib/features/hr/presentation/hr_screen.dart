import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/auth/domain/models/user.dart';
import 'package:danaya_plus/features/auth/presentation/user_form_dialog.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/features/hr/domain/models/employee_contract.dart';
import 'package:danaya_plus/features/hr/domain/models/payroll.dart';
import 'package:danaya_plus/features/hr/domain/models/leave_request.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/hr/data/hr_repository.dart';
import 'package:danaya_plus/features/hr/services/hr_pdf_service.dart';
import 'package:danaya_plus/features/hr/presentation/widgets/contract_form_dialog.dart';
import 'package:danaya_plus/features/hr/presentation/widgets/payroll_form_dialog.dart';
import 'package:danaya_plus/features/hr/presentation/widgets/leave_form_dialog.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/features/auth/providers/user_providers.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/features/inventory/presentation/widgets/dashboard_widgets.dart';
import 'package:danaya_plus/features/hr/domain/models/hr_stats.dart';

class HrScreen extends ConsumerStatefulWidget {
  const HrScreen({super.key});

  @override
  ConsumerState<HrScreen> createState() => _HrScreenState();
}

class _HrScreenState extends ConsumerState<HrScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  bool _isListView = true; // Default to classic list/table view

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = DashColors.of(context);

    final user = ref.watch(authServiceProvider).value;
    if (user == null) {
      return const SizedBox.shrink();
    }

    if (!user.canManageHR) {
      return _buildEmployeeSelfService(theme, c, user);
    }

    final statsAsync = ref.watch(hrStatsProvider);

    // Log access once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).logActivity(
        userId: user.id,
        actionType: 'VIEW_HR',
        description: 'Consultation du module RH par ${user.username}',
      );
    });

    return Container(
      color: c.bg,
      padding: const EdgeInsets.all(24),
      child: statsAsync.when(
        data: (stats) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPageHeader(theme, c, stats),
            const SizedBox(height: 16),
            Expanded(child: _buildMainWorkspace(theme, c)),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Erreur stats: $e", style: TextStyle(color: c.rose))),
      ),
    );
  }

  Widget _buildPageHeader(ThemeData theme, DashColors c, HrStats stats) {
    final annualEstimate = stats.monthlyPayrollSum * 12;
    final coverageRate = stats.totalEmployees > 0
        ? ((stats.activeContracts / stats.totalEmployees) * 100).clamp(0, 100).toStringAsFixed(0)
        : '0';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Row
          Row(
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
                child: Icon(FluentIcons.people_community_24_filled, color: theme.colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Ressources Humaines",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c.textPrimary, letterSpacing: -0.5),
                    ),
                    Text(
                      "Suivi des collaborateurs, contrats, paie & congés",
                      style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  if (_tabController.index == 0) {
                    showDialog(context: context, builder: (_) => const UserFormDialog());
                  } else if (_tabController.index == 1) {
                    showDialog(context: context, builder: (_) => const ContractFormDialog());
                  } else if (_tabController.index == 2) {
                    showDialog(context: context, builder: (_) => const PayrollFormDialog());
                  } else {
                    showDialog(context: context, builder: (_) => const LeaveFormDialog());
                  }
                },
                icon: Icon(
                  _tabController.index == 0 ? FluentIcons.person_add_24_regular :
                  _tabController.index == 1 ? FluentIcons.document_add_24_regular :
                  _tabController.index == 2 ? FluentIcons.money_hand_24_regular :
                  FluentIcons.calendar_add_24_regular,
                  size: 16,
                ),
                label: Text(
                  _tabController.index == 0 ? "Ajouter" :
                  _tabController.index == 1 ? "Contrat" :
                  _tabController.index == 2 ? "Bulletin" :
                  "Congé",
                  style: const TextStyle(fontSize: 13),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Compact Stats Strip
          Container(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                _buildMiniStat(
                  icon: FluentIcons.people_20_filled,
                  label: "Effectif",
                  value: "${stats.totalEmployees}",
                  color: theme.colorScheme.primary,
                  c: c,
                ),
                _buildStripDivider(c),
                _buildMiniStat(
                  icon: FluentIcons.document_checkmark_20_filled,
                  label: "Contrats actifs",
                  value: "${stats.activeContracts}",
                  color: c.emerald,
                  c: c,
                ),
                _buildStripDivider(c),
                _buildMiniStat(
                  icon: FluentIcons.arrow_trending_20_filled,
                  label: "Couverture",
                  value: "$coverageRate%",
                  color: int.parse(coverageRate) == 100 ? c.emerald : c.amber,
                  c: c,
                ),
                _buildStripDivider(c),
                _buildMiniStat(
                  icon: FluentIcons.money_20_filled,
                  label: "Masse salariale",
                  value: ref.fmt(stats.monthlyPayrollSum),
                  color: c.violet,
                  c: c,
                ),
                _buildStripDivider(c),
                _buildMiniStat(
                  icon: FluentIcons.calendar_star_20_filled,
                  label: "Coût annuel est.",
                  value: ref.fmt(annualEstimate),
                  color: c.cyan,
                  c: c,
                ),
                _buildStripDivider(c),
                _buildMiniStat(
                  icon: FluentIcons.clock_20_filled,
                  label: "Congés en attente",
                  value: "${stats.pendingLeaves}",
                  color: stats.pendingLeaves > 0 ? c.amber : c.emerald,
                  c: c,
                ),
                if (stats.expiringContractsCount > 0) ...[
                  _buildStripDivider(c),
                  _buildMiniStat(
                    icon: FluentIcons.warning_20_filled,
                    label: "Expirations proches",
                    value: "${stats.expiringContractsCount}",
                    color: c.rose,
                    c: c,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required DashColors c,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: c.textPrimary,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: c.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStripDivider(DashColors c) {
    return Container(
      width: 1,
      height: 28,
      color: c.border,
    );
  }

  Widget _buildMainWorkspace(ThemeData theme, DashColors c) {
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
          _buildWorkspaceHeader(theme, c),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEmployeesTab(theme, c),
                _buildContractsTab(theme, c),
                _buildPayrollTab(theme, c),
                _buildLeavesTab(theme, c),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceHeader(ThemeData theme, DashColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          TabBar(
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
              Tab(text: "Employés"),
              Tab(text: "Contrats"),
              Tab(text: "Bulletins de Paie"),
              Tab(text: "Congés"),
            ],
          ),
          const Spacer(),
          if (_tabController.index == 0) ...[
            SizedBox(
              width: 260,
              height: 40,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: "Rechercher...",
                  hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
                  prefixIcon: Icon(FluentIcons.search_24_regular, color: theme.colorScheme.primary, size: 16),
                  filled: true,
                  fillColor: c.surfaceElev,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: c.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: () => setState(() => _isListView = !_isListView),
              icon: Icon(_isListView ? FluentIcons.grid_24_regular : FluentIcons.list_24_regular, color: theme.colorScheme.primary, size: 20),
              tooltip: _isListView ? "Vue Grille" : "Vue Liste (Tableau)",
              style: IconButton.styleFrom(
                backgroundColor: c.surfaceElev,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: c.border)),
              ),
            ),
          ],
        ],
      ),
    );
  }

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
                  const SizedBox(width: 100, child: Text("Actions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey), textAlign: TextAlign.right)),
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
                  final settings = ref.watch(shopSettingsProvider).value ?? const ShopSettings();

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
                          child: Text(con.position ?? "Poste NC", style: TextStyle(color: c.textSecondary, fontSize: 13)),
                        ),
                        Expanded(
                          flex: 2,
                          child: UnconstrainedBox(
                            alignment: Alignment.centerLeft,
                            child: StatusBadge(
                              text: con.contractTypeLabel,
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
                          child: UnconstrainedBox(
                            alignment: Alignment.centerLeft,
                            child: StatusBadge(
                              text: con.status.name.toUpperCase(),
                              color: con.status == ContractStatus.active ? c.emerald : c.textSecondary,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(FluentIcons.print_20_regular),
                                color: theme.colorScheme.primary,
                                onPressed: () {
                                  if (user != null) {
                                    _showStyleSelector(context, (style) => HrPdfService().generateAndPrintContract(user, con, style, settings));
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
                  final settings = ref.watch(shopSettingsProvider).value ?? const ShopSettings();

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
                                    _showStyleSelector(context, (style) => HrPdfService().generateAndPrintPayroll(user, p, style, settings));
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

  void _showEmployeeDetail(User user) {
    showDialog(
      context: context,
      builder: (context) => _EmployeeDetailDialog(user: user),
    );
  }

  void _showStyleSelector(BuildContext context, Function(PdfTemplateStyle) onSelect) {
    final styleLabels = {
      PdfTemplateStyle.standard: "Élite Corporate (Standard)",
      PdfTemplateStyle.premium: "Élite Premium (Luxe)",
      PdfTemplateStyle.modern: "Élite Moderne (Design)",
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Style du Document"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: PdfTemplateStyle.values.map((style) => ListTile(
            leading: Icon(
              style == PdfTemplateStyle.premium ? FluentIcons.star_24_regular : 
              (style == PdfTemplateStyle.modern ? FluentIcons.flash_24_regular : FluentIcons.document_24_regular),
              color: style == PdfTemplateStyle.premium ? Colors.amber : (style == PdfTemplateStyle.modern ? Colors.teal : Colors.blue),
            ),
            title: Text(styleLabels[style] ?? style.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              onSelect(style);
            },
          )).toList(),
        ),
      ),
    );
  }

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
    final settings = ref.watch(shopSettingsProvider).value ?? const ShopSettings();
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
                    _showStyleSelector(context, (style) => HrPdfService().generateAndPrintProfessionalAttestation(user, lastContract, style, settings));
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
    final settings = ref.watch(shopSettingsProvider).value ?? const ShopSettings();

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
                        _showStyleSelector(context, (style) => HrPdfService().generateAndPrintContract(user, con, style, settings));
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
    final settings = ref.watch(shopSettingsProvider).value ?? const ShopSettings();

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
                        _showStyleSelector(context, (style) => HrPdfService().generateAndPrintPayroll(user, p, style, settings));
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
                subtitle: Text("${con.contractTypeLabel} • Débute le ${DateFormatter.formatShortDate(con.startDate)}", style: TextStyle(color: c.textSecondary, fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(FluentIcons.print_20_regular),
                      color: theme.colorScheme.primary,
                      onPressed: () {
                        _showStyleSelector(context, (style) => HrPdfService().generateAndPrintContract(widget.user, con, style, settings));
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
      error: (e, s) => Center(child: Text("Erreur: $e", style: TextStyle(color: c.rose))),
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
                        _showStyleSelector(context, (style) => HrPdfService().generateAndPrintPayroll(widget.user, p, style, settings));
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
    _showStyleSelector(context, (style) => HrPdfService().generateAndPrintProfessionalAttestation(user, lastContract, style, settings));
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

  void _showStyleSelector(BuildContext context, Function(PdfTemplateStyle) onSelect) {
    final styleLabels = {
      PdfTemplateStyle.standard: "Élite Corporate (Standard)",
      PdfTemplateStyle.premium: "Élite Premium (Luxe)",
      PdfTemplateStyle.modern: "Élite Moderne (Design)",
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Style du Document"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: PdfTemplateStyle.values.map((style) => ListTile(
            leading: Icon(
              style == PdfTemplateStyle.premium ? FluentIcons.star_24_regular : 
              (style == PdfTemplateStyle.modern ? FluentIcons.flash_24_regular : FluentIcons.document_24_regular),
              color: style == PdfTemplateStyle.premium ? Colors.amber : (style == PdfTemplateStyle.modern ? Colors.teal : Colors.blue),
            ),
            title: Text(styleLabels[style] ?? style.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              onSelect(style);
            },
          )).toList(),
        ),
      ),
    );
  }
}

(String, Color) _getRoleStyle(UserRole role) {
  Color color;
  switch (role) {
    case UserRole.admin: color = Colors.amber; break;
    case UserRole.manager: color = Colors.green; break;
    case UserRole.cashier: color = Colors.blue; break;
    case UserRole.intern: color = Colors.teal; break;
    case UserRole.accountant: color = Colors.purple; break;
    case UserRole.stockManager: color = Colors.orange; break;
    case UserRole.sales: color = Colors.pink; break;
    case UserRole.auditor: color = Colors.indigo; break;
    case UserRole.inventoryAgent: color = Colors.teal; break;
    case UserRole.adminPlus: color = Colors.deepPurple; break;
  }
  return (role.label, color);
}

class _StatusIndicator extends StatelessWidget {
  final bool isActive;
  const _StatusIndicator({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8, height: 8,
      decoration: BoxDecoration(
        color: isActive ? Colors.green : Colors.grey,
        shape: BoxShape.circle,
        boxShadow: [if (isActive) BoxShadow(color: Colors.green.withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 2)],
      ),
    );
  }
}
