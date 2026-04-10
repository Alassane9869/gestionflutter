import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/widgets/premium_settings_widgets.dart';
import '../../../inventory/presentation/widgets/dashboard_widgets.dart';
import 'package:danaya_plus/features/settings/presentation/widgets/license_section.dart';
import 'package:danaya_plus/features/settings/presentation/widgets/network_section.dart';
import 'package:danaya_plus/features/settings/domain/models/shop_settings_models.dart';

import 'package:danaya_plus/features/settings/presentation/widgets/system_health_dashboard.dart';

class SystemMaintenanceSection extends ConsumerWidget {
  final int? daysRemaining;
  final VoidCallback onViewTos;
  final VoidCallback onShowRecoveryKey;
  final NetworkMode networkMode;
  final Function(NetworkMode?) onModeChanged;
  final TextEditingController serverIpCtrl;
  final TextEditingController serverPortCtrl;
  final TextEditingController syncKeyCtrl;
  final VoidCallback onSaveDebounced;
  final bool isAutoLockEnabled;
  final ValueChanged<bool> onAutoLockEnabledChanged;
  final TextEditingController autoLockMinutesCtrl;

  const SystemMaintenanceSection({
    super.key,
    this.daysRemaining,
    required this.onViewTos,
    required this.onShowRecoveryKey,
    required this.networkMode,
    required this.onModeChanged,
    required this.serverIpCtrl,
    required this.serverPortCtrl,
    required this.syncKeyCtrl,
    required this.onSaveDebounced,
    required this.isAutoLockEnabled,
    required this.onAutoLockEnabledChanged,
    required this.autoLockMinutesCtrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = DashColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── EN-TÊTE DE SECTION ──
        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.wrench_24_filled,
          title: "Cockpit de Maintenance",
          subtitle: "Gestion de la licence, sécurité et réseau",
          color: c.blue,
        ),
        const SizedBox(height: 16),

        // ── GRILLE HAUTE (LICENCE + SÉCURITÉ) ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bloc Licence
            Expanded(
              flex: 3,
              child: LicenseSettingsSection(
                daysRemaining: daysRemaining,
                onRenew: () {}, 
                onViewTos: onViewTos,
                onShowRecoveryKey: onShowRecoveryKey,
              ),
            ),
            const SizedBox(width: 16),
            // Bloc Sécurité / Auto-Lock
            Expanded(
              flex: 2,
              child: PremiumSettingsWidgets.buildCard(
                context,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        PremiumSettingsWidgets.buildIconBadge(icon: FluentIcons.shield_lock_16_regular, color: c.amber),
                        const SizedBox(width: 10),
                        const Text("SÉCURITÉ", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
                        const Spacer(),
                        Transform.scale(
                          scale: 0.8,
                          child: Switch.adaptive(
                            value: isAutoLockEnabled, 
                            onChanged: onAutoLockEnabledChanged,
                            activeColor: c.amber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text("Auto-Verrou", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text("Verrouille la session après une période d'inactivité.", style: TextStyle(color: c.textSecondary, fontSize: 9)),
                    if (isAutoLockEnabled) ...[
                      const SizedBox(height: 12),
                      _buildMinutesField(c),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── CENTRE DE SANTÉ ÉLITE (BENTO DASHBOARD) ──
        const SystemHealthDashboard(),
        const SizedBox(height: 24),

        // ── RÉSEAU & CONNECTIVITÉ ──
        NetworkSettingsSection(
          networkMode: networkMode,
          onModeChanged: onModeChanged,
          serverIpCtrl: serverIpCtrl,
          serverPortCtrl: serverPortCtrl,
          syncKey: syncKeyCtrl.text,
          onSaveDebounced: onSaveDebounced,
        ),
        const SizedBox(height: 16),

        // ── PIED DE PAGE : SUPPORT COMPACT ──
        _buildCompactSupportFooter(context, c),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildMinutesField(DashColors c) {
    return Row(
      children: [
        const Icon(FluentIcons.clock_16_regular, size: 14, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: autoLockMinutesCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => onSaveDebounced(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              suffixText: "min",
              suffixStyle: const TextStyle(fontSize: 9),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactSupportFooter(BuildContext context, DashColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: c.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.blue.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.person_support_20_regular, color: c.blue, size: 16),
          const SizedBox(width: 12),
          const Text("ASSISTANCE TECHNIQUE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
          const Spacer(),
          _buildMiniSupportBtn(c, "Guide d'utilisation", FluentIcons.book_question_mark_20_regular, () => onViewTos()),
          const SizedBox(width: 12),
          _buildMiniSupportBtn(c, "Contact", FluentIcons.person_feedback_20_regular, () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: c.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text("SUPPORT TECHNIQUE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.0)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildContactRow(c, FluentIcons.mail_20_regular, "Email", "alaska6e6ui3e@gmail.com"),
                    _buildContactRow(c, FluentIcons.chat_20_regular, "WhatsApp", "+223 66 82 62 07"),
                    _buildContactRow(c, FluentIcons.camera_20_regular, "Snapchat", "alasko_ff"),
                    _buildContactRow(c, FluentIcons.video_20_regular, "TikTok", "danaya+"),
                    _buildContactRow(c, FluentIcons.globe_24_regular, "Site Web", "danayaplus.online"),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text("FERMER", style: TextStyle(fontWeight: FontWeight.bold, color: c.textMuted))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildContactRow(DashColors c, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          PremiumSettingsWidgets.buildIconBadge(icon: icon, color: c.blue),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 9, color: c.textMuted, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              SelectableText(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniSupportBtn(DashColors c, String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8)
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: c.blue),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: c.blue, fontWeight: FontWeight.w800, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
