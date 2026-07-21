import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/premium_settings_widgets.dart';
import '../../../inventory/presentation/widgets/dashboard_widgets.dart';
import '../../providers/shop_settings_provider.dart';
import '../../../assistant/application/assistant_memory_service.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';

class AutomationSettingsSection extends ConsumerWidget {
  final bool useAutoRef;
  final ValueChanged<bool> onUseAutoRefChanged;
  final TextEditingController refPrefixCtrl;
  final ReferenceGenerationModel refModel;
  final ValueChanged<ReferenceGenerationModel?> onRefModelChanged;
  final bool autoPrintLabelsOnStockIn;
  final ValueChanged<bool> onAutoPrintLabelsOnStockInChanged;
  final bool showAssistant;
  final ValueChanged<bool> onShowAssistantChanged;
  final RoundingMode roundingMode;
  final ValueChanged<RoundingMode?> onRoundingModeChanged;
  final Map<String, bool> copilotPermissions;
  final void Function(String key, bool val) onCopilotPermissionChanged;
  final VoidCallback onSaveDebounced;
  final bool useCloudAi;
  final ValueChanged<bool> onUseCloudAiChanged;
  final String cloudAiProvider;
  final ValueChanged<String?> onCloudAiProviderChanged;
  final bool allowCloudAiActions;
  final ValueChanged<bool> onAllowCloudAiActionsChanged;
  final bool enableAiStreaming;
  final ValueChanged<bool> onEnableAiStreamingChanged;
  final TextEditingController deepSeekApiKeyCtrl;
  final TextEditingController geminiApiKeyCtrl;
  final TextEditingController elevenLabsApiKeyCtrl;
  final TextEditingController elevenLabsVoiceIdCtrl;

  const AutomationSettingsSection({
    super.key,
    required this.useAutoRef,
    required this.onUseAutoRefChanged,
    required this.refPrefixCtrl,
    required this.refModel,
    required this.onRefModelChanged,
    required this.autoPrintLabelsOnStockIn,
    required this.onAutoPrintLabelsOnStockInChanged,
    required this.showAssistant,
    required this.onShowAssistantChanged,
    required this.roundingMode,
    required this.onRoundingModeChanged,
    required this.copilotPermissions,
    required this.onCopilotPermissionChanged,
    required this.useCloudAi,
    required this.onUseCloudAiChanged,
    required this.cloudAiProvider,
    required this.onCloudAiProviderChanged,
    required this.allowCloudAiActions,
    required this.onAllowCloudAiActionsChanged,
    required this.enableAiStreaming,
    required this.onEnableAiStreamingChanged,
    required this.deepSeekApiKeyCtrl,
    required this.geminiApiKeyCtrl,
    required this.elevenLabsApiKeyCtrl,
    required this.elevenLabsVoiceIdCtrl,
    required this.onSaveDebounced,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = DashColors.of(context);
    final user = ref.watch(authServiceProvider).value;
    final isAdmin = user?.isAdmin ?? false;

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
                subtitle:
                    "Crée un ID unique si le champ est vide à la création",
                value: useAutoRef,
                onChanged: onUseAutoRefChanged,
                activeThumbColor: c.blue,
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
                      child:
                          PremiumSettingsWidgets.buildCompactDropdown<
                            ReferenceGenerationModel
                          >(
                            context,
                            label: "Modèle de génération",
                            value: refModel,
                            items: ReferenceGenerationModel.values.map((m) {
                              String label = "";
                              if (m == ReferenceGenerationModel.categorical) {
                                label = "Catégoriel (PRFX-CAT-001)";
                              } else if (m ==
                                  ReferenceGenerationModel.sequential) {
                                label = "Séquentiel (PRFX-0001)";
                              } else if (m == ReferenceGenerationModel.random) {
                                label = "Aléatoire (PRFX-A1B2)";
                              } else {
                                label = "Horodaté (PRFX-123456)";
                              }
                              return DropdownMenuItem(
                                value: m,
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
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
                    case RoundingMode.none:
                      label = "Aucun (Précision totale)";
                      break;
                    case RoundingMode.nearest5:
                      label = "Au 5 le plus proche (ex: 125, 130)";
                      break;
                    case RoundingMode.nearest10:
                      label = "Au 10 le plus proche (ex: 120, 130)";
                      break;
                    case RoundingMode.nearest25:
                      label = "Au 25 le plus proche (ex: 125, 150)";
                      break;
                    case RoundingMode.nearest50:
                      label = "Au 50 le plus proche (ex: 150, 200)";
                      break;
                    case RoundingMode.nearest100:
                      label = "Au 100 le plus proche (ex: 100, 200)";
                      break;
                  }
                  return DropdownMenuItem(
                    value: m,
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: onRoundingModeChanged,
                color: c.rose,
              ),
              const SizedBox(height: 14),
              PremiumSettingsWidgets.buildInfoBox(
                context,
                text:
                    "L'arrondi s'applique automatiquement sur le total final lors des encaissements pour éviter les problèmes de monnaie.",
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
                subtitle:
                    "Lance les étiquettes dès la validation du bon d'entrée",
                value: autoPrintLabelsOnStockIn,
                onChanged: onAutoPrintLabelsOnStockInChanged,
                activeThumbColor: c.violet,
                icon: FluentIcons.print_16_regular,
              ),
              const SizedBox(height: 14),
              PremiumSettingsWidgets.buildCompactSwitch(
                context,
                title: "Assistant Virtuel Intelligent",
                subtitle: "Affiche ou masque le bouton de l'assistant IA",
                value: showAssistant,
                onChanged: onShowAssistantChanged,
                activeThumbColor: c.violet,
                icon: FluentIcons.bot_24_regular,
              ),
              if (showAssistant) ...[
                const SizedBox(height: 20),
                _buildCopilotPermissionsSection(context, ref, c, isAdmin),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── 5. SERVICES DE CALCULS VIP HORS-LIGNE/CLOUD ──
        PremiumSettingsWidgets.buildSectionHeader(
          context,
          icon: FluentIcons.brain_circuit_24_filled,
          title: "Moteurs de Calculs VIP",
          subtitle:
              "Connectez l'assistant à des moteurs de calculs avancés",
          color: c.violet,
        ),
        const SizedBox(height: 12),
        PremiumSettingsWidgets.buildCard(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumSettingsWidgets.buildCompactSwitch(
                context,
                title: "Activer les Calculs VIP",
                subtitle:
                    "Permet à l'assistant de consulter des modules de calculs avancés",
                value: useCloudAi,
                onChanged: onUseCloudAiChanged,
                activeThumbColor: c.violet,
                icon: FluentIcons.cloud_24_filled,
              ),
              if (useCloudAi) ...[
                const SizedBox(height: 16),
                PremiumSettingsWidgets.buildCompactDropdown<String>(
                  context,
                  label: "Moteur de calculs",
                  value: ['gemini', 'deepseek'].contains(cloudAiProvider)
                      ? cloudAiProvider
                      : 'gemini',
                  items: const [
                    DropdownMenuItem(
                      value: 'gemini',
                      child: Text(
                        "MOTEUR DE CALCULS VIP (Recommandé)",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'deepseek',
                      child: Text(
                        "MOTEUR DE CALCULS STANDARD",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  onChanged: onCloudAiProviderChanged,
                  color: c.violet,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.violet.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.violet.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            FluentIcons.key_24_regular,
                            color: c.violet,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            cloudAiProvider == 'gemini'
                                ? "CLÉ D'ACTIVATION MOTEUR VIP"
                                : "CLÉ D'ACTIVATION MOTEUR STANDARD",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: c.violet,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: cloudAiProvider == 'gemini'
                            ? geminiApiKeyCtrl
                            : deepSeekApiKeyCtrl,
                        obscureText: true,
                        onChanged: (_) => onSaveDebounced(),
                        style: TextStyle(
                          fontSize: 13,
                          color: c.textPrimary,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          hintText: cloudAiProvider == 'gemini'
                              ? "Clé d'activation du moteur VIP..."
                              : "Clé d'activation du moteur Standard...",
                          hintStyle: TextStyle(
                            color: c.textMuted,
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: c.surfaceElev,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: c.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: c.violet, width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: c.border),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          suffixIcon: Icon(
                            FluentIcons.eye_off_24_regular,
                            color: c.textMuted,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      PremiumSettingsWidgets.buildInfoBox(
                        context,
                        text: cloudAiProvider == 'gemini'
                            ? "Saisissez votre clé d'activation VIP pour activer le moteur haute performance."
                            : "Saisissez votre clé d'activation Standard pour activer le moteur secondaire.",
                        color: c.violet,
                      ),
                      const SizedBox(height: 16),
                      PremiumSettingsWidgets.buildCompactSwitch(
                        context,
                        title: "Autoriser l'IA à agir sur l'application",
                        subtitle:
                            "L'IA pourra modifier des paramètres et naviguer pour vous",
                        value: allowCloudAiActions,
                        onChanged: onAllowCloudAiActionsChanged,
                        activeThumbColor: c.violet,
                        icon: FluentIcons.bot_24_filled,
                      ),
                      const SizedBox(height: 14),
                      PremiumSettingsWidgets.buildCompactSwitch(
                        context,
                        title: "Réponses IA en temps réel (Streaming)",
                        subtitle:
                            "Affiche les réponses mot par mot sans temps d'attente",
                        value: enableAiStreaming,
                        onChanged: onEnableAiStreamingChanged,
                        activeThumbColor: c.violet,
                        icon: FluentIcons.chat_24_regular,
                      ),
                      const Divider(height: 32),
                      Row(
                        children: [
                          Icon(
                            FluentIcons.speaker_2_24_regular,
                            color: c.violet,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "MOTEUR VOCAL AVANCÉ",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: c.violet,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: elevenLabsApiKeyCtrl,
                        obscureText: true,
                        onChanged: (_) => onSaveDebounced(),
                        style: TextStyle(
                          fontSize: 13,
                          color: c.textPrimary,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          hintText: "Clé d'activation du moteur vocal...",
                          hintStyle: TextStyle(
                            color: c.textMuted,
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: c.surfaceElev,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: c.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: c.violet, width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: c.border),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          suffixIcon: Icon(
                            FluentIcons.eye_off_24_regular,
                            color: c.textMuted,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: elevenLabsVoiceIdCtrl,
                        onChanged: (_) => onSaveDebounced(),
                        style: TextStyle(
                          fontSize: 13,
                          color: c.textPrimary,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          hintText: "Identifiant de la voix sélectionnée...",
                          hintStyle: TextStyle(
                            color: c.textMuted,
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: c.surfaceElev,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: c.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: c.violet, width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: c.border),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildCopilotPermissionsSection(
    BuildContext context,
    WidgetRef ref,
    DashColors c,
    bool isAdmin,
  ) {
    bool getVal(String key) => copilotPermissions[key] ?? true;

    Widget buildToggle(
      String key,
      String title,
      String subtitle,
      IconData icon,
    ) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: PremiumSettingsWidgets.buildCompactSwitch(
          context,
          title: title,
          subtitle: subtitle,
          value: getVal(key),
          onChanged: (v) => onCopilotPermissionChanged(key, v),
          activeThumbColor: c.violet,
          icon: icon,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.violet.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.violet.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PremiumSettingsWidgets.buildIconBadge(
                icon: FluentIcons.shield_keyhole_24_regular,
                color: c.violet,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "PERMISSIONS ET CAPABILITÉS DU COPILOT",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: c.violet,
                        fontSize: 13,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Sélectionnez les actions de l'assistant vocal autorisées à s'exécuter de façon autonome :",
                      style: TextStyle(fontSize: 11, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // ── GROUPE 1 : NAVIGATION & STYLE ──
          _buildGroupHeader(
            "NAVIGATION & APPARENCE",
            FluentIcons.navigation_24_filled,
            c.blue,
          ),
          const SizedBox(height: 10),
          buildToggle(
            'navigate',
            "Navigation inter-pages",
            "Autorise à ouvrir les différentes pages de l'application",
            FluentIcons.navigation_24_regular,
          ),
          buildToggle(
            'change_theme',
            "Changement de thème",
            "Autorise à basculer entre le mode clair et le mode sombre",
            FluentIcons.paint_brush_24_regular,
          ),

          const SizedBox(height: 16),
          // ── GROUPE 2 : LECTURE DE DONNÉES ──
          _buildGroupHeader(
            "CONSULTATION DE DONNÉES",
            FluentIcons.book_open_24_filled,
            c.amber,
          ),
          const SizedBox(height: 10),
          buildToggle(
            'search_product',
            "Recherche de produits",
            "Rechercher des articles, voir leurs prix et fiches produits",
            FluentIcons.search_24_regular,
          ),
          buildToggle(
            'get_stock_info',
            "Rapport de stock",
            "Demander la valeur totale et l'état général du stock",
            FluentIcons.box_multiple_24_regular,
          ),
          buildToggle(
            'get_low_stock_alerts',
            "Alertes de stock bas",
            "Consulter la liste des produits en alerte ou rupture de stock",
            FluentIcons.warning_24_regular,
          ),
          buildToggle(
            'get_client_info',
            "Recherche de clients",
            "Consulter les fiches, numéros de téléphone et dettes clients",
            FluentIcons.person_search_24_regular,
          ),
          buildToggle(
            'get_client_debtors',
            "Liste des débiteurs",
            "Consulter la liste des clients ayant des dettes en cours",
            FluentIcons.people_money_24_regular,
          ),
          buildToggle(
            'get_sales_summary',
            "Statistiques de ventes",
            "Consulter les bilans financiers et chiffres d'affaires",
            FluentIcons.data_usage_24_regular,
          ),
          buildToggle(
            'filter_sales',
            "Recherche & filtre ventes",
            "Rechercher et filtrer l'historique des ventes par statut ou paiement",
            FluentIcons.history_24_regular,
          ),
          buildToggle(
            'compare_sales_periods',
            "Comparaison de périodes",
            "Comparer vocalement le chiffre d'affaires entre deux périodes",
            FluentIcons.arrow_trending_24_regular,
          ),
          buildToggle(
            'get_top_profitable_items',
            "Articles les plus rentables",
            "Lister les articles qui génèrent le plus de bénéfices",
            FluentIcons.money_hand_24_regular,
          ),

          const SizedBox(height: 16),
          // ── GROUPE 3 : ACTIONS & ACTIONS D'ÉCRITURE ──
          _buildGroupHeader(
            "MODIFICATION DE DONNÉES (ÉCRITURE)",
            FluentIcons.edit_24_filled,
            c.rose,
          ),
          const SizedBox(height: 10),
          buildToggle(
            'add_to_cart',
            "Ajouter au panier POS",
            "Ajouter vocalement des articles dans la vente en cours",
            FluentIcons.cart_24_regular,
          ),
          buildToggle(
            'remove_from_cart',
            "Retirer du panier POS",
            "Retirer un produit du panier en cours de vente",
            FluentIcons.dismiss_24_regular,
          ),
          buildToggle(
            'clear_cart',
            "Vider le panier POS",
            "Annuler et vider tout le panier en cours de vente",
            FluentIcons.delete_24_regular,
          ),
          buildToggle(
            'add_product',
            "Création de produit",
            "Ajouter un nouveau produit à l'inventaire en stock",
            FluentIcons.add_square_24_regular,
          ),
          buildToggle(
            'update_product',
            "Mise à jour produit",
            "Modifier la description, le prix ou d'autres infos d'un produit",
            FluentIcons.edit_24_regular,
          ),
          buildToggle(
            'delete_product',
            "Suppression produit",
            "Retirer définitivement un produit de l'inventaire (Action sensible)",
            FluentIcons.delete_24_regular,
          ),
          buildToggle(
            'adjust_stock',
            "Ajustement de stock",
            "Modifier la quantité d'un produit (entrée/sortie d'inventaire)",
            FluentIcons.arrow_sync_24_regular,
          ),
          buildToggle(
            'add_client',
            "Création de client",
            "Enregistrer un nouveau profil client dans la base",
            FluentIcons.person_add_24_regular,
          ),
          buildToggle(
            'update_client',
            "Mise à jour client",
            "Modifier les coordonnées ou le crédit autorisé d'un client",
            FluentIcons.person_edit_24_regular,
          ),
          buildToggle(
            'delete_client',
            "Suppression client",
            "Retirer définitivement un client de la base de données",
            FluentIcons.delete_24_regular,
          ),
          buildToggle(
            'settle_client_debt',
            "Règlement de dette client",
            "Enregistrer les remboursements de dette d'un client",
            FluentIcons.person_money_24_regular,
          ),
          buildToggle(
            'manage_sale',
            "Actions de vente (rembourser/ticket)",
            "Réimprimer, afficher les détails ou rembourser une vente",
            FluentIcons.receipt_24_regular,
          ),

          if (isAdmin) ...[
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildGroupHeader(
                  "CONSIGNES & INSTRUCTIONS PERSONNALISÉES (${ref.watch(assistantMemoryProvider).length})",
                  FluentIcons.brain_circuit_24_regular,
                  c.violet,
                ),
                TextButton.icon(
                  icon: Icon(
                    FluentIcons.add_16_regular,
                    color: c.violet,
                    size: 16,
                  ),
                  label: Text(
                    "Ajouter",
                    style: TextStyle(color: c.violet, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showAddMemoryDialog(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...() {
              final memories = ref.watch(assistantMemoryProvider);
              if (memories.isEmpty) {
                return [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      "L'assistant n'a mémorisé aucune consigne ou fait pour l'instant. Parlez-lui ou écrivez-lui pour lui dire de se souvenir de quelque chose, ou cliquez sur 'Ajouter' !",
                      style: TextStyle(
                        fontSize: 12,
                        color: c.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ];
              }
              return [
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: memories.length,
                  itemBuilder: (context, index) {
                    final m = memories[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.surfaceElev,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: c.border.withValues(alpha: 0.4),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              FluentIcons.brain_circuit_20_regular,
                              size: 18,
                              color: c.violet,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.fact,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: c.textPrimary,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Mémorisé le ${_formatDateTime(m.createdAt)}",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: c.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (m.id != 'danaya_founder_fact') ...[
                              IconButton(
                                icon: Icon(
                                  FluentIcons.edit_16_regular,
                                  color: c.textMuted,
                                  size: 16,
                                ),
                                onPressed: () => _showEditMemoryDialog(context, ref, m),
                                tooltip: "Modifier la consigne",
                              ),
                              IconButton(
                                icon: Icon(
                                  FluentIcons.delete_16_regular,
                                  color: c.rose,
                                  size: 16,
                                ),
                                onPressed: () {
                                  ref
                                      .read(assistantMemoryProvider.notifier)
                                      .deleteMemory(m.id);
                                },
                                tooltip: "Supprimer la consigne",
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: Icon(
                      FluentIcons.delete_16_regular,
                      color: c.rose,
                      size: 16,
                    ),
                    label: Text(
                      "Effacer toute la mémoire",
                      style: TextStyle(color: c.rose, fontSize: 12),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("Effacer toute la mémoire ?"),
                          content: const Text(
                            "Voulez-vous vraiment supprimer définitivement toutes les instructions et préférences enregistrées par l'assistant ?",
                          ),
                          actions: [
                            TextButton(
                              child: const Text("Annuler"),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                            TextButton(
                              child: Text(
                                "Oui, tout effacer",
                                style: TextStyle(color: c.rose),
                              ),
                              onPressed: () {
                                ref
                                    .read(assistantMemoryProvider.notifier)
                                    .clearMemories();
                                Navigator.pop(ctx);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ];
            }(),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ],
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
                Text(
                  "APERCU DE LA PROCHAINE RÉFÉRENCE",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: c.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  preview,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: c.blue,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMemoryDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ajouter une instruction"),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Ex: Le patron s'appelle Amadou. Toujours utiliser le vouvoiement.",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Annuler"),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: const Text("Ajouter"),
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                await ref.read(assistantMemoryProvider.notifier).saveMemory(text);
              }
              if (context.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showEditMemoryDialog(BuildContext context, WidgetRef ref, MemoryFact memory) {
    final controller = TextEditingController(text: memory.fact);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Modifier la consigne"),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Annuler"),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: const Text("Enregistrer"),
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                await ref.read(assistantMemoryProvider.notifier).updateMemory(memory.id, text);
              }
              if (context.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
}
