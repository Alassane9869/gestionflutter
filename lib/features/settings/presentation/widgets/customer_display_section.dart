import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/widgets/premium_settings_widgets.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/network/server_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../inventory/presentation/widgets/dashboard_widgets.dart'; // Pour DashColors

class CustomerDisplaySettingsSection extends ConsumerWidget {
  final String theme;
  final Function(String) onThemeChanged;
  final bool enableSounds;
  final ValueChanged<bool> onEnableSoundsChanged;
  final bool use3D;
  final ValueChanged<bool> onUse3DChanged;
  final bool enableTicker;
  final ValueChanged<bool> onEnableTickerChanged;
  final TextEditingController messagesCtrl;
  final VoidCallback onSaveDebounced;
  final NetworkMode networkMode;

  const CustomerDisplaySettingsSection({
    super.key,
    required this.theme,
    required this.onThemeChanged,
    required this.enableSounds,
    required this.onEnableSoundsChanged,
    required this.use3D,
    required this.onUse3DChanged,
    required this.enableTicker,
    required this.onEnableTickerChanged,
    required this.messagesCtrl,
    required this.onSaveDebounced,
    required this.networkMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = DashColors.of(context);

    if (networkMode == NetworkMode.client) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.laptop_24_regular, size: 64, color: c.textMuted),
            const SizedBox(height: 24),
            Text(
              "Mode Client Actif",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              "L'afficheur client doit être configuré sur le Poste Admin.",
              style: TextStyle(color: c.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.phone_screen_time_24_filled,
          title: "Afficheur Client (Pro)",
          subtitle: "Personnalisez l'expérience visuelle de vos clients sur écran externe.",
          color: c.rose,
        ),
        const SizedBox(height: 24),

        // Thèmes visuels
        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.color_24_filled,
          title: "Choix du Style Visuel",
          subtitle: "Apparences prêtes à l'emploi pour l'écran client",
          color: c.amber,
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.8,
          children: [
            _ThemeCard(id: 'theme-luxury', name: 'Luxury Gold', desc: 'Marbre & Or', colors: [const Color(0xFF000000), const Color(0xFFD4AF37)], currentId: theme, onSelect: onThemeChanged, c: c),
            _ThemeCard(id: 'theme-minimal', name: 'Minimalist', desc: 'Studio Blanc', colors: [const Color(0xFFFAF9F6), const Color(0xFF4682B4)], currentId: theme, onSelect: onThemeChanged, c: c),
            _ThemeCard(id: 'theme-neon', name: 'Neon Cyber', desc: 'Futuriste', colors: [const Color(0xFF020617), const Color(0xFF22d3ee)], currentId: theme, onSelect: onThemeChanged, c: c),
            _ThemeCard(id: 'theme-corporate', name: 'Corporate', desc: 'Business Blue', colors: [const Color(0xFF0f172a), const Color(0xFF3b82f6)], currentId: theme, onSelect: onThemeChanged, c: c),
            _ThemeCard(id: 'theme-nature', name: 'Zen Nature', desc: 'Vert Organique', colors: [const Color(0xFF064E3B), const Color(0xFF10b981)], currentId: theme, onSelect: onThemeChanged, c: c),
            _ThemeCard(id: 'theme-sunset', name: 'Solar Sunset', desc: 'Aurora Borealis', colors: [const Color(0xFF2D0A0A), const Color(0xFFf59e0b)], currentId: theme, onSelect: onThemeChanged, c: c),
            _ThemeCard(id: 'theme-midnight', name: 'Midnight OLED', desc: 'Noir Absolu & Iris', colors: [const Color(0xFF000000), const Color(0xFF4F46E5)], currentId: theme, onSelect: onThemeChanged, c: c),
            _ThemeCard(id: 'theme-rose', name: 'Rose Gold', desc: 'Champagne & Pivoine', colors: [const Color(0xFFFDF2F2), const Color(0xFFE594A1)], currentId: theme, onSelect: onThemeChanged, c: c),
            _ThemeCard(id: 'theme-emerald', name: 'Emerald Sea', desc: 'Émeraude & Cyan', colors: [const Color(0xFF064E3B), const Color(0xFF06B6D4)], currentId: theme, onSelect: onThemeChanged, c: c),
            _ThemeCard(id: 'theme-amethyst', name: 'Amethyst Glow', desc: 'Violet Profond', colors: [const Color(0xFF2E1065), const Color(0xFFD8B4FE)], currentId: theme, onSelect: onThemeChanged, c: c),
            _ThemeCard(id: 'theme-cyberpunk', name: 'Cyberpunk Crimson', desc: 'Haute Intensité', colors: [const Color(0xFF110000), const Color(0xFFFF0033)], currentId: theme, onSelect: onThemeChanged, c: c),
            _ThemeCard(id: 'theme-arctic', name: 'Arctic Frost', desc: 'Cristal & Glace', colors: [const Color(0xFFF1F5F9), const Color(0xFF38BDF8)], currentId: theme, onSelect: onThemeChanged, c: c),
          ],
        ),

        const SizedBox(height: 32),

        // Multimédia & Performance
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PremiumSettingsWidgets.buildSectionHeader(
                    context,
                    icon: FluentIcons.play_circle_24_filled,
                    title: "Rendu & Audio",
                    subtitle: "Performances et effets sonores",
                    color: c.blue,
                  ),
                  const SizedBox(height: 12),
                  PremiumSettingsWidgets.buildCard(
                    context,
                    child: Column(
                      children: [
                        PremiumSettingsWidgets.buildCompactSwitch(context, title: "Ambiance Sonore", subtitle: "Bruitages et confirmations audio", value: enableSounds, onChanged: onEnableSoundsChanged, activeColor: c.blue, icon: FluentIcons.speaker_2_20_regular),
                        const Divider(),
                        PremiumSettingsWidgets.buildCompactSwitch(context, title: "Moteur DanayaFX (Premium)", subtitle: "Rendu 100% hors-ligne ultra-performant", value: use3D, onChanged: onUse3DChanged, activeColor: c.violet, icon: FluentIcons.auto_fit_height_24_regular),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PremiumSettingsWidgets.buildSectionHeader(
                    context,
                    icon: FluentIcons.document_text_24_filled,
                    title: "Bannière d'informations",
                    subtitle: "Texte défilant",
                    color: c.emerald,
                  ),
                  const SizedBox(height: 12),
                  PremiumSettingsWidgets.buildCard(
                    context,
                    child: Column(
                      children: [
                        PremiumSettingsWidgets.buildCompactSwitch(context, title: "Activer les messages", subtitle: "Les messages s'affichent si la caisse est inactive.", value: enableTicker, onChanged: onEnableTickerChanged, activeColor: c.emerald, icon: FluentIcons.text_bullet_list_20_regular),
                        if (enableTicker) ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: messagesCtrl,
                            maxLines: 3,
                            style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: c.textPrimary),
                            decoration: InputDecoration(
                              hintText: "Saisissez un message par ligne...",
                              hintStyle: TextStyle(color: c.textMuted),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.all(12),
                              isDense: true,
                            ),
                            onChanged: (_) => onSaveDebounced(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),

        // Liens et Tests
        PremiumSettingsWidgets.buildCard(
          context,
          child: Row(
            children: [
              PremiumSettingsWidgets.buildIconBadge(icon: FluentIcons.preview_link_24_regular, color: c.amber),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Tester la communication", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: c.textPrimary)),
                    const SizedBox(height: 4),
                    Text("Vérifiez le fonctionnement instantané sur vos écrans.", style: TextStyle(fontSize: 10, color: c.textSecondary)),
                  ],
                ),
              ),
              PremiumSettingsWidgets.buildGradientBtn(
                onPressed: () {
                  ref.read(serverServiceProvider).broadcastEvent('sale_completed', {
                    'total': 7500.0,
                    'paid': 8000.0,
                    'change': 500.0,
                  });
                },
                icon: FluentIcons.play_20_filled,
                label: "SIMULER VENTE",
                colors: [c.violet, Colors.purple],
              ),
              const SizedBox(width: 12),
              PremiumSettingsWidgets.buildGradientBtn(
                onPressed: () async {
                  final settings = ref.read(shopSettingsProvider).value;
                  if (settings == null) return;
                  final port = settings.serverPort;
                  final url = Uri.parse('http://localhost:$port/display');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
                icon: FluentIcons.open_20_filled,
                label: "OUVRIR L'AFFICHEUR",
                colors: [c.amber, Colors.orange],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final String id;
  final String name;
  final String desc;
  final List<Color> colors;
  final String currentId;
  final Function(String) onSelect;
  final DashColors c;

  const _ThemeCard({
    required this.id,
    required this.name,
    required this.desc,
    required this.colors,
    required this.currentId,
    required this.onSelect,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentId == id;

    return InkWell(
      onTap: () => onSelect(id),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: c.surfaceElev,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? c.blue : c.border.withValues(alpha: 0.5),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected 
              ? [BoxShadow(color: c.blue.withValues(alpha: 0.2), blurRadius: 15, spreadRadius: 2)]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            children: [
              // Preview Box
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text("Danaya+", 
                        style: TextStyle(
                          color: colors.first.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        )),
                    ),
                  ),
                ),
              ),
              // Name & Desc
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: isSelected ? c.blue : c.textPrimary, letterSpacing: 0.5)),
                          const SizedBox(height: 2),
                          Text(desc, style: TextStyle(fontSize: 9, color: c.textMuted, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(FluentIcons.checkmark_circle_16_filled, color: c.blue, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
