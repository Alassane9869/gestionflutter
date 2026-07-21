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
import 'package:danaya_plus/features/hr/presentation/widgets/hr_doc_viewer.dart';
import 'package:danaya_plus/features/hr/presentation/widgets/contract_form_dialog.dart';
import 'package:danaya_plus/features/hr/presentation/widgets/payroll_form_dialog.dart';
import 'package:danaya_plus/features/hr/presentation/widgets/leave_form_dialog.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/features/auth/providers/user_providers.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/features/inventory/presentation/widgets/dashboard_widgets.dart';
import 'package:danaya_plus/features/hr/presentation/widgets/hr_stats_header.dart';

// Import parts
part 'widgets/tabs/hr_employees_tab.dart';
part 'widgets/tabs/hr_contracts_tab.dart';
part 'widgets/tabs/hr_payroll_tab.dart';
part 'widgets/tabs/hr_leaves_tab.dart';
part 'widgets/tabs/hr_self_service.dart';
part 'widgets/tabs/hr_detail_dialog.dart';

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
            HrStatsHeader(stats: stats, currentTabIndex: _tabController.index),
            const SizedBox(height: 16),
            Expanded(child: _buildMainWorkspace(theme, c)),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Erreur stats: $e", style: TextStyle(color: c.rose))),
      ),
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

  void _showEmployeeDetail(User user) {
    showDialog(
      context: context,
      builder: (context) => _EmployeeDetailDialog(user: user),
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
