import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/widgets/premium_settings_widgets.dart';
import '../../../inventory/presentation/widgets/dashboard_widgets.dart'; 
import 'package:danaya_plus/core/services/sound_service.dart';

class MultimediaSettingsSection extends ConsumerWidget {
  final bool enableSounds;
  final ValueChanged<bool> onEnableSoundsChanged;
  final bool enableAppSounds;
  final ValueChanged<bool> onEnableAppSoundsChanged;
  final bool enableCustomerDisplaySounds;
  final ValueChanged<bool> onEnableCustomerDisplaySoundsChanged;
  final bool useCustomerDisplay3D;
  final ValueChanged<bool> onUseCustomerDisplay3DChanged;
  final VoidCallback onTestSound;
  final VoidCallback onSaveDebounced;

  const MultimediaSettingsSection({
    super.key,
    required this.enableSounds,
    required this.onEnableSoundsChanged,
    required this.enableAppSounds,
    required this.onEnableAppSoundsChanged,
    required this.enableCustomerDisplaySounds,
    required this.onEnableCustomerDisplaySoundsChanged,
    required this.useCustomerDisplay3D,
    required this.onUseCustomerDisplay3DChanged,
    required this.onTestSound,
    required this.onSaveDebounced,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = DashColors.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 750;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PremiumSettingsWidgets.buildSectionHeader(
              context,
              icon: FluentIcons.speaker_2_24_filled,
              title: "Expérience Sensorielle",
              subtitle: "Personnalisez l'ambiance sonore et visuelle de votre application",
              color: c.blue,
            ),
            const SizedBox(height: 12),
            
            if (isNarrow) ...[
              _buildAudioBlock(context, ref, c),
              const SizedBox(height: 16),
              _buildVisualBlock(context, c),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _buildAudioBlock(context, ref, c)),
                  const SizedBox(width: 16),
                  Expanded(flex: 5, child: _buildVisualBlock(context, c)),
                ],
              ),
            ],
          ],
        );
      }
    );
  }

  Widget _buildAudioBlock(BuildContext context, WidgetRef ref, DashColors c) {
    final soundSvc = ref.read(soundServiceProvider);

    return PremiumSettingsWidgets.buildCard(
      context,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PremiumSettingsWidgets.buildIconBadge(icon: FluentIcons.speaker_2_20_regular, color: c.blue),
              const SizedBox(width: 12),
              const Text("AUDIO & NOTIFICATIONS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 16),
          PremiumSettingsWidgets.buildCompactSwitch(
            context,
            title: "Master Audio",
            subtitle: "Activer ou désactiver les sons système",
            value: enableSounds,
            onChanged: (v) { 
              Future.microtask(() => onEnableSoundsChanged(v)); 
              onSaveDebounced(); 
            },
            activeThumbColor: c.blue,
            icon: FluentIcons.speaker_mute_20_regular,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(height: 1),
          ),
          _buildSoundSwitchRowWithTest(
            c,
            title: "Flux Caisse",
            sub: "Bips de scans et alertes d'erreurs",
            value: enableAppSounds,
            onChanged: (v) { 
              Future.microtask(() => onEnableAppSoundsChanged(v)); 
              onSaveDebounced(); 
            },
            onPlayTest: () => soundSvc.playScanSuccess(),
          ),
          const SizedBox(height: 10),
          _buildSoundSwitchRowWithTest(
            c,
            title: "Flux Client",
            sub: "Voix et sons de l'afficheur externe",
            value: enableCustomerDisplaySounds,
            onChanged: (v) { 
              Future.microtask(() => onEnableCustomerDisplaySoundsChanged(v)); 
              onSaveDebounced(); 
            },
            onPlayTest: () => soundSvc.playSaleSuccess(),
          ),
          if (enableSounds) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Divider(height: 1),
            ),
            Text("SUITE DE TEST AUDIO", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: c.blue, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            _buildSoundTestItem(c, "Vente Validée (Kaching!)", () => soundSvc.playSaleSuccess()),
            _buildSoundTestItem(c, "Scan Réussi (Bip)", () => soundSvc.playScanSuccess()),
            _buildSoundTestItem(c, "Erreur Système (Alerte)", () => soundSvc.playScanError()),
            _buildSoundTestItem(c, "Rupture de Stock (Attention)", () => soundSvc.playStockAlert()),
            _buildSoundTestItem(c, "Démarrage Session", () => soundSvc.playSessionStart()),
          ],
        ],
      ),
    );
  }

  Widget _buildVisualBlock(BuildContext context, DashColors c) {
    return PremiumSettingsWidgets.buildCard(
      context,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PremiumSettingsWidgets.buildIconBadge(icon: FluentIcons.glance_24_filled, color: c.violet),
              const SizedBox(width: 12),
              const Text("VISUEL & ANIMATIONS 3D", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 16),
          PremiumSettingsWidgets.buildCompactSwitch(
            context,
            title: "DanayaFX™",
            subtitle: "Activer le moteur 3D et effets spéciaux",
            value: useCustomerDisplay3D,
            onChanged: (v) { 
              Future.microtask(() => onUseCustomerDisplay3DChanged(v)); 
              onSaveDebounced(); 
            },
            activeThumbColor: c.violet,
            icon: FluentIcons.cube_24_regular,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.violet.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.violet.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(FluentIcons.sparkle_20_filled, color: c.violet, size: 18),
                    const SizedBox(width: 8),
                    Text("FONCTIONNALITÉS DU MOTEUR", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: c.violet, letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildEngineCapabilityItem(c, FluentIcons.cube_20_regular, "Sphère Assistante 3D", "Modélisation animée de l'orb de l'IA réactive à la voix."),
                _buildEngineCapabilityItem(c, FluentIcons.sparkle_20_regular, "Effets de Particules", "Effets visuels dynamiques sur les graphiques de vente."),
                _buildEngineCapabilityItem(c, FluentIcons.slide_transition_20_regular, "Transitions Premium", "Passages de fenêtres fluides et animés en 60fps."),
                _buildEngineCapabilityItem(c, FluentIcons.flash_20_regular, "Optimisation GPU", "Accélération matérielle native à faible impact batterie."),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngineCapabilityItem(DashColors c, IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: c.violet),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(description, style: TextStyle(fontSize: 11, color: c.textMuted, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundTestItem(DashColors c, String label, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.surfaceElev,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(FluentIcons.play_16_regular, color: c.blue, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundSwitchRowWithTest(DashColors c, {required String title, required String sub, required bool value, required ValueChanged<bool> onChanged, required VoidCallback onPlayTest}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: value ? c.blue.withValues(alpha: 0.03) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: value ? c.blue.withValues(alpha: 0.1) : Colors.transparent),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(fontSize: 11, color: c.textMuted, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (value) ...[
            IconButton(
              icon: Icon(FluentIcons.play_20_regular, color: c.blue, size: 18),
              onPressed: onPlayTest,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(backgroundColor: c.blue.withValues(alpha: 0.1)),
            ),
            const SizedBox(width: 8),
          ],
          Transform.scale(
            scale: 0.8,
            child: Switch.adaptive(
              value: value, 
              onChanged: (v) { onChanged(v); onSaveDebounced(); }, 
              activeThumbColor: c.blue,
              activeTrackColor: c.blue.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}
