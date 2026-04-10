
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'dart:io';
import '../../../../core/widgets/premium_settings_widgets.dart';
import '../../../inventory/presentation/widgets/dashboard_widgets.dart';

class DatabaseSettingsSection extends StatefulWidget {
  final Map<String, dynamic> dbStats;
  final bool autoBackupEnabled;
  final ValueChanged<bool> onAutoBackupEnabledChanged;
  final List<FileSystemEntity> autoBackups;
  final VoidCallback onBackupDatabase;
  final VoidCallback onRestoreDatabase;
  final Function(FileSystemEntity) onRestoreSpecificBackup;
  final VoidCallback onConfirmResetDb;
  final VoidCallback onRecalculateWac;
  final VoidCallback onCleanupImages;
  final String? cloudBackupPath;
  final ValueChanged<String?> onCloudBackupPathChanged;
  final VoidCallback onSaveDebounced;
  
  final bool isCompact; // Mode Dashboard Bento

  const DatabaseSettingsSection({
    super.key,
    required this.dbStats,
    required this.autoBackupEnabled,
    required this.onAutoBackupEnabledChanged,
    required this.autoBackups,
    required this.onBackupDatabase,
    required this.onRestoreDatabase,
    required this.onRestoreSpecificBackup,
    required this.onConfirmResetDb,
    required this.onRecalculateWac,
    required this.onCleanupImages,
    required this.cloudBackupPath,
    required this.onCloudBackupPathChanged,
    required this.onSaveDebounced,
    this.isCompact = false,
  });

  @override
  State<DatabaseSettingsSection> createState() => _DatabaseSettingsSectionState();
}

class _DatabaseSettingsSectionState extends State<DatabaseSettingsSection> {
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

    if (widget.isCompact) {
      return _buildCompactDashboard(context, c);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.dbStats.isNotEmpty) ...[
          PremiumSettingsWidgets.buildSectionHeader(
            context,
            icon: FluentIcons.database_24_filled,
            title: "État du Système Local",
            subtitle: "Diagnostic et statistiques de la base de données",
            color: c.blue,
          ),
          const SizedBox(height: 12),
          _buildHealthHeader(context, c),
          const SizedBox(height: 24),
        ],

        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.save_24_filled,
          title: "Contrôle des données",
          subtitle: "Sauvegardes et restaurations",
          color: c.amber,
        ),
        const SizedBox(height: 12),
        PremiumSettingsWidgets.buildCard(
          context,
          child: Column(
            children: [
              PremiumSettingsWidgets.buildCompactSwitch(
                context,
                title: "Auto-Backup à la fermeture",
                subtitle: "Crée une sauvegarde à la fermeture de l'application",
                value: widget.autoBackupEnabled,
                onChanged: widget.onAutoBackupEnabledChanged,
                activeColor: c.amber,
                icon: FluentIcons.archive_16_regular,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: PremiumSettingsWidgets.buildGradientBtn(
                      onPressed: widget.onBackupDatabase,
                      icon: FluentIcons.save_16_filled,
                      label: "BACKUP MANUEL",
                      colors: [c.amber, Colors.orange],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PremiumSettingsWidgets.buildGradientBtn(
                      onPressed: widget.onRestoreDatabase,
                      icon: FluentIcons.arrow_upload_16_filled,
                      label: "RESTAURER",
                      colors: [c.rose, Colors.redAccent],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (widget.autoBackups.isNotEmpty) ...[
          PremiumSettingsWidgets.buildSectionHeader(
            context,
            icon: FluentIcons.history_24_filled,
            title: "Historique récent",
            subtitle: "Dernières sauvegardes locales",
            color: c.violet,
          ),
          const SizedBox(height: 12),
          _buildCompactHistoryList(c),
          const SizedBox(height: 24),
        ],

        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.cloud_sync_24_filled,
          title: "Miroir Cloud",
          subtitle: "Lien de synchronisation externe",
          color: c.emerald,
        ),
        const SizedBox(height: 12),
        PremiumSettingsWidgets.buildCard(
          context,
          child: _buildCompactCloudField(c),
        ),
        const SizedBox(height: 24),

        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.wrench_24_filled,
          title: "Maintenance",
          subtitle: "Outils de nettoyage et réparation",
          color: c.rose,
        ),
        const SizedBox(height: 12),
        PremiumSettingsWidgets.buildCard(
          context,
          child: Column(
            children: [
              InkWell(
                onTap: widget.onCleanupImages,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Row(
                    children: [
                      PremiumSettingsWidgets.buildIconBadge(icon: FluentIcons.delete_16_regular, color: c.rose),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Nettoyage des images orphelines", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: c.textPrimary)),
                            Text("Supprime les images de produits qui n'existent plus pour libérer de l'espace", style: TextStyle(fontSize: 9, color: c.textMuted)),
                          ],
                        ),
                      ),
                      Icon(FluentIcons.chevron_right_16_regular, color: c.textMuted, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  // ======= VERSION ELITE COMPACT (BENTO) =======
  Widget _buildCompactDashboard(BuildContext context, DashColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPIs de Santé Database (Glass Card)
        PremiumSettingsWidgets.buildGlassCard(
          context,
          glowColor: c.blue,
          child: Column(
            children: [
              Row(
                children: [
                  PremiumSettingsWidgets.buildIconBadge(icon: FluentIcons.database_20_filled, color: c.blue),
                  const SizedBox(width: 12),
                  const Text("SANTÉ DU SYSTÈME", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.0)),
                  const Spacer(),
                  PremiumSettingsWidgets.buildStatusDot(active: true, activeLabel: "OPTIMISÉ", inactiveLabel: "ERREUR"),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat(c, "Articles", widget.dbStats['products']?.toString() ?? "0", FluentIcons.box_20_regular, c.blue),
                  _buildVerticalDivider(c),
                  _buildMiniStat(c, "Ventes", widget.dbStats['sales']?.toString() ?? "0", FluentIcons.receipt_24_regular, c.emerald),
                  _buildVerticalDivider(c),
                  _buildMiniStat(c, "Audit", widget.dbStats['movements']?.toString() ?? "0", FluentIcons.history_24_regular, c.violet),
                ],
              ),
              const SizedBox(height: 20),
              _buildCompactCloudField(c),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Actions de Backup Premium
        Row(
          children: [
            Expanded(
              child: PremiumSettingsWidgets.buildGradientBtn(
                onPressed: widget.onBackupDatabase,
                icon: FluentIcons.save_16_filled,
                label: "BACKUP LOCAL",
                colors: [c.blue, const Color(0xFF4A90E2)],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PremiumSettingsWidgets.buildGradientBtn(
                onPressed: widget.onRestoreDatabase,
                icon: FluentIcons.arrow_upload_16_filled,
                label: "RESTAURER",
                colors: [c.amber, Colors.orange],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Footer Actions (Historique uniquement)
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
             InkWell(
                onTap: () => setState(() => _showHistory = !_showHistory),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    children: [
                      Icon(FluentIcons.history_16_regular, size: 16, color: c.blue),
                      const SizedBox(width: 8),
                      Text("Voir l'Historique des sauvegardes (${widget.autoBackups.length})", style: TextStyle(fontSize: 10, color: c.textMuted, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
          ],
        ),

        if (_showHistory && widget.autoBackups.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildCompactHistoryList(c).animate().slideY(begin: 0.1, end: 0).fadeIn(),
        ],
      ],
    );
  }

  Widget _buildMiniStat(DashColors c, String label, String val, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color.withValues(alpha: 0.7), size: 16),
        const SizedBox(height: 4),
        Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: c.textPrimary, letterSpacing: -0.5)),
        Text(label.toUpperCase(), style: TextStyle(fontSize: 8, color: c.textMuted, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildVerticalDivider(DashColors c) {
    return Container(width: 1, height: 30, color: c.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05));
  }

  Widget _buildCompactCloudField(DashColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.cloud_sync_20_filled, color: c.emerald, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("MIROIR DE SYNCHRONISATION", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Colors.grey)),
                Text(
                  widget.cloudBackupPath ?? "Configuration requise",
                  style: TextStyle(fontSize: 10, color: widget.cloudBackupPath != null ? c.textPrimary : c.amber, fontWeight: FontWeight.w700, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => widget.onCloudBackupPathChanged(widget.cloudBackupPath),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: c.emerald.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(FluentIcons.folder_open_20_regular, color: c.emerald, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactHistoryList(DashColors c) {
    return PremiumSettingsWidgets.buildCard(
      context,
      child: Column(
        children: widget.autoBackups.take(5).map((file) {
          final stats = file.statSync();
          final name = file.path.split(Platform.pathSeparator).last;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              dense: true,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              leading: PremiumSettingsWidgets.buildIconBadge(icon: FluentIcons.archive_16_regular, color: c.violet),
              title: Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
              subtitle: Text("${DateFormatter.formatDateTime(stats.changed)} • ${(stats.size / 1024 / 1024).toStringAsFixed(2)} MB", style: TextStyle(fontSize: 9, color: c.textSecondary)),
              trailing: IconButton(
                icon: Icon(FluentIcons.arrow_upload_16_regular, size: 16, color: c.blue), 
                onPressed: () => widget.onRestoreSpecificBackup(file),
                tooltip: "Restaurer cette sauvegarde",
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHealthHeader(BuildContext context, DashColors c) {
    return PremiumSettingsWidgets.buildCard(
      context,
      child: Column(
        children: [
          Row(
            children: [
              PremiumSettingsWidgets.buildIconBadge(icon: FluentIcons.database_search_24_filled, color: c.blue),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    Text("DIAGNOSTIC COMPLET", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: c.textMuted, letterSpacing: 0.5)), 
                    const SizedBox(height: 2),
                    Text("Votre base de données est stable.", style: TextStyle(fontSize: 12, color: c.textPrimary, fontWeight: FontWeight.bold)),
                  ]
                )
              ),
              PremiumSettingsWidgets.buildStatusDot(active: true, activeLabel: "Connecté", inactiveLabel: ""),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildMiniStat(c, "Articles", widget.dbStats['products']?.toString() ?? "0", FluentIcons.box_20_regular, c.blue),
              _buildVerticalDivider(c),
              _buildMiniStat(c, "Ventes", widget.dbStats['sales']?.toString() ?? "0", FluentIcons.receipt_20_regular, c.emerald),
              _buildVerticalDivider(c),
              _buildMiniStat(c, "Audit", widget.dbStats['movements']?.toString() ?? "0", FluentIcons.history_20_regular, c.violet),
            ],
          ),
        ],
      ),
    );
  }
}
