import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 650;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PremiumSettingsWidgets.buildSectionHeader(
              context,
              icon: FluentIcons.speaker_2_24_filled,
              title: "Expérience Sensorielle",
              subtitle: "Personnalisez l'ambiance sonore et visuelle",
              color: c.blue,
            ),
            const SizedBox(height: 12),
            
            if (isNarrow) ...[
              _buildAudioBlock(context, c),
              const SizedBox(height: 12),
              _buildVisualBlock(context, c),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _buildAudioBlock(context, c)),
                  const SizedBox(width: 12),
                  Expanded(flex: 4, child: _buildVisualBlock(context, c)),
                ],
              ),
            ],
          ],
        );
      }
    );
  }

  Widget _buildAudioBlock(BuildContext context, DashColors c) {
    return PremiumSettingsWidgets.buildCard(
      context,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PremiumSettingsWidgets.buildIconBadge(icon: FluentIcons.speaker_2_20_regular, color: c.blue),
              const SizedBox(width: 10),
              const Text("AUDIO", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          PremiumSettingsWidgets.buildCompactSwitch(
            context,
            title: "Master Audio",
            subtitle: "Système sonore global",
            value: enableSounds,
            onChanged: (v) { 
              Future.microtask(() => onEnableSoundsChanged(v)); 
              onSaveDebounced(); 
            },
            activeThumbColor: c.blue,
            icon: FluentIcons.speaker_mute_20_regular,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(height: 1),
          ),
          _buildSoundSwitchRowWithTest(
            c,
            title: "Flux Caisse",
            sub: "Scans et alertes",
            value: enableAppSounds,
            onChanged: (v) { 
              Future.microtask(() => onEnableAppSoundsChanged(v)); 
              onSaveDebounced(); 
            },
          ),
          const SizedBox(height: 8),
          _buildSoundSwitchRowWithTest(
            c,
            title: "Flux Client",
            sub: "Afficheur externe",
            value: enableCustomerDisplaySounds,
            onChanged: (v) { 
              Future.microtask(() => onEnableCustomerDisplaySoundsChanged(v)); 
              onSaveDebounced(); 
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVisualBlock(BuildContext context, DashColors c) {
    return PremiumSettingsWidgets.buildCard(
      context,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PremiumSettingsWidgets.buildIconBadge(icon: FluentIcons.glance_24_filled, color: c.violet),
              const SizedBox(width: 10),
              const Text("VISUEL", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          PremiumSettingsWidgets.buildCompactSwitch(
            context,
            title: "DanayaFX™",
            subtitle: "Moteur 3D & Effets",
            value: useCustomerDisplay3D,
            onChanged: (v) { 
              Future.microtask(() => onUseCustomerDisplay3DChanged(v)); 
              onSaveDebounced(); 
            },
            activeThumbColor: c.violet,
            icon: FluentIcons.cube_24_regular,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.violet.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.violet.withValues(alpha: 0.1)),
            ),
            child: Text(
              "Améliore l'immersion avec des effets 3D fluides.",
              style: TextStyle(fontSize: 10, color: c.textMuted, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundSwitchRowWithTest(DashColors c, {required String title, required String sub, required bool value, required ValueChanged<bool> onChanged}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: value ? c.blue.withValues(alpha: 0.03) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: value ? c.blue.withValues(alpha: 0.1) : Colors.transparent),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(sub, style: TextStyle(fontSize: 10, color: c.textMuted, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (value) ...[
            IconButton(
              icon: Icon(FluentIcons.play_20_regular, color: c.blue, size: 18),
              onPressed: onTestSound,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(backgroundColor: c.blue.withValues(alpha: 0.1)),
            ),
            const SizedBox(width: 4),
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
