// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/widgets/premium_settings_widgets.dart';
import 'package:danaya_plus/core/network/network_service.dart';
import 'package:danaya_plus/core/network/server_service.dart';
import 'package:danaya_plus/features/inventory/presentation/widgets/dashboard_widgets.dart';

class NetworkSettingsSection extends ConsumerWidget {
  final NetworkMode networkMode;
  final Function(NetworkMode?) onModeChanged;
  final TextEditingController serverIpCtrl;
  final TextEditingController serverPortCtrl;
  final String? syncKey;
  final VoidCallback onSaveDebounced;

  const NetworkSettingsSection({
    super.key,
    required this.networkMode,
    required this.onModeChanged,
    required this.serverIpCtrl,
    required this.serverPortCtrl,
    this.syncKey,
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
        Row(
          children: [
            _buildEliteModeBtn(context, c, "MONO-POSTE (SOLO)", "Base de données 100% locale isolée", NetworkMode.solo, FluentIcons.person_16_regular),
            const SizedBox(width: 12),
            _buildEliteModeBtn(context, c, "POSTE MAÎTRE (SERVEUR)", "Centralise et partage la base de données", NetworkMode.server, FluentIcons.server_16_regular),
            const SizedBox(width: 12),
            _buildEliteModeBtn(context, c, "POSTE SECONDAIRE (CLIENT)", "Se connecte au poste maître", NetworkMode.client, FluentIcons.laptop_16_regular),
          ],
        ),
        
        if (networkMode != NetworkMode.solo) ...[
          const SizedBox(height: 24),
          PremiumSettingsWidgets.buildSectionHeader(
            context,
            icon: networkMode == NetworkMode.server ? FluentIcons.server_24_regular : FluentIcons.scan_text_24_regular,
            title: networkMode == NetworkMode.server ? "Configuration du Poste Maître" : "Configuration de Connexion",
            subtitle: networkMode == NetworkMode.server ? "Informations à partager aux postes secondaires" : "Connectez-vous au réseau du magasin",
            color: networkMode == NetworkMode.server ? c.emerald : c.amber,
          ),
          const SizedBox(height: 12),
          PremiumSettingsWidgets.buildCard(
            context,
            child: networkMode == NetworkMode.server 
              ? _buildServerView(context, c, ipAsync)
              : _buildClientView(context, c),
          ),
        ],
      ],
    );
  }

  Widget _buildEliteModeBtn(BuildContext context, DashColors c, String label, String desc, NetworkMode mode, IconData icon) {
    final isSelected = networkMode == mode;
    final color = isSelected ? c.blue : c.textMuted;

    return Expanded(
      child: InkWell(
        onTap: () => onModeChanged(mode),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? c.blue.withValues(alpha: 0.1) : c.surfaceElev,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? c.blue : c.border.withValues(alpha: 0.6),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected ? [BoxShadow(color: c.blue.withValues(alpha: 0.2), blurRadius: 15, spreadRadius: -2)] : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumSettingsWidgets.buildIconBadge(icon: icon, color: color),
              const SizedBox(height: 12),
              Text(
                label, 
                style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.w900, 
                  color: color, 
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc, 
                style: TextStyle(
                  fontSize: 14, 
                  fontWeight: FontWeight.bold, 
                  color: isSelected ? color.withValues(alpha: 0.7) : c.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerView(BuildContext context, DashColors c, AsyncValue<String?> ipAsync) {
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
      ],
    );
  }

  Widget _buildClientView(BuildContext context, DashColors c) {
    return Column(
      children: [
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
                onChanged: onSaveDebounced,
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
                onChanged: onSaveDebounced,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _AutoDiscoverButton(serverIpCtrl: serverIpCtrl, serverPortCtrl: serverPortCtrl),
          ],
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
      default:
        color = c.textMuted;
        label = "OFFLINE";
        pulsing = false;
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
