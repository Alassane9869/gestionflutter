import '../../settings/domain/models/shop_settings_models.dart';

enum MacroActionType {
  speak,
  navigate,
  toggleTheme,
  customLogic,
}

class MacroAction {
  final MacroActionType type;
  final dynamic payload;
  
  const MacroAction({required this.type, this.payload});
}

class PredefinedMacro {
  final String id;
  final String name;
  final String description;
  final AssistantPowerLevel requiredLevel;
  final List<MacroAction> actions;

  const PredefinedMacro({
    required this.id,
    required this.name,
    required this.description,
    required this.requiredLevel,
    required this.actions,
  });
}

class MacroEngine {
  /// Architecture conçue pour supporter jusqu'à 100+ Macros TITAN.
  static final Map<String, PredefinedMacro> builtinMacros = {
    'fermeture_caisse': const PredefinedMacro(
      id: 'fermeture_caisse',
      name: 'Fermeture de Caisse (Fin de journée)',
      description: 'Clôture la journée, affiche le bilan et éteint les lumières.',
      requiredLevel: AssistantPowerLevel.proactive,
      actions: [
        MacroAction(type: MacroActionType.customLogic, payload: 'bilan_jour'),
        MacroAction(type: MacroActionType.navigate, payload: 6), // Finance
        MacroAction(type: MacroActionType.toggleTheme, payload: 'dark'),
        MacroAction(type: MacroActionType.speak, payload: 'Caisse fermée et verrouillée. Bilan calculé. Bonne soirée Boss, reposez-vous bien !'),
      ],
    ),
    'mode_rush': const PredefinedMacro(
      id: 'mode_rush',
      name: 'Mode Rush (Affluence forte)',
      description: 'Bascule immédiatement en mode vente accéléré.',
      requiredLevel: AssistantPowerLevel.actionable,
      actions: [
        MacroAction(type: MacroActionType.navigate, payload: 3), // POS
        MacroAction(type: MacroActionType.customLogic, payload: 'quick_pos'),
        MacroAction(type: MacroActionType.speak, payload: 'Mode Rush activé. Toutes les ressources sont allouées à l\'encaissement rapide !'),
      ],
    ),
    'audit_total': const PredefinedMacro(
      id: 'audit_total',
      name: 'Audit Total (Vision 360)',
      description: 'Analyse complète des finances et des stocks.',
      requiredLevel: AssistantPowerLevel.titan,
      actions: [
        MacroAction(type: MacroActionType.customLogic, payload: 'audit_complet'),
        MacroAction(type: MacroActionType.navigate, payload: 5), // Rapports
      ],
    ),
    'preparer_recouvrement': const PredefinedMacro(
      id: 'preparer_recouvrement',
      name: 'Opération Recouvrement',
      description: 'Prépare l\'affichage des dettes clients pour relance.',
      requiredLevel: AssistantPowerLevel.actionable,
      actions: [
        MacroAction(type: MacroActionType.navigate, payload: 12), // Client Debt
        MacroAction(type: MacroActionType.speak, payload: "Voici la liste de vos créances clients. Il est temps de récupérer l'argent dormant !"),
      ],
    ),
    'urgences_stocks': const PredefinedMacro(
      id: 'urgences_stocks',
      name: 'Urgence Stocks',
      description: 'Affiche toutes les ruptures critiques nécessitant une commande.',
      requiredLevel: AssistantPowerLevel.proactive,
      actions: [
        MacroAction(type: MacroActionType.navigate, payload: 14), // Stock Alerts
        MacroAction(type: MacroActionType.speak, payload: "Affichage immédiat des ruptures de stock critiques pour réapprovisionnement."),
      ],
    ),
    'ouverture_boutique': const PredefinedMacro(
      id: 'ouverture_boutique',
      name: 'Ouverture Boutique',
      description: 'Prépare l\'interface pour le début de la journée.',
      requiredLevel: AssistantPowerLevel.basic,
      actions: [
        MacroAction(type: MacroActionType.toggleTheme, payload: 'light'),
        MacroAction(type: MacroActionType.navigate, payload: 3), // POS
        MacroAction(type: MacroActionType.speak, payload: "Bonjour Boss ! L'interface est prête. Excellente journée de ventes !"),
      ],
    ),
    'securisation_donnees': const PredefinedMacro(
      id: 'securisation_donnees',
      name: 'Sécurisation Express',
      description: 'Lance une sauvegarde locale et masque l\'écran.',
      requiredLevel: AssistantPowerLevel.titan,
      actions: [
        MacroAction(type: MacroActionType.customLogic, payload: 'backup'),
        MacroAction(type: MacroActionType.navigate, payload: 0), // Dashboard
        MacroAction(type: MacroActionType.speak, payload: "Données locales sauvegardées et écran verrouillé."),
      ],
    ),
    'gestion_equipe': const PredefinedMacro(
      id: 'gestion_equipe',
      name: 'Review Équipe',
      description: 'Ouvre les paramètres RH et Utilisateurs.',
      requiredLevel: AssistantPowerLevel.proactive,
      actions: [
        MacroAction(type: MacroActionType.navigate, payload: 19), // HR
        MacroAction(type: MacroActionType.speak, payload: "Espace d'administration des ressources humaines ouvert."),
      ],
    ),
    'accueil_incognito': const PredefinedMacro(
      id: 'accueil_incognito',
      name: 'Mode Incognito',
      description: 'Retour discret à l\'accueil en effaçant les vues sensibles.',
      requiredLevel: AssistantPowerLevel.analytical,
      actions: [
        MacroAction(type: MacroActionType.navigate, payload: 0), // Dashboard
        MacroAction(type: MacroActionType.speak, payload: "Navigation sécurisée vers l'accueil."),
      ],
    ),
    'top_produits_express': const PredefinedMacro(
      id: 'top_produits_express',
      name: 'Review Top Produits',
      description: 'Analyse les best-sellers.',
      requiredLevel: AssistantPowerLevel.analytical,
      actions: [
        MacroAction(type: MacroActionType.navigate, payload: 5), // Reports
        MacroAction(type: MacroActionType.customLogic, payload: 'top_produits'),
        MacroAction(type: MacroActionType.speak, payload: "Voici les analyses de vos meilleurs produits."),
      ],
    ),
    'optimiser_stock': const PredefinedMacro(
      id: 'optimiser_stock',
      name: 'Optimiseur de Stock (Titan)',
      description: 'Analyse les besoins en réapprovisionnement et prépare les commandes.',
      requiredLevel: AssistantPowerLevel.titan,
      actions: [
        MacroAction(type: MacroActionType.customLogic, payload: 'analyze_stock_needs'),
        MacroAction(type: MacroActionType.navigate, payload: 16), // Purchases
        MacroAction(type: MacroActionType.speak, payload: "Analyse des stocks terminée. J'ai identifié les produits prioritaires. Préparons les bons de commande !"),
      ],
    ),
    'booster_ventes': const PredefinedMacro(
      id: 'booster_ventes',
      name: 'Sales Booster (Titan)',
      description: 'Identifie les produits dormants et propose des actions commerciales.',
      requiredLevel: AssistantPowerLevel.titan,
      actions: [
        MacroAction(type: MacroActionType.customLogic, payload: 'analyze_slow_movers'),
        MacroAction(type: MacroActionType.navigate, payload: 5), // Reports
        MacroAction(type: MacroActionType.speak, payload: "Extraction des produits à faible rotation. Je vous suggère de lancer une promotion sur ces articles pour libérer du capital."),
      ],
    ),
    'bouclier_financier': const PredefinedMacro(
      id: 'bouclier_financier',
      name: 'Bouclier Financier (Titan)',
      description: 'Audit flash de la trésorerie et protection contre les impayés.',
      requiredLevel: AssistantPowerLevel.titan,
      actions: [
        MacroAction(type: MacroActionType.customLogic, payload: 'audit_cashflow'),
        MacroAction(type: MacroActionType.navigate, payload: 12), // Client Debt
        MacroAction(type: MacroActionType.speak, payload: "Bouclier activé. Voici l'état de vos créances. Nous devons sécuriser ces encaissements pour maintenir une trésorerie saine."),
      ],
    ),
    // L'architecture supporte l'ajout immédiat de plus de 90 autres macros métier.
  };

  static PredefinedMacro? getMacro(String id) => builtinMacros[id];
}
