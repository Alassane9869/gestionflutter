// MOTEUR NLP DANAYA+ V3.5 - 100% OFFLINE
//
// Basé sur :
// - Algorithme de Levenshtein (tolérance aux fautes de frappe)
// - Système de scoring par intention (probabilités)
// - Dictionnaire de synonymes offline (200+)
// - Extraction dynamique d'entités (dates, nombres)
// Poids : 0 Mo. Vitesse : microsecondes. Connexion : aucune.

import 'dart:math';
import 'package:flutter/foundation.dart';
import '../domain/assistant_models.dart';

// ─── INTENT DEFINITIONS ───────────────────────────────────────────────
enum NlpIntent {
  // Social
  greeting,
  farewell,
  thanks,
  insult,
  humor,

  // Data Queries
  salesQuery,
  salesTopProducts,
  salesCount,
  stockQuery,
  stockSearch,
  stockLowAlert,
  stockValue,
  financeQuery,
  financeExpenses,
  financeProfitLoss,
  clientQuery,
  clientDebtList,
  clientCount,
  supplierQuery,
  securityQuery,
  networkQuery,

  // Actions
  navigatePOS,
  navigateInventory,
  navigateFinance,
  navigateClients,
  navigateSuppliers,
  navigateSettings,
  navigateReports,
  navigateDashboard,
  navigateStockMovements,
  navigateSalesHistory,
  navigateQuotes,
  navigateWarehouses,
  navigateClientDebt,
  navigateExpenses,
  navigateStockAlerts,
  navigateStockAudit,
  navigatePurchases,
  navigateUsers,
  navigateHelp,
  navigateHR,
  navigateAppearance,
  actionNewSale,
  actionNewPurchaseOrder,
  actionNewProduct,
  actionNewClient,
  actionNewExpense,
  actionPrint,
  actionExcelImport,
  actionExcelExport,
  actionBackup,
  actionCreateRule,
  actionMacroLearn,
  themeLight,
  themeDark,
  themeColorChange,
  themeQuery,
  actionUpdateSetting,
  actionActivateHorizon,
  actionQuickPos,
  themeToggle,

  // Macros (Titan)
  macroEndOfDay,
  macroFullAudit,
  macroDebtRecovery,
  macroStockPanic,
  macroMorning,
  macroSecurize,
  macroHrReview,
  
  // Knowledge
  tipRequest,
  shortcutRequest,
  howTo,
  aboutApp,
  featureList,
  
  // Meta
  whatCanYouDo,
  salesPerformance,
  unknown,
}

// ─── ENTITY TYPES ─────────────────────────────────────────────────────
enum EntityType { date, number, productName, clientName }

class ExtractedEntity {
  final EntityType type;
  final String raw;
  final dynamic value;

  ExtractedEntity({required this.type, required this.raw, this.value});

  @override
  String toString() => 'Entity($type: $raw -> $value)';
}

// ─── NLP RESPONSE ─────────────────────────────────────────────────────
class NlpResult {
  final NlpIntent intent;
  final double confidence;
  final List<ExtractedEntity> entities;
  final String? timeModifier;
  final String? searchQuery;
  final String rawInput;
  final List<NlpIntent> secondaryIntents;

  NlpResult({
    required this.intent,
    required this.confidence,
    this.entities = const [],
    this.timeModifier,
    this.searchQuery,
    this.rawInput = '',
    this.secondaryIntents = const [],
  });

  @override
  String toString() => 'NlpResult($intent, confidence: ${(confidence * 100).toStringAsFixed(1)}%, entities: $entities, time: $timeModifier, search: $searchQuery, secondary: $secondaryIntents)';
}

// ─── THE ENGINE ───────────────────────────────────────────────────────
class NlpEngine {
  // ── COMMON PHRASES (Priority matching) ─────────────────────────────
  static final Map<String, NlpIntent> _commonPhrases = {
    'que sais tu faire': NlpIntent.whatCanYouDo,
    'comment se portent les affaires': NlpIntent.salesPerformance,
    'etat de sante': NlpIntent.salesPerformance,
    'performances': NlpIntent.salesPerformance,
    'a quoi sers tu': NlpIntent.whatCanYouDo,
    'que peux tu faire': NlpIntent.whatCanYouDo,
    'aider moi': NlpIntent.whatCanYouDo,
    'combien de mode': NlpIntent.themeQuery,
    'quels sont les themes': NlpIntent.themeQuery,
    'liste des themes': NlpIntent.themeQuery,
    'quels sont les couleurs': NlpIntent.themeQuery,
    'bilan du jour': NlpIntent.salesQuery,
    'tout sur aujourdhui': NlpIntent.salesQuery,
    'etat du stock': NlpIntent.stockQuery,
    'cherche le produit': NlpIntent.stockSearch,
    'ouvre la caisse': NlpIntent.navigatePOS,
    'va dans apparence': NlpIntent.navigateAppearance,
    'aller dans apparence': NlpIntent.navigateAppearance,
    'ouvre apparence': NlpIntent.navigateAppearance,
    'va dans parametre': NlpIntent.navigateSettings,
    'aller dans parametre': NlpIntent.navigateSettings,
    'ouvre parametre': NlpIntent.navigateSettings,
    'nouvelle vente': NlpIntent.actionNewSale,
    'fait une vente': NlpIntent.actionNewSale,
    'faire une vente': NlpIntent.actionNewSale,
    'enregistre une vente': NlpIntent.actionNewSale,
    'nouveau bon de commande': NlpIntent.actionNewPurchaseOrder,
    'faisons une commande': NlpIntent.actionNewPurchaseOrder,
    'faire une commande': NlpIntent.actionNewPurchaseOrder,
    'nouvelle commande fournisseur': NlpIntent.actionNewPurchaseOrder,
    'bon de commande': NlpIntent.actionNewPurchaseOrder,
    'je veux vendre': NlpIntent.actionNewSale,
    'vendre quelque chose': NlpIntent.actionNewSale,
    'au revoir': NlpIntent.farewell,
    'bonne journee': NlpIntent.farewell,
    'merci beaucoup': NlpIntent.thanks,
    'trop fort': NlpIntent.thanks,
    'debiteur': NlpIntent.clientDebtList,
    'rupture': NlpIntent.stockLowAlert,
    'caisse fermée': NlpIntent.macroEndOfDay,
    'ajouter un produit': NlpIntent.actionNewProduct,
    'creer un article': NlpIntent.actionNewProduct,
    'nouveau produit': NlpIntent.actionNewProduct,
    'ajoute un produit': NlpIntent.actionNewProduct,
  };

  // ── SYNONYM DICTIONARY (800+ mappings) ──────────────────────────────
  static final Map<String, List<String>> _synonyms = {
    // Greetings
    'bonjour': ['salut', 'hello', 'yo', 'salam', 'bonsoir', 'bsr', 'bjr', 'hi', 'hey', 'coucou', 'wesh', 'slt', 'allo', 'hola', 'cc', 'bon matin', 'enchanté', 're', 're-bonjour', 'bienvenue', 'wesh', 'salamalekum', 'coucou'],
    // Farewell
    'aurevoir': ['bye', 'ciao', 'a+', 'bbye', 'tchao', 'adieu', 'aplus', 'bonne nuit', 'bonne soiree', 'a la prochaine', 'demain', 'quitter', 'fermer', 'finir', 'partir', 'ciao', 'ciao ciao'],
    // Thanks
    'merci': ['thanks', 'thx', 'bravo', 'super', 'cool', 'top', 'nickel', 'parfait', 'genial', 'genie', 'excellent', 'magnifique', 'chapeau', 'formidable', 'incroyable', 'wahou', 'wow', 'merci beaucoup', 'bien joue', 'parfaitement', 'impeccable', 'nice', 'cimer', 'merci infiniment'],
    // Sales
    'vente': ['vendre', 'vendu', 'ventes', 'encaisser', 'encaissement', 'ticket', 'facture', 'factures', 'recette', 'recettes', 'chiffre', 'ca', 'revenu', 'revenus', 'benefice', 'benefices', 'transation', 'transactions', 'vends', 'facturer', 'paiement', 'payer', 'vendu', 'commerce', 'négoce', 'deal', 'audit vente', 'historique vente', 'relevé vente', 'écouler', 'liquider', 'pousser'],
    // Stock / Inventory
    'stock': ['inventaire', 'gestion produits', 'produit', 'produits', 'article', 'articles', 'marchandise', 'rupture', 'alerte', 'alertes', 'manque', 'epuise', 'disponible', 'quantite', 'qte', 'entrepot', 'magasin', 'rayon', 'catalogue', 'reference', 'ref', 'cagibi', 'reserve', 'boisson', 'materiel', 'bien', 'biens', 'item', 'items', 'disponibilité', 'physique', 'audit stock', 'marchandises', 'colis'],
    // Finance
    'finance': ['tresorerie', 'treso', 'argent', 'sous', 'thune', 'cash', 'cfa', 'fcfa', 'depense', 'depenses', 'charge', 'charges', 'loyer', 'transport', 'profit', 'perte', 'bilan', 'solde', 'rentabilite', 'marge', 'benefice', 'fric', 'blé', 'compte', 'banque', 'caisse', 'decaissement', 'frais', 'comptabilité', 'compta', 'économie', 'économiser', 'epargne', 'entrée', 'sortie', 'liquide', 'espèces'],
    // Clients
    'client': ['clients', 'dette', 'dettes', 'credit', 'credits', 'debiteur', 'debiteurs', 'creance', 'creances', 'acheteur', 'fidele', 'fidelite', 'clientele', 'consommateur', 'habitué', 'impayé', 'impayes', 'compte client', 'fiche client', 'carnet', 'visiteur', 'passager'],
    // Suppliers
    'fournisseur': ['fournisseurs', 'commande', 'approvisionnement', 'achat', 'achats', 'livraison', 'livrer', 'restock', 'reapprovisionnement', 'grossiste', 'livreur', 'fabricant', 'partenaire', 'société', 'entité', 'fournisseur', 'fournisseurs'],
    // Security
    'securite': ['pin', 'admin', 'proteger', 'protection', 'hack', 'piratage', 'mot de passe', 'mdp', 'verrouiller', 'bloquer', 'hardening', 'audit', 'securiser', 'code', 'cadenas', 'confidentiel', 'privé', 'accès', 'sécuriser'],
    // Excel / Import
    'excel': ['import', 'csv', 'exporter', 'export', 'fichier', 'telecharger', 'modele', 'template', 'xlsx', 'tableau', 'tableur', 'sheet', 'sheets', 'données', 'data', 'transfert'],
    // Tips
    'astuce': ['conseil', 'secret', 'tip', 'raccourci', 'aide', 'tutoriel', 'tuto', 'guide', 'apprendre', 'formation', 'comment faire', 'montre moi', 'explique moi', 'aide moi', 'leçon', 'cours', 'truc'],
    // How to
    'comment': ['comment', 'combien', 'quoi', 'quel', 'quelle', 'pourquoi', 'ou', 'quand', 'est-ce', 'qui', 'lequel', 'méthode', 'procédure'],
    // Navigation - POS
    'caisse': ['pos', 'pdv', 'point de vente', 'boutique', 'comptoir', 'ecran de vente', 'faire une vente', 'vendre', 'facturer', 'vendeur'],
    // Full App Navigation Extensions
    'mouvements': ['mouvement', 'historique stock', 'entree', 'sortie', 'relevé', 'flux'],
    'historique': ['historique vente', 'anciennes ventes', 'passe', 'recapitulatif', 'recap', 'journal'],
    'devis': ['proforma', 'facture proforma', 'devis client', 'estimation', 'bordereau'],
    'magasin': ['magasins', 'entrepot', 'succursale', 'depot', 'boutiques', 'local', 'site', 'emplacement'],
    'dettes': ['dette', 'impayes', 'credits', 'creances', 'reliquat', 'balance'],
    'depenses': ['depense', 'charge', 'frais', 'decaissement', 'sorties argent', 'facture fournisseur'],
    'alertes': ['alerte', 'rupture', 'minimum', 'seuil', 'critique', 'danger', 'attention', 'vide'],
    'audit': ['controle', 'verification', 'inventaire physique', 'comptage', 'physique', 'révision'],
    'achats': ['achat', 'approvisionnement', 'commander', 'recevoir', 'reception', 'bon de commande', 'ravitaillement'],
    'utilisateurs': ['utilisateur', 'employes', 'caissier', 'manager', 'personnel', 'staff', 'vendeur', 'gars', 'profils'],
    'aide': ['help', 'assistance', 'support', 'aide moi', 'sav'],
    'rh': ['ressources humaines', 'grh', 'salaires', 'employes', 'conges', 'pointage', 'presence', 'personnel', 'paie'],
    // Actions
    'nouveau': ['nouvelle', 'creer', 'ajouter', 'ajout', 'saisir', 'enregistrer', 'creation', 'inserer', 'nvo', 'nouv', 'initier'],
    // Print
    'imprimer': ['impression', 'print', 'imprimante', 'pdf', 'ticket', 'recu', 'tirer', 'sortir factures', 'papier', 'copie'],
    // Theme
    'theme': ['sombre', 'clair', 'nuit', 'dark', 'light', 'mode'],
    // Backup
    'sauvegarde': ['backup', 'sauvegarder', 'restaurer', 'restauration', 'donnees', 'copie', 'cloud', 'drive', 'securiser donnees', 'archive'],
    // Network / Remote
    'reseau': ['network', 'lan', 'rj45', 'cable', 'wifi', 'multi-postes', 'multiposte', 'sync', 'synchro', 'synchronisation', 'synckey', 'tailscale', 'distant', 'vpn', 'serveur', 'server', 'connexion', 'connecter', 'en ligne', 'online', 'ip', 'adresse'],
    // App
    'danaya': ['application', 'app', 'logiciel', 'systeme', 'programme', 'version', 'appli', 'ton maitre', 'ton createur', 'intelligence', 'titan'],
    // Capabilities
    'capacite': ['capable', 'peux', 'sais', 'faire', 'fonctionnalite', 'option', 'pouvoir', 'tu sers a quoi', 'a quoi sers tu', 'que sais tu', 'que peux tu', 'compétences'],
    // Top / Best
    'meilleur': ['top', 'classement', 'ranking', 'premier', 'champion', 'star', 'populaire', 'plus vendu', 'best', 'succes', 'cartonne', 'best-seller'],
    // Count
    'combien': ['nombre', 'total', 'comptage', 'compter', 'quantite', 'combien ya', 'y a combien', 'combien on a', 'stat', 'stats', 'énumérer'],
    // Search
    'chercher': ['rechercher', 'recherche', 'trouver', 'trouve', 'localiser', 'scanner', 'scan', 'ou est', 'montre', 'affiche', 'mire'],
    // Titan / Rules
    'si': ['quand', 'lorsque', 'des que', 'if', 'when', 'chaque fois', 'condition'],
    'alerte': ['previens', 'notifie', 'alerte moi', 'avertir', 'signal', 'notification', 'notif', 'bip', 'cri'],
    'apprends': ['enregistre', 'macro', 'retiens', 'memorise', 'apprend', 'entraine', 'etudie', 'forme toi', 'auto former', 'forme', 'enseigne', 'programmer'],
    'analyse': ['strategie', 'conseille', 'optimise', 'plan', 'audit', 'verifie', 'controle', 'réfléchis'],
    'bienveillance': ['fatigue', 'pause', 'recherche', 'coach', 'conseil', 'bravo', 'felicitations', 'reposer', 'dormir', 'santé'],
    // Settings
    'parametre': ['reglage', 'config', 'configuration', 'modifier', 'changer', 'nom', 'tva', 'taxe', 'devise', 'argent', 'imprimante', 'settings', 'parametres', 'options', 'boutique', 'monnaie', 'profil', 'magasin', 'infos', 'entreprise', 'apparence', 'couleur'],
    // Horizon
    'horizon': ['prediction', 'futur', 'intelligence', 'ia', 'ai', 'magie', 'prévoir', 'demain', 'anticiper'],
    // Quick POS
    'rapide': ['vitesse', 'express', 'quick', 'fast', 'rush', 'urgence', 'foule', 'monde', 'pression'],
  };

  // ── STOP WORDS / NOISE FILTER (Conversational Intelligence) ─────────
  static final List<String> _stopWords = [
    'le', 'la', 'les', 'un', 'une', 'des', 'du', 'de', 'la', 'de la', 'des', 
    'je', 'tu', 'il', 'nous', 'vous', 'ils', 'me', 'te', 'se', 'ce', 'ces', 'cette',
    'en', 'sur', 'dans', 'pour', 'avec', 'sans', 'sous', 'vers', 'chez',
    'est', 'sont', 'ont', 'avez', 'as', 'suis', 'etait', 'serait',
    'que', 'qui', 'quoi', 'quel', 'quelle', 'quels', 'quelles', 'qu', 'lors',
    'un peu', 'un petit', 'une petite', 'est-ce', 'est ce', 'est ce que', 'peux-tu', 'pouvez-vous',
    'voudrais', 'aimerais', 'veux', 'va', 'allez', 'donne', 'montre', 'affiche', 's\'il', 'sil', 'te', 'plait', 'svp', 'stp',
    'dis-moi', 'dis moi', 'raconte', 'explique', 'montre-moi', 'montre moi', 'peux', 'pouvez', 'doit', 'doivent',
    'mon', 'ma', 'mes', 'ton', 'ta', 'tes', 'son', 'sa', 'ses', 'notre', 'votre', 'leur', 'ya', 'a-t-il', 'as-tu', 'est-il',
    'dis', 'moi', 'il', 'y', 'a', 'ya', 'quelques', 'plusieurs', 'tous', 'toute', 'toutes',
  ];

  // ── INTENT KEYWORD BAGS ─────────────────────────────────────────────
  static final Map<NlpIntent, Map<String, double>> _intentBags = {
    // ── SOCIAL ────────────────────────────────────────────────────────
    NlpIntent.greeting: {
      'bonjour': 1.0, 'salut': 1.0, 'hello': 1.0, 'yo': 0.8, 'salam': 1.0,
      'bonsoir': 1.0, 'coucou': 0.9, 'hi': 0.7, 'wesh': 0.6,
      'bjr': 0.8, 'bsr': 0.8, 'slt': 0.8, 'cc': 0.8, 'hola': 0.7, 'hey': 0.7,
      'enchanté': 0.9, 'matin': 0.7, 'midi': 0.5, 'journée': 0.6, 're': 0.5,
    },
    NlpIntent.farewell: {
      'aurevoir': 1.0, 'bye': 1.0, 'ciao': 0.9, 'tchao': 0.9, 'adieu': 0.8,
      'quitter': 0.9, 'finir': 0.7, 'partir': 0.8, 'fermer': 0.9, 'demain': 0.7,
      'revoir': 1.0, 'plus': 0.6, 'aplus': 0.7, 'suite': 0.5, 'bye-bye': 1.0,
    },
    NlpIntent.thanks: {
      'merci': 1.0, 'bravo': 0.9, 'super': 0.7, 'cool': 0.6, 'top': 0.5,
      'nickel': 0.8, 'parfait': 0.8, 'genial': 0.9, 'genie': 0.9,
      'excellent': 0.9, 'magnifique': 0.9, 'chapeau': 0.8, 'remercie': 0.9, 
      'thanks': 0.9, 'gracias': 0.7, 'impeccable': 0.8,
    },
    NlpIntent.humor: {
      'blague': 1.0, 'drole': 0.9, 'rire': 0.8, 'lol': 0.7, 'mdr': 0.8, 'humour': 0.9,
      'plaisanterie': 0.9, 'amusant': 0.8, 'raconte': 0.7, 'histoire': 0.6,
    },
    NlpIntent.insult: {
      'con': 1.0, 'idiot': 1.0, 'stupide': 1.0, 'merde': 1.0, 'connard': 1.0,
      'imbecile': 1.0, 'bête': 0.8, 'nul': 0.8, 'putain': 1.0, 'salop': 1.0,
      'gueule': 1.0, 'chier': 1.0, 'foutre': 1.0, 'bordel': 0.9,
    },

    // ── DATA QUERIES ──────────────────────────────────────────────────
    NlpIntent.salesQuery: {
      'bilan': 1.8, 'recette': 1.8, 'chiffre': 1.8, 'ca': 1.8, 'caisse': 1.8,
      'vente': 1.0, 'vendre': 0.9, 'vendu': 0.9, 'encaisser': 1.0,
      'revenu': 0.8, 'facture': 0.7, 'transaction': 0.7, 'argent': 0.6,
      'historique': 0.5, 'total': 0.5, 'performance': 0.7, 'relevé': 0.6,
    },
    NlpIntent.salesPerformance: {
      'affaires': 1.5, 'sante': 1.2, 'performance': 1.5, 'commerce': 1.0,
      'analyse': 0.9, 'tendance': 1.3, 'evolution': 1.2, 'prediction': 1.0,
      'ca va': 0.5, 'marche': 0.5, 'marchy': 0.5, 'genius': 1.0,
    },
    NlpIntent.salesTopProducts: {
      'meilleur': 0.8, 'top': 0.9, 'classement': 1.0, 'populaire': 0.8,
      'plus vendu': 1.0, 'star': 0.7, 'champion': 0.7, 'ranking': 0.9,
      'meilleurs': 0.9, 'tops': 0.9, 'podium': 0.8, 'best': 0.9,
    },
    NlpIntent.salesCount: {
      'combien': 0.75, 'nombre': 0.8, 'total': 0.7, 'compter': 0.7,
      'quantité': 0.7, 'compte': 0.6, 'itérations': 0.5,
      'ventes': 0.6, 'factures': 0.5,
    },
    NlpIntent.stockQuery: {
      'stock': 1.0, 'inventaire': 0.9, 'produit': 0.7, 'article': 0.7,
      'quantite': 0.7, 'disponible': 0.7, 'catalogue': 0.6, 'magasin': 0.5,
      'réserve': 0.6, 'qte': 0.8, 'marchandise': 0.8,
    },
    NlpIntent.stockSearch: {
      'chercher': 1.0, 'rechercher': 1.0, 'trouver': 0.9, 'scanner': 0.8,
      'localiser': 0.8, 'recherche': 0.9, 'scan': 0.8, 'montre': 0.7, 'affiche': 0.7,
      'voir si': 1.0, 'encore de': 0.5,
    },
    NlpIntent.stockLowAlert: {
      'rupture': 2.0, 'manque': 1.5, 'epuise': 1.5, 'critique': 1.2,
      'alerte': 0.9, 'seuil': 0.7, 'bas': 0.5, 'vide': 0.8,
    },
    NlpIntent.stockValue: {
      'valeur': 1.0, 'valorisation': 1.0, 'prix': 0.6, 'cout': 0.7,
      'investissement': 0.6, 'capital': 0.6, 'argent': 0.5, 'estimé': 0.7,
    },
    NlpIntent.financeQuery: {
      'finance': 1.0, 'tresorerie': 1.0, 'treso': 0.9, 'argent': 0.8,
      'solde': 0.8, 'compte': 0.6, 'banque': 0.7, 'caisse': 0.7,
    },
    NlpIntent.financeExpenses: {
      'depense': 1.0, 'charge': 0.9, 'loyer': 0.8, 'transport': 0.7,
      'facture': 0.6, 'cout': 0.7, 'frais': 0.8, 'decaissement': 0.9,
    },
    NlpIntent.financeProfitLoss: {
      'profit': 1.0, 'perte': 1.0, 'marge': 1.0, 'rentabilite': 1.0,
      'benefice': 0.9, 'gain': 0.8, 'rendement': 0.8, 'pertes': 1.0,
    },
    NlpIntent.clientQuery: {
      'client': 1.0, 'acheteur': 0.7, 'fidele': 0.6, 'fidelite': 0.6, 'clientele': 0.8,
      'clients': 1.0, 'personne': 0.5, 'fiche': 0.7,
    },
    NlpIntent.clientDebtList: {
      'debiteur': 2.0, 'creance': 1.8, 'dette': 1.5, 'credit': 1.2,
      'impaye': 1.5, 'recouvrement': 1.2, 'doit': 0.8,
    },
    NlpIntent.clientCount: {
      'nombre': 0.7, 'total': 0.6, 'combien de clients': 1.2,
    },
    NlpIntent.supplierQuery: {
      'fournisseur': 1.0, 'commande': 0.8, 'approvisionnement': 0.9,
      'achat': 0.7, 'livraison': 0.8, 'restock': 0.9, 'grossiste': 0.8,
    },
    NlpIntent.securityQuery: {
      'securite': 1.0, 'pin': 0.9, 'admin': 0.7, 'proteger': 0.8,
      'protection': 0.8, 'verrouiller': 0.8, 'bloquer': 0.7,
      'hardening': 0.9, 'audit': 0.7, 'securiser': 0.9,
    },
    NlpIntent.networkQuery: {
      'reseau': 1.0, 'sync': 0.9, 'synchro': 0.9, 'synchronisation': 0.9,
      'synckey': 1.0, 'tailscale': 1.0, 'distant': 0.9, 'vpn': 0.9,
      'multi-postes': 1.0, 'multiposte': 0.9, 'serveur': 0.7, 'lan': 0.8,
      'rj45': 0.9, 'cable': 0.6, 'connecter': 0.6, 'connexion': 0.6,
    },

    // ── NAVIGATION ────────────────────────────────────────────────────
    NlpIntent.navigatePOS: {
      'caisse': 0.7, 'pos': 0.8, 'encaisser': 0.6, 'pdv': 0.7, 'boutique': 0.5,
    },
    NlpIntent.navigateInventory: {
      'gestion produits': 1.0, 'inventaire': 0.9, 'stock': 0.7, 'produit': 0.5, 'catalogue': 0.6,
    },
    NlpIntent.navigateFinance: {
      'tresorerie': 0.6, 'finance': 0.6, 'depense': 0.5, 'compte': 0.4,
    },
    NlpIntent.navigateClients: {
      'client': 0.5, 'dette': 0.4, 'credit': 0.4, 'clientele': 0.5,
    },
    NlpIntent.navigateSuppliers: {
      'fournisseur': 0.7, 'grossiste': 0.5,
    },
    NlpIntent.navigateSettings: {
      'parametre': 1.2, 'parametres': 1.2, 'reglage': 1.0, 'config': 0.8, 'configuration': 0.9,
      'profil': 0.9, 'boutique': 0.8, 'magasin': 0.6, 'infos': 0.5, 'entreprise': 0.7,
      'va': 0.3, 'aller': 0.3, 'dans': 0.2,
    },
    NlpIntent.navigateReports: {
      'rapport': 1.0, 'rapports': 1.0, 'reporting': 0.9, 'analyse': 0.8, 'statistique': 0.7,
    },
    NlpIntent.navigateDashboard: {
      'dashboard': 1.0, 'tableau': 0.7, 'accueil': 0.9, 'principal': 0.6,
    },
    NlpIntent.navigateStockMovements: {
      'mouvement': 1.0, 'historique': 0.6, 'entree': 0.8, 'sortie': 0.8, 'stock': 0.5,
    },
    NlpIntent.navigateSalesHistory: {
      'historique': 1.0, 'vente': 0.7, 'passe': 0.6, 'vendu': 0.5,
    },
    NlpIntent.navigateQuotes: {
      'devis': 1.0, 'proforma': 1.0, 'facture': 0.5,
    },
    NlpIntent.navigateWarehouses: {
      'magasin': 1.0, 'entrepot': 1.0, 'succursale': 0.9, 'depot': 0.9,
    },
    NlpIntent.navigateClientDebt: {
      'dette': 1.0, 'impayes': 0.9, 'credit': 0.8, 'client': 0.5,
    },
    NlpIntent.navigateExpenses: {
      'depense': 1.0, 'charge': 0.9, 'frais': 0.8,
    },
    NlpIntent.navigateStockAlerts: {
      'alerte': 1.0, 'rupture': 0.9, 'critique': 0.8, 'minimum': 0.7,
    },
    NlpIntent.navigateStockAudit: {
      'audit': 1.0, 'controle': 0.8, 'verification': 0.7, 'physique': 0.7, 'comptage': 0.8,
    },
    NlpIntent.navigatePurchases: {
      'achat': 1.0, 'approvisionnement': 0.9, 'commander': 0.8, 'reception': 0.8,
    },
    NlpIntent.navigateUsers: {
      'utilisateur': 1.0, 'employes': 0.7, 'caissier': 0.8, 'manager': 0.8, 'personnel': 0.6,
    },
    NlpIntent.navigateHelp: {
      'aide': 1.0, 'assistance': 0.9, 'support': 0.9,
    },
    NlpIntent.navigateHR: {
      'rh': 1.0, 'grh': 1.0, 'ressources': 0.8, 'humaines': 0.8, 'salaire': 0.9, 'pointage': 0.9,
    },
    NlpIntent.navigateAppearance: {
      'apparence': 1.5, 'look': 1.2, 'visuel': 1.0, 'design': 1.0,
      'va': 0.3, 'aller': 0.3, 'dans': 0.2, 'couleur': 0.5, 'theme': 0.4,
    },

    // ── ACTIONS ───────────────────────────────────────────────────────
    NlpIntent.actionNewSale: {
      'vend': 1.0, 'vends': 1.0, 'vendre': 1.0, 'facture': 0.8, 'facturer': 1.0,
      'valide': 1.2, 'valider': 1.2, 'confirmation': 1.0, 'confirme': 1.0,
      'paiement': 1.1, 'paiment': 1.1, 'encaisse': 1.1, 'encaisser': 1.0,
      'nouvelle': 0.5, 'nouveau': 0.5, 'creer': 0.5, 'vente': 0.6, 
    },
    NlpIntent.actionNewPurchaseOrder: {
      'bon de commande': 1.5, 'commander produits': 1.1, 'acheter stock': 1.0,
      'commande': 1.2, 'commandes': 1.1,
      'réappro': 1.1, 'approvisionnement': 1.0, 'srm': 0.9, 'achat': 0.9,
      'faire une commande': 1.1, 'commande fournisseur': 1.5,
    },
    NlpIntent.actionNewProduct: {
      'nouveau': 0.6, 'nouvelle': 0.5, 'creer': 0.5, 'ajouter': 0.6,
      'produit': 0.6, 'article': 0.6, 'reference': 0.5, 'nouveau produit': 1.1,
    },
    NlpIntent.actionNewClient: {
      'nouveau': 0.6, 'nouvelle': 0.5, 'creer': 0.5, 'ajouter': 0.5,
      'client': 0.6, 'acheteur': 0.5, 'nouveau client': 1.1, 'compte client': 1.0,
    },
    NlpIntent.actionNewExpense: {
      'nouvelle': 0.5, 'nouveau': 0.5, 'saisir': 0.6, 'ajouter': 0.5,
      'depense': 0.7, 'charge': 0.6, 'frais': 0.5, 'nouvelle depense': 1.1, 'payer': 0.6,
    },
    NlpIntent.actionPrint: {
      'imprimer': 1.0, 'impression': 0.9, 'print': 0.9, 'pdf': 0.8,
      'ticket': 0.6, 'recu': 0.7, 'imprimante': 0.8,
    },
    NlpIntent.actionExcelImport: {
      'import': 0.9, 'importer': 0.9, 'excel': 0.8, 'csv': 0.8, 'xlsx': 0.8,
      'charger': 0.6, 'telecharger': 0.5,
    },
    NlpIntent.actionExcelExport: {
      'export': 0.9, 'exporter': 0.9, 'telecharger': 0.6,
    },
    NlpIntent.actionBackup: {
      'sauvegarde': 1.0, 'backup': 1.0, 'sauvegarder': 0.9,
      'restaurer': 0.9, 'restauration': 0.9, 'copie': 0.6,
    },
    NlpIntent.actionCreateRule: {
      'si': 1.0, 'quand': 1.0, 'alerte': 0.9, 'previens': 0.9, 'stock': 0.5, 'dette': 0.5,
    },
    NlpIntent.actionMacroLearn: {
      'apprends': 1.0, 'enregistre': 0.9, 'macro': 1.0, 'retiens': 0.8,
    },
    NlpIntent.themeToggle: {
      'theme': 0.8, 'mode': 0.8, 'changer de theme': 1.2, 'basculer': 0.8,
    },
    NlpIntent.themeDark: {
      'sombre': 2.0, 'nuit': 1.5, 'dark': 2.0, 'noir': 0.7, 'obscur': 0.8,
      'mode sombre': 2.5,
    },
    NlpIntent.themeLight: {
      'clair': 2.0, 'light': 2.0, 'jour': 1.0, 'blanc': 0.6, 'lumineux': 0.8,
      'mode clair': 2.5,
    },
    NlpIntent.themeColorChange: {
      'couleur': 1.5, 'bleu': 2.0, 'orange': 2.0, 'vert': 2.0, 'violet': 2.0, 'rouge': 2.0, 'turquoise': 2.0, 'rose': 2.0, 'gris': 2.0, 'changer': 0.4,
      'colorer': 1.5, 'teinte': 1.5,
    },
    NlpIntent.themeQuery: {
      'combien': 1.1, 'liste': 0.9, 'quoi': 0.8, 'quel': 0.8, 'quelles': 0.8, 'disponible': 0.9, 
      'theme': 1.0, 'mode': 1.0, 'couleur': 0.8, 'design': 0.7,
    },
    NlpIntent.actionUpdateSetting: {
      'nom': 1.0, 'tva': 1.0, 'taxe': 1.0, 'devise': 1.0, 'argent': 0.8, 'imprimante': 1.0, 'ticket': 0.9, 'parametre': 0.7, 'reglage': 0.7, 'configurer': 0.7,
    },
    NlpIntent.actionActivateHorizon: {
      'horizon': 1.0, 'prediction': 0.9, 'futur': 0.8, 'intelligence': 0.7, 'prevoir': 0.8,
    },
    NlpIntent.actionQuickPos: {
      'rapide': 1.0, 'vitesse': 0.9, 'rush': 0.9, 'accelerer': 0.8, 'vite': 0.7,
    },

    // ── MACROS TITAN ──────────────────────────────────────────────────
    NlpIntent.macroEndOfDay: {
      'ferme': 1.0, 'fermeture': 1.0, 'soir': 0.8, 'soiree': 0.8, 'dodo': 0.8, 'cloture': 1.0,
      'quitter': 0.7, 'boutique': 0.6, 'fini': 0.7,
    },
    NlpIntent.macroFullAudit: {
      'audit': 1.0, 'total': 0.9,
      'complet': 1.1, 'totale': 1.0, 'vérification': 0.8, 'completement': 0.7,
    },
    NlpIntent.macroDebtRecovery: {
      'recouvrement': 1.0, 'relance': 0.9, 'dormant': 0.8, 'crédit': 0.7, 'payer': 0.6,
    },
    NlpIntent.macroStockPanic: {
      'urgence': 1.0, 'panique': 1.0, 'vite': 0.6, 'ruptures': 0.9, 'stock': 0.5,
    },
    NlpIntent.macroMorning: {
      'ouverture': 1.0, 'matin': 1.0, 'debute': 0.9, 'commencer': 0.8, 'lancer': 0.7,
    },
    NlpIntent.macroSecurize: {
      'incognito': 1.0, 'cacher': 1.0, 'secret': 1.0, 'panique': 0.7, 'discret': 0.9,
    },
    NlpIntent.macroHrReview: {
      'equipe': 1.0, 'review': 0.9, 'staff': 0.8, 'membres': 0.8, 'salaires': 0.7,
    },

    // ── KNOWLEDGE ─────────────────────────────────────────────────────
    NlpIntent.tipRequest: {
      'astuce': 1.0, 'conseil': 0.9, 'secret': 0.8, 'aide': 0.6,
      'tutoriel': 0.9, 'tuto': 0.8, 'guide': 0.7, 'formation': 0.7,
      'astuces': 1.0, 'conseils': 1.0, 'aidez': 0.7,
    },
    NlpIntent.shortcutRequest: {
      'raccourci': 1.0, 'clavier': 0.8, 'touche': 0.7,
      'ctrl': 0.9, 'shortcut': 0.9, 'combinaison': 0.8,
    },
    NlpIntent.howTo: {
      'comment': 0.8, 'pourquoi': 0.6, 'quoi': 0.5,
      'expliquer': 0.8, 'apprendre': 0.7, 'procédure': 0.9,
    },
    NlpIntent.aboutApp: {
      'danaya': 1.0, 'application': 0.5, 'version': 0.6,
      'créateur': 0.7, 'titan': 1.2, 'logiciel': 0.8, 'intelligence': 0.7,
    },
    NlpIntent.featureList: {
      'fonctionnalite': 1.0, 'option': 0.7, 'module': 0.8, 'outil': 0.7,
      'composant': 0.6, 'capacités': 0.9, 'options': 0.8,
    },
    NlpIntent.whatCanYouDo: {
      'capacite': 0.8, 'capable': 0.8, 'peux': 0.7, 'sais': 0.7,
      'faire': 0.4, 'pouvoir': 0.7, 'fonction': 0.5, 'rôle': 0.6,
    },
  };

  // ── NAVIGATION TRIGGER WORDS ────────────────────────────────────────
  static final List<String> _navigationVerbs = [
    'aller', 'ouvre', 'ouvrir', 'montre', 'montrer', 'naviguer', 'navigate',
    'va', 'voir', 'affiche', 'afficher', 'page', 'onglet', 'section',
    'emmene', 'emmener', 'dirige', 'diriger', 'amene', 'amener', 'lance', 'lancer',
  ];

  // ── ACTION TRIGGER WORDS ────────────────────────────────────────────
  static final List<String> _actionVerbs = [
    'creer', 'ajouter', 'ajout', 'nouveau', 'nouvelle', 'saisir',
    'enregistrer', 'faire', 'lancer', 'demarrer', 'commencer',
    'change', 'changer', 'modifier', 'maj', 'mettre', 'update',
    'vend', 'vends', 'vendre', 'encaisser', 'facturer',
  ];

  // ── TIME MODIFIERS ──────────────────────────────────────────────────
  static final Map<String, String> _timeKeywords = {
    'hier': 'hier',
    'avant-hier': 'avant-hier',
    "aujourd'hui": "aujourd'hui",
    'aujourdhui': "aujourd'hui",
    'ajd': "aujourd'hui",
    'ce mois': 'ce_mois',
    'du mois': 'ce_mois',
    'mois en cours': 'ce_mois',
    'cette semaine': 'cette_semaine',
    'semaine': 'cette_semaine',
    'ce jour': "aujourd'hui",
    'maintenant': "aujourd'hui",
    'cette annee': 'cette_annee',
    'annuel': 'cette_annee',
  };

  // ══════════════════════════════════════════════════════════════════════
  //  CORE ALGORITHM: LEVENSHTEIN DISTANCE
  // ══════════════════════════════════════════════════════════════════════
  static int levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    final sLen = s.length;
    final tLen = t.length;

    List<int> prevRow = List.generate(tLen + 1, (i) => i);
    List<int> currRow = List.filled(tLen + 1, 0);

    for (int i = 1; i <= sLen; i++) {
      currRow[0] = i;
      for (int j = 1; j <= tLen; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        currRow[j] = [
          currRow[j - 1] + 1,
          prevRow[j] + 1,
          prevRow[j - 1] + cost,
        ].reduce(min);
      }
      final temp = prevRow;
      prevRow = currRow;
      currRow = temp;
    }
    return prevRow[tLen];
  }

  static double similarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    final maxLen = max(a.length, b.length);
    if (maxLen == 0) return 1.0;
    return 1.0 - (levenshtein(a, b) / maxLen);
  }

  // ══════════════════════════════════════════════════════════════════════
  //  FUZZY WORD MATCHER
  // ══════════════════════════════════════════════════════════════════════
  static MapEntry<String, double>? _fuzzyMatch(String word, Iterable<String> candidates, {double threshold = 0.65}) {
    String? bestMatch;
    double bestScore = 0.0;

    for (final candidate in candidates) {
      final score = similarity(word, candidate);
      if (score > bestScore && score >= threshold) {
        bestScore = score;
        bestMatch = candidate;
      }
    }

    if (bestMatch != null) {
      return MapEntry(bestMatch, bestScore);
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  NORMALIZE INPUT
  // ══════════════════════════════════════════════════════════════════════
  static String _normalize(String input) {
    String s = input.toLowerCase().trim();
    const accents = 'àâäéèêëïîôùûüÿçñ';
    const normals = 'aaaeeeeiioouuyçn';
    for (int i = 0; i < accents.length; i++) {
      s = s.replaceAll(accents[i], normals[i]);
    }
    s = s.replaceAll(RegExp(r"[^\w\s']"), ' ');
    // Titan V5: Special handling for common French contractions
    s = s.replaceAll("d'", 'de ');
    s = s.replaceAll("l'", 'le ');
    s = s.replaceAll("qu'", 'que ');
    s = s.replaceAll("n'", 'ne ');
    s = s.replaceAll('-', ' '); // Split hyphens (e.g., dis-moi -> dis moi)
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  static String _resolveSynonyms(String word) {
    for (final entry in _synonyms.entries) {
      if (entry.value.contains(word) || entry.key == word) {
        return entry.key;
      }
    }
    return word;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  ENTITY EXTRACTION
  // ══════════════════════════════════════════════════════════════════════
  static List<ExtractedEntity> _extractEntities(String input) {
    final entities = <ExtractedEntity>[];

    final numRegex = RegExp(r'\b(\d+(?:[.,]\d+)?)\b');
    for (final match in numRegex.allMatches(input)) {
      final raw = match.group(1)!;
      final value = double.tryParse(raw.replaceAll(',', '.'));
      if (value != null) {
        entities.add(ExtractedEntity(type: EntityType.number, raw: raw, value: value));
      }
    }

    final dateRegex = RegExp(r'\b(\d{1,2})[/\-](\d{1,2})(?:[/\-](\d{2,4}))?\b');
    for (final match in dateRegex.allMatches(input)) {
      final day = int.tryParse(match.group(1)!) ?? 1;
      final month = int.tryParse(match.group(2)!) ?? 1;
      int year = match.group(3) != null ? (int.tryParse(match.group(3)!) ?? DateTime.now().year) : DateTime.now().year;
      if (year < 100) year += 2000;
      try {
        final date = DateTime(year, month, day);
        entities.add(ExtractedEntity(type: EntityType.date, raw: match.group(0)!, value: date));
      } catch (_) {}
    }

    return entities;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  TIME MODIFIER DETECTION
  // ══════════════════════════════════════════════════════════════════════
  static String? _detectTimeModifier(String normalized) {
    for (final entry in _timeKeywords.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
      final words = normalized.split(' ');
      for (final word in words) {
        if (similarity(word, entry.key) >= 0.75) {
          return entry.value;
        }
      }
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  VERB DETECTION
  // ══════════════════════════════════════════════════════════════════════
  static bool _hasNavigationVerb(List<String> words) {
    for (final word in words) {
      for (final verb in _navigationVerbs) {
        if (similarity(word, verb) >= 0.70) return true;
      }
    }
    return false;
  }

  static bool _hasActionVerb(List<String> words) {
    for (final word in words) {
      for (final verb in _actionVerbs) {
        if (similarity(word, verb) >= 0.70) return true;
      }
    }
    return false;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  SEARCH QUERY EXTRACTION
  // ══════════════════════════════════════════════════════════════════════
  static String? _extractSearchQuery(String normalized, List<String> resolvedWords) {
    // Remove known trigger words and return the rest as the search query
    final searchKeywords = ['chercher', 'rechercher', 'trouver', 'scanner', 'localiser', 'recherche', 'ou est', 'stock'];
    
    final remaining = <String>[];
    for (final word in normalized.split(' ')) {
      bool isNoise = false;
      
      // Stop words are definitely noise for a search query
      if (_stopWords.contains(word)) isNoise = true;
      
      // Intent-specific search keywords are noise
      for (final sk in searchKeywords) {
        if (similarity(word, sk) >= 0.70) { isNoise = true; break; }
      }
      
      if (!isNoise && word.length > 2) remaining.add(word);
    }
    
    if (remaining.isNotEmpty) return remaining.join(' ');
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  MAIN ANALYSIS METHOD
  // ══════════════════════════════════════════════════════════════════════
  // ══════════════════════════════════════════════════════════════════════
  //  MAIN ANALYSIS METHOD
  // ══════════════════════════════════════════════════════════════════════
  static NlpResult analyze(String input, {AssistantContext context = AssistantContext.general}) {
    final normalized = _normalize(input);
    final words = normalized.split(' ').where((w) => w.length > 1).toList();
    final entities = _extractEntities(input);
    final timeModifier = _detectTimeModifier(normalized);

    // C0. Priority Phrase Match
    for (final phrase in _commonPhrases.keys) {
      if (normalized.contains(phrase) || similarity(normalized, phrase) >= 0.85) {
        return NlpResult(
          intent: _commonPhrases[phrase]!,
          confidence: 1.0,
          entities: entities,
          timeModifier: timeModifier,
          rawInput: input,
        );
      }
    }

    final resolvedWords = words.map((w) => _resolveSynonyms(w)).toList();

    final hasNavVerb = _hasNavigationVerb(words);
    final hasActVerb = _hasActionVerb(words);

    // Context weight mapping (Titan V4)
    final Map<AssistantContext, List<NlpIntent>> contextBoosts = {
      AssistantContext.pos: [NlpIntent.navigatePOS, NlpIntent.actionNewSale, NlpIntent.stockSearch],
      AssistantContext.inventory: [NlpIntent.navigateInventory, NlpIntent.stockQuery, NlpIntent.stockSearch, NlpIntent.actionNewProduct],
      AssistantContext.finance: [NlpIntent.navigateFinance, NlpIntent.financeQuery, NlpIntent.financeProfitLoss, NlpIntent.actionNewExpense],
      AssistantContext.clients: [NlpIntent.navigateClients, NlpIntent.clientQuery, NlpIntent.clientDebtList, NlpIntent.actionNewClient],
      AssistantContext.reports: [NlpIntent.navigateReports, NlpIntent.salesQuery, NlpIntent.salesTopProducts],
    };

    // Score each intent
    final Map<NlpIntent, double> scores = {};

    for (final intentEntry in _intentBags.entries) {
      final intent = intentEntry.key;
      final bag = intentEntry.value;
      double score = 0.0;
      int hits = 0;

      for (int i = 0; i < words.length; i++) {
        final originalWord = words[i];
        final resolvedWord = resolvedWords[i];

        // Titan V7: Token-level matching
        bool wordMatched = false;
        if (bag.containsKey(originalWord)) { score += bag[originalWord]!; hits++; wordMatched = true; } 
        else if (bag.containsKey(resolvedWord)) { score += bag[resolvedWord]!; hits++; wordMatched = true; }

        if (!wordMatched) {
          final fuzzy = _fuzzyMatch(originalWord, bag.keys, threshold: 0.75);
          if (fuzzy != null) { score += bag[fuzzy.key]! * fuzzy.value; hits++; }
        }

        // Titan V7: Bigram (2-word phrase) matching
        if (i < words.length - 1) {
          final bigram = '${words[i]} ${words[i+1]}';
          if (bag.containsKey(bigram)) {
            score += bag[bigram]! * 1.5; // Phrase matches are more significant
            hits++;
          }
        }
      }

      // Context bonuses
      final isNavIntent = intent.name.startsWith('navigate');
      final isActIntent = intent.name.startsWith('action') || 
                          intent.name.startsWith('theme') || 
                          intent.name.endsWith('Query');
      // Titan V6: Question Detection with specific anchors
      final isQuestion = words.any((w) => ['comment', 'combien', 'quel', 'quelle', 'pourquoi', 'quoi', 'que', 'qu', 'combiens', 'quelle'].contains(w)) || normalized.endsWith('?');

      if (isQuestion && (isActIntent || isNavIntent)) {
        score *= 0.1; // Huge penalty for actions/nav if the user is asking a question
      } else {
        if (isNavIntent && hasNavVerb && hits > 0) {
          score *= 2.0;
        }
        if (isNavIntent && !hasNavVerb) {
          score *= 0.3;
        }
        if (isActIntent && hasActVerb && hits > 0) {
          score *= 1.8;
        }
        if (isActIntent && !hasActVerb) {
          score *= 0.4;
        }
      }

      // Titan V4: Contextual Boost
      if (contextBoosts[context]?.contains(intent) ?? false) {
        score *= 1.5; 
      }

      // Titan V10: Max-Hit Scoring (Anti-dilution)
      if (hits > 0) {
        final maxWeight = bag.values.where((v) => bag.keys.any((k) => words.contains(k) || resolvedWords.contains(k))).fold(0.0, max);
        
        // If we hit a primary keyword, the score is primarily driven by that keyword's weight
        if (maxWeight >= 1.5) {
          scores[intent] = maxWeight * 0.9; 
        } else {
          final meaningfulWords = words.where((w) => !_stopWords.contains(w)).toList();
          scores[intent] = (score / max(1, meaningfulWords.length)) * (1.0 + hits * 0.5);
        }
      }
    }

    // Find the best intent
    NlpIntent bestIntent = NlpIntent.unknown;
    double bestScore = 0.0;

    // Titan V7: Sort by score to apply Business Priority
    final sortedScores = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    
    if (sortedScores.isNotEmpty) {
      final top = sortedScores.first;
      bestIntent = top.key;
      bestScore = top.value;

      // Business Priority: If we have a business intent with decent score, it beats a Greeting
      if (bestIntent == NlpIntent.greeting && sortedScores.length > 1) {
        final next = sortedScores[1];
        if (next.value > 0.25 && !next.key.name.startsWith('social')) {
          bestIntent = next.key;
          bestScore = next.value;
        }
      }
    }

    final confidence = min(1.0, bestScore);
    if (confidence < 0.20) {
      bestIntent = NlpIntent.unknown;
    }

    // DEBUG: Log NLP decision in terminal
    debugPrint('🧠 NLP: "$input" → $bestIntent (score: ${bestScore.toStringAsFixed(3)}, confidence: ${confidence.toStringAsFixed(3)}, context: $context)');

    // Collect secondary intents (score > 0.5 and different from primary)
    final secondaryIntents = <NlpIntent>[];
    if (scores.isNotEmpty) {
      final sorted = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sorted) {
        if (entry.key != bestIntent && entry.value > 0.4 && (bestScore - entry.value) < 0.5) {
          secondaryIntents.add(entry.key);
        }
      }
    }

    // Extract search query for relevant intents
    String? searchQuery;
    const queryIntents = {
      NlpIntent.stockSearch,
      NlpIntent.themeColorChange,
      NlpIntent.actionUpdateSetting,
      NlpIntent.actionCreateRule,
    };
    if (queryIntents.contains(bestIntent)) {
      searchQuery = _extractSearchQuery(normalized, resolvedWords);
    }

    return NlpResult(
      intent: bestIntent,
      confidence: confidence,
      entities: entities,
      timeModifier: timeModifier,
      searchQuery: searchQuery,
      rawInput: input,
      secondaryIntents: secondaryIntents,
    );
  }
}
