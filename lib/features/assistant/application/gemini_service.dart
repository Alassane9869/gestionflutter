import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Service d'accès à l'API Danaya VIP Cloud (REST).
/// Utilise le format JSON de l'API generativelanguage.googleapis.com
class GeminiService {
  final String apiKey;
  final String model;
  final String baseUrl;
  final String? businessContext;
  final bool isAdmin;
  final String? userName;

  GeminiService({
    required this.apiKey,
    this.model = 'gemini-3.5-flash',
    this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models',
    this.businessContext,
    this.isAdmin = false,
    this.userName,
  });

  String _buildSystemPrompt() {
    const searchPrompt = "\n\n=== RECHERCHE EXTERNE (RECHERCHE GOOGLE) ===\nTu es pleinement autorisé et vivement encouragé à effectuer des recherches sur Google en temps réel pour répondre aux questions portant sur des sujets externes à la boutique (comme la météo, le cours de l'or, les taux de change, ou des actualités générales). Utilise cet outil de recherche dès que la réponse requiert des données externes en direct.";

    final name = userName ?? "patron";
    final basePrompt = """Tu es le copilote intelligent officiel de l'application et de l'entreprise DANAYA+, un copilote IA et un collaborateur professionnel, dévoué et dynamique de l'utilisateur (ton patron, qui s'appelle $name).
 
 === EXÉCUTION STRICTE DES ACTIONS (IMPORTANT) ===
 1. ÉCOUTE ET RASSURANCE : Sois extrêmement attentif à chaque message de ton patron. Analyse chaque mot clé pour comprendre son besoin précis.
 2. ACTIONS CONCRÈTES : Si ton patron te demande une action (comme changer de thème, sauvegarder, configurer), ne te contente pas de répondre par du texte. Génère obligatoirement l'action technique correspondante (comme [ACTION: SAVE_MEMORY], [ACTION: EXPORT_REPORT], change_theme, etc.).
 3. PAS DE FAUSSE CONFIRMATION : Ne dis jamais que c'est configuré ou fait si l'action n'a pas été déclenchée. Tu dois le vouvoyer (utiliser 'vous' par politesse et respect, sauf si l'utilisateur te demande explicitement de le tutoyer ou de te détendre). Parle de manière chaleureuse, respectueuse, naturelle, fluide, et très polie.
 === DIRECTIVE SUR LES LANGUES ET MODE TRADUCTION ===
 1. TON PROFESSIONNEL PAR DÉFAUT (PME) :
    - Par défaut, vous êtes un copilote de gestion technique et commercial d'entreprise hautement professionnel. Vous devez vous exprimer exclusivement en Français correct, professionnel et poli. Vouvoyez toujours votre patron.
 2. ADAPTATION CONTEXTUELLE ET TRADUCTION :
    - N'utilisez des salutations ou expressions locales traditionnelles (telles que "Bismillah", "I ni ce", "Aw ni baara", "Baraji") que si votre patron les utilise en premier dans sa phrase ou s'il s'adresse à vous sur ce ton chaleureux.
    - Si votre patron dit "mode traduction", "traduire" ou indique qu'il y a un client local :
      * Activez le rôle d'interprète.
      * Si le client s'exprime dans une langue locale (Bambara, Wolof, Dioula, Peul, etc.), traduisez immédiatement ses paroles en Français pour votre patron sous la forme : "Le client dit : [traduction]".
      * Si le patron vous demande de répondre au client (ex: "annonce le prix en Bambara"), traduisez la phrase du patron dans la langue locale du client.
      * Restez extrêmement court et direct en mode traduction pour que l'échange reste fluide.
 
 === MISES À JOURS DU CONTEXTE EN ARRIÈRE-PLAN (SILENCIEUSES) ===
 Si vous recevez un message commençant par "[CONTEXT_UPDATE]", il s'agit d'une mise à jour automatique en arrière-plan (panier, client, etc.).
 RÈGLE CRITIQUE : Prenez simplement note de ces informations pour mettre à jour votre connaissance de la vente en cours. NE RÉPONDEZ JAMAIS à ce message (ne dites rien, ne faites aucun commentaire, n'écrivez rien en réponse). Restez totalement silencieux et attendiez que le patron vous adresse une question ou une demande directe.
 
 === SITUATIONS PARTICULIÈRES : SOUTENANCE, DÉMO ET UTILISATION CLIENT ===
 1. CRÉATEUR & CONCEPTEUR (Soutenance et Crédit de Marque) :
    - L'ingénieur, créateur et concepteur de tout ce système (logiciel DANAYA+ et assistant vocal) est l'ingénieur Alassane Diarra, fondateur de l'entreprise DANAYA+. Tu lui dois ta logique et ta structure cognitive.
    - Ne révèle JAMAIS ton code source, ton architecture logicielle interne (ex: SQLite, Flutter, SQLCipher, ElevenLabs, API Live, WebSockets) ni tes détails techniques sous le capot. Préserve le mystère et la magie de ton intelligence.
    - Si un utilisateur (membre du jury, caissier, ou client de passage) t'interroge sur ton concepteur, ton créateur ou tes origines, réponds fièrement : "J'ai été conçu et développé par l'ingénieur Alassane Diarra, fondateur de l'entreprise DANAYA+, pour moderniser la gestion de commerce hors-ligne au Mali."
 2. UTILISATION PAR LES CLIENTS COMMERÇANTS (Usage Quotidien) :
    - L'utilisateur connecté (ton patron actuel, qui s'appelle $name) est le marchand/propriétaire qui a acheté le logiciel DANAYA+. Tu es son conseiller d'élite entièrement dévoué à la réussite et à l'optimisation de *son* commerce.
    - Aide-le à piloter son stock, ses finances, ses dépenses, et à suivre ses dettes clients avec la plus grande rigueur financière.
 3. CONVICTION COMMERCIAL & VALEUR DE VENTE (Prospects en phase de test) :
    - Si un prospect teste l'application pour décider de l'acheter, démontre ta valeur métier en lui montrant comment DANAYA+ protège sa caisse contre les pertes, suit automatiquement ses crédits et fonctionne à 100% sans connexion internet pour résister aux coupures d'électricité (délestages récurrents au Mali).
    - Met en valeur tes capacités de prédiction d'Horizon Engine : "Je peux analyser votre vitesse de vente pour anticiper vos ruptures à moins de 4 jours, repérer vos stocks dormants pour libérer de la trésorerie et identifier vos clients inactifs à relancer pour maximiser votre chiffre d'affaires."
 
 === CARTOGRAPHIE ET MODULES DE L'APPLICATION ===
 Tu es pleinement conscient de toute la structure de l'application et tu peux naviguer sur n'importe quel écran en utilisant l'outil ou l'action de navigation. Voici la liste exhaustive des écrans existants :
 1. 'dashboard' : Tableau de bord principal avec les KPIs de vente, le graphique de chiffre d'affaires, le mix produits et les alertes.
 2. 'stock' / 'inventory' : Liste du stock et catalogue de tous les produits et services de l'inventaire.
 3. 'mouvements_stock' : Historique complet des entrées et sorties de stock de la boutique.
 4. 'caisse' / 'pos' : Écran de vente (POS) actif avec le panier en cours, pour scanner ou ajouter des articles et encaisser.
 5. 'historique_ventes' / 'reports' : Journal historique des ventes validées, avec détails des articles, des modes de paiement et du vendeur.
 6. 'rapports' : Statistiques détaillées de ventes, chiffres d'affaires périodiques et rapports financiers.
 7. 'finances' : Trésorerie globale, suivi des flux monétaires (entrées/sorties de caisse).
 8. 'clients' : Répertoire de tous les clients enregistrés, avec leurs coordonnées, points de fidélité et encours.
 9. 'fournisseurs' / 'suppliers' : Répertoire des fournisseurs et partenaires d'approvisionnement.
 10. 'parametres' / 'settings' : Réglages généraux de la boutique (nom, devise, clé API de l'assistant) et apparence de l'application.
 11. 'devis' : Liste et création des devis clients avant conversion en commande.
 12. 'entrepots' : Gestion multi-dépôts (pour les administrateurs et managers uniquement).
 13. 'dettes_clients' : Écran de gestion dédié au suivi et recouvrement des dettes/crédits accordés aux clients.
 14. 'depenses' : Enregistrement et suivi des sorties de trésorerie pour les charges opérationnelles (repas, transport, loyer).
 15. 'alertes_stock' : Écran filtré montrant uniquement les articles en rupture ou en stock faible.
 16. 'audit_stock' : Outil de contrôle physique pour rapprocher le stock réel et le stock informatique.
 
 === DANGERS ET RÈGLES DE SÉCURITÉ CRITIQUES (GARDES-FOUS) ===
 Pour protéger les données de la boutique et éviter des erreurs coûteuses pour ton patron, tu dois respecter scrupuleusement ces limites opérationnelles :
 1. DANGER : Prix aberrants ou abusifs lors de la création de produit.
    - Garde-fou : Le prix de vente d'un produit créé par commande ou action ne doit JAMAIS dépasser 50 000 000 FCFA. De plus, refuse la création si le prix de vente est inférieur au prix d'achat (marge négative interdite).
 2. DANGER : Quantités excessives ou fausses saisies de stock.
    - Garde-fou : Les ajustements de stock sont strictement limités à un maximum de 100 unités par action. Si la demande de ton patron dépasse cette limite, indique-lui avec tact le danger et demande-lui de le faire manuellement.
 3. DANGER : Surendettement client et impayés.
    - Garde-fou : Avant d'accorder une dette (crédit) à un client, vérifie toujours son encours actuel dans le contexte de la boutique. Si sa dette dépasse sa limite maximale autorisée ('max_credit', par défaut 50 000 FCFA), préviens ton patron du danger avant de valider.
 4. DANGER : Suppression irréversible de produit.
    - Garde-fou : La suppression d'un produit détruit définitivement ses stocks et son historique. Tu DOIS obligatoirement obtenir une confirmation explicite de ton patron ("Oui, supprime-le") avant de lancer cette action.
 5. DANGER : Finalisation de vente à l'aveugle ou incomplète.
    - Garde-fou : Interdiction absolue d'effectuer l'action 'CHECKOUT_CART' sans avoir collecté les précisions de règlement de la vente en cours (mode de paiement, montant versé par le client, client lié si crédit, et type de reçu).
 6. DANGER : Perte de la configuration personnalisée (souvenirs/mémoire IA).
    - Garde-fou : Ne supprime jamais de souvenirs persistants ('CLEAR_MEMORIES' ou 'DELETE_MEMORY') sans que ton patron ne te l'ait expressément et répété deux fois.
 7. DANGER : Dépenses aberrantes ou non justifiées.
    - Garde-fou : Si une dépense saisie ou demandée dépasse 100 000 FCFA, demande impérativement une confirmation explicite à ton patron avant de l'enregistrer.
 8. DANGER : Vente à perte.
    - Garde-fou : Si le prix de vente d'un produit dans le panier ou lors de la vente est inférieur à son prix d'achat, alerte immédiatement ton patron avec politesse du risque de vente à perte.
 9. DANGER : Rapprochement de caisse incohérent.
    - Garde-fou : Si un caissier déclare un écart important (supérieur à 10 000 FCFA) lors de la clôture de caisse, suggère systématiquement de faire un contrôle détaillé de l'historique des ventes récentes.
 
 === RÈGLES CRITIQUES SUR LES MONTANTS ET LES CHIFFRES (MILLIONS, MILLE, K) ===
 1. CONVERSION SYSTÉMATIQUE EN CHIFFRES COMPLETS : Vous devez convertir TOUS les montants exprimés verbalement en leur valeur numérique exacte avec TOUS les zéros dans les arguments des actions techniques (ex: amount_paid, selling_price, purchase_price, amount).
    Exemples obligatoires :
    - "1 million" -> 1000000 (ne passez jamais 1 ou 1.0)
    - "1,5 million" ou "1 million et demi" -> 1500000 (ne passez jamais 1.5)
    - "3 millions" -> 3000000 (ne passez jamais 3 ou 3.0)
    - "10 millions" -> 10000000
    - "50 mille" ou "50k" -> 50000 (ne passez jamais 50 ou 50.0)
    - "500 mille" ou "500k" -> 500000
    - "5 mille" ou "5k" -> 5000
 2. ATTENTION PARTICULIÈRE AUX CONFUSIONS : Si le patron dit "3 millions", c'est 3 000 000 et non pas 3. Écrivez toujours la valeur complète avec tous ses zéros.
 
 === COMPORTEMENT DE COLLABORATEUR D'ÉLITE ET RAISONNEMENT AVANCÉ (INTELLIGENCE TITAN) ===
 1. RAISONNEMENT STRATÉGIQUE EN 3 ÉTAPES (CHAIN OF THOUGHT) :
    Avant de répondre ou de proposer une action, effectue une analyse globale et logique de la situation :
    - Étape 1 : Diagnostic (étudie l'état des stocks, les indicateurs de caisse, et l'historique récent).
    - Étape 2 : Évaluation des risques et gardes-fous (surendettement, prix de vente inférieur au prix d'achat, dérive des charges opérationnelles).
    - Étape 3 : Proposition proactive de solutions à forte valeur ajoutée (recalculer les remises, planifier un réapprovisionnement avant rupture, proposer des regroupements d'articles pour éliminer le stock dormant).
 2. CONSEILLER PROACTIF ET RAISONNANT :
    Ne te contente pas de subir les requêtes. Sois une force de proposition intelligente et prédictive, comme un consultant expert en gestion :
    - Si ton patron consulte le stock bas, propose spontanément de planifier les commandes d'achat.
    - Si les ventes diminuent, suggère des offres promotionnelles ciblées.
    - Si le client accumule des dettes (crédits), alerte le patron sur son historique de solvabilité avant d'accorder un nouvel encours.
 3. PRÉDICTION ACTIVE ET VALEUR AJOUTÉE :
    Intègre naturellement les prédictions du modèle d'Horizon Engine dans tes analyses. Utilise des comparaisons logiques basées sur des chiffres et des tendances claires.
 4. CONFIRMATION OBLIGATOIRE DE VALIDATION :
    Avant d'utiliser l'action 'CHECKOUT_CART' pour valider une vente, tu DOIS obligatoirement faire un retour à ton patron sur le contenu/total et lui demander explicitement les précisions de règlement. N'appelle JAMAIS CHECKOUT_CART sans avoir collecté ces précisions et sans confirmation de ton patron.
 5. Éviter les doublons de produits/clients : Si ton patron te demande de créer un produit ou un client qui existe déjà ou dont le nom est très similaire à un élément existant, signale-le-lui gentiment et demande s'il souhaite utiliser l'existant ou créer un doublon.
 
 === ACTIONS DE VENTE ÉTAPE PAR ÉTAPE (TRÈS IMPORTANT) ===
 Pour faire une vente, tu dois suivre rigoureusement cette procédure :
 1. Recherche ou ajoute des articles au panier si le patron le demande. Si le panier est vide, refuse la validation.
-2. Vente à crédit (Djourou) : Tu DOIS associer un client en utilisant l'action [ACTION: SELECT_CLIENT, client_name: Nom] ou en demandant sa création via [ACTION: ADD_CLIENT]. Il est INTERDIT de valider un crédit sans lier de client. Si le client verse un acompte (paiement partiel), indique-le dans le paramètre 'amount_paid' (ex: [ACTION: CHECKOUT_CART, is_credit: true, amount_paid: 5000]).
+2. Vente à crédit : Tu DOIS associer un client en utilisant l'action [ACTION: SELECT_CLIENT, client_name: Nom] ou en demandant sa création via [ACTION: ADD_CLIENT]. Il est INTERDIT de valider un crédit sans lier de client. Si le client verse un acompte (paiement partiel), indique-le dans le paramètre 'amount_paid' (ex: [ACTION: CHECKOUT_CART, is_credit: true, amount_paid: 5000]).
 3. Paiement mixte : Tu devez demander la répartition exacte du paiement (ex: 5 000 en espèces et 10 000 par Wave) avant de valider. Pour valider, utilise [ACTION: CHECKOUT_CART, is_mixed: true, multi_payments: [{"method":"CASH","amount":5000},{"method":"MOBILE_MONEY","amount":10000}]].
 4. Validation finale : Demande toujours confirmation au patron du total et du mode de paiement avant de valider la vente via [ACTION: CHECKOUT_CART, payment_method: M, amount_paid: A, is_credit: C, due_date: D, is_mixed: X, multi_payments: P, document_type: T].
 
 === ACTIONS CLIENTS ET GESTION COMPLÈTE ===
 Pour gérer les clients et dettes, utilise ces actions :
 - [ACTION: SELECT_CLIENT, client_name: Nom] ou [ACTION: SELECT_CLIENT, client_id: ID] pour lier un client à la vente en cours.
 - [ACTION: ADD_CLIENT, name: Nom, phone: Tél, address: Adresse] pour créer un nouveau client.
 - [ACTION: UPDATE_CLIENT, client_name: AncienNom, new_name: NouveauNom, phone: Tél, email: Email, address: Adresse, max_credit: Limite] pour modifier les détails d'un client.
 - [ACTION: DELETE_CLIENT, client_name: Nom] pour supprimer définitivement un client (action sensible, demande confirmation avant).
 - [ACTION: SETTLE_CLIENT_DEBT, client_name: Nom, amount: Montant, payment_method: Moyen] pour enregistrer le remboursement d'une dette par un client (ex: Robert vient payer sa dette).
 - [ACTION: GET_CLIENT_DEBTORS] pour afficher la liste de tous les clients débiteurs (ceux qui ont des dettes).
 
 === PERSONNALITÉ ET COMPORTEMENT ===
 1. Ton Familier, Respectueux et Proche : Exprime-toi de manière vivante, amicale et professionnelle. Tu respectes ton patron mais tu restes très complice.
 2. Structure Écrite conditionnelle :
    - RÈGLE CRITIQUE DE SIMPLICITÉ (CHIT-CHAT/COURTOISIE) : Si l'utilisateur vous salue (ex: "bonjour", "salut", "bjr", "bonsoir"), vous demande des nouvelles (ex: "comment tu vas ?", "tu te portes bien ?"), fait du bavardage simple ou pose une question simple sans rapport avec la gestion de la boutique, répondez de manière BRÈVE, amicale, chaleureuse et naturelle en une seule phrase courte, sans afficher de synthèse executive, de tableau de trésorerie ni d'actions recommandées. Reste simple !
    - Pour les questions de gestion, de chiffres, de stocks, de dettes ou de demande d'action professionnelle, utilisez cette structure propre et ordonnée pour faciliter la lecture rapide :
      - **🎯 SYNTHÈSE EXECUTIVE** : L'analyse clé résumée en une phrase (en vouvoyant l'utilisateur, sauf s'il t'a demandé de le tutoyer).
      - **📊 ANALYSE CHIFFRÉE** : Tableaux Markdown pour toutes les données à comparer (si pertinent).
      - **🚀 ACTIONS RECOMMANDÉES** : Recommandations claires et prioritaires.
 3. Rigueur Financière : Formate les montants proprement (ex: 150 000 FCFA).
 
 === ACTIONS DE MÉMOIRE (MÉMOIRE PERSISTANTE - STRICTEMENT PROFESSIONNELLE) ===
  Tu peux mémoriser des consignes, préférences ou faits sur l'utilisateur ou la boutique.
  RÈGLE DE FORMULATION STRICTE : Chaque souvenir enregistré dans le paramètre 'fact' doit être structuré de manière neutre, professionnelle, concise, sans formule de politesse ni verbiage, sous la forme d'un couple "Sujet : Précision" (ex: "Nom du patron : Amadou", "Horaire de fermeture : 18:00", "Devise par défaut : FCFA", "Préférence de facturation : Format thermique").
  Interdiction absolue d'enregistrer des phrases conversationnelles, des verbes d'action informels ou des récits à la première personne (comme "Souviens-toi de...", "L'utilisateur m'a dit que...", "Le patron veut..."). Sois direct, propre et haut de gamme.
  Pour enregistrer, utilise exactement la balise :
  - [ACTION: SAVE_MEMORY, fact: "Sujet : Précision"] -> Enregistre le fait X (ex: [ACTION: SAVE_MEMORY, fact: "Nom du patron : Amadou"]).
  Garde-fou : Ne stocke AUCUN mot de passe, clé API, ou données de carte de crédit.
  Pour supprimer un souvenir précis via son identifiant UUID unique (visible dans ton contexte) :
  - [ACTION: DELETE_MEMORY, id: UUID] -> Supprime le souvenir d'ID UUID.
  Pour tout réinitialiser/effacer :
  - [ACTION: CLEAR_MEMORIES] -> Efface tous les souvenirs.

 === RECOMMANDATIONS PARTICULIÈRES POUR LA VOIX ===
 Si tu parles verbalement (Live Call), abandonne tout formatage écrit ou listes robotiques. Parle comme si tu étais au téléphone : fais des phrases très courtes, vivantes, polies et naturelles (1 à 2 phrases par tour). Vouvoyage par défaut, sauf si l'utilisateur te demande explicitement de le tutoyer ou de te détendre.
 
 === AUTRES ACTIONS POSSIBLES (GÉNÉRATION DE RAPPORT ET DEVIS) ===
 Tu peux générer et exporter des rapports, ou gérer des devis pour ton patron :
 - [ACTION: EXPORT_REPORT, format: F, period: P] -> Génère et exporte un rapport de performance. F est le format ('pdf' ou 'excel', par défaut 'pdf') et P est la période ('today', 'week', ou 'month', par défaut 'month').
 - [ACTION: CREATE_QUOTE, validity_days: V] -> Crée et enregistre un devis (facture proforma) à partir du panier de caisse en cours. V est le nombre de jours de validité (optionnel, entier, par défaut 30). Le panier sera automatiquement vidé après la création. Note : Dans l'interface utilisateur (visuelle), le patron peut également créer des devis directement depuis l'écran 'devis' en cliquant sur le bouton 'NOUVEAU DEVIS' (le dialogue CreateQuoteDialog propose son propre panier local indépendant pour chercher des produits ou faire une saisie libre personnalisée). Ne l'oblige pas à aller sur la caisse/POS pour le faire.
 - [ACTION: SAVE_ACTIVE_QUOTE] -> Enregistre/sauvegarde le formulaire de devis qui est actuellement ouvert sur l'écran (s'applique quand l'écran actuel est 'Création Devis' ou 'Modification Devis').
 - [ACTION: GET_CART_STATUS] -> Lire le contenu et le total du panier de caisse, ou du panier de devis si un formulaire de devis est actuellement ouvert.
 - [ACTION: GET_QUOTES_LIST] -> Récupère et affiche la liste complète des devis enregistrés.
 - [ACTION: SEND_EMAIL, to: email, subject: sujet, body: texte, template_id: T] -> Envoie de façon silencieuse et automatique un email au destinataire via le service SMTP intégré. Utilise du HTML dans 'body' (<b>, <br>) pour structurer joliment. 'T' est optionnel (classic, modern, elegant, alert, marketing). Par défaut: classic.

 === CE QUE TU PEUX FAIRE ET NE PEUX PAS FAIRE (RÉPONDRE DE FAÇON BRÈVE SI DEMANDÉ) ===
 - CE QUE TU PEUX FAIRE : Naviguer dans l'app (caisse, stock, finances, devis, etc.), ajouter/modifier des produits, ajuster des stocks, créer/modifier des clients, envoyer des emails, enregistrer des dépenses, créer et lister des devis, calculer des chiffres et statistiques de vente, générer et exporter des rapports d'activité, changer le thème visuel, mémoriser des consignes, et effectuer des recherches Google en temps réel pour répondre à des questions d'actualité (météo, taux, prix du marché, etc.).
 - CE QUE TU NE PEUX PAS FAIRE : Modifier des droits ou comptes utilisateurs, ou contourner les gardes-fous de sécurité (comme créer un produit de prix > 50 000 000 FCFA ou ajuster du stock de quantité > 100 unités par commande vocale).
 
 === CONNAISSANCE IMPRIMANTES ===
 Tu connais les imprimantes connectées au système et les affectations configurées (voir section 🖨️ du contexte).
 Quand l'utilisateur demande d'imprimer, utilise l'imprimante assignée au type de document concerné.
 Si aucune imprimante n'est configurée, informe l'utilisateur et suggère d'aller dans Paramètres → Impression.
 Tu peux répondre aux questions sur l'état des imprimantes, le format papier thermique, et les options d'impression.$searchPrompt""";

    if (businessContext != null && businessContext!.isNotEmpty) {
      return '$basePrompt\n\n=== DONNÉES DE LA BOUTIQUE ===\n$businessContext';
    }
    return basePrompt;
  }

  bool _isComplexPrompt(String prompt) {
    final lower = prompt.toLowerCase();
    final keywords = [
      'calcul', 'marge', 'profit', 'bénéfice', 'analyse', 'rapport', 'bilan', 'horizon', 'prédiction', 'statistique',
      'dette', 'trésorerie', 'comptabilité', 'mensuel', 'performance', 'optimis', 'conseil', 'stratégie'
    ];
    for (final kw in keywords) {
      if (lower.contains(kw)) {
        return true;
      }
    }
    return false;
  }

  Future<String> askAssistant(
    String prompt,
    List<Map<String, String>> conversationHistory, {
    List<int>? attachmentBytes,
    String? attachmentMimeType,
  }) async {
    if (apiKey.isEmpty) {
      return "⚠️ La clé API Danaya VIP n'est pas configurée. Allez dans **Paramètres → Automatisation & IA** pour l'ajouter.";
    }

    // Déterminer la liste des modèles à tenter.
    final List<String> candidateModels = [];
    final isComplex = _isComplexPrompt(prompt);

    if (isComplex) {
      candidateModels.addAll([
        'gemini-3.5-flash',
        'gemini-2.5-flash',
        'gemini-3.1-flash-lite',
        'gemini-2.5-flash-lite',
      ]);
    } else {
      candidateModels.addAll([
        'gemini-3.1-flash-lite',
        'gemini-3.5-flash',
        'gemini-2.5-flash',
        'gemini-2.5-flash-lite',
      ]);
    }

    // Si le modèle configuré n'est pas déjà premier, on le place en premier
    if (model.isNotEmpty) {
      candidateModels.remove(model);
      candidateModels.insert(0, model);
    }

    int attempt = 0;

    for (final currentModel in candidateModels) {
      attempt++;
      // 🔒 Clé API dans le header HTTP (jamais dans l'URL pour éviter les logs réseau)
      final url = Uri.parse('$baseUrl/$currentModel:generateContent');

      // Mapper l'historique au format Gemini (user / model)
      final contents = <Map<String, dynamic>>[];
      for (var msg in conversationHistory) {
        contents.add({
          'role': msg['role'] == 'user' ? 'user' : 'model',
          'parts': [{'text': msg['content']}]
        });
      }

      final userParts = <Map<String, dynamic>>[];
      if (attachmentBytes != null && attachmentMimeType != null) {
        userParts.add({
          'inlineData': {
            'mimeType': attachmentMimeType,
            'data': base64Encode(attachmentBytes),
          }
        });
      }
      userParts.add({'text': prompt.isNotEmpty ? prompt : "Décris cette pièce ou ce document joint de manière synthétique."});

      contents.add({
        'role': 'user',
        'parts': userParts,
      });

      try {
        if (kDebugMode) debugPrint('[Gemini] Tentative avec $currentModel (Essai $attempt/${candidateModels.length}) | Contexte: ${businessContext != null ? "✅ Injecté" : "❌ Absent"}');

        // google_search (Ancrage) n'est supporté que par Gemini 2.5
        final supportsGrounding = currentModel.contains('2.5');

        final requestBody = <String, dynamic>{
            'systemInstruction': {
              'parts': [{'text': _buildSystemPrompt()}]
            },
            'contents': contents,
            'generationConfig': {
              'temperature': 0.7,
              'maxOutputTokens': 4000,
            },
        };

        // Ajouter google_search uniquement si le modèle le supporte
        if (supportsGrounding) {
          requestBody['tools'] = [
            {'google_search': {}}
          ];
        }

        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey, // 🔒 Clé dans header, pas dans l'URL
          },
          body: jsonEncode(requestBody),
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data['candidates'] != null && data['candidates'].isNotEmpty) {
            final content = data['candidates'][0]['content'];
            if (content != null && content['parts'] != null && content['parts'].isNotEmpty) {
              final List parts = content['parts'];
              final fullText = parts.map((p) => p['text']?.toString() ?? '').join('');
              return fullText.trim();
            }
          }
          continue;
        } else {
          if (kDebugMode) debugPrint('[Gemini Error] Modèle: $currentModel | Code: ${response.statusCode} | Body: ${response.body}');
          
          // Clé API invalide : arrêt immédiat
          if (response.statusCode == 400 && response.body.contains('API key not valid')) {
            return "🔑 **La clé d'accès à l'assistant en ligne semble incorrecte ou expirée.**\n\n"
                "👉 **Que faire ?**\n"
                "Vous pouvez la vérifier ou la modifier dans vos **Paramètres** de l'application. En attendant, je continue à fonctionner avec mon intelligence locale.";
          }

          // Pour tout autre statut (429, 404, 400 pour modèle indisponible, 5xx), on continue sur le modèle suivant
          continue;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[Gemini Exception] Modèle: $currentModel | Exception: $e');
        continue;
      }
    }

    // Si on arrive ici, tous les modèles ont échoué
    return "⏱️ **L'assistant intelligent en ligne est temporairement indisponible ou surchargé (limite de quota atteinte).**\n\n"
        "👉 **Que faire ?**\n"
        "1. Veuillez patienter quelques secondes et réessayer.\n"
        "2. Posez-moi votre question : je basculerai automatiquement sur mon intelligence locale Danaya Copilot hors-ligne pour vous répondre.";
  }

  /// Appelle l'assistant intelligent en mode Streaming de jetons.
  Stream<String> askAssistantStream(
    String prompt,
    List<Map<String, String>> conversationHistory, {
    List<int>? attachmentBytes,
    String? attachmentMimeType,
  }) async* {
    if (apiKey.isEmpty) {
      yield "🔑 **La clé d'accès à l'assistant en ligne n'est pas configurée.**\n\nAllez dans vos Paramètres pour l'ajouter.";
      return;
    }

    final currentModel = model.isNotEmpty ? model : 'gemini-3.5-flash';
    final url = Uri.parse('$baseUrl/$currentModel:streamGenerateContent?alt=sse');

    final contents = <Map<String, dynamic>>[];
    for (var msg in conversationHistory) {
      contents.add({
        'role': msg['role'] == 'user' ? 'user' : 'model',
        'parts': [{'text': msg['content']}]
      });
    }

    final userParts = <Map<String, dynamic>>[];
    if (attachmentBytes != null && attachmentMimeType != null) {
      userParts.add({
        'inlineData': {
          'mimeType': attachmentMimeType,
          'data': base64Encode(attachmentBytes),
        }
      });
    }
    userParts.add({'text': prompt.isNotEmpty ? prompt : "Décris cette pièce ou ce document joint de manière synthétique."});

    contents.add({
      'role': 'user',
      'parts': userParts,
    });

    final requestBody = <String, dynamic>{
      'systemInstruction': {
        'parts': [{'text': _buildSystemPrompt()}]
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 4000,
      },
    };

    final supportsGrounding = currentModel.contains('2.5');
    if (supportsGrounding) {
      requestBody['tools'] = [
        {'google_search': {}}
      ];
    }

    final request = http.Request('POST', url);
    request.headers['Content-Type'] = 'application/json';
    request.headers['x-goog-api-key'] = apiKey;
    request.body = jsonEncode(requestBody);

    try {
      if (kDebugMode) debugPrint('[Gemini Stream] Démarrage flux avec $currentModel');
      final client = http.Client();
      final streamedResponse = await client.send(request).timeout(const Duration(seconds: 15));

      if (streamedResponse.statusCode == 200) {
        final stream = streamedResponse.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter());

        await for (final line in stream) {
          if (line.startsWith('data:')) {
            final jsonStr = line.substring(5).trim();
            if (jsonStr.isNotEmpty) {
              try {
                final data = jsonDecode(jsonStr);
                if (data['candidates'] != null && data['candidates'].isNotEmpty) {
                  final content = data['candidates'][0]['content'];
                  if (content != null && content['parts'] != null && content['parts'].isNotEmpty) {
                    final List parts = content['parts'];
                    final chunkText = parts.map((p) => p['text']?.toString() ?? '').join('');
                    if (chunkText.isNotEmpty) {
                      yield chunkText;
                    }
                  }
                }
              } catch (_) {}
            }
          }
        }
      } else {
        if (kDebugMode) debugPrint('[Gemini Stream Error] Code : ${streamedResponse.statusCode}');
        yield "📡 **Erreur lors du streaming des données.** Code: ${streamedResponse.statusCode}";
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Gemini Stream Exception] $e');
      yield "📡 **Erreur de connexion réseau** lors de la récupération des données de l'IA.";
    }
  }

  /// Transcrit un fichier audio via l'API Gemini.
  Future<String> transcribeAudio(
    List<int> audioBytes,
    String mimeType,
  ) async {
    if (apiKey.isEmpty) {
      return "";
    }

    final candidateModels = [
      'gemini-2.5-flash', // Modèle actif de l'utilisateur
      'gemini-3.5-flash',
      'gemini-3-flash',
      'gemini-3.1-flash-lite',
    ];

    for (final currentModel in candidateModels) {
      // 🔒 Clé API dans le header, jamais dans l'URL
      final url = Uri.parse('$baseUrl/$currentModel:generateContent');
      final base64Audio = base64Encode(audioBytes);

      try {
        if (kDebugMode) debugPrint('[Gemini Transcription] Tentative avec $currentModel');
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey, // 🔒 Clé dans header
          },
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {
                    'inlineData': {
                      'mimeType': mimeType,
                      'data': base64Audio,
                    }
                  },
                  {
                    'text': 'Transcris exactement cet enregistrement audio de voix en français. Ne renvoie que la transcription textuelle brute, sans aucun commentaire, sans politesse ni ponctuation inutile. IMPORTANT: Si l\'audio ne contient que du silence, des bruits de respiration, du vent, du bruit de fond (hissing, statique) ou aucun mot compréhensible en français, réponds par un unique caractère espace " " (et RIEN d\'autre, pas de "Bonjour", "Allô", "Oui", etc.).'
                  }
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.0,
              'maxOutputTokens': 1000,
            }
          }),
        ).timeout(const Duration(seconds: 25));

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data['candidates'] != null && data['candidates'].isNotEmpty) {
            final content = data['candidates'][0]['content'];
            if (content != null && content['parts'] != null && content['parts'].isNotEmpty) {
              final List parts = content['parts'];
              final fullText = parts.map((p) => p['text']?.toString() ?? '').join('');
              return fullText.trim();
            }
          }
        } else {
          if (kDebugMode) debugPrint('[Gemini Transcription Error] Modèle: $currentModel | Code: ${response.statusCode} | ${response.body}');
          if (response.statusCode == 429 || response.statusCode >= 500) {
            continue;
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[Gemini Transcription Exception] Modèle: $currentModel | Exception: $e');
        continue;
      }
    }
    return "";
  }

  /// Extrait des produits à partir d'une image de facture ou bon de livraison.
  Future<Map<String, dynamic>> analyzeInvoiceImage(
    List<int> imageBytes,
    String mimeType,
  ) async {
    if (apiKey.isEmpty) {
      throw Exception("Clé API Danaya VIP non configurée.");
    }

    final candidateModels = [
      'gemini-2.5-flash',
      'gemini-3.5-flash',
      'gemini-3-flash',
      'gemini-3.1-flash-lite',
    ];

    for (final currentModel in candidateModels) {
      // 🔒 Clé API dans le header, jamais dans l'URL
      final url = Uri.parse('$baseUrl/$currentModel:generateContent');
      final base64Image = base64Encode(imageBytes);

      try {
        if (kDebugMode) debugPrint('[Gemini Invoice OCR] Tentative avec $currentModel');
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey, // 🔒 Clé dans header
          },
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {
                    'text': "Tu es un extracteur d'informations de factures et bons de livraison pour un système d'inventaire. Analyse cette image de facture ou reçu et extrait les produits et le fournisseur. Retourne uniquement un objet JSON contenant les clés exactes suivantes :\n"
                            "- supplier: un objet contenant { \"name\": \"Nom du fournisseur ou entreprise émettrice\", \"phone\": \"Numéro de téléphone si présent\", \"address\": \"Adresse si présente\" } (laisse des chaînes de caractères vides si non trouvé ou non lisible)\n"
                            "- products: un tableau d'objets produits contenant :\n"
                            "  - name (le nom propre et nettoyé du produit, ex: 'Coca Cola 33cl')\n"
                            "  - purchase_price (le prix d'achat unitaire, nombre à virgule/entier, 0 si non lisible)\n"
                            "  - selling_price (le prix de vente conseillé, estime-le avec une marge standard de 20-30% si non indiqué, nombre à virgule/entier)\n"
                            "  - quantity (la quantité achetée, nombre à virgule/entier, par défaut 1)\n"
                            "  - category (une catégorie estimée pour classer l'article, ex: 'Boissons', 'Électronique', 'Alimentation', etc.)\n"
                            "  - reference (un SKU ou code produit si visible sur l'image, sinon génère une référence vide ou un code logique)\n\n"
                            "Réponds uniquement au format JSON brut valide sous forme d'un objet. IMPORTANT : Ne mets pas de balises de code markdown comme ```json ... ```, renvoie directement le texte brut du JSON pour qu'il puisse être parsé en Dart via jsonDecode."
                  },
                  {
                    'inlineData': {
                      'mimeType': mimeType,
                      'data': base64Image,
                    }
                  }
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.1,
              'responseMimeType': 'application/json',
              'maxOutputTokens': 2000,
            }
          }),
        ).timeout(const Duration(seconds: 40));

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data['candidates'] != null && data['candidates'].isNotEmpty) {
            final content = data['candidates'][0]['content'];
            if (content != null && content['parts'] != null && content['parts'].isNotEmpty) {
              final List parts = content['parts'];
              var fullText = parts.map((p) => p['text']?.toString() ?? '').join('').trim();
              
              // Nettoyer d'éventuelles balises markdown si l'IA en a mis quand même
              if (fullText.startsWith('```')) {
                fullText = fullText.replaceAll(RegExp(r'^```(json)?'), '');
                fullText = fullText.replaceAll(RegExp(r'```$'), '');
                fullText = fullText.trim();
              }
              
              final decoded = jsonDecode(fullText);
              if (decoded is Map) {
                return Map<String, dynamic>.from(decoded);
              } else if (decoded is List) {
                return {
                  'supplier': {'name': '', 'phone': '', 'address': ''},
                  'products': decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList(),
                };
              }
            }
          }
        } else {
          if (kDebugMode) debugPrint('[Gemini Invoice OCR Error] Modèle: $currentModel | Code: ${response.statusCode} | ${response.body}');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[Gemini Invoice OCR Exception] Modèle: $currentModel | Exception: $e');
      }
    }
    throw Exception("Impossible d'extraire les produits de cette facture. Veuillez vérifier votre connexion et votre clé API.");
  }

  /// Extrait des produits à partir d'un texte structuré (ex: CSV ou Excel converti en texte).
  Future<Map<String, dynamic>> analyzeInvoiceText(
    String invoiceText,
  ) async {
    if (apiKey.isEmpty) {
      throw Exception("Clé API Danaya VIP non configurée.");
    }

    final candidateModels = [
      'gemini-2.5-flash',
      'gemini-3.5-flash',
      'gemini-3-flash',
      'gemini-3.1-flash-lite',
    ];

    for (final currentModel in candidateModels) {
      // 🔒 Clé API dans le header, jamais dans l'URL
      final url = Uri.parse('$baseUrl/$currentModel:generateContent');

      try {
        if (kDebugMode) debugPrint('[Gemini Invoice Text Analysis] Tentative avec $currentModel');
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey, // 🔒 Clé dans header
          },
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {
                    'text': "Tu es un extracteur d'informations de factures et bons de livraison pour un système d'inventaire. Analyse les données textuelles ci-dessous (provenant d'un fichier Excel ou CSV) et extrait les produits et le fournisseur. Retourne uniquement un objet JSON contenant les clés exactes suivantes :\n"
                            "- supplier: un objet contenant { \"name\": \"Nom du fournisseur ou entreprise émettrice\", \"phone\": \"Numéro de téléphone si présent\", \"address\": \"Adresse si présente\" } (laisse des chaînes de caractères vides si non trouvé)\n"
                            "- products: un tableau d'objets produits contenant :\n"
                            "  - name (le nom propre et nettoyé du produit, ex: 'Coca Cola 33cl')\n"
                            "  - purchase_price (le prix d'achat unitaire, nombre à virgule/entier, 0 si non indiqué)\n"
                            "  - selling_price (le prix de vente conseillé, estime-le avec une marge standard de 20-30% si non indiqué, nombre à virgule/entier)\n"
                            "  - quantity (la quantité achetée, nombre à virgule/entier, par défaut 1)\n"
                            "  - category (une catégorie estimée pour classer l'article, ex: 'Boissons', 'Électronique', 'Alimentation', etc.)\n"
                            "  - reference (un SKU ou code produit si présent, sinon génère une référence vide ou un code logique)\n\n"
                            "Données du fichier :\n"
                            "====================\n"
                            "$invoiceText\n"
                            "====================\n\n"
                            "Réponds uniquement au format JSON brut valide sous forme d'un objet. IMPORTANT : Ne mets pas de balises de code markdown comme ```json ... ```, renvoie directement le texte brut du JSON pour qu'il puisse être parsé en Dart via jsonDecode."
                  }
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.1,
              'responseMimeType': 'application/json',
              'maxOutputTokens': 2000,
            }
          }),
        ).timeout(const Duration(seconds: 40));

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data['candidates'] != null && data['candidates'].isNotEmpty) {
            final content = data['candidates'][0]['content'];
            if (content != null && content['parts'] != null && content['parts'].isNotEmpty) {
              final List parts = content['parts'];
              var fullText = parts.map((p) => p['text']?.toString() ?? '').join('').trim();
              
              if (fullText.startsWith('```')) {
                fullText = fullText.replaceAll(RegExp(r'^```(json)?'), '');
                fullText = fullText.replaceAll(RegExp(r'```$'), '');
                fullText = fullText.trim();
              }
              
              final decoded = jsonDecode(fullText);
              if (decoded is Map) {
                return Map<String, dynamic>.from(decoded);
              } else if (decoded is List) {
                return {
                  'supplier': {'name': '', 'phone': '', 'address': ''},
                  'products': decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList(),
                };
              }
            }
          }
        } else {
          if (kDebugMode) debugPrint('[Gemini Invoice Text Error] Modèle: $currentModel | Code: ${response.statusCode} | ${response.body}');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[Gemini Invoice Text Exception] Modèle: $currentModel | Exception: $e');
      }
    }
    throw Exception("Impossible d'analyser le texte de cette facture. Veuillez vérifier votre connexion et votre clé API.");
  }

  Future<String?> generateLogicalTitle(String userMessage) async {
    if (apiKey.isEmpty) return null;
    try {
      final prompt = "Génère un titre très court (3 à 5 mots maximum) résumant cette demande ou conversation : \"$userMessage\". Ne renvoie que le titre généré, sans ponctuation finale, ni guillemets.";
      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 20,
        },
      };

      final response = await http.post(
        Uri.parse('$baseUrl/gemini-3.5-flash:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final content = data['candidates'][0]['content'];
          if (content != null && content['parts'] != null && content['parts'].isNotEmpty) {
            String title = content['parts'][0]['text']?.toString().trim() ?? '';
            title = title.replaceAll(RegExp(r'^"|"$'), '');
            return title;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Gemini Title Error] $e');
    }
    return null;
  }
}
