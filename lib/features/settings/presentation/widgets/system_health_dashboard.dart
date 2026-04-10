
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:danaya_plus/features/settings/providers/system_health_provider.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import '../../../../core/widgets/premium_settings_widgets.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/features/inventory/presentation/widgets/dashboard_widgets.dart';

class SystemHealthDashboard extends ConsumerWidget {
  const SystemHealthDashboard({super.key});

  void _handleUnlockTap(WidgetRef ref) {
    ref.read(systemHealthSecretCounterProvider.notifier).increment();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = DashColors.of(context);
    final state = ref.watch(systemHealthProvider);
    final notifier = ref.read(systemHealthProvider.notifier);
    final isUnlocked = ref.watch(systemHealthIsUnlockedProvider);

    // 🛡️ Écouteur pour la notification de déverrouillage
    ref.listen(systemHealthIsUnlockedProvider, (previous, next) {
      if (next == true && (previous == false || previous == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("🛡️ MODE ALCHIMISTE ACTIVÉ : OUTILS DE MAINTENANCE RÉVÉLÉS", style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: c.blue,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHealthScoreCard(context, c, ref, state, notifier),
        const SizedBox(height: 20),
        _buildDiagnosticsGrid(context, c, state),
        
        // ── SECTION CACHÉE : Ne s'affiche QUE si déverrouillée ──
        if (isUnlocked) ...[
          const SizedBox(height: 20),
          _buildAdvancedActions(context, c, ref, state, notifier, isUnlocked)
              .animate()
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCirc),
        ],
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildHealthScoreCard(BuildContext context, DashColors c, WidgetRef ref, SystemHealthState state, SystemHealthNotifier notifier) {
    double healthScore = 1.0;
    if (state.lastScannerResult != null) {
      final issues = (state.lastScannerResult!['stock_issues'] as int? ?? 0) + 
                     (state.lastScannerResult!['orphan_images'] as int? ?? 0);
      healthScore = (100 - (issues * 10)).clamp(0, 100).toDouble() / 100;
    }

    return PremiumSettingsWidgets.buildGlassCard(
      context,
      glowColor: healthScore > 0.8 ? c.emerald : (healthScore > 0.5 ? c.amber : c.rose),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: state.isScanning || state.isOptimizing ? null : healthScore,
                  strokeWidth: 8,
                  backgroundColor: c.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                  color: healthScore > 0.8 ? c.emerald : (healthScore > 0.5 ? c.amber : c.rose),
                ),
              ),
              Text(
                state.isScanning || state.isOptimizing ? "?" : "${(healthScore * 100).toInt()}%",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔐 LE DÉCLENCHEUR SECRET (5 clics ici)
                GestureDetector(
                  onTap: () => _handleUnlockTap(ref),
                  behavior: HitTestBehavior.opaque,
                  child: const Text(
                    "SANTÉ GLOBALE DU SYSTÈME", 
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.0)
                  ),
                ),
                Text(
                  state.currentActionLabel ?? "En attente • Prêt pour le diagnostic",
                  style: TextStyle(fontSize: 11, color: c.textMuted, fontWeight: FontWeight.w600),
                ),
                if (state.isOptimizing || state.isScanning) ...[
                   const SizedBox(height: 12),
                   LinearProgressIndicator(
                     value: state.progress, 
                     minHeight: 4, 
                     borderRadius: BorderRadius.circular(2),
                     backgroundColor: c.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
                     color: c.blue,
                   ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 20),
          _buildScanButton(c, state, notifier),
        ],
      ),
    );
  }

  Widget _buildScanButton(DashColors c, SystemHealthState state, SystemHealthNotifier notifier) {
    return PremiumSettingsWidgets.buildGradientBtn(
      onPressed: state.isScanning || state.isOptimizing ? () {} : () => notifier.runFullDiagnostic(),
      icon: state.isScanning ? FluentIcons.arrow_sync_24_regular : FluentIcons.stethoscope_24_filled,
      label: state.isScanning ? "SCAN EN COURS..." : "DIAGNOSTIC",
      colors: state.isScanning ? [c.blue.withValues(alpha: 0.5), c.blue.withValues(alpha: 0.5)] : [c.blue, const Color(0xFF4A90E2)],
    );
  }

  Widget _buildDiagnosticsGrid(BuildContext context, DashColors c, SystemHealthState state) {
    final result = state.lastScannerResult;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              _buildBentoCard(
                context: context,
                c: c,
                title: "BASE DE DONNÉES",
                subtitle: "Stockage Physique",
                icon: FluentIcons.database_24_filled,
                color: c.blue,
                value: result != null ? "${result['db_size_mb']} MB" : "--",
                desc: "Taille totale sur disque",
              ),
              const SizedBox(height: 16),
              _buildBentoCard(
                context: context,
                c: c,
                title: "INTÉGRITÉ LOGIQUE",
                subtitle: "Analyse des écarts",
                icon: FluentIcons.shield_task_24_filled,
                color: (result != null && result['stock_issues'] == 0) ? c.emerald : c.amber,
                value: result != null ? "${result['stock_issues']} Erreurs" : "--",
                desc: "Différence Stock vs Mouvements",
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              _buildBentoCard(
                context: context,
                c: c,
                title: "FICHIERS SYSTÈME",
                subtitle: "Nettoyage Média",
                icon: FluentIcons.image_copy_24_filled,
                color: c.violet,
                value: result != null ? "${result['orphan_images']} Orphelins" : "--",
                desc: "Images non référencées",
              ),
              const SizedBox(height: 16),
              _buildBentoCard(
                context: context,
                c: c,
                title: "HISTORIQUE D'AUDIT",
                subtitle: "Optimisation Logs",
                icon: FluentIcons.history_24_filled,
                color: c.amber,
                value: "STABLE",
                desc: "Prêt pour l'archivage",
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBentoCard({
    required BuildContext context,
    required DashColors c,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String value,
    required String desc,
  }) {
    return PremiumSettingsWidgets.buildCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PremiumSettingsWidgets.buildIconBadge(icon: icon, color: color),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(desc, style: TextStyle(fontSize: 9, color: c.textMuted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAdvancedActions(
    BuildContext context, 
    DashColors c, 
    WidgetRef ref, 
    SystemHealthState state, 
    SystemHealthNotifier notifier,
    bool isUnlocked
  ) {
    if (!isUnlocked) return const SizedBox.shrink(); 
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.rose.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: c.rose.withValues(alpha: 0.05), blurRadius: 30, spreadRadius: -5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PremiumSettingsWidgets.buildIconBadge(icon: FluentIcons.toolbox_24_filled, color: c.rose),
              const SizedBox(width: 12),
              const Text("NETTOYAGE ÉLITE & MAINTENANCE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.0)),
            ],
          ),
          const SizedBox(height: 24),
          
          _buildActionButton(
            context,
            c: c,
            label: "OPTIMISATION GLOBALE",
            sub: "Optimisation profonde de la base de données & PMP",
            icon: FluentIcons.flash_24_filled,
            color: c.emerald,
            onTap: state.isScanning || state.isOptimizing ? null : () => notifier.runMasterOptimization(),
          ),
          
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 24),
          
          Text("SUPPRESSION PAR CATÉGORIE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: c.rose, letterSpacing: 1.0)),
          const SizedBox(height: 16),
          
          _buildSelectiveItem(
            context, c, ref,
            title: "Ventes & Devis",
            desc: "Purger l'historique financier et les transactions.",
            icon: FluentIcons.receipt_24_regular,
            onConfirm: () => notifier.clearSalesOnly(),
          ),
          _buildSelectiveItem(
            context, c, ref,
            title: "Stock & Inventaire",
            desc: "Remise à zéro des quantités (Garde les fiches produits).",
            icon: FluentIcons.box_24_regular,
            onConfirm: () => notifier.clearInventoryOnly(),
          ),
          _buildSelectiveItem(
            context, c, ref,
            title: "Clients & Fournisseurs",
            desc: "Effacer l'intégralité du fichier contacts.",
            icon: FluentIcons.people_community_24_regular,
            onConfirm: () => notifier.clearCRMOnly(),
          ),
          _buildSelectiveItem(
            context, c, ref,
            title: "Journaux d'Activité",
            desc: "Purge totale des logs système et d'audit.",
            icon: FluentIcons.list_24_regular,
            onConfirm: () => notifier.clearLogsOnly(),
          ),
          
          const SizedBox(height: 12),
          _buildSelectiveItem(
            context, c, ref,
            title: "RÉINITIALISATION TOTALE (DANGER)",
            desc: "Remise à zéro intégrale et irréversible de l'application.",
            icon: FluentIcons.warning_24_filled,
            isNuclear: true,
            onConfirm: () => notifier.nuclearReset(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required DashColors c,
    required String label,
    required String sub,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 12),
              Text(label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: color)),
              const SizedBox(height: 4),
              Text(sub, style: TextStyle(fontSize: 10, color: c.textMuted, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectiveItem(
    BuildContext context, DashColors c, WidgetRef ref, {
    required String title,
    required String desc,
    required IconData icon,
    required VoidCallback onConfirm,
    bool isNuclear = false,
  }) {
    final color = isNuclear ? c.rose : c.textMuted;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showSecurePurgeDialog(context, c, ref, title, desc, onConfirm),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.isDark ? Colors.black.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                PremiumSettingsWidgets.buildIconBadge(icon: icon, color: color),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: isNuclear ? c.rose : null)),
                      const SizedBox(height: 4),
                      Text(desc, style: TextStyle(fontSize: 10, color: c.textSecondary, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Icon(FluentIcons.chevron_right_20_regular, size: 16, color: c.textMuted.withValues(alpha: 0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSecurePurgeDialog(BuildContext context, DashColors c, WidgetRef ref, String title, String desc, VoidCallback onAction) {
    showDialog(
      context: context,
      builder: (context) => EnterpriseWidgets.buildPremiumDialog(
        context,
        title: "SÉCURITÉ : $title",
        icon: FluentIcons.shield_lock_24_filled,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: c.rose.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(FluentIcons.warning_24_filled, color: c.rose, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      "Attention : Cette action va effacer définitivement les données suivantes : $desc",
                      style: TextStyle(color: c.rose, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text("Entrez le CODE PIN MANAGER pour confirmer", style: TextStyle(fontSize: 12, color: c.textMuted, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            _PinEntryField(
              onComplete: (pin) {
                final settings = ref.read(shopSettingsProvider).value;
                if (pin == settings?.managerPin) {
                  Navigator.pop(context);
                  onAction();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Code PIN Incorrect"), backgroundColor: Colors.red),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("ANNULER", style: TextStyle(color: c.textMuted, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}

class _PinEntryField extends StatefulWidget {
  final Function(String) onComplete;
  const _PinEntryField({required this.onComplete});

  @override
  State<_PinEntryField> createState() => _PinEntryFieldState();
}

class _PinEntryFieldState extends State<_PinEntryField> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return TextField(
      controller: _ctrl,
      obscureText: true,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 4,
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 20),
      decoration: InputDecoration(
        counterText: "",
        filled: true,
        fillColor: c.isDark ? Colors.black.withValues(alpha: 0.3) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.blue.withValues(alpha: 0.3))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.blue, width: 2)),
      ),
      onChanged: (val) {
        if (val.length == 4) widget.onComplete(val);
      },
    );
  }
}
