import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/widgets/premium_settings_widgets.dart';
import '../../../inventory/presentation/widgets/dashboard_widgets.dart';
import '../../providers/shop_settings_provider.dart';

class AutomationSettingsSection extends StatelessWidget {
  final bool useAutoRef;
  final ValueChanged<bool> onUseAutoRefChanged;
  final TextEditingController refPrefixCtrl;
  final ReferenceGenerationModel refModel;
  final ValueChanged<ReferenceGenerationModel?> onRefModelChanged;
  final BarcodeGenerationModel barcodeModel;
  final ValueChanged<BarcodeGenerationModel?> onBarcodeModelChanged;
  final bool autoPrintLabelsOnStockIn;
  final ValueChanged<bool> onAutoPrintLabelsOnStockInChanged;
  final bool showAssistant;
  final ValueChanged<bool> onShowAssistantChanged;
  final RoundingMode roundingMode;
  final ValueChanged<RoundingMode?> onRoundingModeChanged;
  final AssistantPowerLevel assistantLevel;
  final ValueChanged<AssistantPowerLevel?> onAssistantLevelChanged;
  final VoidCallback onSaveDebounced;

  const AutomationSettingsSection({
    super.key,
    required this.useAutoRef,
    required this.onUseAutoRefChanged,
    required this.refPrefixCtrl,
    required this.refModel,
    required this.onRefModelChanged,
    required this.barcodeModel,
    required this.onBarcodeModelChanged,
    required this.autoPrintLabelsOnStockIn,
    required this.onAutoPrintLabelsOnStockInChanged,
    required this.showAssistant,
    required this.onShowAssistantChanged,
    required this.roundingMode,
    required this.onRoundingModeChanged,
    required this.assistantLevel,
    required this.onAssistantLevelChanged,
    required this.onSaveDebounced,
  });

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. RÉFÉRENTIEL AUTOMATIQUE ──
        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.tag_24_filled,
          title: "Référencement Automatique",
          subtitle: "Génération intelligente des identifiants produits",
          color: c.blue,
        ),
        const SizedBox(height: 12),
        PremiumSettingsWidgets.buildCard(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumSettingsWidgets.buildCompactSwitch(
                context,
                title: "Générer les références automatiquement",
                subtitle: "Crée un ID unique si le champ est vide à la création",
                value: useAutoRef,
                onChanged: onUseAutoRefChanged,
                activeColor: c.blue,
                icon: FluentIcons.text_bullet_list_tree_16_regular,
              ),
              if (useAutoRef) ...[
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 1,
                      child: PremiumSettingsWidgets.buildCompactField(
                        context,
                        label: "Préfixe",
                        hint: "REF",
                        icon: FluentIcons.text_field_20_regular,
                        controller: refPrefixCtrl,
                        color: c.blue,
                        onChanged: onSaveDebounced,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: PremiumSettingsWidgets.buildCompactDropdown<ReferenceGenerationModel>(
                        context,
                        label: "Modèle de génération",
                        value: refModel,
                        items: ReferenceGenerationModel.values.map((m) {
                          String label = "";
                          if (m == ReferenceGenerationModel.categorical) label = "Catégoriel (PRFX-CAT-001)";
                          else if (m == ReferenceGenerationModel.sequential) label = "Séquentiel (PRFX-0001)";
                          else if (m == ReferenceGenerationModel.random) label = "Aléatoire (PRFX-A1B2)";
                          else label = "Horodaté (PRFX-123456)";
                          return DropdownMenuItem(value: m, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)));
                        }).toList(),
                        onChanged: onRefModelChanged,
                        color: c.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildRefPreview(context, c),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── 2. CODES-BARRES ──
        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.barcode_scanner_24_filled,
          title: "Normes & Codes-Barres",
          subtitle: "Format par défaut des étiquettes et standards",
          color: c.amber,
        ),
        const SizedBox(height: 12),
        PremiumSettingsWidgets.buildCard(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumSettingsWidgets.buildCompactDropdown<BarcodeGenerationModel>(
                context,
                label: "Standard de codification",
                value: barcodeModel,
                items: BarcodeGenerationModel.values.map((m) {
                  String label = "";
                  if (m == BarcodeGenerationModel.ean13) label = "EAN-13 (Standard Retail)";
                  else if (m == BarcodeGenerationModel.upcA) label = "UPC-A (Standard US)";
                  else if (m == BarcodeGenerationModel.code128) label = "Code 128 (Alpha-Numérique)";
                  else label = "Numérique 9 (Optimisé interne)";
                  return DropdownMenuItem(value: m, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)));
                }).toList(),
                onChanged: onBarcodeModelChanged,
                color: c.amber,
              ),
              const SizedBox(height: 14),
              PremiumSettingsWidgets.buildInfoBox(
                context,
                text: "Utilisé uniquement pour les nouveaux articles lors de la génération automatique d'un code-barre.",
                color: c.amber,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── 3. CALCULS & ARRONDIS ──
        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.math_formula_24_filled,
          title: "Calculs & Arrondis",
          subtitle: "Fiabilisation des montants d'encaissement",
          color: c.rose,
        ),
        const SizedBox(height: 12),
        PremiumSettingsWidgets.buildCard(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumSettingsWidgets.buildCompactDropdown<RoundingMode>(
                context,
                label: "Mode d'arrondi (Caisse)",
                value: roundingMode,
                items: RoundingMode.values.map((m) {
                  String label = "";
                  switch (m) {
                    case RoundingMode.none: label = "Aucun (Précision totale)"; break;
                    case RoundingMode.nearest5: label = "Au 5 le plus proche (ex: 125, 130)"; break;
                    case RoundingMode.nearest10: label = "Au 10 le plus proche (ex: 120, 130)"; break;
                    case RoundingMode.nearest25: label = "Au 25 le plus proche (ex: 125, 150)"; break;
                    case RoundingMode.nearest50: label = "Au 50 le plus proche (ex: 150, 200)"; break;
                    case RoundingMode.nearest100: label = "Au 100 le plus proche (ex: 100, 200)"; break;
                  }
                  return DropdownMenuItem(value: m, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)));
                }).toList(),
                onChanged: onRoundingModeChanged,
                color: c.rose,
              ),
              const SizedBox(height: 14),
              PremiumSettingsWidgets.buildInfoBox(
                context,
                text: "L'arrondi s'applique automatiquement sur le total final lors des encaissements pour éviter les problèmes de monnaie.",
                color: c.rose,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── 4. FLUX INTELLIGENTS ──
        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.flash_24_filled,
          title: "Assistants & Flux",
          subtitle: "Optimisations pour un gain de temps maximal",
          color: c.violet,
        ),
        const SizedBox(height: 12),
        PremiumSettingsWidgets.buildCard(
          context,
          child: Column(
            children: [
              PremiumSettingsWidgets.buildCompactSwitch(
                context,
                title: "Auto-Étiquetage en Réception",
                subtitle: "Lance les étiquettes dès la validation du bon d'entrée",
                value: autoPrintLabelsOnStockIn,
                onChanged: onAutoPrintLabelsOnStockInChanged,
                activeColor: c.violet,
                icon: FluentIcons.print_16_regular,
              ),
              const SizedBox(height: 14),
              PremiumSettingsWidgets.buildCompactSwitch(
                context,
                title: "Assistant Virtuel Intelligent",
                subtitle: "Affiche ou masque le bouton de l'assistant IA",
                value: showAssistant,
                onChanged: onShowAssistantChanged,
                activeColor: c.violet,
                icon: FluentIcons.bot_24_regular,
              ),
              if (showAssistant) ...[
                const SizedBox(height: 20),
                _buildAssistantLevelSlider(context, c),
              ],
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildAssistantLevelSlider(BuildContext context, DashColors c) {
    String levelName = "";
    String levelDesc = "";
    IconData levelIcon = FluentIcons.brain_circuit_24_regular;
    Color levelColor = c.violet;

    switch (assistantLevel) {
      case AssistantPowerLevel.basic:
        levelName = "NIVEAU 1 : BASIQUE";
        levelDesc = "Recherche intelligente, Navigation vocale & Raccourcis IA.";
        levelIcon = FluentIcons.search_24_regular;
        levelColor = c.textMuted;
        break;
      case AssistantPowerLevel.analytical:
        levelName = "NIVEAU 2 : ANALYTIQUE";
        levelDesc = "Prévisions de ventes, Stats comparatives & Rapports dynamiques.";
        levelIcon = FluentIcons.data_usage_24_regular;
        levelColor = c.blue;
        break;
      case AssistantPowerLevel.actionable:
        levelName = "NIVEAU 3 : PROACTIF";
        levelDesc = "Modifications en masse & CRM Automatisé (Relance dettes).";
        levelIcon = FluentIcons.flash_24_regular;
        levelColor = c.amber;
        break;
      case AssistantPowerLevel.proactive:
        levelName = "NIVEAU 4 : EXPERT";
        levelDesc = "Détection d'anomalies & Optimisation prédictive des stocks.";
        levelIcon = FluentIcons.alert_badge_24_regular;
        levelColor = c.rose;
        break;
      case AssistantPowerLevel.titan:
        levelName = "NIVEAU 5 : SUPERVISEUR";
        levelDesc = "Analyse Business, Macros complexes & Orchestration totale.";
        levelIcon = FluentIcons.star_emphasis_24_regular;
        levelColor = c.violet;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: levelColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: levelColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PremiumSettingsWidgets.buildIconBadge(icon: levelIcon, color: levelColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      levelName,
                      style: TextStyle(fontWeight: FontWeight.w900, color: levelColor, fontSize: 11, letterSpacing: 1),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      levelDesc,
                      style: TextStyle(fontSize: 10, color: c.textSecondary, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: levelColor,
              inactiveTrackColor: levelColor.withValues(alpha: 0.1),
              thumbColor: levelColor,
              overlayColor: levelColor.withValues(alpha: 0.2),
              valueIndicatorColor: levelColor,
              valueIndicatorTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            child: Slider(
              value: assistantLevel.index.toDouble(),
              min: 0,
              max: 4,
              divisions: 4,
              label: (assistantLevel.index + 1).toString(),
              onChanged: (v) {
                onAssistantLevelChanged(AssistantPowerLevel.values[v.toInt()]);
              },
            ),
          ),
          Center(
            child: Text(
              "Ajustez la puissance et l'autonomie de l'IA",
              style: TextStyle(fontSize: 9, color: c.textMuted, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefPreview(BuildContext context, DashColors c) {
    String prefix = refPrefixCtrl.text.isEmpty ? "REF" : refPrefixCtrl.text;
    String preview = "";
    
    switch (refModel) {
      case ReferenceGenerationModel.categorical:
        preview = "$prefix-BOUTIQUE-001";
        break;
      case ReferenceGenerationModel.timestamp:
        preview = "$prefix-1710892800";
        break;
      case ReferenceGenerationModel.sequential:
        preview = "$prefix-0042";
        break;
      case ReferenceGenerationModel.random:
        preview = "$prefix-XJ9P";
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceElev,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.blue.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.eye_20_regular, color: c.blue, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("APERCU DE LA PROCHAINE RÉFÉRENCE", style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: c.textMuted, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(preview, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.blue, letterSpacing: 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
