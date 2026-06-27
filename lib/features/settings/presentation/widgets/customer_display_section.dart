import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:danaya_plus/core/widgets/premium_settings_widgets.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/core/network/server_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:screen_retriever/screen_retriever.dart'; // Pour détecter les écrans
import 'dart:io'; 
import '../../../inventory/presentation/widgets/dashboard_widgets.dart'; 

class CustomerDisplaySettingsSection extends ConsumerWidget {
  final String theme;
  final Function(String) onThemeChanged;
  final bool enableSounds;
  final ValueChanged<bool> onEnableSoundsChanged;
  final bool use3D;
  final ValueChanged<bool> onUse3DChanged;
  final bool isVoiceEnabled;
  final ValueChanged<bool> onIsVoiceEnabledChanged;
  final bool enableVoiceConfig;
  final ValueChanged<bool> onEnableVoiceConfigChanged;
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
    required this.isVoiceEnabled,
    required this.onIsVoiceEnabledChanged,
    required this.enableVoiceConfig,
    required this.onEnableVoiceConfigChanged,
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

    Widget buildCategory(String title, IconData icon, List<Widget> items) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 8),
            child: Row(
              children: [
                Icon(icon, size: 16, color: c.textSecondary),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: c.textSecondary, fontSize: 13, letterSpacing: 0.5)),
              ],
            ),
          ),
          SizedBox(
            height: 130, // Hauteur fixe pour éviter le flou lié au grand scroll vertical
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: 180,
                  child: items[index],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
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
        buildCategory("Quincaillerie & Matériaux (BTP)", FluentIcons.building_retail_24_regular, [
          _ThemeCard(id: 'theme-q-acier', name: 'Qualité & Robustesse', desc: 'Quincaillerie & BTP Pro', colors: [const Color(0xFF1E293B), const Color(0xFF94A3B8)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-q-ciment', name: 'Bâtir l\'Avenir', desc: 'Matériaux Durables', colors: [const Color(0xFFF1F5F9), const Color(0xFF64748B)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-q-brique', name: 'Solidité & Confiance', desc: 'Brique de Qualité', colors: [const Color(0xFF7F1D1D), const Color(0xFFFCA5A5)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-q-bois', name: 'Menuiserie de Précision', desc: 'Ébénisterie d\'Art', colors: [const Color(0xFF451A03), const Color(0xFFD97706)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-q-fer', name: 'Métallurgie & Force', desc: 'Ouvrages Métalliques', colors: [const Color(0xFF020617), const Color(0xFFEF4444)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-q-outil', name: 'Outils Professionnels', desc: 'Outillage Élite', colors: [const Color(0xFF0F172A), const Color(0xFFEAB308)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-q-chantier', name: 'Sécurité & Réussite', desc: 'Gros Œuvre', colors: [const Color(0xFFFFFBEB), const Color(0xFFD97706)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-faso', name: 'Bâtisseur National', desc: 'Développement', colors: [const Color(0xFF064E3B), const Color(0xFFFACC15)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-q-alu', name: 'Clarté & Modernité', desc: 'Alu & Vitrage', colors: [const Color(0xFFE2E8F0), const Color(0xFF3B82F6)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-q-cuivre', name: 'Énergie & Plomberie', desc: 'Réseaux & Fluides', colors: [const Color(0xFF2E1065), const Color(0xFFD97706)], currentId: theme, onSelect: onThemeChanged, c: c),
        ]),
        buildCategory("Prêt-à-porter & Mode", FluentIcons.shopping_bag_24_regular, [
          _ThemeCard(id: 'theme-bazin', name: 'Élégance & Prestige', desc: 'Bazin Riche', colors: [const Color(0xFF0D1B2A), const Color(0xFF778DA9)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-kita', name: 'Douceur & Tradition', desc: 'Kita Authentique', colors: [const Color(0xFFFDFBF7), const Color(0xFF8B6E58)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-p-soie', name: 'Raffinement Unique', desc: 'Soierie Fine', colors: [const Color(0xFFFDF2F8), const Color(0xFFEC4899)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-p-wax', name: 'Harmonie & Couleurs', desc: 'Wax d\'Exception', colors: [const Color(0xFF14532D), const Color(0xFFFACC15)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-p-indigo', name: 'Style & Denim', desc: 'Prêt-à-Porter', colors: [const Color(0xFF1E3A8A), const Color(0xFF93C5FD)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-p-cuir', name: 'Maroquinerie d\'Exception', desc: 'Cuir Véritable', colors: [const Color(0xFF27272A), const Color(0xFFA1A1AA)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-p-dentelle', name: 'Détails de Charme', desc: 'Prêt-à-Porter Féminin', colors: [const Color(0xFFFAF5FF), const Color(0xFFC084FC)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-p-urbain', name: 'Mode Contemporaine', desc: 'Urbain Chic', colors: [const Color(0xFF000000), const Color(0xFF10B981)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-p-tailleur', name: 'Sur-Mesure Élite', desc: 'Tailleurs de Prestige', colors: [const Color(0xFF1E293B), const Color(0xFF94A3B8)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-p-accessoire', name: 'L\'Éclat du Détail', desc: 'Accessoires de Luxe', colors: [const Color(0xFFFEFCE8), const Color(0xFFEAB308)], currentId: theme, onSelect: onThemeChanged, c: c),
        ]),
        buildCategory("Supermarché & Alimentation", FluentIcons.cart_24_regular, [
          _ThemeCard(id: 'theme-sugu', name: 'Votre Grand Marché', desc: 'Libre-Service', colors: [const Color(0xFF8B0000), const Color(0xFFFF4500)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-s-frais', name: 'Fraîcheur Absolue', desc: 'Primeurs & Fruits', colors: [const Color(0xFFF0FDF4), const Color(0xFF22C55E)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-s-epice', name: 'Saveurs & Parfums', desc: 'Condiments Fins', colors: [const Color(0xFFFFF7ED), const Color(0xFFEA580C)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-s-fruit', name: 'Verger & Nature', desc: 'Fruits de Saison', colors: [const Color(0xFFFDF4FF), const Color(0xFFD946EF)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-s-boulanger', name: 'Fournil & Tradition', desc: 'Boulangerie Chaude', colors: [const Color(0xFFFEF3C7), const Color(0xFFD97706)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-s-viande', name: 'Boucherie Premium', desc: 'Viandes Sélectionnées', colors: [const Color(0xFF4C0519), const Color(0xFFFB7185)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-s-lait', name: 'Crèmerie Pure', desc: 'Produits Laitiers', colors: [const Color(0xFFF8FAFC), const Color(0xFF38BDF8)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-garabal', name: 'Agroalimentaire Pro', desc: 'Élevage & Distribution', colors: [const Color(0xFF451A03), const Color(0xFFD97706)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-s-bio', name: 'Alimentation Saine', desc: 'Produits Biologiques', colors: [const Color(0xFF064E3B), const Color(0xFF10B981)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-s-gourmet', name: 'Épicerie Fine', desc: 'Prestige Gastronomique', colors: [const Color(0xFF171717), const Color(0xFFD4AF37)], currentId: theme, onSelect: onThemeChanged, c: c),
        ]),
        buildCategory("Beauté & Cosmétique", FluentIcons.sparkle_24_regular, [
          _ThemeCard(id: 'theme-karite', name: 'Soin & Bien-être', desc: 'Karité Naturel', colors: [const Color(0xFF2A4D33), const Color(0xFFA3B18A)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-b-parfum', name: 'Fragrances Uniques', desc: 'Parfumerie Fine', colors: [const Color(0xFF2E1065), const Color(0xFFD8B4FE)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-b-argan', name: 'Huiles & Soins', desc: 'Sérums & Élixirs', colors: [const Color(0xFF451A03), const Color(0xFFFCD34D)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-b-goudron', name: 'Tradition & Pureté', desc: 'Encens & Rituels', colors: [const Color(0xFF09090B), const Color(0xFFA1A1AA)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-rose', name: 'Éclat & Douceur', desc: 'Cosmétiques de Prestige', colors: [const Color(0xFF4C0519), const Color(0xFFE11D48)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-b-nude', name: 'Teint Parfait', desc: 'Rituels de Beauté', colors: [const Color(0xFFFDF8F6), const Color(0xFFFB923C)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-b-or', name: 'Beauté de Luxe', desc: 'Soin Anti-Âge Or', colors: [const Color(0xFF1C1917), const Color(0xFFD4AF37)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-b-spa', name: 'Détente & Harmonie', desc: 'Spa & Thalasso', colors: [const Color(0xFFF0FDFA), const Color(0xFF14B8A6)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-b-onglerie', name: 'Esthétique Parfaite', desc: 'Onglerie de Prestige', colors: [const Color(0xFFFDF2F8), const Color(0xFFF472B6)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-b-cheveux', name: 'Coiffure Design', desc: 'Soins Capillaires', colors: [const Color(0xFF0F172A), const Color(0xFF38BDF8)], currentId: theme, onSelect: onThemeChanged, c: c),
        ]),
        buildCategory("High-Tech & Électronique", FluentIcons.desktop_24_regular, [
          _ThemeCard(id: 'theme-neon', name: 'L\'Innovation Connectée', desc: 'High-Tech Store', colors: [const Color(0xFF020617), const Color(0xFF38BDF8)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-cyberpunk', name: 'Performance & Puissance', desc: 'Informatique Élite', colors: [const Color(0xFF3F000F), const Color(0xFFE11D48)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-midnight', name: 'Haute Résolution', desc: 'Écrans & OLED', colors: [const Color(0xFF000000), const Color(0xFFA855F7)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-h-silicon', name: 'Solutions Informatiques', desc: 'PC & Serveurs', colors: [const Color(0xFF0F172A), const Color(0xFF10B981)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-h-fibre', name: 'Fibre & Connectivité', desc: 'Réseaux Haut Débit', colors: [const Color(0xFF082F49), const Color(0xFF38BDF8)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-h-gaming', name: 'Setup Haute Performance', desc: 'Accessoires de Jeu', colors: [const Color(0xFF171717), const Color(0xFFEF4444)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-h-mobile', name: 'Solutions Mobiles', desc: 'Smartphones & Tablettes', colors: [const Color(0xFFF8FAFC), const Color(0xFF3B82F6)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-h-photo', name: 'Objectif & Image', desc: 'Photo & Vidéo Pro', colors: [const Color(0xFF1C1917), const Color(0xFFEAB308)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-h-audio', name: 'Acoustique Pure', desc: 'Son & Studio Pro', colors: [const Color(0xFF312E81), const Color(0xFF818CF8)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-h-smart', name: 'Maison Connectée', desc: 'Domotique & Sécurité', colors: [const Color(0xFFF0FDFA), const Color(0xFF0D9488)], currentId: theme, onSelect: onThemeChanged, c: c),
        ]),
        buildCategory("Corporate & Prestige", FluentIcons.building_bank_24_regular, [
          _ThemeCard(id: 'theme-luxury', name: 'Service d\'Exception', desc: 'Prestige & Distinction', colors: [const Color(0xFF121212), const Color(0xFFD4AF37)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-corporate', name: 'À Votre Service', desc: 'Partenariat Commercial', colors: [const Color(0xFF0F172A), const Color(0xFF3B82F6)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-wallstreet', name: 'Ambition & Croissance', desc: 'Solutions d\'Affaires', colors: [const Color(0xFF111827), const Color(0xFF2563EB)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-monaco', name: 'Raffinement Signature', desc: 'Élégance Intemporelle', colors: [const Color(0xFFFEFCE8), const Color(0xFFB76E79)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-empire', name: 'Excellence Durable', desc: 'Engagement Réussite', colors: [const Color(0xFF4A0E17), const Color(0xFFD4AF37)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-dakan', name: 'Votre Réussite', desc: 'Projets & Avenir', colors: [const Color(0xFF2E1065), const Color(0xFFC084FC)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-wariba', name: 'Valeur & Sécurité', desc: 'Solutions de Confiance', colors: [const Color(0xFF422006), const Color(0xFFF59E0B)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-jago', name: 'Relations de Confiance', desc: 'Sérieux Professionnel', colors: [const Color(0xFF0F172A), const Color(0xFF94A3B8)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-obsidian', name: 'Discrétion & Rigueur', desc: 'Expertise Premium', colors: [const Color(0xFF030712), const Color(0xFFE5E7EB)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-sanife', name: 'L\'Art du Détail', desc: 'Prestations de Qualité', colors: [const Color(0xFF083344), const Color(0xFF22D3EE)], currentId: theme, onSelect: onThemeChanged, c: c),
        ]),
        buildCategory("Prestige & Innovations", FluentIcons.sparkle_24_regular, [
          _ThemeCard(id: 'theme-ocean-flame', name: 'Excellence & Confiance', desc: 'Sensation Visuelle unique', colors: [const Color(0xFF1C0C02), const Color(0xFFEA580C)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-abyss-fire', name: 'L\'Art du Service', desc: 'Rendu Dynamique Premium', colors: [const Color(0xFF0D0400), const Color(0xFFDC2626)], currentId: theme, onSelect: onThemeChanged, c: c),
          _ThemeCard(id: 'theme-cosmic-magma', name: 'Prestige Signature', desc: 'Technologie & Innovation', colors: [const Color(0xFF140226), const Color(0xFFC084FC)], currentId: theme, onSelect: onThemeChanged, c: c),
        ]),
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
                        PremiumSettingsWidgets.buildCompactSwitch(context, title: "Ambiance Sonore", subtitle: "Bruitages et confirmations audio", value: enableSounds, onChanged: onEnableSoundsChanged, activeThumbColor: c.blue, icon: FluentIcons.speaker_2_20_regular),
                        const Divider(),
                        PremiumSettingsWidgets.buildCompactSwitch(context, title: "Synthèse Vocale (Voix)", subtitle: "Annoncer les articles et le total vocalement", value: isVoiceEnabled, onChanged: onIsVoiceEnabledChanged, activeThumbColor: c.blue, icon: FluentIcons.mic_sparkle_24_regular),
                        const Divider(),
                        PremiumSettingsWidgets.buildCompactSwitch(context, title: "Moteur DanayaFX (Premium)", subtitle: "Rendu 100% hors-ligne ultra-performant", value: use3D, onChanged: onUse3DChanged, activeThumbColor: c.violet, icon: FluentIcons.auto_fit_height_24_regular),
                        const Divider(),
                        PremiumSettingsWidgets.buildCompactSwitch(context, title: "Configuration Vocale Directe", subtitle: "Afficher l'engrenage de réglage de voix sur l'écran client", value: enableVoiceConfig, onChanged: onEnableVoiceConfigChanged, activeThumbColor: c.emerald, icon: FluentIcons.settings_24_regular),
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
                        PremiumSettingsWidgets.buildCompactSwitch(context, title: "Activer les messages", subtitle: "Les messages s'affichent si la caisse est inactive.", value: enableTicker, onChanged: onEnableTickerChanged, activeThumbColor: c.emerald, icon: FluentIcons.text_bullet_list_20_regular),
                        if (enableTicker) ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: messagesCtrl,
                            maxLines: 3,
                            style: TextStyle(fontSize: 14, fontFamily: 'monospace', color: c.textPrimary),
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

        // Écrans et Lancement
        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.desktop_mac_24_filled,
          title: "Projection Physique (Smart TV / Moniteur)",
          subtitle: "Sélectionnez sur quel écran matériel vous souhaitez projeter l'afficheur client.",
          color: c.amber,
        ),
        const SizedBox(height: 12),
        _DisplayLauncherCard(c: c),

        const SizedBox(height: 32),

        // Tests de Communication
        PremiumSettingsWidgets.buildCard(
          context,
          child: Row(
            children: [
              PremiumSettingsWidgets.buildIconBadge(icon: FluentIcons.preview_link_24_regular, color: c.violet),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Tester l'animation de vente", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: c.textPrimary)),
                    const SizedBox(height: 4),
                    Text("Simule l'encaissement d'un produit pour voir l'effet sur l'écran client.", style: TextStyle(fontSize: 13, color: c.textSecondary)),
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
                label: "SIMULER UNE VENTE",
                colors: [c.violet, Colors.purple],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DisplayLauncherCard extends ConsumerStatefulWidget {
  final DashColors c;
  const _DisplayLauncherCard({required this.c});

  @override
  ConsumerState<_DisplayLauncherCard> createState() => _DisplayLauncherCardState();
}

class _DisplayLauncherCardState extends ConsumerState<_DisplayLauncherCard> {
  List<Display> _displays = [];
  Display? _selectedDisplay;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDisplays();
  }

  Future<void> _fetchDisplays() async {
    try {
      final displays = await screenRetriever.getAllDisplays();
      if (mounted) {
        setState(() {
          _displays = displays;
          // Sélectionner automatiquement le deuxième écran s'il existe
          if (displays.length > 1) {
            _selectedDisplay = displays.firstWhere(
              (d) => (d.visiblePosition?.dx ?? 0) != 0 || (d.visiblePosition?.dy ?? 0) != 0,
              orElse: () => displays.first,
            );
          } else {
            _selectedDisplay = displays.first;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumSettingsWidgets.buildCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FluentIcons.device_eq_24_regular, color: widget.c.textSecondary, size: 20),
              const SizedBox(width: 8),
              Text("Liste des écrans détectés :", style: TextStyle(fontWeight: FontWeight.bold, color: widget.c.textPrimary)),
              const Spacer(),
              if (_isLoading) 
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: widget.c.amber))
              else
                IconButton(
                  icon: Icon(FluentIcons.arrow_clockwise_20_regular, color: widget.c.textSecondary, size: 18),
                  tooltip: "Rafraîchir les écrans",
                  onPressed: () {
                    setState(() => _isLoading = true);
                    _fetchDisplays();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.c.surfaceElev,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: widget.c.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Display>(
                      value: _selectedDisplay,
                      isExpanded: true,
                      dropdownColor: widget.c.surfaceElev,
                      hint: Text("Aucun écran détecté", style: TextStyle(color: widget.c.textMuted)),
                      icon: Icon(FluentIcons.chevron_down_20_regular, color: widget.c.textSecondary),
                      items: _displays.map((d) {
                        final isPrimary = (d.visiblePosition?.dx ?? 0) == 0 && (d.visiblePosition?.dy ?? 0) == 0;
                        final name = isPrimary ? "Écran Principal (Caisse)" : "Écran HDMI (Afficheur Client)";
                        final res = "${d.size.width.toInt()}x${d.size.height.toInt()}";
                        return DropdownMenuItem<Display>(
                          value: d,
                          child: Text(
                            "$name  •  $res",
                            style: TextStyle(
                              color: isPrimary ? widget.c.textPrimary : widget.c.amber, 
                              fontSize: 14, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedDisplay = val);
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              PremiumSettingsWidgets.buildGradientBtn(
                onPressed: () { if (_selectedDisplay != null) _launchDisplay(); },
                icon: FluentIcons.play_24_filled,
                label: "LANCER L'AFFICHEUR",
                colors: [widget.c.amber, Colors.orange],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _launchDisplay() async {
    final settings = ref.read(shopSettingsProvider).value;
    if (settings == null || _selectedDisplay == null) return;
    
    final port = settings.serverPort;
    final urlStr = 'http://localhost:$port/display';
    
    int targetX = _selectedDisplay!.visiblePosition?.dx.toInt() ?? 0;
    int targetY = _selectedDisplay!.visiblePosition?.dy.toInt() ?? 0;
    
    final edgeDir = '${Directory.systemTemp.path}\\DanayaDisplay';

    try {
      await Process.run('cmd', [
        '/c',
        'start',
        'msedge',
        '--user-data-dir=$edgeDir',
        '--app=$urlStr',
        '--window-position=$targetX,$targetY',
        '--start-fullscreen'
      ]);
    } catch (e) {
      final url = Uri.parse(urlStr);
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    }
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
                          fontSize: 12,
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
                          Text(name, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: isSelected ? c.blue : c.textPrimary, letterSpacing: 0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(desc, style: TextStyle(fontSize: 10, color: c.textMuted, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
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
