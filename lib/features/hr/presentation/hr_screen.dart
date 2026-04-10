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
import 'package:danaya_plus/core/widgets/access_denied_screen.dart';
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
  bool _isListView = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final statsAsync = ref.watch(hrStatsProvider);

    final user = ref.watch(authServiceProvider).value;
    if (user == null || !user.canManageHR) {
      return const AccessDeniedScreen(
        message: "Module RH Restreint",
        subtitle: "Seuls les administrateurs et comptables peuvent accéder à la gestion du personnel.",
      );
    }

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
      child: Column(
        children: [
          _buildTopBar(c),
          Expanded(
            child: statsAsync.when(
              data: (stats) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: _buildHeader(stats, c),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildTabSection(c),
                    ),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text("Erreur stats: $e")),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(DashColors c) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border, width: 1)),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.people_community_24_filled, color: c.blue, size: 24),
          const SizedBox(width: 12),
          Text(
            'Ressources Humaines',
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const Spacer(),
          _buildTabIndicator(c),
        ],
      ),
    );
  }

  Widget _buildTabIndicator(DashColors c) {
    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicator: BoxDecoration(
          color: c.blue,
          borderRadius: BorderRadius.circular(7),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: c.textSecondary,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: "Employés"),
          Tab(text: "Contrats"),
          Tab(text: "Paies"),
          Tab(text: "Congés"),
        ],
      ),
    );
  }

  Widget _buildHeader(HrStats stats, DashColors c) {
    final w = MediaQuery.of(context).size.width;
    final cols = w > 1200 ? 4 : (w > 600 ? 2 : 1);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: cols,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: cols == 4 ? 2.2 : 2.5,
      children: [
        UltraKpiCard(
          label: "Total Personnel",
          value: "${stats.totalEmployees}",
          icon: FluentIcons.people_24_regular,
          accent: c.blue,
        ),
        UltraKpiCard(
          label: "Contrats Actifs",
          value: "${stats.activeContracts}",
          icon: FluentIcons.document_text_24_regular,
          accent: c.emerald,
          change: stats.expiringContractsCount > 0 ? "${stats.expiringContractsCount} expirent bientôt" : null,
          positive: stats.expiringContractsCount == 0,
        ),
        UltraKpiCard(
          label: "Masse Salariale (Mois)",
          value: ref.fmt(stats.monthlyPayrollSum),
          icon: FluentIcons.money_24_regular,
          accent: c.violet,
        ),
        UltraKpiCard(
          label: "Congés en Attente",
          value: "${stats.pendingLeaves}",
          icon: FluentIcons.calendar_clock_24_regular,
          accent: stats.pendingLeaves > 0 ? c.amber : c.emerald,
        ),
      ],
    );
  }

  Widget _buildTabSection(DashColors c) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildEmployeesTab(),
              _buildContractsTab(),
              _buildPayrollTab(),
              _buildLeavesTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeesTab() {
    final c = DashColors.of(context);
    final usersAsync = ref.watch(userListProvider);
    final query = _searchCtrl.text.toLowerCase();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: "Rechercher...",
                    prefixIcon: Icon(FluentIcons.search_24_regular, color: c.blue),
                    filled: true,
                    fillColor: c.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => setState(() => _isListView = !_isListView),
                icon: Icon(_isListView ? FluentIcons.grid_24_regular : FluentIcons.list_24_regular, color: c.blue),
                tooltip: _isListView ? "Vue Grille" : "Vue Liste",
                style: IconButton.styleFrom(
                  backgroundColor: c.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.border)),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => showDialog(context: context, builder: (_) => const UserFormDialog()),
                icon: const Icon(FluentIcons.person_add_24_regular, size: 18),
                label: const Text("Ajouter"),
                style: FilledButton.styleFrom(
                  backgroundColor: c.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: usersAsync.when(
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
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _EmployeeListRow(
                    user: filtered[index],
                    onTap: () => _showEmployeeDetail(filtered[index]),
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 380,
                  mainAxisExtent: 240, 
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) => _ModernEmployeeCard(
                  user: filtered[index],
                  onTap: () => _showEmployeeDetail(filtered[index]),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text("Erreur: $e")),
          ),
        ),
      ],
    );
  }

  void _showEmployeeDetail(User user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EmployeeDetailSheet(user: user),
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

  void _showPrintActions(BuildContext context, User user, ShopSettings settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Impression - ${user.fullName}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(FluentIcons.document_text_24_regular, color: Colors.amber),
              title: const Text("Dernier Contrat"),
              onTap: () async {
                final contracts = await ref.read(hrRepositoryProvider).getContractsForUser(user.id);
                if (contracts.isNotEmpty) {
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _showStyleSelector(context, (style) => HrPdfService().generateAndPrintContract(user, contracts.first, style, settings));
                } else {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aucun contrat trouvé")));
                }
              },
            ),
            ListTile(
              leading: const Icon(FluentIcons.money_24_regular, color: Colors.green),
              title: const Text("Dernier Bulletin de Paie"),
              onTap: () async {
                final payrolls = await ref.read(hrRepositoryProvider).getPayrollsForUser(user.id);
                if (payrolls.isNotEmpty) {
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _showStyleSelector(context, (style) => HrPdfService().generateAndPrintPayroll(user, payrolls.first, style, settings));
                } else {
                  if (!context.mounted) return;
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Demande envoyée')),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(FluentIcons.hat_graduation_24_regular, color: Colors.blue),
              title: const Text("Attestation Pro."),
              onTap: () async {
                final contracts = await ref.read(hrRepositoryProvider).getContractsForUser(user.id);
                final lastContract = contracts.isNotEmpty ? contracts.first : null;
                if (!context.mounted) return;
                Navigator.pop(context);
                _showStyleSelector(context, (style) => HrPdfService().generateAndPrintProfessionalAttestation(user, lastContract, style, settings));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContractsTab() {
    final c = DashColors.of(context);
    final contractsAsync = ref.watch(allContractsProvider);
    
    return contractsAsync.when(
      data: (contracts) => SectionCard(
        title: "Liste des Contrats",
        subtitle: "${contracts.length} contrats enregistrés",
        action: IconButton(
          icon: Icon(FluentIcons.add_24_regular, color: c.blue),
          onPressed: () {
            showDialog(context: context, builder: (_) => const ContractFormDialog());
          },
        ),
        child: contracts.isEmpty
            ? Padding(padding: const EdgeInsets.all(32), child: Center(child: Text("Aucun contrat", style: TextStyle(color: c.textSecondary))))
            : Column(
                children: contracts.map((con) => _buildContractItem(con, c)).toList(),
              ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text("Erreur: $e")),
    );
  }

  Widget _buildContractItem(EmployeeContract con, DashColors c) {
    final settings = ref.watch(shopSettingsProvider).value ?? const ShopSettings();
    final users = ref.watch(userListProvider).value ?? [];
    final userName = users.where((u) => u.id == con.userId).firstOrNull?.fullName ?? "Employé inconnu";
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: c.blue.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(FluentIcons.document_text_24_regular, color: c.blue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userName, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                Text("${con.position ?? 'Poste non défini'} • ${con.contractTypeLabel}", style: TextStyle(color: c.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(FluentIcons.print_20_regular, size: 18, color: c.blue),
            onPressed: () async {
               final users = await ref.read(userListProvider.future);
               final user = users.firstWhere((u) => u.id == con.userId);
               if (!mounted) return;
               _showStyleSelector(context, (style) => HrPdfService().generateAndPrintContract(user, con, style, settings));
            },
            tooltip: "Imprimer ce contrat",
          ),
          StatusBadge(
            text: con.status.name.toUpperCase(),
            color: con.status == ContractStatus.active ? c.emerald : c.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollTab() {
    final c = DashColors.of(context);
    final payrollsAsync = ref.watch(allPayrollsProvider);
    
    return payrollsAsync.when(
      data: (payrolls) => SectionCard(
        title: "Historique des Paies",
        subtitle: "Derniers bulletins générés",
        action: IconButton(
          icon: Icon(FluentIcons.add_24_regular, color: c.emerald),
          onPressed: () => showDialog(context: context, builder: (_) => const PayrollFormDialog()),
        ),
        child: payrolls.isEmpty
            ? Padding(padding: const EdgeInsets.all(32), child: Center(child: Text("Aucun bulletin", style: TextStyle(color: c.textSecondary))))
            : Column(
                children: payrolls.map((p) => _buildPayrollItem(p, c)).toList(),
              ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text("Erreur: $e")),
    );
  }

  Widget _buildPayrollItem(Payroll p, DashColors c) {
    final settings = ref.watch(shopSettingsProvider).value ?? const ShopSettings();
    final users = ref.watch(userListProvider).value ?? [];
    final userName = users.where((u) => u.id == p.userId).firstOrNull?.fullName ?? "Employé inconnu";
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: c.emerald.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(FluentIcons.money_24_regular, color: c.emerald, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userName, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                Text("Bulletin ${p.periodLabel} • Payé le ${p.paymentDate != null ? DateFormatter.formatShortYear(p.paymentDate!) : 'N/A'}", style: TextStyle(color: c.textSecondary, fontSize: 12)),
                if (p.extraLines.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 8,
                      children: p.extraLines.take(3).map((line) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (line.isAddition ? c.emerald : c.rose).withValues(alpha: 0.1), 
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "${line.isAddition ? '+' : '-'}${ref.fmt(line.amount)} (${line.label})", 
                          style: TextStyle(
                            color: line.isAddition ? c.emerald : c.rose, 
                            fontSize: 9, 
                            fontWeight: FontWeight.w600
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
              ],
            ),
          ),
          Text(ref.fmt(p.netSalary), style: TextStyle(color: c.emerald, fontWeight: FontWeight.bold)),
          IconButton(
            icon: Icon(FluentIcons.print_20_regular, size: 18, color: c.emerald),
            onPressed: () async {
               final users = await ref.read(userListProvider.future);
               final user = users.firstWhere((u) => u.id == p.userId);
               if (!mounted) return;
               _showStyleSelector(context, (style) => HrPdfService().generateAndPrintPayroll(user, p, style, settings));
            },
            tooltip: "Imprimer ce bulletin",
          ),
        ],
      ),
    );
  }

  Widget _buildLeavesTab() {
    final c = DashColors.of(context);
    final leavesAsync = ref.watch(allLeavesProvider);
    return leavesAsync.when(
      data: (leaves) => SectionCard(
        title: "Demandes de Congés",
        subtitle: "${leaves.length} demandes au total",
        action: IconButton(
          icon: Icon(FluentIcons.add_24_regular, color: c.amber),
          onPressed: () => showDialog(context: context, builder: (_) => const LeaveFormDialog()),
        ),
        child: leaves.isEmpty
            ? Padding(padding: const EdgeInsets.all(32), child: Center(child: Text("Aucune demande", style: TextStyle(color: c.textSecondary))))
            : Column(
                children: leaves.map((l) => _buildLeaveItem(l, c)).toList(),
              ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text("Erreur: $e")),
    );
  }

  Widget _buildLeaveItem(LeaveRequest l, DashColors c) {
    final isSick = l.leaveType == LeaveType.sick;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: (isSick ? c.rose : c.amber).withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(isSick ? FluentIcons.doctor_24_regular : FluentIcons.calendar_24_regular, color: isSick ? c.rose : c.amber, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.leaveTypeLabel, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                Text("${l.durationInDays} jours (du ${DateFormatter.formatShortDate(l.startDate)} au ${DateFormatter.formatShortDate(l.endDate)})", style: TextStyle(color: c.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(FluentIcons.edit_20_regular, size: 18),
                onPressed: () => showDialog(context: context, builder: (_) => LeaveFormDialog(userId: l.userId, request: l)),
                tooltip: "Modifier la demande",
              ),
              StatusBadge(
                text: l.status.name.toUpperCase(),
                color: l.status == LeaveStatus.approved ? c.emerald : (l.status == LeaveStatus.pending ? c.amber : c.rose),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmployeeDetailSheet extends ConsumerWidget {
  final User user;
  const _EmployeeDetailSheet({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final contractsAsync = ref.watch(userContractsProvider(user.id));
    final payrollsAsync = ref.watch(userPayrollsProvider(user.id));
    final settingsAsync = ref.watch(shopSettingsProvider);
    final settings = settingsAsync.value ?? const ShopSettings();

    return Container(
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(user.fullName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                   if (user.fullName != user.username) 
                     Text("(${user.username})", style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                    Text(user.role.name.toUpperCase(), style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(FluentIcons.dismiss_24_regular)),
            ],
          ),
          const Divider(height: 32),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoSection(context, "Coordonnées", FluentIcons.contact_card_24_regular, [
                    _infoRow("Email", user.email ?? "N/A"),
                    _infoRow("Téléphone", user.phone ?? "N/A"),
                    _infoRow("Adresse", user.address ?? "N/A"),
                  ]),
                  const SizedBox(height: 24),
                  _actionSection(context, "Actions Rapides", [
                    _actionButton(context, "Contrat", FluentIcons.document_add_24_regular, Colors.blue, 
                        () => showDialog(context: context, builder: (context) => ContractFormDialog(userId: user.id))),
                    _actionButton(context, "Paie", FluentIcons.money_24_regular, Colors.green, () {
                      final activeContract = contractsAsync.value?.where((c) => c.status == ContractStatus.active).firstOrNull;
                      showDialog(context: context, builder: (context) => PayrollFormDialog(userId: user.id, activeContract: activeContract));
                    }),
                    _actionButton(context, "Congé", FluentIcons.calendar_24_regular, Colors.orange, 
                        () => showDialog(context: context, builder: (context) => LeaveFormDialog(userId: user.id))),
                    if (!user.isAdmin && user.isActive && !ref.watch(authServiceProvider.notifier).isImpersonating)
                      _actionButton(context, "Incarner", FluentIcons.incognito_24_regular, Colors.orange, () {
                        EnterpriseWidgets.showPremiumConfirmDialog(
                          context,
                          title: "Incarner l'utilisateur ?",
                          message: "Voulez-vous agir en tant que ${user.fullName} ?",
                          confirmText: "Incarner",
                          onConfirm: () {
                             ref.read(authServiceProvider.notifier).impersonate(user);
                             Navigator.pop(context); // Close sheet
                          },
                        );
                      }),
                  ]),
                  const SizedBox(height: 24),
                  _listSection(context, "Contrats", FluentIcons.document_text_24_regular, contractsAsync.when(
                    data: (contracts) => contracts.isEmpty ? const Text("Aucun contrat") : Column(children: contracts.map((c) => _contractTile(context, c, settings)).toList()),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, s) => Text("Erreur: $e"),
                  )),
                  const SizedBox(height: 16),
                  _listSection(context, "Bulletins de Paie", FluentIcons.money_24_regular, payrollsAsync.when(
                    data: (payrolls) => payrolls.isEmpty ? const Text("Aucun bulletin") : Column(children: payrolls.take(3).map((p) => _payrollTile(context, p, settings, ref)).toList()),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, s) => Text("Erreur: $e"),
                  )),
                  const SizedBox(height: 32),
                  Center(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => showDialog(context: context, builder: (context) => UserFormDialog(user: user)),
                          icon: const Icon(FluentIcons.edit_24_regular),
                          label: const Text("Modifier Profil"),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _printProfessionalAttestation(context, user, settings, ref),
                          icon: const Icon(FluentIcons.hat_graduation_24_regular),
                          label: const Text("Attestation Pro."),
                        ),
                        if (user.id != 'sysadmin' && user.id != ref.read(authServiceProvider).value?.id)
                          OutlinedButton.icon(
                            onPressed: () => _confirmDeleteAccount(context, ref, user),
                            icon: const Icon(FluentIcons.delete_24_regular, color: Colors.red),
                            label: const Text("Supprimer Compte", style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
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
            Navigator.pop(context); // Close detail sheet
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

  Widget _infoSection(BuildContext context, String title, IconData icon, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 20, color: Colors.blue),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
      const SizedBox(height: 12),
      ...children,
    ]);
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
      ]),
    );
  }

  Widget _actionSection(BuildContext context, String title, List<Widget> buttons) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: buttons),
    ]);
  }

  Widget _actionButton(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: (MediaQuery.of(context).size.width - 64) / 3,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Column(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  Widget _listSection(BuildContext context, String title, IconData icon, Widget content) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
      ]),
      const SizedBox(height: 8),
      content,
    ]);
  }

  Widget _contractTile(BuildContext context, EmployeeContract c, ShopSettings settings) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(c.position ?? "Poste NC"),
        subtitle: Text(c.contractTypeLabel),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(FluentIcons.edit_24_regular, size: 20),
              onPressed: () => showDialog(context: context, builder: (_) => ContractFormDialog(userId: user.id, contract: c)),
              tooltip: "Modifier le contrat",
            ),
            IconButton(
              icon: const Icon(FluentIcons.print_24_regular, size: 20),
              onPressed: () {
                final state = context.findAncestorStateOfType<_HrScreenState>();
                if (state != null) {
                  state._showStyleSelector(context, (style) => HrPdfService().generateAndPrintContract(user, c, style, settings));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _payrollTile(BuildContext context, Payroll p, ShopSettings settings, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(p.periodLabel),
        subtitle: Text(ref.fmt(p.netSalary)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(FluentIcons.edit_24_regular, size: 20),
              onPressed: () => showDialog(context: context, builder: (_) => PayrollFormDialog(userId: user.id, payroll: p)),
              tooltip: "Modifier le bulletin",
            ),
            IconButton(
              icon: const Icon(FluentIcons.print_24_regular, size: 20),
              onPressed: () {
                final state = context.findAncestorStateOfType<_HrScreenState>();
                if (state != null) {
                  state._showStyleSelector(context, (style) => HrPdfService().generateAndPrintPayroll(user, p, style, settings));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _printProfessionalAttestation(BuildContext context, User user, ShopSettings settings, WidgetRef ref) async {
    final state = context.findAncestorStateOfType<_HrScreenState>();
    if (state != null) {
      final contracts = await ref.read(hrRepositoryProvider).getContractsForUser(user.id);
      final lastContract = contracts.isNotEmpty ? contracts.first : null;
      if (!context.mounted) return;
      state._showStyleSelector(context, (style) => HrPdfService().generateAndPrintProfessionalAttestation(user, lastContract, style, settings));
    }
  }
}

class _ModernEmployeeCard extends ConsumerWidget {
  final User user;
  final VoidCallback? onTap;
  const _ModernEmployeeCard({required this.user, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = DashColors.of(context);
    final isSysadmin = user.id == 'sysadmin';
    final (roleLabel, roleColor) = _getRoleStyle(user.role);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Edit Overlay Button
          Positioned(
            top: 8,
            right: 28,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!user.isAdmin && user.isActive && !ref.watch(authServiceProvider.notifier).isImpersonating)
                  IconButton(
                    icon: const Icon(FluentIcons.incognito_20_regular),
                    color: Colors.orange,
                    iconSize: 18,
                    tooltip: "Incarner",
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      EnterpriseWidgets.showPremiumConfirmDialog(
                        context,
                        title: "Incarner l'utilisateur ?",
                        message: "Voulez-vous agir en tant que ${user.fullName} ?\n\nVous pourrez revenir à votre compte admin via le bandeau en haut.",
                        confirmText: "Incarner",
                        onConfirm: () => ref.read(authServiceProvider.notifier).impersonate(user),
                      );
                    },
                  ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(FluentIcons.edit_20_regular, size: 18, color: c.textSecondary),
                  onPressed: () => showDialog(context: context, builder: (_) => UserFormDialog(user: user)),
                  tooltip: "Modifier le profil",
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [roleColor.withValues(alpha: 0.2), roleColor.withValues(alpha: 0.1)]),
                        shape: BoxShape.circle,
                        border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                      ),
                      child: Icon(isSysadmin ? FluentIcons.shield_24_regular : FluentIcons.person_24_regular, color: roleColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName, 
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: c.textPrimary), 
                            maxLines: 1, 
                            overflow: TextOverflow.ellipsis
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                            child: Text(roleLabel.toUpperCase(), style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ),
                    // Status LED & Admin Protection
                    Column(
                      children: [
                        _StatusIndicator(isActive: user.isActive),
                        if (isSysadmin) ...[
                          const SizedBox(height: 8),
                          Tooltip(
                            message: "Administrateur Principal Protégé",
                            child: Icon(FluentIcons.shield_24_filled, color: roleColor, size: 16),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                if (isSysadmin)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: roleColor.withValues(alpha: 0.2)),
                      ),
                      child: Center(
                        child: Text(
                          "SYSTÈME PROTÉGÉ",
                          style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                        ),
                      ),
                    ),
                  ),
                const Divider(height: 12),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    _ActionButton(icon: FluentIcons.person_info_24_regular, label: "Détails", color: c.blue, onPressed: () {
                      final state = context.findAncestorStateOfType<_HrScreenState>();
                      if (state != null) state._showEmployeeDetail(user);
                    }),
                    _ActionButton(icon: FluentIcons.document_edit_24_regular, label: "Contrat", color: c.amber, onPressed: () => showDialog(context: context, builder: (_) => ContractFormDialog(userId: user.id))),
                    _ActionButton(icon: FluentIcons.money_hand_24_regular, label: "Payer", color: c.emerald, onPressed: () => showDialog(context: context, builder: (_) => PayrollFormDialog(userId: user.id))),
                    _ActionButton(icon: FluentIcons.print_24_regular, label: "Imprimer", color: c.violet, onPressed: () {
                      final state = context.findAncestorStateOfType<_HrScreenState>();
                      if (state != null) {
                        final settings = ref.read(shopSettingsProvider).value ?? const ShopSettings();
                        state._showPrintActions(context, user, settings);
                      }
                    }),
                  ],
                ),
              ],
            ),
          ),
          Positioned(top: 0, left: 20, right: 20, child: Container(height: 2, color: roleColor.withValues(alpha: 0.5))),
        ],
        ),
      ),
    );
  }

}

class _EmployeeListRow extends ConsumerWidget {
  final User user;
  final VoidCallback onTap;
  const _EmployeeListRow({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = DashColors.of(context);
    final (roleLabel, roleColor) = _getRoleStyle(user.role);
    final isSysadmin = user.id == 'sysadmin';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
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
                child: Icon(isSysadmin ? FluentIcons.shield_20_regular : FluentIcons.person_20_regular, color: roleColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName, style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary, fontSize: 14)),
                    Text("@${user.username}", style: TextStyle(color: c.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(roleLabel.toUpperCase(), style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ),
              const SizedBox(width: 16),
              _StatusIndicator(isActive: user.isActive),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(FluentIcons.edit_20_regular, size: 18, color: c.textSecondary),
                onPressed: () => showDialog(context: context, builder: (_) => UserFormDialog(user: user)),
                tooltip: "Modifier le profil",
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Global role style helper used by both Card and ListRow
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    );
  }
}
