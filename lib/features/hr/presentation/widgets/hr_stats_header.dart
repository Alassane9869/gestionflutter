import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/inventory/presentation/widgets/dashboard_widgets.dart';

import 'package:danaya_plus/features/hr/domain/models/hr_stats.dart';
import 'package:danaya_plus/core/extensions/ref_extensions.dart';
import 'package:danaya_plus/features/auth/presentation/user_form_dialog.dart';
import 'package:danaya_plus/features/hr/presentation/widgets/contract_form_dialog.dart';
import 'package:danaya_plus/features/hr/presentation/widgets/payroll_form_dialog.dart';
import 'package:danaya_plus/features/hr/presentation/widgets/leave_form_dialog.dart';
import 'package:danaya_plus/features/hr/presentation/widgets/mass_payroll_dialog.dart';
import 'package:danaya_plus/features/hr/presentation/templates_manager_screen.dart';

class HrStatsHeader extends ConsumerWidget {
  final HrStats stats;
  final int currentTabIndex;

  const HrStatsHeader({
    super.key,
    required this.stats,
    required this.currentTabIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = DashColors.of(context);
    
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
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TemplatesManagerScreen()));
                },
                icon: const Icon(FluentIcons.document_toolbox_24_regular, size: 16),
                label: const Text("Modèles", style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () {
                  if (currentTabIndex == 0) {
                    showDialog(context: context, builder: (_) => const UserFormDialog());
                  } else if (currentTabIndex == 1) {
                    showDialog(context: context, builder: (_) => const ContractFormDialog());
                  } else if (currentTabIndex == 2) {
                    showDialog(context: context, builder: (_) => const PayrollFormDialog());
                  } else {
                    showDialog(context: context, builder: (_) => const LeaveFormDialog());
                  }
                },
                icon: Icon(
                  currentTabIndex == 0 ? FluentIcons.person_add_24_regular :
                  currentTabIndex == 1 ? FluentIcons.document_add_24_regular :
                  currentTabIndex == 2 ? FluentIcons.money_hand_24_regular :
                  FluentIcons.calendar_add_24_regular,
                  size: 16,
                ),
                label: Text(
                  currentTabIndex == 0 ? "Ajouter" :
                  currentTabIndex == 1 ? "Contrat" :
                  currentTabIndex == 2 ? "Bulletin" :
                  "Congé",
                  style: const TextStyle(fontSize: 13),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              if (currentTabIndex == 2) ...[
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const MassPayrollDialog(),
                    );
                  },
                  icon: const Icon(FluentIcons.layer_24_filled, size: 16),
                  label: const Text("Génération de Masse", style: TextStyle(fontSize: 13)),
                  style: FilledButton.styleFrom(
                    backgroundColor: DashColors.of(context).emerald,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
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
}
