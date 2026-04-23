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
  final VoidCallback onSaveDebounced;

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
    required this.onSaveDebounced,
  });

  @override
  State<DatabaseSettingsSection> createState() => _DatabaseSettingsSectionState();
}

class _DatabaseSettingsSectionState extends State<DatabaseSettingsSection> {
  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SECTION 1 : ÉTAT DU SYSTÈME
        if (widget.dbStats.isNotEmpty) ...[
          PremiumSettingsWidgets.buildSectionHeader(
            context,
            icon: FluentIcons.database_24_filled,
            title: "État du Système de Données",
            subtitle: "Statistiques et diagnostic d'intégrité",
            color: c.blue,
          ),
          const SizedBox(height: 12),
          _buildHealthStatus(context, c),
          const SizedBox(height: 24),
        ],

        // SECTION 2 : GESTION DES BACKUPS
        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.save_24_filled,
          title: "Sauvegardes Locales",
          subtitle: "Archivage et restauration de la base de données",
          color: c.amber,
        ),
        const SizedBox(height: 12),
        _buildBackupControls(context, c),
        const SizedBox(height: 24),

        // SECTION 3 : HISTORIQUE
        if (widget.autoBackups.isNotEmpty) ...[
          PremiumSettingsWidgets.buildSectionHeader(
            context,
            icon: FluentIcons.history_24_filled,
            title: "Archives Récentes",
            subtitle: "Dernières sauvegardes générées sur ce poste",
            color: c.violet,
          ),
          const SizedBox(height: 12),
          _buildHistoryList(c),
          const SizedBox(height: 24),
        ],

        // SECTION 4 : MAINTENANCE
        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.wrench_24_filled,
          title: "Utilitaires de Maintenance",
          subtitle: "Optimisation et nettoyage technique",
          color: c.rose,
        ),
        const SizedBox(height: 12),
        _buildMaintenanceCard(context, c),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildHealthStatus(BuildContext context, DashColors c) {
    return PremiumSettingsWidgets.buildCard(
      context,
      child: Column(
        children: [
          Row(
            children: [
              PremiumSettingsWidgets.buildIconBadge(icon: FluentIcons.shield_checkmark_24_filled, color: c.blue),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("DIAGNOSTIC SQL", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: c.textPrimary)),
                    Text("Le moteur de base de données est opérationnel", style: TextStyle(fontSize: 12, color: c.textMuted)),
                  ],
                ),
              ),
              PremiumSettingsWidgets.buildStatusDot(active: true, activeLabel: "OPTIMISÉ", inactiveLabel: "SCANNÉ"),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: c.border.withValues(alpha: 0.5)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(c, "Produits", widget.dbStats['products']?.toString() ?? "0", FluentIcons.box_20_regular, c.blue),
              _buildStatItem(c, "Transactions", widget.dbStats['sales']?.toString() ?? "0", FluentIcons.receipt_20_regular, c.emerald),
              _buildStatItem(c, "Logs Audit", widget.dbStats['movements']?.toString() ?? "0", FluentIcons.history_20_regular, c.violet),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(DashColors c, String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: c.textPrimary)),
        Text(label.toUpperCase(), style: TextStyle(fontSize: 10, color: c.textMuted, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildBackupControls(BuildContext context, DashColors c) {
    return PremiumSettingsWidgets.buildCard(
      context,
      child: Column(
        children: [
          PremiumSettingsWidgets.buildCompactSwitch(
            context,
            title: "Sauvegarde automatique à la fermeture",
            subtitle: "Sécurité maximale pour éviter toute perte de données",
            value: widget.autoBackupEnabled,
            onChanged: widget.onAutoBackupEnabledChanged,
            activeThumbColor: c.amber,
            icon: FluentIcons.flash_16_filled,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: PremiumSettingsWidgets.buildGradientBtn(
                  onPressed: widget.onBackupDatabase,
                  icon: FluentIcons.save_16_filled,
                  label: "GÉNÉRER UN BACKUP SQL",
                  colors: [c.amber, Colors.orange.shade800],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PremiumSettingsWidgets.buildGradientBtn(
                  onPressed: widget.onRestoreDatabase,
                  icon: FluentIcons.folder_open_16_filled,
                  label: "RESTAURER UNE BASE",
                  colors: [c.rose, Colors.red.shade700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(DashColors c) {
    return PremiumSettingsWidgets.buildCard(
      context,
      child: Column(
        children: widget.autoBackups.take(5).map((file) {
          final stats = file.statSync();
          final name = file.path.split(Platform.pathSeparator).last;
          return ListTile(
            dense: true,
            leading: Icon(FluentIcons.archive_20_regular, color: c.violet),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text("${DateFormatter.formatDateTime(stats.changed)} • ${(stats.size / 1024 / 1024).toStringAsFixed(2)} Mo"),
            trailing: IconButton(
              icon: Icon(FluentIcons.arrow_upload_16_filled, color: c.blue),
              onPressed: () => widget.onRestoreSpecificBackup(file),
              tooltip: "Restaurer cette version",
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMaintenanceCard(BuildContext context, DashColors c) {
    return PremiumSettingsWidgets.buildCard(
      context,
      child: Column(
        children: [
          _buildMaintenanceItem(
            c,
            icon: FluentIcons.image_shadow_20_regular,
            title: "Nettoyage de la photothèque",
            subtitle: "Supprimer les images orphelines (gain d'espace)",
            onTap: widget.onCleanupImages,
            color: c.rose,
          ),
          Divider(color: c.border.withValues(alpha: 0.3), height: 1),
          _buildMaintenanceItem(
            c,
            icon: FluentIcons.math_formula_20_regular,
            title: "Recalcul des Coûts (CMUP)",
            subtitle: "Synchroniser les marges après import massif",
            onTap: widget.onRecalculateWac,
            color: c.blue,
          ),
          Divider(color: c.border.withValues(alpha: 0.3), height: 1),
          _buildMaintenanceItem(
            c,
            icon: FluentIcons.delete_dismiss_20_regular,
            title: "RAZ de la base de données",
            subtitle: "Effacer tout le contenu (Action irréversible !)",
            onTap: widget.onConfirmResetDb,
            color: Colors.red,
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceItem(DashColors c, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap, required Color color, bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            PremiumSettingsWidgets.buildIconBadge(icon: icon, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: isDestructive ? Colors.red : c.textPrimary)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: c.textMuted)),
                ],
              ),
            ),
            Icon(FluentIcons.chevron_right_12_regular, color: c.textMuted, size: 14),
          ],
        ),
      ),
    );
  }
}
