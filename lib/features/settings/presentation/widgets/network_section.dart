// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/widgets/premium_settings_widgets.dart';
import 'package:danaya_plus/core/network/network_service.dart';
import 'package:danaya_plus/core/network/server_service.dart';
import 'package:danaya_plus/features/inventory/presentation/widgets/dashboard_widgets.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/core/network/client_sync_service.dart';
import 'package:danaya_plus/core/network/cloud_sync_service.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';

final pendingSyncCountProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    final db = await ref.watch(databaseServiceProvider).database;
    int total = 0;
    final tables = [
      'sales', 'purchase_orders', 'stock_movements', 'client_payments',
      'financial_transactions', 'cash_sessions', 'products', 'clients', 'suppliers'
    ];
    for (final table in tables) {
      try {
        final res = await db.rawQuery('SELECT COUNT(*) FROM $table WHERE is_synced = 0');
        if (res.isNotEmpty) {
          final count = res.first.values.first as int? ?? 0;
          total += count;
        }
      } catch (_) {}
    }
    return total;
  } catch (_) {
    return 0;
  }
});

class NetworkSettingsSection extends ConsumerWidget {
  final NetworkMode networkMode;
  final Function(NetworkMode?) onModeChanged;
  final TextEditingController serverIpCtrl;
  final TextEditingController serverPortCtrl;
  final String? syncKey;
  final TextEditingController cloudSyncKeyCtrl;
  final TextEditingController cloudEndpointCtrl;
  final VoidCallback onSaveDebounced;

  const NetworkSettingsSection({
    super.key,
    required this.networkMode,
    required this.onModeChanged,
    required this.serverIpCtrl,
    required this.serverPortCtrl,
    this.syncKey,
    required this.cloudSyncKeyCtrl,
    required this.cloudEndpointCtrl,
    required this.onSaveDebounced,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = DashColors.of(context);
    final ipAsync = ref.watch(localIpProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.network_check_24_filled,
          title: "Architecture Réseau",
          subtitle: "Topologie : Définissez le rôle de poste sur le réseau",
          color: c.blue,
        ),
        const SizedBox(height: 12),
        // Mode Réseau
        Column(
          children: [
            _buildEliteModeBtn(context, c, "MONO-POSTE (SOLO)", "Base de données 100% locale isolée, sans partage", NetworkMode.solo, FluentIcons.person_16_regular),
            _buildEliteModeBtn(context, c, "POSTE MAÎTRE (SERVEUR)", "Héberge la base de données pour d'autres postes", NetworkMode.server, FluentIcons.server_16_regular),
            _buildEliteModeBtn(context, c, "POSTE SECONDAIRE (CLIENT)", "Se connecte à un poste maître existant", NetworkMode.client, FluentIcons.laptop_16_regular),
            _buildEliteModeBtn(context, c, "POSTE DISTANT (CLOUD)", "Sauvegarde et synchronisation Cloud hybride", NetworkMode.cloud, FluentIcons.cloud_24_regular),
          ],
        ),
        
        if (networkMode != NetworkMode.solo) ...[
          const SizedBox(height: 24),
          PremiumSettingsWidgets.buildSectionHeader(
            context,
            icon: networkMode == NetworkMode.server 
                ? FluentIcons.server_24_regular 
                : networkMode == NetworkMode.client 
                    ? FluentIcons.scan_text_24_regular 
                    : FluentIcons.cloud_24_regular,
            title: networkMode == NetworkMode.server 
                ? "Configuration du Poste Maître" 
                : networkMode == NetworkMode.client 
                    ? "Configuration de Connexion" 
                    : "Configuration Cloud Hybride",
            subtitle: networkMode == NetworkMode.server 
                ? "Informations à partager aux postes secondaires" 
                : networkMode == NetworkMode.client 
                    ? "Connectez-vous au réseau du magasin" 
                    : "Connectez votre magasin au Cloud pour accès distant",
            color: networkMode == NetworkMode.server 
                ? c.emerald 
                : networkMode == NetworkMode.client 
                    ? c.amber 
                    : c.violet,
          ),
          const SizedBox(height: 12),
          PremiumSettingsWidgets.buildCard(
            context,
            child: networkMode == NetworkMode.server 
              ? _buildServerView(context, ref, c, ipAsync)
              : networkMode == NetworkMode.client 
                  ? _buildClientView(context, ref, c)
                  : _buildCloudView(context, ref, c),
          ),
        ],
      ],
    );
  }

  Widget _buildEliteModeBtn(BuildContext context, DashColors c, String label, String desc, NetworkMode mode, IconData icon) {
    final isSelected = networkMode == mode;
    final color = isSelected ? c.blue : c.textMuted;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          if (isSelected) return;
          if (mode == NetworkMode.client) {
            _showClientWarningDialog(context, c);
          } else {
            onModeChanged(mode);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: isSelected ? (isDark ? c.blue.withValues(alpha: 0.1) : c.blue.withValues(alpha: 0.05)) : (isDark ? c.surface : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? c.blue : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              PremiumSettingsWidgets.buildIconBadge(icon: icon, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label, 
                      style: TextStyle(
                        fontSize: 15, 
                        fontWeight: FontWeight.w800, 
                        color: color, 
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc, 
                      style: TextStyle(
                        fontSize: 13, 
                        fontWeight: FontWeight.w600, 
                        color: isSelected ? color.withValues(alpha: 0.8) : c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(FluentIcons.checkmark_circle_24_filled, color: c.blue, size: 24)
              else
                Icon(FluentIcons.circle_24_regular, color: c.border, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showClientWarningDialog(BuildContext context, DashColors c) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            PremiumSettingsWidgets.buildIconBadge(icon: FluentIcons.warning_24_filled, color: c.amber),
            const SizedBox(width: 12),
            const Text("Mode Client", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Passer en mode Poste Secondaire ?",
              style: TextStyle(fontSize: 15, color: c.textMuted, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(
                "Vos données locales (Solo) seront sauvegardées et mises en pause. L'application se connectera à un Serveur Maître pour travailler.\n\nVous pourrez revenir en mode Solo à tout moment et retrouver vos données intactes.",
                style: TextStyle(fontSize: 14, color: c.textPrimary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text("ANNULER", style: TextStyle(color: c.textMuted, fontWeight: FontWeight.w800))
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onModeChanged(NetworkMode.client);
            }, 
            style: FilledButton.styleFrom(backgroundColor: c.amber),
            child: const Text("CONFIGURER", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _buildServerView(BuildContext context, WidgetRef ref, DashColors c, AsyncValue<String?> ipAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
             _RemoteHelpButton(onTap: () => _showRemoteAccessHelp(context)),
             _ServerStatusBadge(),
          ],
        ),
        const SizedBox(height: 16),
        if (syncKey != null && syncKey!.isNotEmpty)
          _buildEliteSyncKey(c, syncKey!),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ipAsync.when(
                data: (ip) => PremiumSettingsWidgets.buildInfoBox(
                  context,
                  text: "Adresse IP du Serveur : ${ip ?? 'N/A'}",
                  color: c.emerald,
                  icon: FluentIcons.wifi_1_24_regular,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text("erreur: $e", style: const TextStyle(fontSize: 13)),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 120,
              child: PremiumSettingsWidgets.buildCompactField(
                context,
                controller: serverPortCtrl,
                label: "PORT",
                hint: "8080",
                icon: FluentIcons.number_symbol_16_regular,
                isNumber: true,
                color: c.emerald,
                onChanged: onSaveDebounced,
              ),
            ),
          ],
        ),
        // 📡 LISTE DES CLIENTS CONNECTÉS EN DIRECT
        _buildActiveClientsList(context, ref, c),
        // 📥 LOGS DE SYNCHRO EN DIRECT
        _buildSyncLogsList(context, ref, c),
      ],
    );
  }

  Widget _buildClientView(BuildContext context, WidgetRef ref, DashColors c) {
    final isReachable = ref.watch(serverReachabilityProvider);
    final pendingSyncAsync = ref.watch(pendingSyncCountProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Statut de la liaison",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isReachable ? c.emerald.withValues(alpha: 0.1) : c.rose.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isReachable ? c.emerald.withValues(alpha: 0.3) : c.rose.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  if (isReachable)
                    _PulseDot(color: c.emerald)
                  else
                    Icon(FluentIcons.circle_12_filled, color: c.rose, size: 8),
                  const SizedBox(width: 8),
                  Text(
                    isReachable ? "CONNECTÉ AU SERVEUR" : "HORS LIGNE (SOLO)",
                    style: TextStyle(
                      color: isReachable ? c.emerald : c.rose,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: PremiumSettingsWidgets.buildCompactField(
                context,
                controller: serverIpCtrl,
                label: "ADRESSE IP DU SERVEUR MAÎTRE",
                hint: "Ex: 192.168.1.100",
                icon: FluentIcons.desktop_16_regular,
                color: c.amber,
                // On NE sauvegarde PAS à chaque touche pour éviter d'enregistrer une fausse IP !
                onChanged: () {}, 
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 120,
              child: PremiumSettingsWidgets.buildCompactField(
                context,
                controller: serverPortCtrl,
                label: "PORT",
                hint: "8080",
                icon: FluentIcons.number_symbol_16_regular,
                isNumber: true,
                color: c.amber,
                // Idem, pas de sauvegarde automatique
                onChanged: () {}, 
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _AutoDiscoverButton(serverIpCtrl: serverIpCtrl, serverPortCtrl: serverPortCtrl),
            _TestConnectionButton(
              serverIpCtrl: serverIpCtrl, 
              serverPortCtrl: serverPortCtrl, 
              onSuccess: onSaveDebounced,
            ),
          ],
        ),
        const Divider(height: 32),
        // État de la Synchronisation
        pendingSyncAsync.when(
          data: (count) {
            final hasPending = count > 0;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: hasPending 
                    ? (isDark ? c.amber.withValues(alpha: 0.05) : c.amber.withValues(alpha: 0.02))
                    : (isDark ? c.emerald.withValues(alpha: 0.05) : c.emerald.withValues(alpha: 0.02)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasPending ? c.amber.withValues(alpha: 0.2) : c.emerald.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasPending ? FluentIcons.warning_24_filled : FluentIcons.checkmark_circle_24_filled,
                    color: hasPending ? c.amber : c.emerald,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasPending 
                              ? "$count modification(s) en attente d'envoi" 
                              : "Toutes vos données sont synchronisées",
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasPending 
                              ? "Ces données seront envoyées dès que la liaison est active." 
                              : "Votre poste local est parfaitement à jour.",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (hasPending)
                    ElevatedButton.icon(
                      onPressed: () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: const Text("Synchro en cours..."), backgroundColor: c.blue),
                        );
                        await ref.read(clientSyncProvider).syncPendingAuditData();
                        ref.invalidate(pendingSyncCountProvider);
                      },
                      icon: const Icon(FluentIcons.arrow_sync_16_regular),
                      label: const Text("FORCER"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.amber,
                        foregroundColor: Colors.black,
                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                ],
              ),
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (err, _) => Text("Erreur de calcul de synchro : $err", style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  String _parseUserAgent(String ua) {
    final l = ua.toLowerCase();
    if (l.contains('windows')) return 'Windows';
    if (l.contains('android')) return 'Android';
    if (l.contains('iphone') || l.contains('ipad')) return 'iOS';
    if (l.contains('macintosh') || l.contains('mac os')) return 'macOS';
    if (l.contains('linux')) return 'Linux';
    return 'Poste Danaya+';
  }

  IconData _getOSIcon(String os) {
    switch (os) {
      case 'Windows': return FluentIcons.window_dev_tools_16_regular;
      case 'Android': return FluentIcons.phone_24_regular;
      case 'iOS': return FluentIcons.phone_24_regular;
      case 'macOS': return FluentIcons.laptop_24_regular;
      case 'Linux': return FluentIcons.window_apps_24_regular;
      default: return FluentIcons.desktop_24_regular;
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final sec = dt.second.toString().padLeft(2, '0');
    return '$hour:$min:$sec';
  }

  Widget _buildActiveClientsList(BuildContext context, WidgetRef ref, DashColors c) {
    final clients = ref.watch(connectedClientsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Row(
          children: [
            Icon(FluentIcons.plug_connected_24_filled, color: c.blue, size: 20),
            const SizedBox(width: 8),
            const Text(
              "POSTES CLIENTS ACTIFS",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: clients.isEmpty ? c.textMuted.withValues(alpha: 0.1) : c.emerald.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "${clients.length} connecté(s)",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: clients.isEmpty ? c.textMuted : c.emerald,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (clients.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? c.surface : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(FluentIcons.server_play_20_regular, color: c.textMuted.withValues(alpha: 0.3), size: 36),
                const SizedBox(height: 8),
                Text(
                  "En attente de connexion...",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  "Connectez vos postes secondaires en saisissant l'IP du serveur.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: clients.length,
            itemBuilder: (context, index) {
              final client = clients[index];
              final os = _parseUserAgent(client.userAgent);
              final osIcon = _getOSIcon(os);
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? c.surface : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.emerald.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: c.emerald.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(osIcon, color: c.emerald, size: 18),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Adresse IP : ${client.ip}",
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "OS : $os • ID: ${client.id.substring(0, 12)}",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(color: c.emerald, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "En Ligne",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: c.emerald),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Depuis ${_formatTime(client.connectedAt)}",
                          style: TextStyle(fontSize: 11, color: c.textMuted, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSyncLogsList(BuildContext context, WidgetRef ref, DashColors c) {
    final logs = ref.watch(serverSyncLogsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Row(
          children: [
            Icon(FluentIcons.history_24_filled, color: c.violet, size: 20),
            const SizedBox(width: 8),
            const Text(
              "FLUX DE SYNCHRONISATION EN DIRECT",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (logs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? c.surface : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(FluentIcons.clock_20_regular, color: c.textMuted.withValues(alpha: 0.3), size: 36),
                const SizedBox(height: 8),
                Text(
                  "Aucun flux d'activité",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  "Les événements de synchronisation apparaîtront ici en temps réel.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary),
                ),
              ],
            ),
          )
        else
          Container(
            constraints: const BoxConstraints(maxHeight: 250),
            decoration: BoxDecoration(
              color: isDark ? c.surface : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: logs.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final log = logs[index];
                
                Color badgeColor = c.blue;
                IconData badgeIcon = FluentIcons.add_circle_16_regular;
                
                switch (log.action) {
                  case 'insert':
                    badgeColor = c.emerald;
                    badgeIcon = FluentIcons.add_circle_16_filled;
                    break;
                  case 'update':
                    badgeColor = c.blue;
                    badgeIcon = FluentIcons.arrow_sync_16_filled;
                    break;
                  case 'delete':
                    badgeColor = c.rose;
                    badgeIcon = FluentIcons.delete_16_filled;
                    break;
                  case 'skip':
                    badgeColor = c.amber;
                    badgeIcon = FluentIcons.arrow_right_16_filled;
                    break;
                  case 'error':
                    badgeColor = c.rose;
                    badgeIcon = FluentIcons.dismiss_circle_16_filled;
                    break;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(badgeIcon, color: badgeColor, size: 14),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.details,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Source : ${log.clientIp} • Module : ${log.resource.toUpperCase()}",
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatTime(log.timestamp),
                        style: TextStyle(fontSize: 11, color: c.textMuted, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEliteSyncKey(DashColors c, String key) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.violet.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.violet.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          PremiumSettingsWidgets.buildIconBadge(icon: FluentIcons.key_16_filled, color: c.violet),
          const SizedBox(width: 16),
          Expanded(
             child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("CLÉ DE SYNCHRONISATION", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: c.violet.withValues(alpha: 0.8), letterSpacing: 0.5)),
                const SizedBox(height: 4),
                SelectableText(
                  key,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: c.violet, letterSpacing: 1),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _showRemoteAccessHelp(BuildContext context) {
    final c = DashColors.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            PremiumSettingsWidgets.buildIconBadge(icon: FluentIcons.globe_24_filled, color: c.blue),
            const SizedBox(width: 12),
            const Text("Accès Distant Elite", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Optimisez votre mobilité avec une connexion sécurisée.",
              style: TextStyle(fontSize: 15, color: c.textMuted, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildEliteStep(c, "1", "Tailscale VPN", "Installez Tailscale sur tous vos appareils pour un réseau maillé sécurisé."),
            _buildEliteStep(c, "2", "IP Dédiée", "Utilisez l'adresse IP fournie par Tailscale (100.x.y.z) dans les réglages du poste Client."),
            _buildEliteStep(c, "3", "SyncKey", "Assurez-vous que la clé de synchronisation est identique sur tous les postes."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text("J'AI COMPRIS", style: TextStyle(color: c.blue, fontWeight: FontWeight.w900))
          ),
        ],
      ),
    );
  }

  Widget _buildEliteStep(DashColors c, String num, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: c.blue.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Text(num, style: TextStyle(fontSize: 14, color: c.blue, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: c.textPrimary)), 
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(fontSize: 14, color: c.textSecondary, fontWeight: FontWeight.bold))
              ]
            )
          ),
        ],
      ),
    );
  }

  Widget _buildCloudView(BuildContext context, WidgetRef ref, DashColors c) {
    final status = ref.watch(cloudSyncStatusProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Statut Cloud",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: status.state == CloudSyncState.syncing
                    ? c.amber.withValues(alpha: 0.1)
                    : status.state == CloudSyncState.success
                        ? c.emerald.withValues(alpha: 0.1)
                        : status.state == CloudSyncState.error
                            ? c.rose.withValues(alpha: 0.1)
                            : c.textMuted.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: status.state == CloudSyncState.syncing
                      ? c.amber.withValues(alpha: 0.3)
                      : status.state == CloudSyncState.success
                          ? c.emerald.withValues(alpha: 0.3)
                          : status.state == CloudSyncState.error
                              ? c.rose.withValues(alpha: 0.3)
                              : c.textMuted.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  if (status.state == CloudSyncState.syncing)
                    _PulseDot(color: c.amber)
                  else if (status.state == CloudSyncState.success)
                    Icon(FluentIcons.checkmark_circle_12_filled, color: c.emerald, size: 12)
                  else if (status.state == CloudSyncState.error)
                    Icon(FluentIcons.dismiss_circle_12_filled, color: c.rose, size: 12)
                  else
                    Icon(FluentIcons.cloud_sync_16_regular, color: c.textMuted, size: 12),
                  const SizedBox(width: 8),
                  Text(
                    status.state == CloudSyncState.syncing
                        ? "SYNCHRONISATION..."
                        : status.state == CloudSyncState.success
                            ? "SYNCHRONISÉ"
                            : status.state == CloudSyncState.error
                                ? "ERREUR"
                                : "EN ATTENTE",
                    style: TextStyle(
                      color: status.state == CloudSyncState.syncing
                          ? c.amber
                          : status.state == CloudSyncState.success
                              ? c.emerald
                              : status.state == CloudSyncState.error
                                  ? c.rose
                                  : c.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: PremiumSettingsWidgets.buildCompactField(
                context,
                controller: cloudSyncKeyCtrl,
                label: "CLÉ CLOUD / BOUTIQUE ID",
                hint: "Ex: danaya_magasin_1",
                icon: FluentIcons.key_16_regular,
                color: c.violet,
                onChanged: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: PremiumSettingsWidgets.buildCompactField(
                context,
                controller: cloudEndpointCtrl,
                label: "URL DU CLOUD FIREBASE",
                hint: "https://votre-projet.firebaseio.com",
                icon: FluentIcons.cloud_24_regular,
                color: c.violet,
                onChanged: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                final endpoint = cloudEndpointCtrl.text.trim();
                final key = cloudSyncKeyCtrl.text.trim();
                if (endpoint.isEmpty || key.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Veuillez saisir l'URL du Cloud et la clé de boutique."),
                      backgroundColor: c.rose,
                    ),
                  );
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Validation de la connexion Cloud... ⏳"),
                    duration: Duration(seconds: 2),
                  ),
                );

                final syncService = ref.read(cloudSyncServiceProvider);
                final res = await syncService.validateCloudConnection(
                  endpoint: endpoint,
                  key: key,
                );

                if (!context.mounted) return;

                if (res == 'success') {
                  onSaveDebounced();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Liaison Cloud validée avec succès ! ✅"),
                      backgroundColor: c.emerald,
                    ),
                  );
                  syncService.runFullSyncCycle();
                } else if (res == 'not_found') {
                  showDialog(
                    context: context,
                    builder: (dialogCtx) => AlertDialog(
                      backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Row(
                        children: [
                          Icon(FluentIcons.warning_24_regular, color: Colors.amber, size: 28),
                          const SizedBox(width: 12),
                          const Text("Nouvelle Boutique ?"),
                        ],
                      ),
                      content: Text(
                        "La clé de boutique \"$key\" n'est pas encore enregistrée sur ce serveur Cloud.\n\n"
                        "S'agit-il d'une nouvelle boutique à enregistrer ?\n"
                        "Si oui, cliquez sur 'ENREGISTRER' pour l'initialiser de façon sécurisée.\n\n"
                        "⚠️ Si vous avez fait une faute de frappe, cliquez sur 'ANNULER'.",
                        style: const TextStyle(fontSize: 14),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text("ANNULER"),
                        ),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(dialogCtx);
                            // 🔒 Exiger le PIN admin avant l'enregistrement
                            _showAdminPinForCloudRegistration(
                              context, ref, syncService, endpoint, key, c,
                            );
                          },
                          child: const Text("ENREGISTRER LA BOUTIQUE"),
                        ),
                      ],
                    ),
                  );
                } else {
                  showDialog(
                    context: context,
                    builder: (dialogCtx) => AlertDialog(
                      backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Row(
                        children: [
                          Icon(FluentIcons.dismiss_circle_24_filled, color: c.rose, size: 28),
                          const SizedBox(width: 12),
                          const Text("Échec de Connexion"),
                        ],
                      ),
                      content: Text(res.startsWith('error:') ? res.substring(6) : res, style: const TextStyle(fontSize: 14)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text("COMPRIS"),
                        ),
                      ],
                    ),
                  );
                }
              },
              icon: const Icon(FluentIcons.shield_keyhole_20_regular),
              label: const Text("TESTER & VALIDER LA LIAISON CLOUD"),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.violet.withValues(alpha: 0.1),
                foregroundColor: c.violet,
                elevation: 0,
                side: BorderSide(color: c.violet.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (status.message.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: status.state == CloudSyncState.error
                  ? c.rose.withValues(alpha: 0.05)
                  : c.violet.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: status.state == CloudSyncState.error
                    ? c.rose.withValues(alpha: 0.2)
                    : c.violet.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              status.message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: status.state == CloudSyncState.error ? c.rose : c.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              status.lastSyncTime != null
                  ? "Dernière synchro : ${_formatTime(status.lastSyncTime!)}"
                  : "Aucune synchronisation effectuée",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
              ),
            ),
            PremiumSettingsWidgets.buildGradientBtn(
              onPressed: status.state == CloudSyncState.syncing
                  ? () {}
                  : () {
                      ref.read(cloudSyncServiceProvider).runFullSyncCycle();
                    },
              icon: FluentIcons.arrow_sync_20_regular,
              label: status.state == CloudSyncState.syncing
                  ? "Synchronisation..."
                  : "SYNCHRONISER MAINTENANT",
              colors: [c.violet, Colors.deepPurple],
            ),
          ],
        ),
        const Divider(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: status.pendingCount > 0
                ? (isDark ? c.amber.withValues(alpha: 0.05) : c.amber.withValues(alpha: 0.02))
                : (isDark ? c.emerald.withValues(alpha: 0.05) : c.emerald.withValues(alpha: 0.02)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: status.pendingCount > 0 ? c.amber.withValues(alpha: 0.2) : c.emerald.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                status.pendingCount > 0 ? FluentIcons.warning_24_filled : FluentIcons.checkmark_circle_24_filled,
                color: status.pendingCount > 0 ? c.amber : c.emerald,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.pendingCount > 0
                          ? "${status.pendingCount} modification(s) locale(s) en attente du Cloud"
                          : "Toutes vos données locales sont synchronisées sur le Cloud",
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status.pendingCount > 0
                          ? "Ces données seront automatiquement envoyées lors de la prochaine tâche de fond."
                          : "Votre Cloud est parfaitement à jour.",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 🔒 Dialogue de vérification PIN admin avant enregistrement Cloud
  void _showAdminPinForCloudRegistration(
    BuildContext context,
    WidgetRef ref,
    CloudSyncService syncService,
    String endpoint,
    String key,
    DashColors c,
  ) {
    final pinCtrl = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (pinCtx) => StatefulBuilder(
        builder: (pinCtx, setPinState) => AlertDialog(
          backgroundColor: Theme.of(pinCtx).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(FluentIcons.shield_keyhole_24_filled, color: c.violet, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text("Vérification Administrateur", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "L'enregistrement d'une nouvelle boutique sur le Cloud nécessite une authentification administrateur.",
                style: TextStyle(fontSize: 14, color: c.textSecondary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: "PIN ADMINISTRATEUR",
                  hintText: "••••",
                  prefixIcon: const Icon(FluentIcons.password_24_regular),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.violet, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isVerifying ? null : () => Navigator.pop(pinCtx),
              child: Text("ANNULER", style: TextStyle(color: c.textMuted, fontWeight: FontWeight.w800)),
            ),
            FilledButton(
              onPressed: isVerifying
                  ? null
                  : () async {
                      final pin = pinCtrl.text.trim();
                      if (pin.isEmpty) return;

                      setPinState(() => isVerifying = true);

                      try {
                        final isAdmin = await ref
                            .read(authServiceProvider.notifier)
                            .verifyAdminPin(pin);

                        if (!pinCtx.mounted) return;

                        if (!isAdmin) {
                          setPinState(() => isVerifying = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text("PIN administrateur incorrect. ❌"),
                              backgroundColor: c.rose,
                            ),
                          );
                          return;
                        }

                        // PIN vérifié → procéder à l'enregistrement
                        Navigator.pop(pinCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Enregistrement en cours... ⏳")),
                        );

                        final regRes = await syncService.registerShopOnCloud(
                          endpoint: endpoint,
                          key: key,
                        );

                        if (context.mounted) {
                          if (regRes == 'success') {
                            onSaveDebounced();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text("Boutique enregistrée et liaison Cloud activée ! ✅"),
                                backgroundColor: c.emerald,
                              ),
                            );
                            syncService.runFullSyncCycle();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Erreur : ${regRes.startsWith('error:') ? regRes.substring(6) : regRes}"),
                                backgroundColor: c.rose,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (pinCtx.mounted) {
                          setPinState(() => isVerifying = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Erreur: $e"),
                              backgroundColor: c.rose,
                            ),
                          );
                        }
                      }
                    },
              style: FilledButton.styleFrom(backgroundColor: c.violet),
              child: isVerifying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text("VÉRIFIER & ENREGISTRER", style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemoteHelpButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RemoteHelpButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: c.violet.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Icon(FluentIcons.globe_16_filled, size: 14, color: c.violet),
            const SizedBox(width: 8),
            Text("Guide Accès Distant", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.violet)),
          ],
        ),
      ),
    );
  }
}

class _AutoDiscoverButton extends ConsumerStatefulWidget {
  final TextEditingController serverIpCtrl;
  final TextEditingController serverPortCtrl;

  const _AutoDiscoverButton({required this.serverIpCtrl, required this.serverPortCtrl});

  @override
  ConsumerState<_AutoDiscoverButton> createState() => _AutoDiscoverButtonState();
}

class _AutoDiscoverButtonState extends ConsumerState<_AutoDiscoverButton> {
  bool _isSearching = false;

  Future<void> _startSearch() async {
    setState(() => _isSearching = true);
    final c = DashColors.of(context);
    try {
      final result = await ref.read(networkServiceProvider).discoverServer();
      if (mounted && result != null) {
        widget.serverIpCtrl.text = result['ip']!;
        widget.serverPortCtrl.text = result['port']!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Serveur détecté : ${result['ip']}"), backgroundColor: c.emerald));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Aucun serveur trouvé"), backgroundColor: c.rose));
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return PremiumSettingsWidgets.buildGradientBtn(
      onPressed: _isSearching ? () {} : _startSearch,
      icon: FluentIcons.search_20_regular,
      label: _isSearching ? "Recherche en cours..." : "LANCER LA RECHERCHE AUTO",
      colors: [c.amber, Colors.orange],
    );
  }
}

class _TestConnectionButton extends StatefulWidget {
  final TextEditingController serverIpCtrl;
  final TextEditingController serverPortCtrl;
  final VoidCallback onSuccess;

  const _TestConnectionButton({
    required this.serverIpCtrl,
    required this.serverPortCtrl,
    required this.onSuccess,
  });

  @override
  State<_TestConnectionButton> createState() => _TestConnectionButtonState();
}

class _TestConnectionButtonState extends State<_TestConnectionButton> {
  bool _isTesting = false;

  Future<void> _runTest() async {
    final ip = widget.serverIpCtrl.text.trim();
    final port = widget.serverPortCtrl.text.trim();
    final c = DashColors.of(context);

    if (ip.isEmpty || port.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Veuillez saisir l'IP et le port"), backgroundColor: c.rose));
      return;
    }

    setState(() => _isTesting = true);

    try {
      // Appel à la méthode de vérification HTTP
      final success = await _pingServer(ip, port);

      if (!mounted) return;

      if (success) {
        widget.onSuccess(); // SAUVEGARDE L'IP ICI !
        _showSuccessRestartDialog(c);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Serveur Danaya+ introuvable. Vérifiez l'IP !"), backgroundColor: c.rose));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur réseau: $e"), backgroundColor: c.rose));
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<bool> _pingServer(String ip, String port) async {
    try {
      final request = await HttpClient().getUrl(Uri.parse('http://$ip:$port/health'))
          .timeout(const Duration(seconds: 3));
      final response = await request.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void _showSuccessRestartDialog(DashColors c) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            PremiumSettingsWidgets.buildIconBadge(icon: FluentIcons.checkmark_circle_24_filled, color: c.emerald),
            const SizedBox(width: 12),
            const Text("Connexion Réussie", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Le poste est maintenant lié au serveur.",
              style: TextStyle(fontSize: 15, color: c.textMuted, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.emerald.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(
                "L'application doit être redémarrée pour fermer la session Solo locale et basculer sur les données distantes du serveur.\n\nVeuillez fermer l'application et la relancer.",
                style: TextStyle(fontSize: 14, color: c.emerald, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              exit(0); // Force kill app to restart clean
            }, 
            style: FilledButton.styleFrom(backgroundColor: c.emerald),
            child: const Text("QUITTER L'APPLICATION", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return PremiumSettingsWidgets.buildGradientBtn(
      onPressed: _isTesting ? () {} : _runTest,
      icon: FluentIcons.plug_connected_20_regular,
      label: _isTesting ? "Vérification..." : "TESTER ET APPLIQUER",
      colors: [c.emerald, Colors.green],
    );
  }
}

class _ServerStatusBadge extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(isServerRunningProvider);
    final c = DashColors.of(context);
    Color color = c.textSecondary;
    String label = "UNKNOWN";
    bool pulsing = false;

    switch (status) {
      case ServerStatus.running:
        color = c.emerald;
        label = "SERVEUR ONLINE";
        pulsing = true;
        break;
      case ServerStatus.starting:
        color = c.amber;
        label = "DÉMARRAGE...";
        pulsing = true;
        break;
      case ServerStatus.error:
        color = c.rose;
        label = "ERREUR RÉSEAU";
        pulsing = false;
        break;
      case ServerStatus.stopped:
        color = c.textMuted;
        label = "OFFLINE";
        pulsing = false;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1), 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: color.withValues(alpha: 0.3))
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pulsing) _PulseDot(color: color) else Icon(FluentIcons.circle_12_filled, color: color, size: 8),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _controller, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)));
  }
}
