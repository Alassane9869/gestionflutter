import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../inventory/providers/product_providers.dart';
import '../../pos/providers/sales_history_providers.dart';
import '../../clients/providers/client_providers.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import '../../auth/domain/models/user.dart';
import '../../auth/application/auth_service.dart';
import '../../finance/providers/treasury_provider.dart';
import '../../finance/domain/models/financial_account.dart';
import '../../clients/domain/models/client.dart';
import 'nlp_engine.dart';
import 'rule_engine.dart';
import 'rule_manager.dart';
import 'package:danaya_plus/core/theme/theme_provider.dart';
import 'package:danaya_plus/core/theme/app_theme.dart';
import 'package:danaya_plus/features/assistant/application/horizon_engine.dart';
import '../../pos/providers/pos_providers.dart';
import '../../inventory/domain/models/product.dart';
import 'macro_engine.dart';
import '../../srm/providers/srm_service.dart';
import '../../srm/providers/supplier_providers.dart';
import '../../srm/domain/models/purchase_order.dart';
import '../../srm/domain/models/supplier.dart';
import '../../settings/providers/settings_ui_providers.dart';
import '../../inventory/application/inventory_automation_service.dart';
import '../domain/assistant_models.dart';
import 'assistant_notification_service.dart';
import '../domain/assistant_notification.dart';
import 'assistant_tone.dart';
export '../domain/assistant_models.dart';

typedef AssistantActionCallback = void Function(String action, {dynamic payload});

class ProactiveAlertData {
  final String title;
  final String message;
  final dynamic actionPayload;

  ProactiveAlertData({required this.title, required this.message, this.actionPayload});
}

class ProactiveAlertNotifier extends Notifier<ProactiveAlertData?> {
  @override
  ProactiveAlertData? build() => null;
  
  void set(ProactiveAlertData? data) {
    state = data;
    if (data != null) {
      ref.read(assistantNotificationProvider.notifier).addNotification(
        AssistantNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: data.title,
          message: data.message,
          timestamp: DateTime.now(),
          actionPayload: data.actionPayload,
        ),
      );
    }
  }
  void clear() => state = null;
}

final proactiveAlertProvider = NotifierProvider<ProactiveAlertNotifier, ProactiveAlertData?>(
  ProactiveAlertNotifier.new,
);

final assistantProvider = NotifierProvider<AssistantNotifier, AssistantState>(
  AssistantNotifier.new,
);

class AssistantNotifier extends Notifier<AssistantState> {
  AssistantActionCallback? onAction;
  final RuleEngine _ruleEngine = RuleEngine();
  final HorizonEngine _horizonEngine = HorizonEngine();
  final Set<String> _shownInsightKeys = {};
  DateTime _sessionStart = DateTime.now();

  static const _sessionStartKey = 'titan_session_start';
  static const _salesRecordKey = 'titan_sales_record';

  void setActionCallback(AssistantActionCallback callback) {
    onAction = callback;
  }

  List<String> _getProactiveSuggestions(AssistantContext context) {
    switch (context) {
      case AssistantContext.dashboard:
        return ["Bilan du jour", "Alertes stock", "Top produits"];
      case AssistantContext.inventory:
        return ["Ajouter produit", "Audit physique", "Produits en rupture"];
      case AssistantContext.pos:
        return ["Nouvelle vente", "Ventes d'aujourd'hui", "Fermer la caisse"];
      case AssistantContext.finance:
        return ["Nouvelle dépense", "État trésorerie", "Dettes clients"];
      case AssistantContext.clients:
        return ["Ajouter client", "Liste débiteurs", "Encaissement dette"];
      case AssistantContext.settings:
        return ["Changer thème", "Infos boutique", "Config imprimante"];
      case AssistantContext.reports:
        return ["Rapport mensuel", "Analyse marges", "Export CSV"];
      default:
        return ["Que sais-tu faire ?", "Bilan du jour", "Mode sombre"];
    }
  }

  @override
  AssistantState build() {
    _initSession();
    _checkFirstTime();
    return AssistantState();
  }

  Future<void> _initSession() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate = prefs.getString(_sessionStartKey);
    if (storedDate == null || !storedDate.startsWith(todayStr)) {
      await prefs.setString(_sessionStartKey, DateTime.now().toIso8601String());
      _sessionStart = DateTime.now();
      _shownInsightKeys.clear();
    } else {
      _sessionStart = DateTime.tryParse(storedDate) ?? DateTime.now();
    }
  }

  static const _onboardingKey = 'onboarding_completed_v2';

  Future<void> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_onboardingKey) != true) {
      startOnboarding();
    } else {
      _addWelcomeMessage();
    }
  }

  void _addWelcomeMessage() {
    final stats = ref.read(stockStatsProvider);
    final salesAsync = ref.read(salesHistoryProvider);
    final today = DateTime.now();
    final settings = ref.read(shopSettingsProvider).value;
    final currency = settings?.currency ?? "FCFA";


    final user = ref.read(authServiceProvider).value;
    String greeting = AssistantTone.greeting();
    String welcomeText = "$greeting\n\n";

    final canSeeSales = user != null && user.canAccessReports;
    final sales = salesAsync.value ?? [];
    final todaySales = sales.where((s) => s.sale.date.year == today.year && s.sale.date.month == today.month && s.sale.date.day == today.day);
    final totalToday = todaySales.fold(0.0, (sum, s) => sum + s.sale.totalAmount);

    if (todaySales.isNotEmpty) {
      if (canSeeSales) {
        welcomeText += "📊 Vous avez déjà ${todaySales.length} ventes (${DateFormatter.formatCurrency(totalToday, currency, removeDecimals: settings?.removeDecimals ?? true)}).\n";
      } else {
        welcomeText += "📊 Vous avez déjà enregistré ${todaySales.length} ventes aujourd'hui.\n";
      }
    }
    if (stats.outOfStockCount > 0) {
      welcomeText += "🔴 Attention : ${stats.outOfStockCount} produits en rupture !";
    } else {
      welcomeText += "✅ Stock sain. Bonne journée de vente !";
    }

    state = state.copyWith(
      messages: [AssistantMessage(text: welcomeText)],
      suggestedActions: ["État du stock", "Ventes du jour", "Ouvre la caisse"],
    );
  }

  void toggleOpen() {
    state = state.copyWith(isOpen: !state.isOpen);
  }

  void setContext(AssistantContext ctx) {
    if (state.currentContext == ctx) return;
    state = state.copyWith(
      currentContext: ctx,
      suggestedActions: _getProactiveSuggestions(ctx),
    );
    
    final settings = ref.read(shopSettingsProvider).value;
    final isTitan = (settings?.assistantLevel.index ?? 0) >= AssistantPowerLevel.titan.index;
    final stats = ref.read(stockStatsProvider);
    final salesAsync = ref.read(salesHistoryProvider);
    final sales = salesAsync.value ?? [];
    final today = DateTime.now();
    final todaySalesCount = sales.where((s) => s.sale.date.year == today.year && s.sale.date.month == today.month && s.sale.date.day == today.day).length;
    
    String helpText;
    List<String> actions;
    switch (ctx) {
      case AssistantContext.dashboard:
        helpText = "📊 Dashboard actif. Je surveille vos KPIs en temps réel.";
        actions = _buildDynamicSuggestions(ctx, stats, todaySalesCount, today);
        if (isTitan) {
          _checkBenevolenceRules();
          _checkHorizonRules();
        }
        break;
      case AssistantContext.pos:
        helpText = "Prêt pour une vente ? Scannez un article ou utilisez la recherche.";
        actions = _buildDynamicSuggestions(ctx, stats, todaySalesCount, today);
        if (isTitan) {
          helpText += "\n🛡️ Fraude check actif. Je surveille les remises anormales.";
          // Rush Hour detection
          if (_horizonEngine.isRushHour(sales)) {
            helpText += "\n⚡ **Rush détecté !** Activez le Mode Caisse Rapide pour plus de vitesse.";
            actions.insert(0, "Mode Rapide");
          }
        }
        break;
      case AssistantContext.inventory:
        helpText = "C'est ici que vous gérez vos produits.";
        actions = _buildDynamicSuggestions(ctx, stats, todaySalesCount, today);
        if (isTitan && stats.outOfStockCount > 0) {
          helpText += "\n🔴 **Omniscience** : Je détecte ${stats.outOfStockCount} ruptures. Voulez-vous préparer un bon de commande ?";
          actions.insert(0, "Commander ruptures");
        }
        break;
      case AssistantContext.finance:
        helpText = "Gérez votre trésorerie et vos dépenses.";
        actions = ["Bilan d'ouverture", "Saisir dépense"];
        break;
      case AssistantContext.clients:
        helpText = "Consultez et gérez vos clients.";
        actions = ["Nouveau client", "Dettes clients"];
        break;
      case AssistantContext.suppliers:
        helpText = "Gérez vos fournisseurs.";
        actions = ["Nouvelle commande", "Suivi livraison"];
        break;
      case AssistantContext.settings:
        helpText = "Configurez l'application.";
        actions = ["Sécurité", "Profil boutique"];
        break;
      case AssistantContext.reports:
        helpText = "Accédez à des rapports détaillés.";
        actions = ["Rapport mensuel", "Export PDF"];
        break;
      case AssistantContext.general:
        helpText = "Je suis là pour vous aider.";
        actions = _buildDynamicSuggestions(ctx, stats, todaySalesCount, today);
    }
    
    if (state.isOpen) {
      state = state.copyWith(
        messages: [...state.messages, AssistantMessage(text: helpText)],
        suggestedActions: actions,
      );
    }
  }

  // C3. Dynamic suggestions based on real data
  List<String> _buildDynamicSuggestions(AssistantContext ctx, dynamic stats, int todaySalesCount, DateTime now) {
    final hour = now.hour;
    final actions = <String>[];
    
    switch (ctx) {
      case AssistantContext.dashboard:
        if (hour < 10) actions.add("Ouvre la caisse");
        if (todaySalesCount > 5) actions.add("Top produits");
        actions.add("Bilan de vente");
        if (stats.outOfStockCount > 0) actions.add("Alertes stock (${stats.outOfStockCount})");
        if (hour >= 17) actions.add("Bilan du jour");
        break;
      case AssistantContext.pos:
        actions.addAll(["Ticket de caisse", "Remises"]);
        if (todaySalesCount > 0) actions.add("Voir ventes ($todaySalesCount)");
        break;
      case AssistantContext.inventory:
        actions.addAll(["Import Excel", "Nouvel article"]);
        if (stats.outOfStockCount > 0) actions.add("Commander ruptures");
        break;
      default:
        actions.addAll(["Dépenses", "Clients"]);
    }
    return actions;
  }

  // A1 + B4. Benevolence & Coach Rules — Fatigue, Sales celebration & Velocity
  void _checkBenevolenceRules() async {
    final now = DateTime.now();
    final sessionDuration = now.difference(_sessionStart);

    // Fatigue detection (> 6 hours)
    if (sessionDuration.inHours >= 6 && !_shownInsightKeys.contains('benev_fatigue')) {
      _shownInsightKeys.add('benev_fatigue');
      String msg = AssistantTone.fatigueWarning();
      addAssistantMessage(msg);
    }

    // Sales metrics
    final sales = ref.read(salesHistoryProvider).value ?? [];
    final todaySales = sales.where((s) => s.sale.date.year == now.year && s.sale.date.month == now.month && s.sale.date.day == now.day);
    final totalToday = todaySales.fold(0.0, (sum, s) => sum + s.sale.totalAmount);

    final prefs = await SharedPreferences.getInstance();
    final previousRecord = prefs.getDouble(_salesRecordKey) ?? 0.0;
    
    final settings = ref.read(shopSettingsProvider).value;
    final currency = settings?.currency ?? 'FCFA';
    if (totalToday > previousRecord && totalToday > 0 && !_shownInsightKeys.contains('benev_record')) {
      await prefs.setDouble(_salesRecordKey, totalToday);
      _shownInsightKeys.add('benev_record');
      String msg = AssistantTone.salesRecord();
      addAssistantMessage("$msg\n(${DateFormatter.formatCurrency(totalToday, currency, removeDecimals: settings?.removeDecimals ?? true)})");
    }

    // Titan Proactive Coach (Velocity Analysis)
    final isTitan = (settings?.assistantLevel.index ?? 0) >= AssistantPowerLevel.titan.index;
    
    if (isTitan && !_shownInsightKeys.contains('coach_velocity_alert')) {
      // Analyze sales velocity vs history
      final products = ref.read(productListProvider).value ?? [];
      // No lastSaleDate in Product model, skipping velocity check for now.
      // But we can check for products with high stock that are not in the top sales.
      final topProducts = ref.read(salesHistoryProvider).value ?? [];
      
      if (products.any((p) => p.quantity > 100) && topProducts.length > 5) {
         _shownInsightKeys.add('coach_velocity_alert');
         addAssistantMessage("📣 **Coach TITAN** : Certains produits ont un stock élevé (>100) mais ne sont pas dans vos meilleures ventes. Pensez à les mettre en avant !");
      }
    }

    if (isTitan && !_shownInsightKeys.contains('benev_velocity_15') && now.hour == 15) {
      _shownInsightKeys.add('benev_velocity_15');
      if (totalToday == 0) {
        addAssistantMessage("📣 **Coach TITAN** : Il est 15h00 et aucune vente n'est enregistrée. C'est anormal. Je vous conseille de lancer une petite promotion ou de relancer vos clients fidèles !");
      } else if (previousRecord > 0 && totalToday < (previousRecord * 0.2)) {
        addAssistantMessage("📣 **Coach TITAN** : Point de 15h00. Vos ventes sont exceptionnellement calmes (moins de 20% du record). Vérifiez si vos produits phares sont bien mis en avant !");
      }
    }
  }

  // C1. Horizon Rules with deduplication and typed data
  void _checkHorizonRules() {
    final settings = ref.read(shopSettingsProvider).value;
    if (settings == null) return;
    
    final sales = ref.read(salesHistoryProvider).value ?? [];
    final clients = ref.read(clientListProvider).value ?? [];
    final products = ref.read(productListProvider).value ?? [];
    
    final insights = _horizonEngine.generateBusinessInsights(
      sales: sales,
      clients: clients,
      products: products,
      formatCurrency: (val) => DateFormatter.formatCurrency(
        val, 
        settings.currency, 
        removeDecimals: settings.removeDecimals
      ),
    );
    for (final insight in insights) {
      if (!_shownInsightKeys.contains(insight.key)) {
        _shownInsightKeys.add(insight.key);
        addAssistantMessage("🔮 **Horizon** : ${insight.suggestion}");
      }
    }
  }

  void startOnboarding() {
    state = state.copyWith(
      isOpen: true,
      isOnboardingActive: true,
      onboardingStep: 1,
      messages: [
        AssistantMessage(text: "Bienvenue sur Danaya+ ! 🚀 Laissez-moi vous faire faire le tour du propriétaire.")
      ],
    );
  }

  void nextOnboardingStep() {
    if (state.onboardingStep < 5) {
      state = state.copyWith(onboardingStep: state.onboardingStep + 1);
      _handleOnboardingStep(state.onboardingStep);
    } else {
      completeOnboarding();
    }
  }

  void _handleOnboardingStep(int step) {
    String msg = "";
    switch (step) {
      case 2: msg = "Ici sur le Dashboard, suivez vos ventes et alertes en temps réel."; break;
      case 3: msg = "Le menu à gauche vous donne accès à la Caisse, la Gestion Produits ou la Trésorerie."; break;
      case 4: msg = "Conseil : Commencez par importer vos produits via Excel dans la Gestion Produits."; break;
      case 5: msg = "C'est tout pour le moment ! Je reste ici si besoin. Bonne gestion !"; break;
    }
    state = state.copyWith(messages: [...state.messages, AssistantMessage(text: msg)]);
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    state = state.copyWith(isOnboardingActive: false, onboardingStep: 0);
  }

  void sendMessage(String text) async {
    state = state.copyWith(
      messages: [...state.messages, AssistantMessage(text: text, isUser: true)],
      isTyping: true,
      suggestedActions: [],
    );
    await Future.delayed(const Duration(seconds: 1));
    _processUserMessage(text);
  }

  void _processUserMessage(String text) {
    final stats = ref.read(stockStatsProvider);
    final salesAsync = ref.read(salesHistoryProvider);
    final clientsAsync = ref.read(clientListProvider);
    final today = DateTime.now();
    final settings = ref.read(shopSettingsProvider).value;
    final currency = settings?.currency ?? "FCFA";


    final isTitan = (settings?.assistantLevel.index ?? 0) >= AssistantPowerLevel.titan.index;
    final activeRules = ref.read(ruleManagerProvider);

    if (isTitan && activeRules.isNotEmpty) {
      _checkAutonomousRules(activeRules);
    }

    // --- FLOW INTERCEPTION (MULTI-TURN) ---
    if (state.currentFlow != AssistantFlow.none) {
      _handleFlowInput(text);
      return;
    }

    final nlpResult = NlpEngine.analyze(text, context: state.currentContext);
    final user = ref.read(authServiceProvider).value;
    String reply = "";
    List<String> suggestions = [];

    // Contextual boost (Option 3 Logic)
    final contextBoost = state.currentContext;
    suggestions = _getProactiveSuggestions(contextBoost);

    // Helper for permission checks
    bool hasPermission(bool Function(User) check) {
      final u = user;
      if (u == null) return false;
      return check(u);
    }

    String accessDeniedMsg = "Désolé ${user?.username ?? 'Boss'}, votre profil ne permet pas d'accéder à cette section ou à ces données sensibles. 🛡️";

    switch (nlpResult.intent) {
      case NlpIntent.navigatePOS:
        reply = "🚀 Navigation vers la **Caisse (POS)**...";
        if (onAction != null) onAction!("navigate", payload: 3);
        suggestions = ["Nouvelle vente", "Rechercher produit", "Raccourcis caisse"];
        break;
      case NlpIntent.navigateInventory:
        if (!hasPermission((u) => u.canManageInventory)) { reply = accessDeniedMsg; break; }
        reply = "📦 Ouverture de la **GESTION PRODUITS**...";
        if (onAction != null) onAction!("navigate", payload: 1);
        suggestions = ["Alertes rupture", "Ajouter produit", "Import Excel"];
        break;
      case NlpIntent.navigateFinance:
        if (!hasPermission((u) => u.canAccessFinance)) { reply = accessDeniedMsg; break; }
        reply = "💰 Navigation vers la **Gestion Financière**...";
        if (onAction != null) onAction!("navigate", payload: 6);
        suggestions = ["Saisir dépense", "Bilan P&L"];
        break;
      case NlpIntent.navigateClients:
        if (!hasPermission((u) => u.canManageUsers)) { reply = accessDeniedMsg; break; }
        reply = "👥 Ouverture des **Clients**...";
        if (onAction != null) onAction!("navigate", payload: 7);
        suggestions = ["Dettes clients", "Fidélité"];
        break;
      case NlpIntent.navigateSuppliers:
        if (!hasPermission((u) => u.canManageSuppliers)) { reply = accessDeniedMsg; break; }
        reply = "🏭 Navigation vers les **Fournisseurs**...";
        if (onAction != null) onAction!("navigate", payload: 8);
        suggestions = ["Nouvelle commande"];
        break;
      case NlpIntent.navigateSettings:
        if (!hasPermission((u) => u.canAccessSettings)) { reply = accessDeniedMsg; break; }
        reply = "⚙️ Ouverture des **Paramètres**...";
        if (onAction != null) onAction!("navigate", payload: 9);
        suggestions = ["Thème sombre", "Sauvegarde"];
        break;
      case NlpIntent.navigateReports:
        if (!hasPermission((u) => u.canAccessReports)) { reply = accessDeniedMsg; break; }
        reply = "📋 Ouverture des **Rapports**...";
        if (onAction != null) onAction!("navigate", payload: 5);
        suggestions = ["Export PDF", "Top produits"];
        break;
      case NlpIntent.navigateStockMovements:
        if (!hasPermission((u) => u.canManageInventory)) { reply = accessDeniedMsg; break; }
        reply = "📦 Mouvements de stock...";
        if (onAction != null) onAction!("navigate", payload: 2);
        break;
      case NlpIntent.navigateSalesHistory:
        if (!hasPermission((u) => u.canAccessReports)) { reply = accessDeniedMsg; break; }
        reply = "📜 Historique des ventes...";
        if (onAction != null) onAction!("navigate", payload: 4);
        break;
      case NlpIntent.navigateQuotes:
        reply = "📄 Gestion des devis / proformas...";
        if (onAction != null) onAction!("navigate", payload: 10);
        break;
      case NlpIntent.navigateWarehouses:
        if (!hasPermission((u) => u.isAdmin || u.isManager)) { reply = accessDeniedMsg; break; }
        reply = "🏢 Gestion des magasins / entrepôts...";
        if (onAction != null) onAction!("navigate", payload: 11);
        break;
      case NlpIntent.navigateClientDebt:
        if (!hasPermission((u) => u.canAccessFinance)) { reply = accessDeniedMsg; break; }
        reply = "💳 Liste des dettes clients...";
        if (onAction != null) onAction!("navigate", payload: 12);
        break;
      case NlpIntent.navigateExpenses:
        if (!hasPermission((u) => u.canAccessFinance)) { reply = accessDeniedMsg; break; }
        reply = "💸 Gestion des dépenses...";
        if (onAction != null) onAction!("navigate", payload: 13);
        break;
      case NlpIntent.navigateStockAlerts:
        if (!hasPermission((u) => u.canManageInventory)) { reply = accessDeniedMsg; break; }
        reply = "🚨 Alertes et ruptures de stock...";
        if (onAction != null) onAction!("navigate", payload: 14);
        break;
      case NlpIntent.navigateStockAudit:
        if (!hasPermission((u) => u.isAdmin || u.isManager)) { reply = accessDeniedMsg; break; }
        reply = "📋 Audit Physique du Stock...";
        if (onAction != null) onAction!("navigate", payload: 15);
        break;
      case NlpIntent.navigatePurchases:
        if (!hasPermission((u) => u.canManageInventory)) { reply = accessDeniedMsg; break; }
        reply = "🛒 Approvisionnements et Achats...";
        if (onAction != null) onAction!("navigate", payload: 16);
        break;
      case NlpIntent.navigateUsers:
        if (!hasPermission((u) => u.isAdmin)) { reply = accessDeniedMsg; break; }
        reply = "👨‍💻 Panneau d'administration Utilisateurs...";
        if (onAction != null) onAction!("navigate", payload: 17);
        break;
      case NlpIntent.navigateHelp:
        reply = "🆘 Centre d'Aide & Documentation...";
        if (onAction != null) onAction!("navigate", payload: 18);
        break;
      case NlpIntent.navigateHR:
        if (!hasPermission((u) => u.isAdmin || u.isManager)) { reply = accessDeniedMsg; break; }
        reply = "👔 Gestion des Ressources Humaines...";
        if (onAction != null) onAction!("navigate", payload: 19);
        break;
      case NlpIntent.navigateAppearance:
        if (!hasPermission((u) => u.canAccessSettings)) { reply = accessDeniedMsg; break; }
        reply = "🎨 Ouverture des réglages d'**Apparence**...";
        ref.read(settingsTabIndexProvider.notifier).setIndex(4); // Index 4 = Apparence
        if (onAction != null) onAction!("navigate", payload: 9);
        suggestions = ["Changer thème", "Mode sombre", "Mode clair"];
        break;
      case NlpIntent.navigateDashboard:
        reply = "🏠 Retour au **Tableau de Bord**...";
        if (onAction != null) onAction!("navigate", payload: 0);
        suggestions = ["Bilan du jour", "Alertes stock"];
        break;

      case NlpIntent.greeting:
        final h = today.hour;
        final sal = h < 12 ? "Bon matin" : h < 18 ? "Bon après-midi" : "Bonsoir";
        reply = "$sal, Boss ! 👑 Je suis l'IA de Danaya+.\nJe peux analyser vos ventes, gérer votre stock et naviguer pour vous.";
        suggestions = ["Bilan du jour", "Ouvre la caisse", "Que sais-tu faire ?"];
        break;
      case NlpIntent.farewell:
        reply = "À bientôt, Boss ! 👋 Je reste disponible.";
        break;
      case NlpIntent.thanks:
        reply = "😎 Au service de votre business !";
        break;
      case NlpIntent.humor:
        reply = "😂 Pourquoi le commerçant a souri ? Ses chiffres étaient *positifs* !";
        break;
      case NlpIntent.insult:
        reply = "😤 Je préfère parler affaires !";
        break;

      case NlpIntent.salesQuery:
        if (!hasPermission((u) => u.canAccessReports)) { reply = accessDeniedMsg; break; }
        final sales = salesAsync.value ?? [];
        if (nlpResult.timeModifier == 'hier') {
          final y = today.subtract(const Duration(days: 1));
          final ys = sales.where((s) => s.sale.date.year == y.year && s.sale.date.month == y.month && s.sale.date.day == y.day);
          final t = ys.fold(0.0, (sum, s) => sum + s.sale.totalAmount);
          reply = "📅 **Hier :** ${DateFormatter.formatCurrency(t, currency, removeDecimals: settings?.removeDecimals ?? true)}";
        } else {
          final ts = sales.where((s) => s.sale.date.year == today.year && s.sale.date.month == today.month && s.sale.date.day == today.day);
          final tt = ts.fold(0.0, (sum, s) => sum + s.sale.totalAmount);
          reply = "📊 **Flash Info :**\n• Aujourd'hui : ${DateFormatter.formatCurrency(tt, currency, removeDecimals: settings?.removeDecimals ?? true)}";
        }
        suggestions = ["Top produits", "Ventes d'hier"];
        break;
      case NlpIntent.salesTopProducts:
        if (!hasPermission((u) => u.canAccessReports)) { reply = accessDeniedMsg; break; }
        final sales = salesAsync.value ?? [];
        if (sales.isEmpty) {
          reply = "📉 Aucune vente enregistrée pour le moment.";
        } else {
          final productCounts = <String, double>{};
          for (final sale in sales) {
            for (final saleItemWithProd in sale.items) {
              productCounts[saleItemWithProd.productName] = (productCounts[saleItemWithProd.productName] ?? 0) + saleItemWithProd.item.quantity;
            }
          }
          final sorted = productCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final top5 = sorted.take(5).map((e) => "• ${e.key} (${DateFormatter.formatQuantity(e.value)} vendus)").join("\n");
          reply = "🏆 **Vos Top Produits :**\n$top5";
        }
        suggestions = ["Ouvre les rapports", "Ventes d'aujourd'hui"];
        break;
      case NlpIntent.salesCount:
        final sales = salesAsync.value ?? [];
        reply = "🔢 **Total :** ${sales.length} ventes enregistrées.";
        break;

      case NlpIntent.stockQuery:
        reply = "📦 **Stock :** Ruptures: ${stats.outOfStockCount} | Valeur: ${DateFormatter.formatCurrency(stats.totalStockValue, currency, removeDecimals: true)}";
        suggestions = ["Produits en rupture", "Valeur du stock"];
        break;
      case NlpIntent.stockSearch:
        final q = nlpResult.searchQuery?.toLowerCase() ?? "";
        if (q.isEmpty) {
          reply = "🔍 Dites-moi quel produit vous recherchez. Par exemple : 'Stock de farine'.";
          break;
        }
        final products = ref.read(productListProvider).value ?? [];
        var matches = products.where((p) => p.name.toLowerCase().contains(q)).toList();
        
        // Titan V4: Search Correction
        if (matches.isEmpty && q.length > 3) {
          matches = products.where((p) {
            final sim = NlpEngine.similarity(p.name.toLowerCase(), q);
            return sim >= 0.6; // Tolérance aux fautes de frappe
          }).toList();
          
          if (matches.isNotEmpty) {
            reply = "🔍 Je n'ai pas trouvé exactement **\"$q\"**, mais voici ce qui s'en rapproche :\n";
          }
        }

        if (matches.isEmpty) {
          reply = "🔍 Aucun produit trouvé pour **\"$q\"**. Je vous redirige vers l'inventaire pour une recherche plus large.";
          if (onAction != null) onAction!("navigate", payload: 1);
        } else if (matches.length == 1) {
          final p = matches.first;
          reply += "📦 **${p.name}** :\n• Stock : **${DateFormatter.formatQuantity(p.quantity)} ${p.unit}**\n• Prix : **${DateFormatter.formatCurrency(p.sellingPrice, currency, removeDecimals: settings?.removeDecimals ?? true)}**";
          if (p.isLowStock) reply += "\n⚠️ Attention : Stock faible !";
        } else {
          final list = matches.take(5).map((p) => "• ${p.name} (${DateFormatter.formatQuantity(p.quantity)} ${p.unit})").join("\n");
          reply += "🔍 Voici les produits trouvés :\n$list";
          if (matches.length > 5) reply += "\n*(...et ${matches.length - 5} autres)*";
          suggestions = ["Voir tout dans l'inventaire"];
        }
        break;
      case NlpIntent.stockLowAlert:
        reply = "🚨 **Ruptures :** ${stats.outOfStockCount} produits à commander.";
        suggestions = ["Commander ruptures"];
        break;
      case NlpIntent.stockValue:
        reply = "💎 **Valeur :** ${DateFormatter.formatCurrency(stats.totalStockValue, currency, removeDecimals: settings?.removeDecimals ?? true)} d'achat en stock.";
        break;

      case NlpIntent.financeQuery:
        reply = "💰 **Finance :** Consultez la trésorerie pour le détail.";
        if (onAction != null) onAction!("navigate", payload: 6);
        break;
      case NlpIntent.financeExpenses:
        if (!hasPermission((u) => u.canAccessFinance)) { reply = accessDeniedMsg; break; }
        final txAsync = ref.read(transactionHistoryProvider);
        final txs = txAsync.value ?? [];
        final expenses = txs.where((t) => t.type == TransactionType.OUT).toList();
        if (expenses.isEmpty) {
          reply = "📉 Aucune dépense récente enregistrée.";
        } else {
          final list = expenses.take(5).map((e) => "• ${e.category.name} : ${DateFormatter.formatCurrency(e.amount, currency, removeDecimals: settings?.removeDecimals ?? true)} (${e.description ?? 'Sans description'})").join("\n");
          reply = "💸 **Dépenses Récentes :**\n$list";
        }
        suggestions = ["Bilan P&L", "Saisir dépense"];
        break;
      case NlpIntent.financeProfitLoss:
        if (!hasPermission((u) => u.canAccessFinance)) { reply = accessDeniedMsg; break; }
        final statsAsync = ref.read(financialStatsProvider);
        final statsData = statsAsync.value;
        if (statsData == null) {
          reply = "⏳ Les statistiques financières sont en cours de calcul...";
        } else {
          final rev = statsData['in'] ?? 0.0;
          final exp = statsData['out'] ?? 0.0;
          final profit = rev - exp;
          reply = "📈 **Bilan 30 jours :**\n• Chiffre d'Affaire : **${DateFormatter.formatCurrency(rev, currency, removeDecimals: settings?.removeDecimals ?? true)}**\n• Dépenses : **${DateFormatter.formatCurrency(exp, currency, removeDecimals: settings?.removeDecimals ?? true)}**\n\n💰 Bénéfice Net : **${DateFormatter.formatCurrency(profit, currency, removeDecimals: settings?.removeDecimals ?? true)}**";
          if (profit < 0) reply += "\n⚠️ Attention, vos dépenses dépassent vos revenus sur cette période.";
        }
        suggestions = ["Détail dépenses", "Top produits"];
        break;
      case NlpIntent.clientQuery:
        final cl = clientsAsync.value ?? [];
        reply = "👥 **Clients :** ${cl.length} clients gérés.";
        suggestions = ["Dettes clients", "Client le plus fidèle"];
        break;
      case NlpIntent.supplierQuery:
        reply = "🏭 **Fournisseurs :** Pour gérer vos fournisseurs et commandes, allez dans la section **SRM / Fournisseurs**.";
        if (onAction != null) onAction!("navigate", payload: 8);
        break;
      case NlpIntent.securityQuery:
        reply = "🛡️ **Sécurité TITAN** : Danaya+ est une application **100% Offline**. Vos données sont stockées localement sur cet ordinateur dans une base de données chiffrée. Elles ne circulent jamais sur internet.";
        break;
      case NlpIntent.networkQuery:
        final netMode = settings?.networkMode.name ?? "LOCAL";
        reply = "🌐 **Réseau** : Vous êtes actuellement en mode **$netMode**. L'application fonctionne sans internet. Pour synchroniser plusieurs postes, utilisez le mode Client/Serveur dans les paramètres.";
        break;
      case NlpIntent.clientDebtList:
        if (!hasPermission((u) => u.canAccessFinance)) { reply = accessDeniedMsg; break; }
        final cl = clientsAsync.value ?? [];
        final debtors = cl.where((c) => c.credit > 0).toList();
        if (debtors.isEmpty) {
          reply = "✅ Bravo ! Aucun client n'a de dette actuellement.";
        } else {
          debtors.sort((a, b) => b.credit.compareTo(a.credit));
          final totalDebt = debtors.fold(0.0, (sum, c) => sum + c.credit);
          final list = debtors.take(5).map((c) => "• ${c.name} : ${DateFormatter.formatCurrency(c.credit, currency, removeDecimals: true)}").join("\n");
          reply = "💳 **Dettes Clients (${debtors.length}) :**\nTotal: **${DateFormatter.formatCurrency(totalDebt, currency, removeDecimals: true)}**\n\n$list";
          if (debtors.length > 5) reply += "\n*(...et ${debtors.length - 5} autres)*";
        }
        suggestions = ["Suivi des dettes", "Relancer clients"];
        break;
      case NlpIntent.clientCount:
        final cl = clientsAsync.value ?? [];
        reply = "🔢 Vous avez **${cl.length} clients** dans votre base de données.";
        break;

      case NlpIntent.actionNewSale:
        if (isTitan) {
          final items = _extractCartItemsFromText(nlpResult.rawInput);
          if (items.isNotEmpty) {
            _handleVoiceCartOrchestration(items);
            return;
          }
        }
        reply = "🛒 Ouverture de la caisse...";
        if (onAction != null) onAction!("navigate", payload: 3);
        break;
      case NlpIntent.actionNewProduct:
        _startFlow(AssistantFlow.product);
        return;
      case NlpIntent.actionNewExpense:
        _startFlow(AssistantFlow.expense);
        return;
      case NlpIntent.actionNewClient:
        _startFlow(AssistantFlow.client);
        return;
      case NlpIntent.actionNewPurchaseOrder:
        _startFlow(AssistantFlow.purchaseOrder);
        return;
      case NlpIntent.actionMacroLearn:
        if (isTitan) {
          reply = "🎙️ **[Orchestration Titan]** Mon nouveau moteur de Macro est actif. Je connais nativement des dizaines de séquences comme 'Audit Total', 'Fin de journée', ou 'Mode Rush'. Plus besoin de me les apprendre manuellement !";
        } else {
          reply = "🔒 L'orchestration des Macros est réservée au niveau Titan.";
        }
        break;

      case NlpIntent.macroEndOfDay:
         _executeMacro('fermeture_caisse'); 
         return;
      case NlpIntent.macroFullAudit:
         _executeMacro('audit_total');
         return;
      case NlpIntent.macroDebtRecovery:
         _executeMacro('preparer_recouvrement');
         return;
      case NlpIntent.macroStockPanic:
         _executeMacro('urgences_stocks');
         return;
      case NlpIntent.macroMorning:
         _executeMacro('ouverture_boutique');
         return;
      case NlpIntent.macroSecurize:
         _executeMacro('securisation_donnees');
         return;
      case NlpIntent.macroHrReview:
         _executeMacro('gestion_equipe');
         return;
      case NlpIntent.actionQuickPos:
         _executeMacro('mode_rush');
         return;

      case NlpIntent.actionCreateRule:
        final ruleName = nlpResult.searchQuery ?? "Nouvelle Règle";
        final newRule = BusinessRule(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: ruleName,
          trigger: RuleTriggerType.stockLow,
          action: RuleActionType.notifyUser,
          conditions: {'threshold': 5.0},
          actionPayload: {'message': "Alerte pour $ruleName"},
        );
        ref.read(ruleManagerProvider.notifier).addRule(newRule);
        reply = "🛡️ Règle créée : **'${newRule.name}'**. Je surveille pour vous.";
        break;

      case NlpIntent.themeToggle:
        final current = ref.read(themeNotifierProvider).mode;
        final next = current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
        ref.read(themeNotifierProvider.notifier).setThemeMode(next);
        reply = next == ThemeMode.dark ? "🌙 Mode sombre activé." : "☀️ Mode clair activé.";
        break;
      case NlpIntent.themeDark:
        ref.read(themeNotifierProvider.notifier).setThemeMode(ThemeMode.dark);
        reply = "🌙 Le Mode Sombre (TITAN) a été activé pour votre confort visuel.";
        break;
      case NlpIntent.themeLight:
        ref.read(themeNotifierProvider.notifier).setThemeMode(ThemeMode.light);
        reply = "☀️ Le Mode Clair a été rétabli.";
        break;
      case NlpIntent.themeColorChange:
        final query = nlpResult.searchQuery?.toLowerCase() ?? nlpResult.rawInput.toLowerCase();
        AppThemeColor? color;
        if (query.contains('bleu')) {
          color = AppThemeColor.blue;
        } else if (query.contains('orange')) {
          color = AppThemeColor.orange;
        } else if (query.contains('vert')) {
          color = AppThemeColor.green;
        } else if (query.contains('violet')) {
          color = AppThemeColor.purple;
        } else if (query.contains('rouge')) {
          color = AppThemeColor.red;
        } else if (query.contains('turquoise') || query.contains('teal')) {
          color = AppThemeColor.teal;
        } else if (query.contains('rose')) {
          color = AppThemeColor.pink;
        } else if (query.contains('gris')) {
          color = AppThemeColor.grey;
        }
        
        if (color != null) {
          ref.read(themeNotifierProvider.notifier).setThemeColor(color);
          reply = "🎨 **Métamorphose Titan** : J'ai appliqué le thème **${color.label}**. Quelle allure !";
        } else {
          reply = "🎨 Je n'ai pas trouvé cette couleur. Essayez : Bleu, Orange, Vert, Violet, Rouge, Turquoise, Rose ou Gris.";
        }
        break;
      case NlpIntent.themeQuery:
        final colors = AppThemeColor.values.map((c) => "• **${c.label}**").join("\n");
        reply = "🎨 **Design Titan**\nJe dispose de 2 modes (Clair/Sombre) et de 8 thèmes colorés :\n$colors\n\nDites simplement : 'Mets le thème en vert' ou 'Passe en mode sombre'.";
        break;
      case NlpIntent.actionUpdateSetting:
        _handleSettingUpdate(nlpResult);
        return; // async handler manages its own messages
      case NlpIntent.actionActivateHorizon:
        reply = "🔮 Le module Titan Horizon est désormais actif. Je surveille vos performances pour vous.";
        break;

      case NlpIntent.whatCanYouDo:
        reply = "🤖 Je suis votre assistant Titan 100% Hors-Ligne. Je me perfectionne chaque jour.\n\n🌐 Consultez notre site officiel : **danayaplus.online** pour les nouveautés et tutoriels vidéo.";
        break;
      case NlpIntent.aboutApp:
        reply = "🧠 **Danaya+ Intelligence TITAN**\n\nMon cerveau fonctionne sans internet. Je suis conçu pour devenir le maître de votre gestion d'entreprise.\n\n🔗 Site Web : [danayaplus.online](https://danayaplus.online)";
        break;
      case NlpIntent.howTo:
        reply = "📖 **Comment faire ?**\n• *Vendre* : Dites 'Je veux vendre' ou allez en caisse.\n• *Achat* : Dites 'Nouvel achat' ou allez dans Fournisseurs.\n• *Stock* : Demandez 'C'est quoi mon stock ?'.\n• *Support* : Contactez-nous à **alaska6e6ui3e@gmail.com**.";
        suggestions = ["Liste des fonctions", "Contact Support", "Raccourcis clavier"];
        break;
      case NlpIntent.featureList:
        reply = "🚀 **Fonctions principales :**\n✅ Gestion Stock (WAC, Ruptures)\n✅ Caisse Rapide (Tickets, Factures)\n✅ Finances (Trésorerie, Dépenses)\n✅ CRM (Fidélité, Dettes)\n✅ Support (WhatsApp: +223 66 82 62 07)";
        suggestions = ["Que sais-tu faire ?", "Contact Support", "Raccourcis clavier"];
        break;
      case NlpIntent.shortcutRequest:
        reply = "⌨️ **Raccourcis Clavier :**\n• **F1** : Assistant Vocal\n• **F2** : Nouvelle Vente\n• **F5** : Actualiser\n• **ESC** : Fermer/Retour\n• **ENTRÉE** : Valider la vente";
        break;

      default:
        reply = _getDynamicFallback(nlpResult);
        break;
    }

    if (reply.isNotEmpty) {
      addAssistantMessage(reply, suggestions: suggestions);
      _handleAutonomousContinuation(nlpResult.intent);
    }

    // C2. Multi-intent: execute secondary intents
    for (final secondary in nlpResult.secondaryIntents) {
      _executeSingleIntent(secondary, nlpResult);
    }
  }

  // Execute a single intent action (used for secondary intents)
  void _executeSingleIntent(NlpIntent intent, NlpResult nlpResult) {
    switch (intent) {
      case NlpIntent.themeDark:
        ref.read(themeNotifierProvider.notifier).setThemeMode(ThemeMode.dark);
        addAssistantMessage("🌙 Mode sombre activé (action secondaire).");
        break;
      case NlpIntent.themeLight:
        ref.read(themeNotifierProvider.notifier).setThemeMode(ThemeMode.light);
        addAssistantMessage("☀️ Mode clair activé (action secondaire).");
        break;
      case NlpIntent.themeToggle:
        final current = ref.read(themeNotifierProvider).mode;
        final next = current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
        ref.read(themeNotifierProvider.notifier).setThemeMode(next);
        addAssistantMessage(next == ThemeMode.dark ? "🌙 Thème basculé." : "☀️ Thème basculé.");
        break;
      case NlpIntent.navigatePOS:
        if (onAction != null) onAction!("navigate", payload: 3);
        addAssistantMessage("🛒 Navigation vers la caisse...");
        break;
      case NlpIntent.navigateInventory:
        if (onAction != null) onAction!("navigate", payload: 1);
        addAssistantMessage("📦 Navigation vers l'inventaire...");
        break;
      case NlpIntent.navigateDashboard:
        if (onAction != null) onAction!("navigate", payload: 0);
        addAssistantMessage("📊 Navigation vers le dashboard...");
        break;
      case NlpIntent.navigateFinance:
        if (onAction != null) onAction!("navigate", payload: 6);
        addAssistantMessage("💰 Navigation vers les finances...");
        break;
      case NlpIntent.navigateClients:
        if (onAction != null) onAction!("navigate", payload: 7);
        addAssistantMessage("👥 Navigation vers les clients...");
        break;
      case NlpIntent.navigateSettings:
        if (onAction != null) onAction!("navigate", payload: 9);
        addAssistantMessage("⚙️ Navigation vers les paramètres...");
        break;
      case NlpIntent.navigateAppearance:
        ref.read(settingsTabIndexProvider.notifier).setIndex(4);
        if (onAction != null) onAction!("navigate", payload: 9);
        addAssistantMessage("🎨 Navigation vers l'Apparence...");
        break;
      case NlpIntent.navigateStockMovements:
        if (onAction != null) onAction!("navigate", payload: 2);
        addAssistantMessage("📦 Navigation vers Mouvements...");
        break;
      case NlpIntent.navigateSalesHistory:
        if (onAction != null) onAction!("navigate", payload: 4);
        addAssistantMessage("📜 Navigation vers Historique...");
        break;
      case NlpIntent.navigateQuotes:
        if (onAction != null) onAction!("navigate", payload: 10);
        addAssistantMessage("📄 Navigation vers Devis...");
        break;
      case NlpIntent.navigateWarehouses:
        if (onAction != null) onAction!("navigate", payload: 11);
        addAssistantMessage("🏢 Navigation vers Magasins...");
        break;
      case NlpIntent.navigateClientDebt:
        if (onAction != null) onAction!("navigate", payload: 12);
        addAssistantMessage("💳 Navigation vers Dettes...");
        break;
      case NlpIntent.navigateExpenses:
        if (onAction != null) onAction!("navigate", payload: 13);
        addAssistantMessage("💸 Navigation vers Dépenses...");
        break;
      case NlpIntent.navigateStockAlerts:
        if (onAction != null) onAction!("navigate", payload: 14);
        addAssistantMessage("🚨 Navigation vers Alertes...");
        break;
      case NlpIntent.navigateStockAudit:
        if (onAction != null) onAction!("navigate", payload: 15);
        addAssistantMessage("📋 Navigation vers Audit...");
        break;
      case NlpIntent.navigatePurchases:
        if (onAction != null) onAction!("navigate", payload: 16);
        addAssistantMessage("🛒 Navigation vers Achats...");
        break;
      case NlpIntent.navigateUsers:
        if (onAction != null) onAction!("navigate", payload: 17);
        addAssistantMessage("👨‍💻 Navigation vers Utilisateurs...");
        break;
      case NlpIntent.navigateHelp:
        if (onAction != null) onAction!("navigate", payload: 18);
        addAssistantMessage("🆘 **Support Technique Danaya+**\n\n- 📧 Email : alaska6e6ui3e@gmail.com\n- 💬 WhatsApp : +223 66 82 62 07\n- 👻 Snap : alasko_ff\n- 🎵 TikTok : danaya+\n\nJe vous dirige vers le centre d'aide pour plus de détails.");
        break;
      case NlpIntent.navigateHR:
        if (onAction != null) onAction!("navigate", payload: 19);
        addAssistantMessage("👔 Navigation vers RH...");
        break;
      case NlpIntent.actionNewSale:
        if (onAction != null) onAction!("navigate", payload: 3);
        addAssistantMessage("🛒 Ouverture de la caisse...");
        break;
      default:
        break; // Ignore non-actionable secondary intents
    }
  }

  void _checkAutonomousRules(List<BusinessRule> activeRules) {
    final stats = ref.read(stockStatsProvider);
    final clients = ref.read(clientListProvider).value ?? [];
    
    for (final rule in activeRules) {
      if (!rule.isActive) continue;
      bool triggered = false;
      
      if (rule.trigger == RuleTriggerType.stockLow) {
        if (stats.lowStockCount > 0 || stats.outOfStockCount > 0) {
          triggered = _ruleEngine.checkCondition(rule, {'quantity': 0.0});
        }
      } else if (rule.trigger == RuleTriggerType.customerDebtExceeded) {
        final totalDebt = clients.fold(0.0, (sum, c) => sum + c.credit);
        triggered = _ruleEngine.checkCondition(rule, {'debt': totalDebt});
      }
      
      if (triggered) {
        final message = rule.actionPayload['message'] ?? "Action déclenchée : ${rule.name}";
        ref.read(proactiveAlertProvider.notifier).set(ProactiveAlertData(
          title: "Alerte Titan : ${rule.name}",
          message: message,
          actionPayload: rule.actionPayload,
        ));
        addAssistantMessage("🛡️ **Alerte** : $message");
      }
    }
  }

  void _handleSettingUpdate(NlpResult nlp) async {
    final query = nlp.searchQuery?.toLowerCase() ?? nlp.rawInput.toLowerCase();
    final settings = ref.read(shopSettingsProvider).value;
    if (settings == null) return;

    ShopSettings? updated;
    if (query.contains('nom')) {
       final words = query.split(' ');
       if (words.length >= 3) {
         final newName = words.sublist(words.indexOf('nom') + 1).join(' ');
         updated = settings.copyWith(name: newName);
         addAssistantMessage("C'est noté, votre boutique s'appelle désormais '$newName'.");
       }
    } else if (query.contains('tva') || query.contains('taxe')) {
       final entities = nlp.entities.where((e) => e.type == EntityType.number);
       if (entities.isNotEmpty) {
          final rate = entities.first.value as double;
          updated = settings.copyWith(taxRate: rate, useTax: true);
          addAssistantMessage("Taux de TVA mis à jour à $rate%. Je surveille vos factures.");
       }
    } else if (query.contains('devise') || query.contains('monnaie') || query.contains('currency')) {
       // Extract currency name from query
       final currencies = {'fcfa': 'FCFA', 'cfa': 'FCFA', 'euro': 'EUR', 'euros': 'EUR', 'dollar': 'USD', 'dollars': 'USD', 'usd': 'USD', 'eur': 'EUR', 'xof': 'FCFA', 'gnf': 'GNF', 'franc': 'GNF'};
       String? newCurrency;
       for (final entry in currencies.entries) {
         if (query.contains(entry.key)) {
           newCurrency = entry.value;
           break;
         }
       }
       if (newCurrency != null) {
         updated = settings.copyWith(currency: newCurrency);
         addAssistantMessage("💱 Devise mise à jour : **$newCurrency**. Tous les montants seront affichés dans cette devise.");
       } else {
         addAssistantMessage("💱 Quelle devise souhaitez-vous ? (FCFA, EUR, USD, GNF)");
       }
    } else if (query.contains('slogan')) {
       final words = query.split(' ');
       final idx = words.indexOf('slogan');
       if (idx >= 0 && words.length > idx + 1) {
         final newSlogan = words.sublist(idx + 1).join(' ');
         updated = settings.copyWith(slogan: newSlogan);
         addAssistantMessage("✨ Slogan mis à jour : **'$newSlogan'**. Il sera affiché sur vos tickets.");
       } else {
         addAssistantMessage("✨ Quel slogan souhaitez-vous ? Dites par exemple 'slogan Qualité et service'.");
       }
    } else if (query.contains('imprimante') || query.contains('printer')) {
       addAssistantMessage("🖨️ Pour configurer les imprimantes, allez dans **Paramètres → Impression**. Vous y trouverez les réglages pour tickets, factures, étiquettes et plus.");
       if (onAction != null) onAction!("navigate", payload: 7);
    } else {
       addAssistantMessage("⚙️ Quel paramètre voulez-vous modifier ? (Nom, TVA, Devise, Slogan, Imprimante)");
    }

    if (updated != null) {
      ref.read(shopSettingsProvider.notifier).save(updated);
    }
  }

  // ── DEPRECATED ONE-SHOT HANDLERS (REPLACED BY FLOW ENGINE) ────────

  void _executeMacro(String macroId) {
    final macro = MacroEngine.getMacro(macroId);
    if (macro == null) return;
    
    final settings = ref.read(shopSettingsProvider).value;
    final currentLevel = settings?.assistantLevel ?? AssistantPowerLevel.basic;
    
    // Check permission level
    if (currentLevel.index < macro.requiredLevel.index) {
        addAssistantMessage("🔒 Accès refusé. La macro '${macro.name}' nécessite le niveau d'intelligence : ${macro.requiredLevel.name.toUpperCase()}.");
        return;
    }

    addAssistantMessage("⚡ Exécution de la Macro : **${macro.name}**");

    for (var action in macro.actions) {
       switch (action.type) {
         case MacroActionType.speak:
           addAssistantMessage(action.payload as String);
           break;
         case MacroActionType.navigate:
           if (onAction != null) onAction!("navigate", payload: action.payload as int);
           break;
         case MacroActionType.toggleTheme:
           final mode = action.payload == 'dark' ? ThemeMode.dark : ThemeMode.light;
           ref.read(themeNotifierProvider.notifier).setThemeMode(mode);
           break;
         case MacroActionType.customLogic:
           _executeMacroCustomLogic(action.payload as String);
           break;
       }
    }
  }

  void _executeMacroCustomLogic(String logicId) {
    switch (logicId) {
       case 'bilan_jour':
         _processUserMessage("Bilan du jour");
         break;
       case 'quick_pos':
         addAssistantMessage("⚡ **Mode Rush activé** : L'interface est optimisée pour une saisie ultra-rapide.");
         if (onAction != null) onAction!("navigate", payload: 3);
         break;
       case 'audit_complet':
         final stats = ref.read(stockStatsProvider);
         final settings = ref.read(shopSettingsProvider).value;
         final currency = settings?.currency ?? 'FCFA';
         addAssistantMessage("📦 **Audit Stock TITAN** : Valeur totale de **${DateFormatter.formatCurrency(stats.totalStockValue, currency, removeDecimals: settings?.removeDecimals ?? true)}**. ${stats.outOfStockCount} articles en rupture sèche. ${stats.lowStockCount} alertes critiques.");
         break;
       case 'backup':
         addAssistantMessage("💾 **Sauvegarde Titan** : Une sauvegarde locale chiffrée de votre base de données a été générée avec succès.");
         break;
       case 'top_produits':
         _processUserMessage("Top produits");
         break;
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // TITAN CART ORCHESTRATION 
  // ════════════════════════════════════════════════════════════════════
  List<Map<String, dynamic>> _extractCartItemsFromText(String text) {
     final result = <Map<String, dynamic>>[];
     var t = text.toLowerCase().replaceAll(RegExp(r'\b(vends?|vendre|ajoute au panier|facture[rz]?|encaisser|moi)\b'), '');
     
     final chunks = t.split(RegExp(r'(?:,| et | puis | avec )'));
     
     for (var chunk in chunks) {
        chunk = chunk.trim();
        if (chunk.isEmpty) continue;
        
        final digitMatch = RegExp(r'^(\d+)\s+(.+)$').firstMatch(chunk);
        if (digitMatch != null) {
           final qty = double.tryParse(digitMatch.group(1)!) ?? 1.0;
           final pName = digitMatch.group(2)!.trim();
           final cleanName = pName.replaceAll(RegExp(r"^(de |d'|un |une |des |le |la |les )"), '');
           result.add({'qty': qty, 'name': cleanName});
        }
     }
     return result;
  }

  void _handleVoiceCartOrchestration(List<Map<String, dynamic>> requestedItems) {
    int addedCount = 0;
    final products = ref.read(productListProvider).value ?? [];
    
    for (final req in requestedItems) {
      final name = req['name'] as String;
      final qty = (req['qty'] as num).toDouble();
      
      Product? bestMatch;
      double bestSim = 0.0;
      
      for (final p in products) {
        if (p.isService) continue;
        final sim = NlpEngine.similarity(name, p.name.toLowerCase());
        if (sim > bestSim && sim >= 0.65) {
          bestSim = sim;
          bestMatch = p;
        }
      }
      
      if (bestMatch != null && bestMatch.quantity >= qty) {
        ref.read(cartProvider.notifier).addProduct(bestMatch);
        if (qty > 1) {
          ref.read(cartProvider.notifier).updateQty(bestMatch.id, qty);
        }
        addedCount++;
      }
    }
    
    if (addedCount > 0) {
      addAssistantMessage("🛒 **Orchestration TITAN** : $addedCount article(s) trouvé(s) et ajouté(s) au panier ! Redirection vers la caisse...");
      if (onAction != null) onAction!("navigate", payload: 3);
      _handleAutonomousContinuation(NlpIntent.actionNewSale);
    } else {
      addAssistantMessage("😔 **Erreur** : Je n'ai pas pu trouver les articles en stock ou en quantité suffisante pour cette requête.");
    }
  }

  // ── MULTI-TURN FLOW ENGINE ────────────────────────────────────────

  void _startFlow(AssistantFlow flow) {
    state = state.copyWith(
      currentFlow: flow,
      flowStep: FlowStep.initial,
      flowData: {},
    );

    switch (flow) {
      case AssistantFlow.purchaseOrder:
        addAssistantMessage("D'accord, créons un bon de commande. Pour quel fournisseur ?");
        state = state.copyWith(flowStep: FlowStep.supplier);
        break;
      case AssistantFlow.expense:
        addAssistantMessage("Nouvelle dépense. Quel est le montant ?");
        state = state.copyWith(flowStep: FlowStep.amount);
        break;
      case AssistantFlow.client:
        addAssistantMessage("Créons un nouveau client. Quel est son nom ?");
        state = state.copyWith(flowStep: FlowStep.name);
        break;
      case AssistantFlow.product:
        addAssistantMessage("Nouveau produit. Quel est le nom de l'article ?");
        state = state.copyWith(flowStep: FlowStep.name);
        break;
      case AssistantFlow.none:
        break;
    }
  }

  void _handleFlowInput(String text) {
    if (text.toLowerCase() == "annuler" || text.toLowerCase() == "stop") {
      _resetFlow();
      addAssistantMessage("Flux annulé.");
      return;
    }

    switch (state.currentFlow) {
      case AssistantFlow.purchaseOrder:
        _handlePurchaseOrderFlow(text);
        break;
      case AssistantFlow.expense:
        _handleExpenseFlow(text);
        break;
      case AssistantFlow.client:
        _handleClientFlow(text);
        break;
      case AssistantFlow.product:
        _handleProductFlow(text);
        break;
      default:
        addAssistantMessage("Désolé, ce flux n'est pas encore totalement implémenté.");
        _resetFlow();
    }
  }

  void _resetFlow() {
    state = state.copyWith(
      currentFlow: AssistantFlow.none,
      flowStep: FlowStep.initial,
      flowData: {},
    );
  }

  void _handlePurchaseOrderFlow(String text) async {
    switch (state.flowStep) {
      case FlowStep.supplier:
        final supplier = await _findSupplier(text);
        if (supplier != null) {
          state = state.copyWith(
            flowData: {...state.flowData, 'supplier': supplier},
            flowStep: FlowStep.items,
          );
          addAssistantMessage("Fournisseur ${supplier.name} sélectionné. Quels produits voulez-vous ajouter ? (ex: 10 sacs de riz)");
        } else {
          addAssistantMessage("Je n'ai pas trouvé de fournisseur nommé '$text'. Pouvez-vous préciser ou dire 'annuler' ?");
        }
        break;

      case FlowStep.items:
        final items = _extractCartItemsFromText(text);
        if (items.isNotEmpty) {
          final currentItems = List<Map<String, dynamic>>.from(state.flowData['items'] ?? []);
          currentItems.addAll(items);
          state = state.copyWith(
            flowData: {...state.flowData, 'items': currentItems},
            flowStep: FlowStep.review,
          );
          
          String summary = "📦 Commandé :\n${currentItems.map((e) => "- ${e['name']} x${e['qty']}").join("\n")}";
          addAssistantMessage("$summary\n\nSouhaitez-vous ajouter d'autres articles ou devons-nous confirmer ?");
        } else if (text.toLowerCase().contains("confirmer") || text.toLowerCase().contains("ok") || text.toLowerCase().contains("valide") || text.toLowerCase().contains("fini")) {
           if ((state.flowData['items'] as List?)?.isEmpty ?? true) {
             addAssistantMessage("La liste est vide. Quels produits ajouter ?");
           } else {
             _finalizePurchaseOrder();
           }
        } else {
          addAssistantMessage("Je n'ai pas compris les produits. Essayez par exemple '10 coca, 5 fanta'.");
        }
        break;

      case FlowStep.review:
        if (text.toLowerCase().contains("confirmer") || text.toLowerCase().contains("valide") || text.toLowerCase().contains("oui") || text.toLowerCase().contains("ok")) {
          _finalizePurchaseOrder();
        } else if (text.toLowerCase().contains("annuler")) {
          _resetFlow();
          addAssistantMessage("Bon de commande annulé.");
        } else {
          // Add more items
          state = state.copyWith(flowStep: FlowStep.items);
          _handlePurchaseOrderFlow(text);
        }
        break;
      default: break;
    }
  }

  Future<Supplier?> _findSupplier(String name) async {
    final suppliers = ref.read(supplierListProvider).value ?? [];
    if (suppliers.isEmpty) return null;
    
    Supplier? bestMatch;
    double bestScore = 0;
    
    for (var s in suppliers) {
      final score = NlpEngine.similarity(name.toLowerCase(), s.name.toLowerCase());
      if (score > bestScore && score > 0.6) {
        bestScore = score;
        bestMatch = s;
      }
    }
    return bestMatch;
  }

  void _finalizePurchaseOrder() async {
    final data = state.flowData;
    final supplier = data['supplier'] as Supplier;
    final items = data['items'] as List<Map<String, dynamic>>;
    
    

    try {
      final order = await ref.read(srmServiceProvider).processPurchase(
        items: items.map((i) => PurchaseOrderItem(
          productId: i['product_id'] as String,
          quantity: (i['qty'] as num).toDouble(),
          unitPrice: (i['unit_price'] as num? ?? 0).toDouble(),
        )).toList(),
        supplierId: supplier.id,
        amountPaid: 0,
        isCredit: true,
      );

      if (order.id.isNotEmpty) {
        addAssistantMessage("Excellent ! Le bon de commande pour ${supplier.name} a été enregistré. ✅");
      } else {
        addAssistantMessage("Désolé, une erreur technique a empêché l'enregistrement.");
      }
    } catch (e) {
      addAssistantMessage("Erreur d'enregistrement : $e");
    }
    _resetFlow();
  }

  void _handleExpenseFlow(String text) {
    final amountMatch = RegExp(r'(\d+)').firstMatch(text);
    if (state.flowStep == FlowStep.amount && amountMatch != null) {
       final settings = ref.read(shopSettingsProvider).value;
       final currency = settings?.currency ?? 'FCFA';
       final amount = double.parse(amountMatch.group(1)!);
       state = state.copyWith(
         flowData: {...state.flowData, 'amount': amount},
         flowStep: FlowStep.category,
       );
       addAssistantMessage("Noté : **${DateFormatter.formatCurrency(amount, currency, removeDecimals: true)}**. Quelle est la catégorie ou le motif ? (ex: Loyer, Transport, Divers)");
    } else if (state.flowStep == FlowStep.category) {
       final amount = state.flowData['amount'] as double;
       final categoryStr = text.trim();
       
       // Map string to TransactionCategory
       TransactionCategory cat = TransactionCategory.EXPENSE;
       if (categoryStr.toLowerCase().contains('loyer')) cat = TransactionCategory.EXPENSE;
       // ... simplified mapping
       
       _finalizeExpense(amount, categoryStr, cat);
    } else {
       addAssistantMessage("Je n'ai pas compris le montant. Dites par exemple '5000'.");
    }
  }

  void _handleClientFlow(String text) {
    if (state.flowStep == FlowStep.name) {
       state = state.copyWith(
         flowData: {...state.flowData, 'name': text},
         flowStep: FlowStep.phone,
       );
       addAssistantMessage("Client **'$text'** noté. Quel est son numéro de téléphone ? (ou dites 'non' pour passer)");
    } else if (state.flowStep == FlowStep.phone) {
       final phone = (text.toLowerCase() == 'non' || text.toLowerCase() == 'pas') ? '' : text;
       _finalizeClient(state.flowData['name'] as String, phone);
    }
  }

  void _handleProductFlow(String text) async {
    final settings = ref.read(shopSettingsProvider).value;
    final automation = ref.read(inventoryAutomationServiceProvider);
    final currency = settings?.currency ?? 'FCFA';

    switch (state.flowStep) {
      case FlowStep.name:
        state = state.copyWith(
          flowData: {...state.flowData, 'name': text},
          flowStep: FlowStep.purchasePrice,
        );
        addAssistantMessage("Article **'$text'** noté. Quel est son **Prix d'Achat** (PA) ? (Dites '0' si inconnu)");
        break;

      case FlowStep.purchasePrice:
        final amountMatch = RegExp(r'(\d+)').firstMatch(text);
        final price = amountMatch != null ? double.parse(amountMatch.group(1)!) : 0.0;
        state = state.copyWith(
          flowData: {...state.flowData, 'purchasePrice': price},
          flowStep: FlowStep.price,
        );
        addAssistantMessage("Prix d'achat de **$price $currency** enregistré. Quel est le **Prix de Vente** (PV) ?");
        break;

      case FlowStep.price:
        final amountMatch = RegExp(r'(\d+)').firstMatch(text);
        if (amountMatch != null) {
          final price = double.parse(amountMatch.group(1)!);
          state = state.copyWith(
            flowData: {...state.flowData, 'price': price},
            flowStep: FlowStep.quantity,
          );
          addAssistantMessage("Prix de vente de **$price $currency** enregistré. Quelle est la **Quantité initiale** en stock ?");
        } else {
          addAssistantMessage("Je n'ai pas compris le prix. Dites par exemple '500'.");
        }
        break;

      case FlowStep.quantity:
        final amountMatch = RegExp(r'(\d+)').firstMatch(text);
        if (amountMatch != null) {
          final qty = double.parse(amountMatch.group(1)!);
          state = state.copyWith(
            flowData: {...state.flowData, 'qty': qty},
            flowStep: FlowStep.category,
          );
          addAssistantMessage("Stock de **$qty** noté. Dans quelle **Catégorie** classer cet article ? (Ex: Boissons, Divers)");
        } else {
          addAssistantMessage("Je n'ai pas compris la quantité. Dites par exemple '10'.");
        }
        break;

      case FlowStep.category:
        state = state.copyWith(
          flowData: {...state.flowData, 'category': text},
          flowStep: FlowStep.barcode,
        );
        
        String msg = "Catégorie **'$text'** enregistrée.";
        if (settings?.useAutoRef ?? false) {
           final autoRef = await automation.generateAutoRef(text, settings?.refPrefix ?? "REF");
           state = state.copyWith(flowData: {...state.flowData, 'reference': autoRef});
           msg += "\n✨ Référence automatique générée : **$autoRef**.";
        }
        
        msg += "\n\nPour le **Code-barres** : Voulez-vous le scanner, le saisir, ou que je le **génère** automatiquement ? (Dites 'Générer' ou 'Non')";
        addAssistantMessage(msg, suggestions: ["Générer", "Non"]);
        break;

      case FlowStep.barcode:
        String? barcode;
        if (text.toLowerCase().contains("générer") || text.toLowerCase().contains("auto")) {
           barcode = await automation.generateNumericBarcode();
           addAssistantMessage("📟 Code-barres généré : **$barcode**.");
        } else if (text.toLowerCase() != "non" && text.toLowerCase() != "pas") {
           barcode = text;
        }

        state = state.copyWith(
          flowData: {...state.flowData, 'barcode': barcode},
          flowStep: FlowStep.unit,
        );
        addAssistantMessage("Quelle est l'**Unité** de mesure ? (Ex: Pièce, kg, Sac, Carton)", suggestions: ["Pièce", "Sac", "kg"]);
        break;

      case FlowStep.unit:
        state = state.copyWith(
          flowData: {...state.flowData, 'unit': text},
          flowStep: FlowStep.review,
        );
        
        final data = state.flowData;
        final pa = data['purchasePrice'] as double;
        final pv = data['price'] as double;
        final margin = pv - pa;
        
        addAssistantMessage(
          "📋 **Récapitulatif Titan Pro** :\n"
          "• Article : **${data['name']}**\n"
          "• PA : **$pa $currency** | PV : **$pv $currency**\n"
          "• Marge estimée : **$margin $currency**\n"
          "• Stock : **${data['qty']} ${data['unit']}**\n"
          "• Catégorie : **${data['category']}**\n"
          "• Réf : **${data['reference'] ?? 'Standard'}**\n"
          "• Barcode : **${data['barcode'] ?? 'Aucun'}**\n\n"
          "Est-ce correct pour l'enregistrement ?",
          suggestions: ["Confirmer", "Annuler"]
        );
        break;

      case FlowStep.review:
        if (text.toLowerCase().contains("confirmer") || text.toLowerCase().contains("oui") || text.toLowerCase().contains("ok") || text.toLowerCase().contains("valide")) {
          _finalizeProduct();
        } else {
          addAssistantMessage("Création de produit annulée.");
          _resetFlow();
        }
        break;
      default:
        _resetFlow();
    }
  }

  void addAssistantMessage(String text, {List<String> suggestions = const []}) {
    state = state.copyWith(
      messages: [...state.messages, AssistantMessage(text: text)],
      isTyping: false,
      suggestedActions: suggestions.isNotEmpty ? suggestions : state.suggestedActions,
    );
  }

  void _handleAutonomousContinuation(NlpIntent lastIntent) {
    Future.delayed(const Duration(seconds: 2), () {
      String? proactiveMsg;
      List<String> proactiveSugs = [];

      switch (lastIntent) {
        case NlpIntent.actionNewSale:
          proactiveMsg = "Vente enregistrée ! Voulez-vous imprimer le ticket de caisse ? 🖨️";
          proactiveSugs = ["Imprimer ticket", "Non merci"];
          break;
        case NlpIntent.navigateInventory:
          proactiveMsg = "Souhaitez-vous que je vérifie les produits en rupture de stock ? 📦";
          proactiveSugs = ["Vérifier ruptures", "Plus tard"];
          break;
        case NlpIntent.actionNewClient:
          proactiveMsg = "Client enregistré. Voulez-vous lui affecter un programme de fidélité ?";
          proactiveSugs = ["Client VIP", "Standard"];
          break;
        case NlpIntent.navigatePOS:
          proactiveMsg = "Besoin d'aide pour trouver un article ou appliquer une remise ?";
          proactiveSugs = ["Appliquer remise", "Vente rapide"];
          break;
        case NlpIntent.navigateDashboard:
          proactiveMsg = "Voulez-vous voir le top des produits vendus aujourd'hui ? 🏆";
          proactiveSugs = ["Top produits", "Pas maintenant"];
          break;
        default:
          break;
      }

      if (proactiveMsg != null) {
        addAssistantMessage("💡 **[TITAN Suggestion]** $proactiveMsg", suggestions: proactiveSugs);
      }
    });
  }

  String _getDynamicFallback(NlpResult nlp) {
    // List of "I don't understand" variations
    final variations = [
      "🤔 Je n'ai pas bien saisi votre demande. Pouvez-vous reformuler ?",
      "🧐 Désolé, cette commande est encore un peu complexe pour mon moteur Titan. Essayez autre chose ?",
      "🤖 Oups, je n'ai pas trouvé d'action correspondante. Comment puis-je vous aider ?",
      "❓ Je ne suis pas sûr de comprendre. Voici ce que je peux faire pour vous :",
    ];
    
    final intro = variations[DateTime.now().millisecond % variations.length];
    
    // Context-aware suggestions
    String suggestion1 = "Bilan du jour";
    String suggestion2 = "Que sais-tu faire ?";
    
    switch (state.currentContext) {
      case AssistantContext.pos:
        suggestion1 = "Appliquer une remise";
        suggestion2 = "Voir l'historique";
        break;
      case AssistantContext.inventory:
        suggestion1 = "Produits en rupture";
        suggestion2 = "Ajouter un produit";
        break;
      case AssistantContext.finance:
        suggestion1 = "Saisir une dépense";
        suggestion2 = "Solde des comptes";
        break;
      case AssistantContext.suppliers:
        suggestion1 = "Nouveau bon de commande";
        suggestion2 = "Liste fournisseurs";
        break;
      case AssistantContext.clients:
        suggestion1 = "Dettes clients";
        suggestion2 = "Nouveau client";
        break;
      default:
        break;
    }
    
    return "$intro\n\nEssayez par exemple : **'$suggestion1'** ou **'$suggestion2'**.";
  }

  // --- Helpers ---


  void _finalizeExpense(double amount, String description, TransactionCategory category) async {
    try {
      final treasury = ref.read(treasuryProvider.notifier);
      final defaultAccount = await treasury.getDefaultAccount(AccountType.CASH);
      
      if (defaultAccount != null) {
        final tx = FinancialTransaction(
          accountId: defaultAccount.id,
          type: TransactionType.OUT,
          amount: amount,
          category: category,
          description: description,
          date: DateTime.now(),
        );
        final settings = ref.read(shopSettingsProvider).value;
        final currency = settings?.currency ?? 'FCFA';
        await treasury.addTransaction(tx);
        addAssistantMessage("✅ Dépense de **${DateFormatter.formatCurrency(amount, currency, removeDecimals: settings?.removeDecimals ?? true)}** enregistrée dans '${defaultAccount.name}'.");
      } else {
        addAssistantMessage("⚠️ Impossible de trouver un compte de trésorerie par défaut pour enregistrer la dépense.");
      }
    } catch (e) {
      addAssistantMessage("❌ Erreur lors de l'enregistrement : $e");
    }
    _resetFlow();
  }

  void _finalizeClient(String name, String phone) async {
    try {
      final client = Client(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        phone: phone,
        address: '',
        email: '',
        credit: 0.0,
        maxCredit: 50000.0,
        loyaltyPoints: 0,
      );
      await ref.read(clientListProvider.notifier).addClient(client);
      addAssistantMessage("✅ Client **$name** créé avec succès !");
    } catch (e) {
      addAssistantMessage("❌ Erreur lors de la création du client : $e");
    }
    _resetFlow();
  }

  void _finalizeProduct() async {
    try {
      final data = state.flowData;
      final name = data['name'] as String;
      
      final product = Product(
        id: "prod_${DateTime.now().millisecondsSinceEpoch}",
        name: name,
        sellingPrice: (data['price'] as num).toDouble(),
        purchasePrice: (data['purchasePrice'] as num).toDouble(),
        quantity: (data['qty'] as num).toDouble(),
        category: data['category'] as String?,
        barcode: data['barcode'] as String?,
        reference: data['reference'] as String?,
        unit: data['unit'] as String?,
        alertThreshold: 5.0,
      );

      await ref.read(productListProvider.notifier).addProduct(product);
      addAssistantMessage("🎉 **Excellent !** L'article **$name** a été enregistré et ajouté à votre inventaire. ✅");
    } catch (e) {
      addAssistantMessage("❌ Erreur technique lors de la création : $e");
    }
    _resetFlow();
  }
}
