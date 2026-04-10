import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:danaya_plus/core/widgets/premium_settings_widgets.dart';
import '../../../inventory/presentation/widgets/dashboard_widgets.dart'; 

class MultimediaSettingsSection extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.speaker_2_24_filled,
          title: "Centre Multimédia & Audio",
          subtitle: "Gérez l'ambiance sonore et les effets visuels de l'application",
          color: c.blue,
        ),
        const SizedBox(height: 12),
        PremiumSettingsWidgets.buildCard(
          context,
          child: Column(
            children: [
              PremiumSettingsWidgets.buildCompactSwitch(
                context,
                title: "Master Switch (Tous les sons)",
                subtitle: "Activer ou désactiver globalement l'ambiance sonore",
                value: enableSounds,
                onChanged: (v) { onEnableSoundsChanged(v); onSaveDebounced(); },
                activeColor: c.blue,
                icon: FluentIcons.speaker_2_20_regular,
              ),
              const Divider(),
              _buildSoundSwitchRowWithTest(
                c,
                title: "Sons de l'Application (POS)",
                sub: "Bips de scan, alertes stock et sons de caisse",
                value: enableAppSounds,
                onChanged: onEnableAppSoundsChanged,
              ),
              const Divider(),
              PremiumSettingsWidgets.buildCompactSwitch(
                context,
                title: "Sons de l'Afficheur Client",
                subtitle: "Bruitages et ambiance sur l'écran TV/Client",
                value: enableCustomerDisplaySounds,
                onChanged: (v) { onEnableCustomerDisplaySoundsChanged(v); onSaveDebounced(); },
                activeColor: c.blue,
                icon: FluentIcons.phone_screen_time_20_regular,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        
        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.cube_24_filled,
          title: "Expérience Visuelle Avancée",
          subtitle: "Moteurs de rendu haute performance",
          color: c.violet,
        ),
        const SizedBox(height: 12),
        PremiumSettingsWidgets.buildCard(
          context,
          child: Column(
            children: [
              PremiumSettingsWidgets.buildCompactSwitch(
                context,
                title: "DanayaFX (Rendu Premium)",
                subtitle: "Effets visuels 100% hors-ligne (Aura & Réseau Géométrique)",
                value: useCustomerDisplay3D,
                onChanged: (v) { onUseCustomerDisplay3DChanged(v); onSaveDebounced(); },
                activeColor: c.violet,
                icon: FluentIcons.cube_20_regular,
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildSoundSwitchRowWithTest(DashColors c, {required String title, required String sub, required bool value, required ValueChanged<bool> onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          PremiumSettingsWidgets.buildIconBadge(icon: FluentIcons.speaker_1_20_regular, color: c.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(sub, style: TextStyle(fontSize: 11, color: c.textSecondary)),
              ],
            ),
          ),
          if (value) ...[
            IconButton(
              icon: Icon(FluentIcons.play_20_filled, color: c.emerald, size: 20),
              onPressed: onTestSound,
              tooltip: "Tester le son",
            ),
            const SizedBox(width: 8),
          ],
          Switch.adaptive(value: value, onChanged: (v) { onChanged(v); onSaveDebounced(); }, activeColor: c.blue),
        ],
      ),
    );
  }
}
