import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:danaya_plus/core/widgets/premium_settings_widgets.dart';
import '../../../inventory/presentation/widgets/dashboard_widgets.dart';

class AuditSettingsSection extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  final VoidCallback onRefresh;

  const AuditSettingsSection({
    super.key,
    required this.logs,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

    return Column(
      children: [
        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.history_24_filled,
          title: "Journal d'Audit Système",
          subtitle: "Historique des 100 dernières actions critiques effectuées",
          color: c.rose,
          trailing: InkWell(
            onTap: onRefresh,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: c.rose.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                   Icon(FluentIcons.arrow_sync_16_regular, color: c.rose, size: 18),
                   const SizedBox(width: 8),
                   Text("Actualiser", style: TextStyle(color: c.rose, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        PremiumSettingsWidgets.buildCard(
          context,
          child: logs.isEmpty
              ? _buildEmptyState(c)
              : Container(
                  constraints: const BoxConstraints(maxHeight: 500),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: logs.length,
                    separatorBuilder: (context, index) => Divider(color: c.border.withValues(alpha: 0.3), height: 1),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return _buildLogTile(context, log, c);
                    },
                  ),
                ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildEmptyState(DashColors c) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(FluentIcons.history_24_regular, size: 48, color: c.textMuted.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              "Aucun journal d'activité pour le moment",
              style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogTile(BuildContext context, Map<String, dynamic> log, DashColors c) {
    final date = DateTime.parse(log['date']);
    final timeStr = DateFormatter.formatTimeSeconds(date);
    final dateStr = DateFormatter.formatDate(date);
    
    final type = (log['action_type'] as String?)?.toUpperCase() ?? 'INFO';
    final description = log['description'] ?? 'Pas de détails';
    final username = log['username'] as String? ?? 'Système';
    
    IconData icon;
    Color color;

    switch (type) {
      case 'SALE':
      case 'TRANSACTION':
      case 'PAYMENT':
        icon = FluentIcons.receipt_20_regular;
        color = c.emerald;
        break;
      case 'DELETE':
      case 'PRODUCT_DELETE':
      case 'SALE_DELETE':
        icon = FluentIcons.delete_20_regular;
        color = c.rose;
        break;
      case 'UPDATE':
      case 'CREATE':
      case 'PRODUCT_CREATE':
      case 'PRODUCT_UPDATE':
      case 'SETTINGS_UPDATE':
        icon = FluentIcons.edit_20_regular;
        color = c.blue;
        break;
      case 'LOGIN':
      case 'LOGOUT':
        icon = FluentIcons.person_board_20_regular;
        color = c.violet;
        break;
      case 'SECURITY_ALERT':
      case 'LOGIN_ERROR':
        icon = FluentIcons.shield_error_20_filled;
        color = c.rose;
        break;
      case 'VIEW_REPORTS':
      case 'VIEW_SETTINGS':
        icon = FluentIcons.eye_20_regular;
        color = c.amber;
        break;
      default:
        icon = FluentIcons.info_20_regular;
        color = c.textSecondary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumSettingsWidgets.buildIconBadge(icon: icon, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
                      ),
                    ),
                    Text(
                      "$dateStr à $timeStr",
                      style: TextStyle(color: c.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(FluentIcons.person_12_regular, size: 14, color: c.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      "Action effectuée par : ",
                      style: TextStyle(color: c.textSecondary, fontSize: 12),
                    ),
                    Text(
                      username,
                      style: TextStyle(color: c.textPrimary, fontSize: 12, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
