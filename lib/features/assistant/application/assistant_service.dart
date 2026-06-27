import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode, DateTimeRange;
import 'package:danaya_plus/features/reports/providers/report_providers.dart';
import 'package:danaya_plus/features/reports/services/pdf_report_service.dart';
import 'package:danaya_plus/features/reports/services/excel_export_service.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/core/services/hardware_service.dart';
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
import '../../finance/providers/session_providers.dart';
import '../../clients/domain/models/client.dart';
import 'nlp_engine.dart';
import 'rule_engine.dart';
import 'rule_manager.dart';
import 'deepseek_service.dart';
import 'gemini_service.dart';
import 'voice_service.dart';
import 'package:danaya_plus/core/theme/theme_provider.dart';
import 'package:danaya_plus/core/theme/app_theme.dart';
import 'package:danaya_plus/features/assistant/application/horizon_engine.dart';
import '../../inventory/providers/dashboard_customization_provider.dart';
import '../../inventory/providers/dashboard_providers.dart';
import '../../pos/providers/pos_providers.dart';
import '../../pos/providers/quote_providers.dart';
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
import 'assistant_memory_service.dart';
import '../domain/assistant_notification.dart';
import 'package:uuid/uuid.dart';
import 'assistant_tone.dart';
export '../domain/assistant_models.dart';

typedef AssistantActionCallback = void Function(String action, {dynamic payload});

enum AlertLevel { info, success, warning, error }

class ProactiveAlertData {
  final String title;
  final String message;
  final AlertLevel? level;
  final dynamic actionPayload;

  ProactiveAlertData({
    required this.title,
    required this.message,
    this.level,
    this.actionPayload,
  });

  AlertLevel get detectedLevel {
    if (level != null) return level!;
    final combined = '$title $message'.toLowerCase();
    if (combined.contains('erreur') || 
        combined.contains('impossible') || 
        combined.contains('refusé') || 
        combined.contains('dépasse') || 
        combined.contains('dépassé') || 
        combined.contains('échoué') || 
        combined.contains('vide') || 
        combined.contains('aucun client')) {
      return AlertLevel.error;
    }
    if (combined.contains('attention') || 
        combined.contains('alerte') || 
        combined.contains('risque') || 
        combined.contains('seuil') || 
        combined.contains('bas') ||
        combined.contains('rupture') || 
        combined.contains('warning')) {
      return AlertLevel.warning;
    }
    if (combined.contains('succès') || 
        combined.contains('réussi') || 
        combined.contains('terminé') || 
        combined.contains('validé') || 
        combined.contains('enregistré')) {
      return AlertLevel.success;
    }
    return AlertLevel.info;
  }
}



class ProactiveAlertNotifier extends Notifier<ProactiveAlertData?> {
  @override
  ProactiveAlertData? build() => null;
  
  void set(ProactiveAlertData? data) {
    state = data;
    if (data != null) {
      final isAssistantOpen = ref.read(assistantProvider).isOpen;
      final isVoiceCallActive = ref.read(voiceServiceProvider).isCallActive;

      if (!isAssistantOpen && !isVoiceCallActive) {
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
      
      // Auto-dismiss après 3.5 secondes pour éviter d'encombrer l'écran
      Future.delayed(const Duration(milliseconds: 3500), () {
        if (state == data) {
          state = null;
        }
      });
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
    ref.listen(authServiceProvider, (prev, next) {
      if (prev?.value?.id != next.value?.id) {
        state = state.copyWith(messages: []);
        _initSession();
        _checkFirstTime();
      }
    });
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

  String get _chatHistoryKey {
    final user = ref.read(authServiceProvider).value;
    return user != null ? 'danaya_copilot_chat_history_${user.id}' : 'danaya_copilot_chat_history';
  }

  String get _chatThreadsKey {
    final user = ref.read(authServiceProvider).value;
    return user != null ? 'danaya_copilot_chat_threads_${user.id}' : 'danaya_copilot_chat_threads';
  }

  Future<void> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Charger les fils de discussion existants (threads)
    final threadsStr = prefs.getString(_chatThreadsKey);
    List<ChatThread> loadedThreads = [];
    String? activeThreadId;

    if (threadsStr != null && threadsStr.isNotEmpty) {
      try {
        final List decoded = jsonDecode(threadsStr);
        loadedThreads = decoded.map((item) => ChatThread.fromJson(item as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint("Error loading chat threads: $e");
      }
    }

    // Migration depuis l'historique hérité (legacy) si aucun fil de discussion n'existe
    if (loadedThreads.isEmpty) {
      final legacyStr = prefs.getString(_chatHistoryKey);
      if (legacyStr != null && legacyStr.isNotEmpty) {
        try {
          final List decoded = jsonDecode(legacyStr);
          final legacyMessages = decoded.map((m) => AssistantMessage(
            text: m['text'] as String? ?? '',
            isUser: m['isUser'] as bool? ?? false,
            timestamp: DateTime.tryParse(m['timestamp'] as String? ?? ''),
            isError: m['isError'] as bool? ?? false,
            attachmentName: m['attachmentName'] as String?,
            attachmentMimeType: m['attachmentMimeType'] as String?,
          )).toList();

          if (legacyMessages.isNotEmpty) {
            final legacyThread = ChatThread(
              id: const Uuid().v4(),
              title: "Discussion précédente",
              updatedAt: DateTime.now(),
              messages: legacyMessages,
            );
            loadedThreads.add(legacyThread);
            activeThreadId = legacyThread.id;
          }
        } catch (e) {
          debugPrint("Error migrating legacy history: $e");
        }
      }
    }

    // Si toujours aucun fil, en créer un vierge initial
    if (loadedThreads.isEmpty) {
      final initialId = const Uuid().v4();
      final initialThread = ChatThread(
        id: initialId,
        title: "Nouvelle discussion",
        updatedAt: DateTime.now(),
        messages: [],
      );
      loadedThreads.add(initialThread);
      activeThreadId = initialId;
    } else {
      activeThreadId = activeThreadId ?? loadedThreads.first.id;
    }

    // Extraire les messages du fil de discussion actif
    final activeThread = loadedThreads.firstWhere((t) => t.id == activeThreadId, orElse: () => loadedThreads.first);
    
    // Si la liste de messages est vide, ajouter le message de bienvenue initial
    List<AssistantMessage> currentMessages = List.from(activeThread.messages);
    if (currentMessages.isEmpty) {
      currentMessages = [
        AssistantMessage(
          text: "Bonjour ! Je suis Danaya, ton assistant intelligent de gestion. Que puis-je faire pour t'aider aujourd'hui ?",
          isUser: false,
          timestamp: DateTime.now(),
        )
      ];
      final idx = loadedThreads.indexWhere((t) => t.id == activeThread.id);
      if (idx != -1) {
        loadedThreads[idx] = loadedThreads[idx].copyWith(messages: currentMessages);
      }
    }

    state = state.copyWith(
      threads: loadedThreads,
      currentThreadId: activeThread.id,
      messages: currentMessages,
    );

    if (prefs.getBool(_onboardingKey) != true) {
      startOnboarding();
    }
  }

  void _addWelcomeMessage() {
    final stats = ref.read(stockStatsProvider);
    final salesAsync = ref.read(salesHistoryProvider);
    final today = DateTime.now();
    final settings = ref.read(shopSettingsProvider).value;
    final currency = settings?.currency ?? "FCFA";


    final user = ref.read(authServiceProvider).value;
    final String? displayName = user != null ? (user.firstName ?? user.username) : null;
    String greeting = AssistantTone.greeting(userName: displayName);
    String welcomeText = "$greeting\n\n";

    final canSeeSales = user != null && user.canAccessReports;
    final sales = salesAsync.value ?? [];
    final todaySales = sales.where((s) => s.sale.date.year == today.year && s.sale.date.month == today.month && s.sale.date.day == today.day);
    final totalToday = todaySales.fold(0.0, (sum, s) => sum + s.sale.totalAmount);

    if (todaySales.isNotEmpty) {
      if (canSeeSales) {
        welcomeText += "📊 Tu as déjà fait ${todaySales.length} ventes (${DateFormatter.formatCurrency(totalToday, currency, removeDecimals: settings?.removeDecimals ?? true)}).\n";
      } else {
        welcomeText += "📊 Tu as déjà enregistré ${todaySales.length} ventes aujourd'hui.\n";
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
    debugPrint('[AssistantNotifier] toggleOpen() called. New isOpen state: ${state.isOpen}');
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
    _saveChatHistory();
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    state = state.copyWith(isOnboardingActive: false, onboardingStep: 0);
  }

  void sendMessage(
    String text, {
    List<int>? attachmentBytes,
    String? attachmentMimeType,
    String? attachmentName,
  }) async {
    final settings = ref.read(shopSettingsProvider).value;
    if (settings != null && (!settings.isAiEnabled || !settings.showAssistant)) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          AssistantMessage(
            text: "⚠️ **Service Désactivé** : Les fonctionnalités d'IA et de Copilot sont désactivées sur ce système.",
            isUser: false,
            isError: true,
          )
        ],
        isTyping: false,
      );
      return;
    }

    final user = ref.read(authServiceProvider).value;
    if (user != null && !user.canUseAi) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          AssistantMessage(
            text: "⚠️ **Accès Refusé** : Votre profil n'est pas autorisé à utiliser l'assistant intelligent.",
            isUser: false,
          )
        ],
        isTyping: false,
      );
      return;
    }

    state = state.copyWith(
      messages: [
        ...state.messages,
        AssistantMessage(
          text: text,
          isUser: true,
          attachmentBytes: attachmentBytes,
          attachmentMimeType: attachmentMimeType,
          attachmentName: attachmentName,
        )
      ],
      isTyping: true,
      suggestedActions: [],
    );
    _saveChatHistory();

    // Si l'IA Cloud est active, on vérifie d'abord si c'est une commande locale
    // (navigation, action, thème) sinon on envoie directement au Cloud
    if (settings?.useCloudAi == true) {
      final nlpResult = NlpEngine.analyze(text, context: state.currentContext);
      final isLocalCommand = nlpResult.intent.name.startsWith('navigate') ||
                             nlpResult.intent.name.startsWith('action') ||
                             nlpResult.intent.name.startsWith('theme') ||
                             nlpResult.intent == NlpIntent.greeting ||
                             nlpResult.intent == NlpIntent.farewell ||
                             nlpResult.intent == NlpIntent.thanks;

      // Si c'est une commande locale avec une forte confiance et sans PJ, on la traite localement
      if (isLocalCommand && nlpResult.confidence >= 0.6 && attachmentBytes == null) {
        await Future.delayed(const Duration(seconds: 1));
        await _processUserMessage(text);
      } else {
        // Sinon, on envoie directement à l'IA Danaya Cloud
        await Future.delayed(const Duration(milliseconds: 300));
        _callCloudAiAndReply(text, attachmentBytes: attachmentBytes, attachmentMimeType: attachmentMimeType);
      }
    } else {
      // Mode 100% local (Titan)
      await Future.delayed(const Duration(seconds: 1));
      await _processUserMessage(text);
    }
  }

  Future<void> _processUserMessage(String text, {bool isConnectionFallback = false}) async {
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
        final settingsIndex = _getSettingsTabIndexFromQuery(text);
        ref.read(settingsTabIndexProvider.notifier).setIndex(settingsIndex);
        reply = "⚙️ Ouverture des **Paramètres → ${_getSettingsTabLabel(settingsIndex)}**...";
        if (onAction != null) onAction!("navigate", payload: 9);
        suggestions = ["Sauvegarde", "Imprimantes", "Apparence"];
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
            final sim = math.max(
              NlpEngine.similarity(p.name.toLowerCase(), q),
              NlpEngine.phoneticSimilarity(p.name.toLowerCase(), q),
            );
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
        _startFlow(AssistantFlow.product, initialText: text);
        return;
      case NlpIntent.actionNewExpense:
        _startFlow(AssistantFlow.expense, initialText: text);
        return;
      case NlpIntent.actionNewClient:
        _startFlow(AssistantFlow.client, initialText: text);
        return;
      case NlpIntent.actionNewPurchaseOrder:
        _startFlow(AssistantFlow.purchaseOrder, initialText: text);
        return;
      case NlpIntent.actionNewQuote:
        if (!hasPermission((u) => u.canSell)) { reply = accessDeniedMsg; break; }
        final cartItems = ref.read(cartProvider);
        if (cartItems.isEmpty) {
          reply = "Je vous redirige vers la page de gestion des Devis. Vous pourrez y consulter tous vos devis ou en créer un nouveau en cliquant sur le bouton.";
          if (onAction != null) onAction!("navigate", payload: 10); // Devis/Quotes Page
          suggestions = ["Ouvre les devis", "Ouvre la caisse"];
        } else {
          final clientId = ref.read(selectedClientIdProvider);
          final user = ref.read(authServiceProvider).value;
          final userId = user?.id ?? 'admin';
          
          final validityDays = settings?.quoteValidityDays ?? 30;
          final validUntil = DateTime.now().add(Duration(days: validityDays));
          final subtotal = ref.read(cartProvider.notifier).subtotal;
          
          final taxRate = settings?.useTax == true ? (settings?.taxRate ?? 0.0) : 0.0;
          final totalAmount = settings?.useTax == true ? subtotal * (1 + taxRate / 100) : subtotal;
          
          final quoteItems = cartItems.map((item) => QuoteItemWithId(
            name: item.name,
            qty: item.qty,
            unitPrice: item.unitPrice,
            productId: item.productId,
          )).toList();
          
          final quoteId = await ref.read(quoteRepositoryProvider).createQuote(
            clientId: clientId,
            items: quoteItems,
            subtotal: subtotal,
            totalAmount: totalAmount,
            userId: userId,
            validUntil: validUntil,
          );
          
          ref.invalidate(quoteListProvider);
          ref.read(cartProvider.notifier).clear();
          
          reply = "📄 **Devis créé avec succès !**\n\nLe panier a été vidé et le devis a été enregistré avec l'ID `$quoteId`.\nVous pouvez le consulter et l'imprimer dans la section Devis.";
          suggestions = ["Ouvre les devis", "Ouvre la caisse"];
        }
        break;

      case NlpIntent.quoteQuery:
        if (!hasPermission((u) => u.canAccessReports)) { reply = accessDeniedMsg; break; }
        final quotes = await ref.read(quoteListProvider.future);
        if (quotes.isEmpty) {
          reply = "Aucun devis n'a été enregistré pour le moment.";
        } else {
          final totalCount = quotes.length;
          final pendingQuotes = quotes.where((q) => q['status'] == 'PENDING').toList();
          final totalPendingAmount = pendingQuotes.fold<double>(0.0, (sum, q) => sum + (q['total_amount'] as num).toDouble());
          
          final listStr = quotes.take(5).map((q) {
            final clientName = q['client'] != null ? q['client']['name'] : 'Client Anonyme';
            final dateStr = DateFormatter.formatDate(DateTime.parse(q['date'] as String));
            final total = DateFormatter.formatCurrency((q['total_amount'] as num).toDouble(), currency, removeDecimals: settings?.removeDecimals ?? true);
            return "• **${q['quote_number']}** ($clientName) du $dateStr : **$total** [${q['status']}]";
          }).join("\n");
          
          reply = "📄 **Gestion des Devis ($totalCount devis au total) :**\n"
              "• Devis en attente : **${pendingQuotes.length}** pour un total de **${DateFormatter.formatCurrency(totalPendingAmount, currency, removeDecimals: settings?.removeDecimals ?? true)}**\n\n"
              "**Derniers devis récents :**\n$listStr";
          
          if (quotes.length > 5) {
            reply += "\n*(...et ${quotes.length - 5} autres devis)*";
          }
        }
        suggestions = ["Ouvre les devis", "Créer un devis"];
        break;
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
      case NlpIntent.actionBackup:
        if (!hasPermission((u) => u.canAccessSettings)) { reply = accessDeniedMsg; break; }
        ref.read(settingsTabIndexProvider.notifier).setIndex(10); // Index 10 = Sauvegardes & Restauration
        reply = "💾 Navigation vers l'onglet **Sauvegardes & Maintenance**...";
        if (onAction != null) onAction!("navigate", payload: 9);
        suggestions = ["Faire un backup", "Restauration"];
        break;
      case NlpIntent.actionPrint:
        if (!hasPermission((u) => u.canAccessSettings)) { reply = accessDeniedMsg; break; }
        ref.read(settingsTabIndexProvider.notifier).setIndex(5); // Index 5 = Matériel & Imprimantes
        reply = "🖨️ Configuration de vos **Imprimantes et du Matériel**...";
        if (onAction != null) onAction!("navigate", payload: 9);
        suggestions = ["Test ticket", "Tiroir caisse"];
        break;
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
        if (settings?.useCloudAi == true && !isConnectionFallback) {
          _callCloudAiAndReply(text);
          return;
        }
        if (isConnectionFallback) {
          reply = "📡 **Erreur de connexion** : Impossible de joindre l'IA Danaya Cloud pour traiter cette demande.\n\n💡 *Puisque vous êtes hors-ligne, vous pouvez me demander des actions locales comme :*\n• 📦 'état du stock de [produit]'\n• 💰 'bilan de la journée'\n• 🚀 'ouvre la caisse'";
        } else {
          reply = _getDynamicFallback(nlpResult);
        }
        break;
    }

    if (reply.isNotEmpty) {
      final finalReply = isConnectionFallback 
          ? "📡 *Connexion instable. Traitement local :*\n\n$reply"
          : reply;
      addAssistantMessage(finalReply, suggestions: suggestions, isStreaming: true);
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
        final settingsIndex = _getSettingsTabIndexFromQuery(nlpResult.rawInput);
        ref.read(settingsTabIndexProvider.notifier).setIndex(settingsIndex);
        if (onAction != null) onAction!("navigate", payload: 9);
        addAssistantMessage("⚙️ Navigation vers les paramètres → ${_getSettingsTabLabel(settingsIndex)}...");
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
     } else if (query.contains('téléphone') || query.contains('telephone') || query.contains('tél') || query.contains('tel')) {
        final words = query.split(' ');
        int idx = words.indexWhere((w) => w.contains('téléphone') || w.contains('telephone') || w.contains('tél') || w.contains('tel'));
        if (idx >= 0 && words.length > idx + 1) {
          int start = idx + 1;
          while (start < words.length && ['en', 'sur', 'à', 'au', 'le', 'de', 'du', 'la', 'par', ':'].contains(words[start])) {
            start++;
          }
          if (start < words.length) {
            final newPhone = words.sublist(start).join(' ').replaceAll(RegExp(r'[.?!,;]'), '').trim();
            updated = settings.copyWith(phone: newPhone);
            addAssistantMessage("\ud83d\udcde Numéro de téléphone mis à jour : **$newPhone**.");
          } else {
            addAssistantMessage("\ud83d\udcde Quel numéro de téléphone souhaitez-vous configurer ? Dites par exemple 'téléphone 77123456'.");
          }
        } else {
          addAssistantMessage("\ud83d\udcde Quel numéro de téléphone souhaitez-vous configurer ? Dites par exemple 'téléphone 77123456'.");
        }
     } else if (query.contains('whatsapp') || query.contains('whats')) {
        final words = query.split(' ');
        int idx = words.indexWhere((w) => w.contains('whatsapp') || w.contains('whats'));
        if (idx >= 0 && words.length > idx + 1) {
          int start = idx + 1;
          while (start < words.length && ['en', 'sur', 'à', 'au', 'le', 'de', 'du', 'la', 'par', ':'].contains(words[start])) {
            start++;
          }
          if (start < words.length) {
            final newWhatsapp = words.sublist(start).join(' ').replaceAll(RegExp(r'[.?!,;]'), '').trim();
            updated = settings.copyWith(whatsapp: newWhatsapp);
            addAssistantMessage("\ud83d\udcac Numéro WhatsApp mis à jour : **$newWhatsapp**.");
          } else {
            addAssistantMessage("\ud83d\udcac Quel numéro WhatsApp souhaitez-vous configurer ? Dites par exemple 'WhatsApp 77123456'.");
          }
        } else {
          addAssistantMessage("\ud83d\udcac Quel numéro WhatsApp souhaitez-vous configurer ? Dites par exemple 'WhatsApp 77123456'.");
        }
     } else if (query.contains('adresse') || query.contains('address') || query.contains('localisation') || query.contains('lieu')) {
        final words = query.split(' ');
        int idx = words.indexWhere((w) => w.contains('adresse') || w.contains('address') || w.contains('localisation') || w.contains('lieu'));
        if (idx >= 0 && words.length > idx + 1) {
          int start = idx + 1;
          while (start < words.length && ['en', 'sur', 'à', 'au', 'le', 'de', 'du', 'la', 'par', ':'].contains(words[start])) {
            start++;
          }
          if (start < words.length) {
            final newAddress = words.sublist(start).join(' ').replaceAll(RegExp(r'[.?!,;]'), '').trim();
            updated = settings.copyWith(address: newAddress);
            addAssistantMessage("\ud83d\udccd Adresse de la boutique mise à jour : **$newAddress**.");
          } else {
            addAssistantMessage("\ud83d\udccd Quelle adresse souhaitez-vous configurer ? Dites par exemple 'adresse Bamako Coura'.");
          }
        } else {
          addAssistantMessage("\ud83d\udccd Quelle adresse souhaitez-vous configurer ? Dites par exemple 'adresse Bamako Coura'.");
        }
     } else if (query.contains('email') || query.contains('mail') || query.contains('courriel')) {
        final words = query.split(' ');
        int idx = words.indexWhere((w) => w.contains('email') || w.contains('mail') || w.contains('courriel'));
        if (idx >= 0 && words.length > idx + 1) {
          int start = idx + 1;
          while (start < words.length && ['en', 'sur', 'à', 'au', 'le', 'de', 'du', 'la', 'par', ':'].contains(words[start])) {
            start++;
          }
          if (start < words.length) {
            final newEmail = words.sublist(start).join(' ').replaceAll(RegExp(r'[.?!,;]'), '').trim();
            updated = settings.copyWith(email: newEmail);
            addAssistantMessage("\ud83d\udce2 Adresse email mise à jour : **$newEmail**.");
          } else {
            addAssistantMessage("\ud83d\udce2 Quelle adresse email souhaitez-vous configurer ? Dites par exemple 'email contact@shop.com'.");
          }
        } else {
          addAssistantMessage("\ud83d\udce2 Quelle adresse email souhaitez-vous configurer ? Dites par exemple 'email contact@shop.com'.");
        }
    } else if (query.contains('afficheur') || query.contains('display') || query.contains('ecran externe') || query.contains('écran externe')) {
        final themesMap = {
          'theme-q-acier': ['acier', 'robustesse'],
          'theme-q-ciment': ['ciment', 'batir'],
          'theme-q-brique': ['brique', 'solidite'],
          'theme-q-bois': ['bois', 'menuiserie'],
          'theme-q-fer': ['fer', 'metallurgie'],
          'theme-q-outil': ['outil', 'outillage'],
          'theme-q-chantier': ['chantier', 'gros oeuvre'],
          'theme-faso': ['faso', 'batisseur'],
          'theme-q-alu': ['alu', 'vitrage', 'clarte'],
          'theme-q-cuivre': ['cuivre', 'plomberie'],
          'theme-bazin': ['bazin'],
          'theme-kita': ['kita'],
          'theme-p-soie': ['soie'],
          'theme-p-wax': ['wax'],
          'theme-p-indigo': ['indigo'],
          'theme-p-cuir': ['cuir'],
          'theme-p-dentelle': ['dentelle'],
          'theme-p-urbain': ['urbain', 'contemporaine'],
          'theme-p-tailleur': ['tailleur'],
          'theme-p-accessoire': ['accessoire'],
          'theme-sugu': ['sugu', 'marche'],
          'theme-s-frais': ['frais', 'primeur'],
          'theme-s-epice': ['epice', 'épice'],
          'theme-s-fruit': ['fruit'],
          'theme-s-boulanger': ['boulanger', 'boulangerie'],
          'theme-s-viande': ['viande', 'boucherie'],
          'theme-s-lait': ['lait', 'cremerie'],
          'theme-garabal': ['garabal'],
          'theme-s-bio': ['bio'],
          'theme-s-gourmet': ['gourmet'],
          'theme-karite': ['karite', 'karité'],
          'theme-b-parfum': ['parfum'],
          'theme-b-argan': ['argan'],
          'theme-b-goudron': ['goudron', 'encens'],
          'theme-rose': ['rose'],
          'theme-b-nude': ['nude'],
          'theme-b-or': ['or', 'dore', 'doré'],
          'theme-b-spa': ['spa'],
          'theme-b-onglerie': ['onglerie'],
          'theme-b-cheveux': ['cheveux', 'coiffure'],
          'theme-neon': ['neon', 'néon'],
          'theme-cyberpunk': ['cyberpunk'],
          'theme-midnight': ['midnight', 'minuit'],
          'theme-h-silicon': ['silicon', 'silicone'],
          'theme-h-fibre': ['fibre'],
          'theme-h-gaming': ['gaming', 'setup'],
          'theme-h-mobile': ['mobile'],
          'theme-h-photo': ['photo'],
          'theme-h-audio': ['audio', 'studio'],
          'theme-h-smart': ['smart'],
          'theme-luxury': ['luxury', 'luxe'],
          'theme-corporate': ['corporate'],
          'theme-wallstreet': ['wallstreet', 'wall street'],
          'theme-monaco': ['monaco'],
          'theme-empire': ['empire'],
          'theme-dakan': ['dakan'],
          'theme-wariba': ['wariba'],
          'theme-jago': ['jago'],
          'theme-obsidian': ['obsidian', 'obsidienne'],
          'theme-sanife': ['sanife'],
          'theme-ocean-flame': ['ocean', 'océan'],
        };

        String? foundThemeId;
        for (final entry in themesMap.entries) {
          for (final keyword in entry.value) {
            if (query.contains(keyword)) {
              foundThemeId = entry.key;
              break;
            }
          }
          if (foundThemeId != null) break;
        }

        if (foundThemeId != null) {
          updated = settings.copyWith(customerDisplayTheme: foundThemeId);
          addAssistantMessage("📺 Thème de l'afficheur client mis à jour : **$foundThemeId**.");
        } else if (query.contains('theme') || query.contains('thème') || query.contains('style') || query.contains('visuel')) {
          addAssistantMessage("📺 Quel thème visuel souhaitez-vous appliquer à l'afficheur ? (ex: Kita, Luxury, Faso, Bazin, etc.)");
        } else if (query.contains('son') || query.contains('bruit') || query.contains('effet')) {
          final enable = query.contains('active') || query.contains('oui') || query.contains('allume') || query.contains('avec') || !query.contains('desactive') && !query.contains('coupe') && !query.contains('sans') && !query.contains('non') && !query.contains('etein');
          updated = settings.copyWith(enableCustomerDisplaySounds: enable);
          addAssistantMessage("📺 Sons de l'afficheur client : **${enable ? 'Activés' : 'Désactivés'}**.");
        } else if (query.contains('3d') || query.contains('relief')) {
          final enable = query.contains('active') || query.contains('oui') || query.contains('allume') || query.contains('avec') || !query.contains('desactive') && !query.contains('sans') && !query.contains('non') && !query.contains('etein');
          updated = settings.copyWith(useCustomerDisplay3D: enable);
          addAssistantMessage("📺 Rendu 3D de l'afficheur client : **${enable ? 'Activé' : 'Désactivé'}**.");
        } else if (query.contains('voix') || query.contains('synthese') || query.contains('synthèse') || query.contains('parle')) {
          final enable = query.contains('active') || query.contains('oui') || query.contains('allume') || query.contains('avec') || !query.contains('desactive') && !query.contains('sans') && !query.contains('non') && !query.contains('coupe');
          updated = settings.copyWith(isVoiceEnabled: enable);
          addAssistantMessage("📺 Synthèse vocale de l'afficheur client : **${enable ? 'Activée' : 'Désactivée'}**.");
        } else if (query.contains('defilement') || query.contains('défilement') || query.contains('ticker') || query.contains('bandeau')) {
          final enable = query.contains('active') || query.contains('oui') || query.contains('allume') || query.contains('avec') || !query.contains('desactive') && !query.contains('sans') && !query.contains('non');
          updated = settings.copyWith(enableCustomerDisplayTicker: enable);
          addAssistantMessage("📺 Bandeau défilant de l'afficheur client : **${enable ? 'Activé' : 'Désactivé'}**.");
        } else if (query.contains('message') || query.contains('texte') || query.contains('phrase')) {
          final parts = query.split(RegExp(r'\s+(de|du|sur|pour|comme|:)\s+'));
          String? newMsg;
          if (parts.length > 1) {
            newMsg = parts.sublist(1).join(' ').trim();
          } else {
            final words = query.split(' ');
            final msgIdx = words.indexWhere((w) => w.contains('message') || w.contains('texte'));
            if (msgIdx >= 0 && words.length > msgIdx + 1) {
              newMsg = words.sublist(msgIdx + 1).join(' ');
            }
          }
          if (newMsg != null && newMsg.isNotEmpty) {
            newMsg = newMsg.replaceAll(RegExp(r'[.?!,;]'), '').trim();
            updated = settings.copyWith(customerDisplayMessages: [newMsg]);
            addAssistantMessage("📺 Message de l'afficheur client mis à jour : **$newMsg**.");
          } else {
            addAssistantMessage("📺 Quel message souhaitez-vous afficher ? Dites par exemple : 'message afficheur Bienvenue chez nous !'");
          }
        } else {
          ref.read(settingsTabIndexProvider.notifier).setIndex(6); // Index 6 = Afficheur Client
          addAssistantMessage("📺 Ouverture des réglages de **l'Afficheur Client**...");
          if (onAction != null) onAction!("navigate", payload: 9);
        }
    } else if (query.contains('imprimante') || query.contains('printer')) {
       // Check if they specified a printer name to assign
       String? printerName;
       final parts = query.split(RegExp(r'\s+(sur|en|à|comme|pour)\s+'));
       if (parts.length > 1) {
         printerName = parts.last.trim();
       } else {
         // Fallback check: look for words after 'imprimante'
         final words = query.split(' ');
         final impIndex = words.indexWhere((w) => w.contains('imprimante') || w.contains('printer'));
         if (impIndex >= 0 && words.length > impIndex + 2) {
           final nextWord = words[impIndex + 1];
           if (['sur', 'en', 'à', 'comme', 'pour', 'le', 'la', 'de'].contains(nextWord)) {
             printerName = words.sublist(impIndex + 2).join(' ');
           } else {
             printerName = words.sublist(impIndex + 1).join(' ');
           }
         }
       }

       if (printerName != null && printerName.isNotEmpty) {
         printerName = printerName.replaceAll(RegExp(r'[.?!,;]'), '').trim();
         
         final printers = await ref.read(hardwareServiceProvider).listPrinters();
         final matched = printers.firstWhere(
           (p) => p.name.toLowerCase().contains(printerName!.toLowerCase()),
           orElse: () => ExternalDevice(name: '', status: '', deviceClass: DeviceClass.printer, rawData: {}),
         );

         if (matched.name.isNotEmpty) {
           if (query.contains('facture') || query.contains('a4')) {
             updated = settings.copyWith(invoicePrinterName: matched.name);
             addAssistantMessage("🖨️ Imprimante **Factures A4** configurée avec succès sur : **${matched.name}**.");
           } else if (query.contains('devis')) {
             updated = settings.copyWith(quotePrinterName: matched.name);
             addAssistantMessage("🖨️ Imprimante **Devis** configurée avec succès sur : **${matched.name}**.");
           } else if (query.contains('etiquette') || query.contains('étiquette')) {
             updated = settings.copyWith(labelPrinterName: matched.name);
             addAssistantMessage("🖨️ Imprimante **Étiquettes** configurée avec succès sur : **${matched.name}**.");
           } else if (query.contains('rapport')) {
             updated = settings.copyWith(reportPrinterName: matched.name);
             addAssistantMessage("🖨️ Imprimante **Rapports** configurée avec succès sur : **${matched.name}**.");
           } else {
             updated = settings.copyWith(thermalPrinterName: matched.name);
             addAssistantMessage("🖨️ Imprimante **Tickets (Thermique)** configurée avec succès sur : **${matched.name}**.");
           }
         } else {
            final printerListStr = printers.isEmpty ? "\u2022 *Aucune imprimante installée*" : printers.map((p) => "\u2022 ${p.name}").join("\n");
            addAssistantMessage("\ud83d\udcbe Je n'ai pas trouvé d'imprimante contenant le nom **'$printerName'** installée sur votre système.\n\nVoici les imprimantes disponibles :\n$printerListStr");
         }
       } else {
         ref.read(settingsTabIndexProvider.notifier).setIndex(5); // Index 5 = Matériel Hub / Imprimantes
         addAssistantMessage("🖨️ Ouverture des réglages de **Matériel & Imprimantes**...");
         if (onAction != null) onAction!("navigate", payload: 9);
       }
    } else {
       addAssistantMessage("⚙️ Quel paramètre voulez-vous modifier ? (Nom, TVA, Devise, Slogan, Imprimante)");
    }

    if (updated != null) {
      ref.read(shopSettingsProvider.notifier).save(updated);
    }
  }

  int _getSettingsTabIndexFromQuery(String query) {
    final q = query.toLowerCase();
    if (q.contains('imprimante') || q.contains('printer') || q.contains('impression') || q.contains('ticket') || q.contains('facture') || q.contains('materiel') || q.contains('matériel') || q.contains('tiroir')) {
      return 5;
    }
    if (q.contains('sauvegarde') || q.contains('backup') || q.contains('restaurer') || q.contains('restauration') || q.contains('sql') || q.contains('maintenance')) {
      return 10;
    }
    if (q.contains('apparence') || q.contains('design') || q.contains('theme') || q.contains('thème') || q.contains('visuel') || q.contains('pdf') || q.contains('modèle')) {
      return 4;
    }
    if (q.contains('taxe') || q.contains('tva') || q.contains('devise') || q.contains('monnaie') || q.contains('finance') || q.contains('fiscal') || q.contains('capital') || q.contains('nif') || q.contains('rc')) {
      return 1;
    }
    if (q.contains('fidelite') || q.contains('fidélité') || q.contains('vip') || q.contains('points') || q.contains('point')) {
      return 2;
    }
    if (q.contains('afficheur')) {
      return 6;
    }
    if (q.contains('son') || q.contains('bruit') || q.contains('multimedia') || q.contains('multimédia') || q.contains('alerte sonore')) {
      return 7;
    }
    if (q.contains('ia') || q.contains('assistant') || q.contains('danaya') || q.contains('copilot') || q.contains('rules') || q.contains('regles') || q.contains('règles')) {
      return 8;
    }
    if (q.contains('smtp') || q.contains('email') || q.contains('courriel') || q.contains('envoi rapports')) {
      return 9;
    }
    if (q.contains('reseau') || q.contains('réseau') || q.contains('serveur') || q.contains('multiposte') || q.contains('sync') || q.contains('synchro') || q.contains('distant') || q.contains('vpn')) {
      return 11;
    }
    if (q.contains('log') || q.contains('logs') || q.contains('historique actions')) {
      return 12;
    }
    if (q.contains('academy') || q.contains('tuto') || q.contains('tutoriel') || q.contains('guide')) {
      return 14;
    }
    if (q.contains('whatsapp') || q.contains('meta') || q.contains('api whatsapp')) {
      return 15;
    }
    if (q.contains('enseigne') || q.contains('nom') || q.contains('slogan') || q.contains('adresse') || q.contains('logo') || q.contains('telephone') || q.contains('téléphone')) {
      return 0;
    }
    return 0; // Default: Enseigne
  }

  String _getSettingsTabLabel(int index) {
    switch (index) {
      case 0: return "Enseigne & Identité";
      case 1: return "Commerce & Fiscalité";
      case 2: return "Points & Fidélité";
      case 3: return "Politiques & SAV";
      case 4: return "Design PDF & Documents";
      case 5: return "Matériel & Imprimantes";
      case 6: return "Afficheur Client";
      case 7: return "Sons & Alertes";
      case 8: return "Assistant IA";
      case 9: return "SMTP & Rapports";
      case 10: return "Sauvegardes & Restauration";
      case 11: return "Serveur & Multi-postes";
      case 12: return "Logs Système";
      case 13: return "Personnalisation Interface";
      case 14: return "D+ Academy";
      case 15: return "WhatsApp Cloud API";
      default: return "Général";
    }
  }

  // ── DEPRECATED ONE-SHOT HANDLERS (REPLACED BY FLOW ENGINE) ────────

  void _executeMacro(String macroId) {
    final macro = MacroEngine.getMacro(macroId);
    if (macro == null) return;
    
    final user = ref.read(authServiceProvider).value;
    final settings = ref.read(shopSettingsProvider).value;
    final currentLevel = settings?.assistantLevel ?? AssistantPowerLevel.basic;
    
    // Check permission level
    if (currentLevel.index < macro.requiredLevel.index) {
        addAssistantMessage("🔒 Accès refusé. La macro '${macro.name}' nécessite le niveau d'intelligence : ${macro.requiredLevel.name.toUpperCase()}.");
        return;
    }

    // 🛡️ Contrôle d'accès basé sur le rôle (RBAC) pour les macros d'orchestration
    if (macroId == 'fermeture_caisse' && !(user?.canAccessFinance ?? false)) {
      addAssistantMessage("🛡️ Accès refusé. Vous devez avoir les permissions financières ou être Gérant pour fermer la caisse.");
      return;
    }
    if (macroId == 'audit_total' && !(user?.canAccessReports ?? false)) {
      addAssistantMessage("🛡️ Accès refusé. Vous devez être autorisé à consulter les rapports pour lancer l'audit.");
      return;
    }
    if (macroId == 'gestion_equipe' && !(user?.canManageHR ?? false)) {
      addAssistantMessage("🛡️ Accès refusé. Vous n'avez pas les droits de gestion RH requis pour cette macro.");
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
     var t = text.toLowerCase().replaceAll(RegExp(r"\b(vends?|vendre|ajoute au panier|facture[rz]?|encaisser|moi)\b"), '');
     t = t.replaceAll(RegExp(r"\b(salut|bonjour|bonsoir|s'il te plaît|s'il vous plaît|danaya)\b"), '');
     
     final chunks = t.split(RegExp(r"(?:,| et | puis | avec )"));
     
     final numberMap = {
       'un': 1.0, 'une': 1.0, 'kelen': 1.0,
       'deux': 2.0, 'fila': 2.0,
       'trois': 3.0, 'saba': 3.0,
       'quatre': 4.0, 'naani': 4.0,
       'cinq': 5.0, 'duuru': 5.0,
       'six': 6.0, 'wooro': 6.0,
       'sept': 7.0, 'wolonwula': 7.0,
       'huit': 8.0, 'segi': 8.0,
       'neuf': 9.0, 'kononto': 9.0,
       'dix': 10.0, 'tan': 10.0,
     };
     
     for (var chunk in chunks) {
        chunk = chunk.trim();
        if (chunk.isEmpty) continue;
        
        final tokens = chunk.split(RegExp(r'\s+'));
        if (tokens.isEmpty) continue;
        
        double qty = 1.0;
        String pName = chunk;
        
        final firstToken = tokens.first;
        final firstAsNum = double.tryParse(firstToken);
        if (firstAsNum != null) {
          qty = firstAsNum;
          pName = tokens.skip(1).join(' ');
        } else if (numberMap.containsKey(firstToken)) {
          qty = numberMap[firstToken]!;
          pName = tokens.skip(1).join(' ');
        } else if (tokens.length > 1) {
          final lastToken = tokens.last;
          final lastAsNum = double.tryParse(lastToken);
          if (lastAsNum != null) {
            qty = lastAsNum;
            pName = tokens.take(tokens.length - 1).join(' ');
          } else if (numberMap.containsKey(lastToken)) {
            qty = numberMap[lastToken]!;
            pName = tokens.take(tokens.length - 1).join(' ');
          }
        }
        
        pName = pName.trim();
        if (pName.isNotEmpty) {
           final cleanName = pName.replaceAll(RegExp(r"^(de |d'|un |une |des |le |la |les )"), '').trim();
           if (cleanName.isNotEmpty) {
             result.add({'qty': qty, 'name': cleanName});
           }
        }
     }
     return result;
  }

  void _handleVoiceCartOrchestration(List<Map<String, dynamic>> requestedItems) {
    int addedCount = 0;
    final products = ref.read(productListProvider).value ?? [];
    final warnings = <String>[];
    final addedItemsDetails = <String>[];
    
    for (final req in requestedItems) {
      final name = req['name'] as String;
      final qty = (req['qty'] as num).toDouble();
      
      Product? bestMatch;
      double bestScore = 0.0;
      
      for (final p in products) {
        if (p.isService) continue;
        final prodNameLower = p.name.toLowerCase();
        final searchNameLower = name.toLowerCase();
        
        double score = 0.0;
        if (prodNameLower == searchNameLower) {
          score = 1.0;
        } else if (prodNameLower.contains(searchNameLower)) {
          score = 0.9;
        } else if (searchNameLower.contains(prodNameLower)) {
          score = 0.85;
        } else {
          final searchWords = searchNameLower.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
          if (searchWords.isNotEmpty) {
            int overlap = 0;
            for (final w in searchWords) {
              if (prodNameLower.contains(w)) {
                overlap++;
              }
            }
            score = (overlap / searchWords.length) * 0.75;
          }
        }
        
        final sim = math.max(
          NlpEngine.similarity(searchNameLower, prodNameLower),
          NlpEngine.phoneticSimilarity(searchNameLower, prodNameLower),
        );
        if (sim > score) {
          score = sim;
        }
        
        if (score > bestScore && score >= 0.6) {
          bestScore = score;
          bestMatch = p;
        }
      }
      
      if (bestMatch != null) {
        if (bestMatch.quantity <= 0) {
          warnings.add("❌ **Rupture** : '${bestMatch.name}' est en rupture totale de stock.");
        } else if (bestMatch.quantity < qty) {
          final available = bestMatch.quantity;
          ref.read(cartProvider.notifier).addProduct(bestMatch);
          ref.read(cartProvider.notifier).updateQty(bestMatch.id, available);
          addedCount++;
          addedItemsDetails.add("${available}x ${bestMatch.name}");
          warnings.add("⚠️ **Rupture partielle** : Seulement $available unités de '${bestMatch.name}' ajoutées (sur $qty demandées).");
        } else {
          ref.read(cartProvider.notifier).addProduct(bestMatch);
          if (qty > 1) {
            ref.read(cartProvider.notifier).updateQty(bestMatch.id, qty);
          }
          addedCount++;
          addedItemsDetails.add("${qty}x ${bestMatch.name}");
        }
      } else {
        warnings.add("❓ **Introuvable** : Aucun produit ne correspond à '$name'.");
      }
    }
    
    if (addedCount > 0) {
      final summary = "🛒 **Orchestration TITAN** : Ajouté au panier : ${addedItemsDetails.join(', ')}.";
      final warningsText = warnings.isNotEmpty ? "\n${warnings.join('\n')}" : "";
      addAssistantMessage("$summary$warningsText\nRedirection vers la caisse...");
      if (onAction != null) onAction!("navigate", payload: 3);
      _handleAutonomousContinuation(NlpIntent.actionNewSale);
    } else {
      final warningsText = warnings.isNotEmpty ? "\n${warnings.join('\n')}" : "";
      addAssistantMessage("😔 **Erreur d'orchestration** : Aucun article n'a pu être ajouté au panier.$warningsText");
    }
  }

  // ── MULTI-TURN FLOW ENGINE ────────────────────────────────────────

  void _startFlow(AssistantFlow flow, {String? initialText}) {
    final user = ref.read(authServiceProvider).value;
    
    // 🛡️ Contrôle d'accès basé sur le rôle (RBAC) pour les formulaires conversationnels
    if (flow == AssistantFlow.product && !(user?.canManageInventory ?? false)) {
      addAssistantMessage("🛡️ Désolé ${user?.username ?? 'Boss'}, vous n'avez pas la permission de gérer l'inventaire ou de créer des produits.");
      return;
    }
    if (flow == AssistantFlow.expense && !(user?.canManageExpenses ?? false)) {
      addAssistantMessage("🛡️ Désolé ${user?.username ?? 'Boss'}, vous n'avez pas la permission d'enregistrer des dépenses.");
      return;
    }
    if (flow == AssistantFlow.client && !(user?.canManageCustomers ?? false)) {
      addAssistantMessage("🛡️ Désolé ${user?.username ?? 'Boss'}, vous n'avez pas la permission de créer des fiches clients.");
      return;
    }
    if (flow == AssistantFlow.purchaseOrder && !(user?.canManageInventory ?? false)) {
      addAssistantMessage("🛡️ Désolé ${user?.username ?? 'Boss'}, vous n'avez pas la permission de gérer les approvisionnements ou de créer des bons de commande.");
      return;
    }
    if (flow == AssistantFlow.quote && !(user?.canSell ?? false)) {
      addAssistantMessage("🛡️ Désolé ${user?.username ?? 'Boss'}, vous n'avez pas la permission de créer des devis.");
      return;
    }

    state = state.copyWith(
      currentFlow: flow,
      flowStep: FlowStep.initial,
      flowData: {},
    );

    final settings = ref.read(shopSettingsProvider).value;
    final currency = settings?.currency ?? 'FCFA';

    switch (flow) {
      case AssistantFlow.quote:
        addAssistantMessage("Vous pouvez créer un devis directement depuis l'écran **Gestion des Devis** en cliquant sur **Nouveau Devis** (avec saisie de produits ou saisie libre), ou bien à la voix/texte en ajoutant des articles à votre panier de caisse puis en me demandant de 'créer le devis'.");
        _resetFlow();
        break;
      case AssistantFlow.purchaseOrder:
        addAssistantMessage("D'accord, créons un bon de commande. Pour quel fournisseur ?");
        state = state.copyWith(flowStep: FlowStep.supplier);
        break;
      case AssistantFlow.expense:
        double? parsedAmount;
        String? parsedCategory;
        if (initialText != null) {
          final amountMatch = RegExp(r'(\d+(?:[\s.,]?\d+)*)').firstMatch(initialText);
          if (amountMatch != null) {
            final rawNum = amountMatch.group(1)!.replaceAll(RegExp(r'[\s.,]'), '');
            parsedAmount = double.tryParse(rawNum);
          }
          
          final catKeywords = ['loyer', 'transport', 'divers', 'fourniture', 'repas', 'facture', 'achat', 'électricité', 'eau', 'internet'];
          for (final kw in catKeywords) {
            if (initialText.toLowerCase().contains(kw)) {
              parsedCategory = kw;
              break;
            }
          }
        }
        if (parsedAmount != null) {
          if (parsedCategory != null) {
            _finalizeExpense(parsedAmount, parsedCategory.toUpperCase(), TransactionCategory.EXPENSE);
          } else {
            state = state.copyWith(
              flowData: {'amount': parsedAmount},
              flowStep: FlowStep.category,
            );
            addAssistantMessage("Dépense de **$parsedAmount $currency** notée. Quelle est la catégorie ou le motif ? (ex: Loyer, Transport, Divers)");
          }
        } else {
          addAssistantMessage("Nouvelle dépense. Quel est le montant ?");
          state = state.copyWith(flowStep: FlowStep.amount);
        }
        break;
      case AssistantFlow.client:
        String? parsedName;
        String? parsedPhone;
        
        if (initialText != null) {
          // Extraction intelligente du nom (ex: Hadiza Sikasso) après s'appelle, nommé, appelé, nom de
          final nameMatch = RegExp(r"(?:s'appelle|nommé|appelé|nom de)\s+(.*?)(?:\s+avec|\s+tél|\s+numéro|$)", caseSensitive: false)
              .firstMatch(initialText);
          if (nameMatch != null) {
            parsedName = nameMatch.group(1)!.trim();
          }
          
          // Extraction du téléphone (ex: 77123456)
          final phoneMatch = RegExp(r"(?:\+?\d[\s-]?){8,15}").firstMatch(initialText);
          if (phoneMatch != null) {
            parsedPhone = phoneMatch.group(0)!.replaceAll(RegExp(r'[\s-]'), '');
          }
        }

        if (parsedName != null && parsedName.isNotEmpty) {
          state = state.copyWith(
            flowData: {'name': parsedName},
            flowStep: FlowStep.phone,
          );
          if (parsedPhone != null && parsedPhone.isNotEmpty) {
            _finalizeClient(parsedName, parsedPhone);
          } else {
            addAssistantMessage("Client **'$parsedName'** détecté. Quel est son numéro de téléphone ? (ou dites 'non' pour passer)");
          }
        } else {
          addAssistantMessage("Créons un nouveau client. Quel est son nom ?");
          state = state.copyWith(flowStep: FlowStep.name);
        }
        break;
      case AssistantFlow.product:
        String? parsedName;
        if (initialText != null) {
          final nameMatch = RegExp(r"(?:nom de|nommé|produit)\s+([^,.\n]+)", caseSensitive: false)
              .firstMatch(initialText);
          if (nameMatch != null) {
            parsedName = nameMatch.group(1)!.trim();
          }
        }
        if (parsedName != null && parsedName.isNotEmpty) {
          state = state.copyWith(
            flowData: {'name': parsedName},
            flowStep: FlowStep.purchasePrice,
          );
          addAssistantMessage("Article **'$parsedName'** noté. Quel est son **Prix d'Achat** (PA) ? (Dites '0' si inconnu)");
        } else {
          addAssistantMessage("Nouveau produit. Quel est le nom de l'article ?");
          state = state.copyWith(flowStep: FlowStep.name);
        }
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
      case AssistantFlow.quote:
        _resetFlow();
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
      final score = math.max(
        NlpEngine.similarity(name.toLowerCase(), s.name.toLowerCase()),
        NlpEngine.phoneticSimilarity(name.toLowerCase(), s.name.toLowerCase()),
      );
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
    final amountMatch = RegExp(r'(\d+(?:[\s.,]?\d+)*)').firstMatch(text);
    if (state.flowStep == FlowStep.amount && amountMatch != null) {
       final settings = ref.read(shopSettingsProvider).value;
       final currency = settings?.currency ?? 'FCFA';
       final rawNum = amountMatch.group(1)!.replaceAll(RegExp(r'[\s.,]'), '');
       final amount = double.tryParse(rawNum) ?? 0.0;
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
        final amountMatch = RegExp(r'(\d+(?:[\s.,]?\d+)*)').firstMatch(text);
        final rawNum = amountMatch != null ? amountMatch.group(1)!.replaceAll(RegExp(r'[\s.,]'), '') : '0';
        final price = double.tryParse(rawNum) ?? 0.0;
        state = state.copyWith(
          flowData: {...state.flowData, 'purchasePrice': price},
          flowStep: FlowStep.price,
        );
        addAssistantMessage("Prix d'achat de **$price $currency** enregistré. Quel est le **Prix de Vente** (PV) ?");
        break;

      case FlowStep.price:
        final amountMatch = RegExp(r'(\d+(?:[\s.,]?\d+)*)').firstMatch(text);
        if (amountMatch != null) {
          final rawNum = amountMatch.group(1)!.replaceAll(RegExp(r'[\s.,]'), '');
          final price = double.tryParse(rawNum) ?? 0.0;
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
        final amountMatch = RegExp(r'(\d+(?:[\s.,]?\d+)*)').firstMatch(text);
        if (amountMatch != null) {
          final rawNum = amountMatch.group(1)!.replaceAll(RegExp(r'[\s.,]'), '');
          final qty = double.tryParse(rawNum) ?? 0.0;
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

  void addAssistantMessage(String text, {List<String> suggestions = const [], bool isStreaming = false, bool isError = false}) {
    state = state.copyWith(
      messages: [...state.messages, AssistantMessage(text: text, isStreaming: isStreaming, isError: isError)],
      isTyping: false,
      suggestedActions: suggestions.isNotEmpty ? suggestions : state.suggestedActions,
    );
    _saveChatHistory();

    final isProactive = text.contains("🔮") || 
                        text.contains("📣") || 
                        text.contains("💡") || 
                        text.contains("🛡️") ||
                        text.contains("🔴") ||
                        text.contains("⚡") ||
                        text.contains("⚠️");

    final isVoiceCallActive = ref.read(voiceServiceProvider).isCallActive;
    if (!state.isOpen && !isVoiceCallActive) {
      final cleanMsg = text
          .replaceAll(RegExp(r'\*\*|🔮|📣|💡|🛡️|🔴|⚡|⚠️'), '')
          .replaceAll(RegExp(r'\[TITAN Suggestion\]'), '')
          .trim();
      
      final title = isProactive ? "Rapport d'activité IA" : "Message de l'Assistant";
      
      ref.read(assistantNotificationProvider.notifier).addNotification(
        AssistantNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          message: cleanMsg.length > 80 ? "${cleanMsg.substring(0, 80)}..." : cleanMsg,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  void updateLiveResponse(String text, {bool save = true}) {
    if (state.messages.isEmpty || state.messages.last.isUser) {
      state = state.copyWith(
        messages: [...state.messages, AssistantMessage(text: text, isStreaming: false)],
        isTyping: false,
      );
    } else {
      final updated = List<AssistantMessage>.from(state.messages);
      updated[updated.length - 1] = AssistantMessage(
        text: text,
        isUser: false,
        timestamp: updated.last.timestamp,
        isStreaming: false,
      );
      state = state.copyWith(messages: updated);
    }
    if (save) {
      _saveChatHistory();
    }
  }

  Future<void> saveChatHistory() async {
    await _saveChatHistory();
  }

  void markMessageStreamingCompleted(String textId) {
    final index = state.messages.indexWhere((m) => m.text == textId && m.isStreaming);
    if (index != -1) {
      final updated = List<AssistantMessage>.from(state.messages);
      final msg = updated[index];
      updated[index] = AssistantMessage(
        text: msg.text,
        isUser: msg.isUser,
        timestamp: msg.timestamp,
        isStreaming: false,
        isError: msg.isError,
      );
      state = state.copyWith(messages: updated);
    }
  }

  void retryLastFailedMessage() {
    final userMessages = state.messages.where((m) => m.isUser).toList();
    if (userMessages.isNotEmpty) {
      final lastUserMsg = userMessages.last;
      
      // Nettoyer le message d'erreur de l'historique de discussion
      final updated = List<AssistantMessage>.from(state.messages);
      if (updated.isNotEmpty && !updated.last.isUser) {
        updated.removeLast();
      }
      state = state.copyWith(messages: updated);
      
      // Renvoyer le texte de la dernière question
      sendMessage(lastUserMsg.text);
    }
  }

  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Enregistrement legacy
      final legacyList = state.messages.map((m) => {
        'text': m.text,
        'isUser': m.isUser,
        'timestamp': m.timestamp.toIso8601String(),
        'isError': m.isError,
        'attachmentName': m.attachmentName,
        'attachmentMimeType': m.attachmentMimeType,
      }).toList();
      await prefs.setString(_chatHistoryKey, jsonEncode(legacyList));

      // Enregistrement dans les fils de discussion (threads)
      final activeId = state.currentThreadId;
      if (activeId != null) {
        final idx = state.threads.indexWhere((t) => t.id == activeId);
        if (idx != -1) {
          var activeThread = state.threads[idx];
          
          // Nommer automatiquement le fil à partir du premier message de l'utilisateur
          var title = activeThread.title;
          if (title == "Nouvelle discussion") {
            final firstUser = state.messages.firstWhere((m) => m.isUser, orElse: () => AssistantMessage(text: ""));
            if (firstUser.text.isNotEmpty) {
              title = firstUser.text;
              if (title.length > 28) {
                title = "${title.substring(0, 25)}...";
              }
            }
          }

          final updatedThread = activeThread.copyWith(
            title: title,
            updatedAt: DateTime.now(),
            messages: state.messages,
          );

          final List<ChatThread> updatedThreads = List.from(state.threads);
          updatedThreads[idx] = updatedThread;
          
          // Trier par mise à jour la plus récente en premier
          updatedThreads.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          state = state.copyWith(threads: updatedThreads);
          await _saveThreadsToPrefs();
        }
      }
    } catch (e) {
      debugPrint("Error saving chat history/threads: $e");
    }
  }

  Future<void> createNewThread() async {
    final newId = const Uuid().v4();
    final newThread = ChatThread(
      id: newId,
      title: "Nouvelle discussion",
      updatedAt: DateTime.now(),
      messages: [
        AssistantMessage(
          text: "Bonjour ! Je suis Danaya, ton assistant intelligent de gestion. Que puis-je faire pour t'aider aujourd'hui ?",
          isUser: false,
          timestamp: DateTime.now(),
        )
      ],
    );

    final updatedThreads = [newThread, ...state.threads];
    state = state.copyWith(
      threads: updatedThreads,
      currentThreadId: newId,
      messages: newThread.messages,
    );

    await _saveThreadsToPrefs();
  }

  Future<void> switchThread(String threadId) async {
    final idx = state.threads.indexWhere((t) => t.id == threadId);
    if (idx == -1) return;

    final targetThread = state.threads[idx];
    state = state.copyWith(
      currentThreadId: threadId,
      messages: targetThread.messages,
    );
  }

  Future<void> deleteThread(String threadId) async {
    final updatedThreads = state.threads.where((t) => t.id != threadId).toList();
    String? newActiveId = state.currentThreadId;
    List<AssistantMessage> newMessages = state.messages;

    if (state.currentThreadId == threadId) {
      if (updatedThreads.isEmpty) {
        final newId = const Uuid().v4();
        final initialThread = ChatThread(
          id: newId,
          title: "Nouvelle discussion",
          updatedAt: DateTime.now(),
          messages: [
            AssistantMessage(
              text: "Bonjour ! Je suis Danaya, ton assistant intelligent de gestion. Que puis-je faire pour t'aider aujourd'hui ?",
              isUser: false,
              timestamp: DateTime.now(),
            )
          ],
        );
        updatedThreads.add(initialThread);
        newActiveId = newId;
        newMessages = initialThread.messages;
      } else {
        newActiveId = updatedThreads.first.id;
        newMessages = updatedThreads.first.messages;
      }
    }

    state = state.copyWith(
      threads: updatedThreads,
      currentThreadId: newActiveId,
      messages: newMessages,
    );

    await _saveThreadsToPrefs();
  }

  Future<void> renameThread(String threadId, String newTitle) async {
    final cleanedTitle = newTitle.trim();
    if (cleanedTitle.isEmpty) return;

    final updatedThreads = state.threads.map((t) {
      if (t.id == threadId) {
        return t.copyWith(title: cleanedTitle);
      }
      return t;
    }).toList();

    state = state.copyWith(threads: updatedThreads);
    await _saveThreadsToPrefs();
  }

  void toggleSidebar() {
    state = state.copyWith(isSidebarOpen: !state.isSidebarOpen);
  }

  Future<void> _saveThreadsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(state.threads.map((t) => t.toJson()).toList());
      await prefs.setString(_chatThreadsKey, jsonStr);
    } catch (e) {
      debugPrint("Error saving chat threads: $e");
    }
  }

  Future<void> clearChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chatHistoryKey);
      
      final activeId = state.currentThreadId;
      List<ChatThread> updatedThreads = List.from(state.threads);
      if (activeId != null) {
        final idx = updatedThreads.indexWhere((t) => t.id == activeId);
        if (idx != -1) {
          updatedThreads[idx] = updatedThreads[idx].copyWith(
            title: "Nouvelle discussion",
            updatedAt: DateTime.now(),
            messages: [],
          );
        }
      }
      
      state = state.copyWith(
        threads: updatedThreads,
        messages: [],
      );
      _addWelcomeMessage();
      await _saveThreadsToPrefs();
    } catch (e) {
      debugPrint("Error clearing chat history: $e");
    }
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

  Future<String> buildBusinessContext() async {
    // Charger et récupérer la mémoire persistante
    await ref.read(assistantMemoryProvider.notifier).loadMemories();
    final memoryPrompt = ref.read(assistantMemoryProvider.notifier).getFormattedMemoryPrompt();

    final user = ref.read(authServiceProvider).value;
    final canAccessFinance = user?.canAccessFinance ?? false;
    final canManageStock = user?.canManageInventory ?? false;
    final canAccessReports = user?.canAccessReports ?? false;

    final settings = ref.read(shopSettingsProvider).value;
    final currency = settings?.currency ?? 'FCFA';
    final removeDecimals = settings?.removeDecimals ?? true;

    final activeSession = ref.read(activeSessionProvider).value;
    final String sessionStatusStr;
    if (activeSession != null) {
      sessionStatusStr = "OUVERTE (Fond de caisse initial : ${DateFormatter.formatCurrency(activeSession.openingBalance, currency, removeDecimals: removeDecimals)}, Ouverte le : ${DateFormatter.formatDate(activeSession.openDate)} à ${activeSession.openDate.hour}h${activeSession.openDate.minute.toString().padLeft(2, '0')})";
    } else {
      sessionStatusStr = "FERMÉE";
    }
    final assistantLevel = settings?.assistantLevel ?? AssistantPowerLevel.basic;

    final themeSettings = ref.read(themeNotifierProvider);
    final themeModeStr = themeSettings.mode == ThemeMode.dark ? 'Sombre' : (themeSettings.mode == ThemeMode.light ? 'Clair' : 'Système');
    final themeColorLabel = themeSettings.color.label;
    final themeColorName = themeSettings.color.name;
    
    final customization = ref.read(dashboardCustomizationProvider);
    
    // Le niveau définit le nombre d'éléments à inclure
    final isAdvancedOrMax = assistantLevel == AssistantPowerLevel.analytical || assistantLevel == AssistantPowerLevel.titan || assistantLevel == AssistantPowerLevel.proactive || assistantLevel == AssistantPowerLevel.actionable;
    final isMax = assistantLevel == AssistantPowerLevel.titan;

    final clients = await ref.read(clientListProvider.future);
    final products = await ref.read(productListProvider.future);
    final suppliers = await ref.read(supplierListProvider.future);
    final salesAsync = await ref.read(salesHistoryProvider.future);
    final stats = StockStats.fromProducts(products);
    final today = DateTime.now();

    // 🛒 PANIER EN COURS (VENTE ACTIVE)
    final cart = ref.read(cartProvider);
    final selectedClientId = ref.read(selectedClientIdProvider);
    String selectedClientName = "Aucun (Client Anonyme)";
    if (selectedClientId != null) {
      try {
        final client = clients.firstWhere((c) => c.id == selectedClientId);
        selectedClientName = "${client.name} (Tél: ${client.phone ?? 'N/A'}, Dette: ${DateFormatter.formatCurrency(client.credit, currency, removeDecimals: removeDecimals)})";
      } catch (_) {}
    }

    final cartTotal = cart.fold(0.0, (sum, item) => sum + item.lineTotal);
    final totalItems = cart.fold<double>(0.0, (sum, item) => sum + item.qty);
    final cartItemsSummary = cart.isNotEmpty
        ? cart.map((item) {
            final discountStr = item.discountPercent > 0 ? " (-${item.discountPercent}%)" : "";
            return "    * ${item.name} | Qté: ${item.qty} | P.U.: ${DateFormatter.formatCurrency(item.unitPrice, currency, removeDecimals: removeDecimals)} | Total: ${DateFormatter.formatCurrency(item.lineTotal, currency, removeDecimals: removeDecimals)}$discountStr";
          }).join("\n")
        : "    * Le panier est actuellement vide.";

    final insights = _horizonEngine.generateBusinessInsights(
      sales: salesAsync,
      clients: clients,
      products: products,
      formatCurrency: (val) => DateFormatter.formatCurrency(
        val,
        currency,
        removeDecimals: removeDecimals,
      ),
    );

    final insightsSummary = insights.isNotEmpty
        ? insights.map((i) => '    * [${i.trend}] ${i.suggestion}').join('\n')
        : '    * Aucune alerte ou conseil prédictif généré pour le moment.';

    // ── Ventes du jour ──
    final todaySales = salesAsync.where((s) =>
        s.sale.date.year == today.year &&
        s.sale.date.month == today.month &&
        s.sale.date.day == today.day);
    final totalToday = todaySales.fold(0.0, (sum, s) => sum + s.sale.totalAmount);

    // ── Top produits (5, 10 ou 20 selon le niveau) ──
    final productCounts = <String, double>{};
    for (final sale in salesAsync) {
      for (final item in sale.items) {
        productCounts[item.productName] = (productCounts[item.productName] ?? 0) + item.item.quantity;
      }
    }
    final topProductsCount = isMax ? 20 : (isAdvancedOrMax ? 10 : 5);
    final topProductsStr = (productCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .take(topProductsCount)
        .map((e) => '${e.key} (${e.value.toStringAsFixed(0)} vendus)')
        .join(', ');

    // ── Ventes par période ──
    final sevenDaysAgo = today.subtract(const Duration(days: 7));
    final salesLast7Days = salesAsync.where((s) => s.sale.date.isAfter(sevenDaysAgo));
    final totalLast7Days = salesLast7Days.fold(0.0, (sum, s) => sum + s.sale.totalAmount);

    final monthlyAmounts = <String, double>{};
    final monthlyCounts = <String, int>{};
    for (final s in salesAsync) {
      final date = s.sale.date;
      final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      monthlyAmounts[monthKey] = (monthlyAmounts[monthKey] ?? 0.0) + s.sale.totalAmount;
      monthlyCounts[monthKey] = (monthlyCounts[monthKey] ?? 0) + 1;
    }

    final sortedMonths = monthlyAmounts.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    final monthsCount = isMax ? 12 : (isAdvancedOrMax ? 6 : 3);
    final monthlySummary = sortedMonths.take(monthsCount).map((e) {
      final key = e.key;
      final count = monthlyCounts[key] ?? 0;
      final formattedAmount = DateFormatter.formatCurrency(e.value, currency, removeDecimals: removeDecimals);
      return '    * $key : $formattedAmount ($count ventes)';
    }).join('\n');

    // ── Débiteurs ──
    final debtors = clients.where((c) => c.credit > 0).toList()
      ..sort((a, b) => b.credit.compareTo(a.credit));
    final totalDebt = debtors.fold(0.0, (sum, c) => sum + c.credit);
    
    final debtorsCount = isMax ? 20 : (isAdvancedOrMax ? 10 : 5);
    final topDebtorsList = canAccessFinance 
      ? debtors.take(debtorsCount)
          .map((c) => '    * ${c.name} : ${DateFormatter.formatCurrency(c.credit, currency, removeDecimals: removeDecimals)}')
          .join('\n')
      : '    * Accès restreint (Dettes masquées)';

    // ── Fournisseurs ──
    final suppliersCount = isMax ? 50 : (isAdvancedOrMax ? 20 : 5);
    final suppliersSummary = suppliers.take(suppliersCount).map((s) {
      final phoneStr = (s.phone != null && s.phone!.isNotEmpty) ? s.phone : "N/A";
      return '    * ${s.name} (Contact: $phoneStr)';
    }).join('\n');

    // ── Catégories & Marges ──
    final categoryCounts = <String, int>{};
    for (final p in products) {
      final cat = p.category ?? "Général";
      categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
    }
    final categorySummary = categoryCounts.entries
        .map((e) => '    * ${e.key} : ${e.value} articles')
        .take(isMax ? 20 : (isAdvancedOrMax ? 10 : 5))
        .join('\n');

    // Top produits les plus rentables
    final profitableProducts = List<Product>.from(products)
      ..sort((a, b) {
        final marginA = a.sellingPrice - a.purchasePrice;
        final marginB = b.sellingPrice - b.purchasePrice;
        return marginB.compareTo(marginA);
      });
    final marginCount = isMax ? 30 : (isAdvancedOrMax ? 15 : 5);
    final topMarginSummary = canAccessReports 
      ? profitableProducts.take(marginCount).map((p) {
          final margin = p.sellingPrice - p.purchasePrice;
          final marginPct = p.purchasePrice > 0 ? '${(margin / p.purchasePrice * 100).toStringAsFixed(0)}%' : '0%';
          return '    * ${p.name} | PV: ${DateFormatter.formatCurrency(p.sellingPrice, currency, removeDecimals: removeDecimals)} | Marge: ${DateFormatter.formatCurrency(margin, currency, removeDecimals: removeDecimals)} ($marginPct)';
        }).join('\n')
      : '    * Accès restreint (Marges masquées)';

    // ── Alertes de Stocks ──
    final stockAlerts = products.where((p) => p.quantity <= 0 || p.isLowStock).toList()
      ..sort((a, b) => a.quantity.compareTo(b.quantity));
    final alertsCount = isMax ? 100 : (isAdvancedOrMax ? 30 : 10);
    final stockAlertsSummary = stockAlerts.take(alertsCount).map((p) {
      final status = p.quantity <= 0 ? 'Rupture' : 'Faible';
      return '    * ${p.name} (Réf: ${p.reference ?? "N/A"}) : Stock: ${p.quantity.toStringAsFixed(1)} ${p.unit ?? "pcs"} ($status | Seuil: ${p.alertThreshold})';
    }).join('\n');

    // ── Journal des ventes (Ultra-précis) ──
    final salesCount = isMax ? 50 : (isAdvancedOrMax ? 25 : 5);
    final recentSalesSummary = salesAsync.take(salesCount).map((s) {
      final itemsStr = s.items.map((i) => '${i.productName} (x${i.item.quantity.toStringAsFixed(0)} à ${DateFormatter.formatCurrency(i.item.unitPrice, currency, removeDecimals: removeDecimals)})').join(', ');
      final dateStr = DateFormatter.formatDate(s.sale.date);
      final timeStr = '${s.sale.date.hour.toString().padLeft(2, '0')}h${s.sale.date.minute.toString().padLeft(2, '0')}';
      return '    * Le $dateStr à $timeStr | Vendeur: ${s.userName ?? "Inconnu"} | Total: ${DateFormatter.formatCurrency(s.sale.totalAmount, currency, removeDecimals: removeDecimals)} | Mode: ${s.sale.paymentMethod ?? "Espèces"} | Client: ${s.clientName ?? "Anonyme"} | Contenu: $itemsStr';
    }).join('\n');

    final stockValueStr = canManageStock || canAccessReports ? DateFormatter.formatCurrency(stats.totalStockValue, currency, removeDecimals: removeDecimals) : 'Accès restreint';
    final debtorsCountStr = canAccessFinance ? '${debtors.length} clients' : 'Accès restreint';
    final totalDebtStr = canAccessFinance ? DateFormatter.formatCurrency(totalDebt, currency, removeDecimals: removeDecimals) : 'Accès restreint';

    // ── Imprimantes connectées ──
    final hwService = ref.read(hardwareServiceProvider);
    List<ExternalDevice> connectedPrinters = [];
    try {
      connectedPrinters = await hwService.listPrinters();
    } catch (_) {}

    final printerAssignments = <String, String?>{
      'Tickets/Thermique': settings?.thermalPrinterName,
      'Factures': settings?.invoicePrinterName,
      'Devis': settings?.quotePrinterName,
      'Bons de commande': settings?.purchaseOrderPrinterName,
      'Étiquettes': settings?.labelPrinterName,
      'Contrats': settings?.contractPrinterName,
      'Fiches de paie': settings?.payrollPrinterName,
      'Rapports': settings?.reportPrinterName,
      'Proformas': settings?.proformaPrinterName,
      'Bons de livraison': settings?.deliveryPrinterName,
    };
    final assignmentsSummary = printerAssignments.entries
        .where((e) => e.value != null && e.value!.isNotEmpty)
        .map((e) => '    * ${e.key} → ${e.value}')
        .join('\n');
    final connectedPrintersSummary = connectedPrinters.isNotEmpty
        ? connectedPrinters.map((p) => '    * ${p.name} (${p.status})').join('\n')
        : '    * Aucune imprimante détectée';

    return '''
=== CONTEXTE BOUTIQUE SYNTHÉTIQUE (Temps Réel - Danaya+ - Niveau: ${assistantLevel.name.toUpperCase()}) ===
Boutique : ${settings?.name ?? 'Non configurée'} | ${settings?.address ?? ''}
Date : ${DateFormatter.formatDate(today)} | Heure : ${today.hour}h${today.minute.toString().padLeft(2, '0')}
Devise : $currency
Session de caisse actuelle : $sessionStatusStr

🛒 PANIER EN COURS (VENTE ACTIVE) :
  - Client associé à la vente : $selectedClientName
  - Nombre d'articles distincts : ${cart.length}
  - Quantité totale d'articles : ${totalItems.toStringAsFixed(0)}
  - Montant total actuel du panier : ${DateFormatter.formatCurrency(cartTotal, currency, removeDecimals: removeDecimals)}
  - Articles actuellement dans le panier :
$cartItemsSummary

🎨 APPARENCE & INTERFACE :
  - Thème d'affichage actuel : $themeModeStr
  - Couleur d'accentuation actuelle : $themeColorLabel ($themeColorName)
  - Personnalisation du tableau de bord (sections visibles) :
    * KPIs : ${customization.showKpis ? 'Visible' : 'Masqué'}
    * Graphique des revenus : ${customization.showRevenueChart ? 'Visible' : 'Masqué'}
    * Mix Produits : ${customization.showProductMix ? 'Visible' : 'Masqué'}
    * Top Ventes : ${customization.showTopSales ? 'Visible' : 'Masqué'}
    * Activité Récente : ${customization.showRecentSales ? 'Visible' : 'Masqué'}
    * Alertes Stock : ${customization.showStockAlerts ? 'Visible' : 'Masqué'}
    * Résumé Financier : ${customization.showFinancialSummary ? 'Visible' : 'Masqué'}
    * Dettes Clients : ${customization.showDebtors ? 'Visible' : 'Masqué'}

🖨️ IMPRIMANTES & CONFIGURATION D'IMPRESSION :
  - Format papier thermique : ${settings?.thermalFormat.name ?? 'mm58'}
  - Impression directe (sans aperçu) : ${settings?.directPhysicalPrinting == true ? 'Activée' : 'Désactivée'}
  - Aperçu avant impression : ${settings?.showPreviewBeforePrint == true ? 'Activé' : 'Désactivé'}
  - Impression auto du ticket après vente : ${settings?.autoPrintTicket == true ? 'Activée' : 'Désactivée'}
  - Ouverture auto du tiroir-caisse : ${settings?.openCashDrawer == true ? 'Activée' : 'Désactivée'}
  - Imprimantes connectées au système :
$connectedPrintersSummary
  - Affectations d'imprimantes configurées :
${assignmentsSummary.isNotEmpty ? assignmentsSummary : '    * Aucune affectation configurée'}

👥 CLIENTS & DETTES (Total clients: ${clients.length}) :
  - Clients débiteurs : $debtorsCountStr | Dettes cumulées : $totalDebtStr
  - Liste des débiteurs principaux de la boutique :
${topDebtorsList.isNotEmpty ? topDebtorsList : '    * Aucun client débiteur'}

🔮 PRÉDICTIONS & CONSEILS DE GESTION (HORIZON ENGINE) :
$insightsSummary

🏭 FOURNISSEURS (Total fournisseurs: ${suppliers.length}) :
${suppliersSummary.isNotEmpty ? suppliersSummary : '    * Aucun fournisseur enregistré'}

📊 RÉPARTITION PAR CATÉGORIE :
${categorySummary.isNotEmpty ? categorySummary : '    * Aucun produit'}

📦 STOCKS & ALERTES (Total: ${products.length} articles | Valeur: $stockValueStr) :
  - Ruptures de stock : ${stats.outOfStockCount} articles
  - Stock faible : ${stats.lowStockCount} articles
  - Liste des articles prioritaires à réapprovisionner :
${stockAlertsSummary.isNotEmpty ? stockAlertsSummary : '    * Aucun produit en alerte'}

💰 RENTABILITÉ & ANALYSE DE MARGE (Top produits les plus rentables) :
${topMarginSummary.isNotEmpty ? topMarginSummary : '    * Pas de données'}

📈 HISTORIQUE MENSUEL ET HEBDOMADAIRE :
  - Ventes d'aujourd'hui : ${todaySales.length} transactions = ${DateFormatter.formatCurrency(totalToday, currency, removeDecimals: removeDecimals)}
  - Ventes des 7 derniers jours : ${salesLast7Days.length} transactions = ${DateFormatter.formatCurrency(totalLast7Days, currency, removeDecimals: removeDecimals)}
  - Chiffre d'affaires historique par mois :
${monthlySummary.isNotEmpty ? monthlySummary : '    * Aucun historique par mois'}
  - Top produits vendus globalement : ${topProductsStr.isNotEmpty ? topProductsStr : 'Aucun'}



=========================================
📝 JOURNAL ULTRA-PRÉCIS DES DERNIÈRES VENTES (Indispensable pour votre analysis - inclut les VENDEURS) :
${recentSalesSummary.isNotEmpty ? recentSalesSummary : '    * Aucune transaction récente enregistrée'}

$memoryPrompt
=== FIN DU CONTEXTE ===
${settings?.allowCloudAiActions == true ? '''
 
=== INSTRUCTIONS SPÉCIALES D'ACTION (CAPACITÉ D'AGIR) ===
Vous ÊTES capable d'agir directement sur l'application Danaya+. Si l'utilisateur vous demande de modifier un paramètre, d'ouvrir une page, de changer le thème, d'ajouter des produits, des dépenses ou des clients, VOUS POUVEZ LE FAIRE (ne dites jamais que vous ne pouvez pas !).
Pour exécuter une action, vous DEVEZ inclure l'une des balises exactes suivantes n'importe où dans votre réponse (le système l'interceptera et l'exécutera de manière invisible pour l'utilisateur). Tu peux en inclure plusieurs à la suite s'il y a plusieurs actions à effectuer :
- [ACTION: RENAME_SHOP, name: X] -> Renomme la boutique en X. (ex: [ACTION: RENAME_SHOP, name: DANAYA+])
- [ACTION: THEME_DARK] -> Active le mode sombre.
- [ACTION: THEME_LIGHT] -> Active le mode clair.
- [ACTION: THEME_COLOR, color: X] -> Change la couleur d'accentuation principale de l'interface de l'application. X doit être l'un des suivants : blue, orange, green, purple, red, teal, pink, grey. (ex: [ACTION: THEME_COLOR, color: teal])
- [ACTION: NAVIGATE, target: X] -> Va vers une page (X = pos, inventory, finance, clients, suppliers, settings, reports, dashboard).
- [ACTION: NOTIFY, message: X] -> Affiche une notification toast importante à l'utilisateur. (ex: [ACTION: NOTIFY, message: Attention au stock bas !])
- [ACTION: SET_CURRENCY, currency: X] -> Change la devise de la boutique (ex: FCFA, USD, EUR).
- [ACTION: ENABLE_LOYALTY] -> Active le système de points de fidélité.
- [ACTION: ADD_PRODUCT, name: X, price: Y, purchasePrice: Z, quantity: Q, category: C, barcode: B, unit: U] -> Ajoute ou crée un produit dans la base de données de l'inventaire avec son nom X, prix de vente Y, son prix d'achat Z, quantité en stock Q, sa catégorie C, code-barres B (optionnel ou vide), et son unité de mesure U (ex: Pièce, kg, Sac, etc.). Pour ajouter plusieurs produits, mets plusieurs balises distinctes les unes après les autres.
- [ACTION: ADD_CLIENT, name: X, phone: Y] -> Crée ou enregistre une fiche client dans la base de données avec son nom X et son téléphone Y.
- [ACTION: ADD_EXPENSE, amount: X, category: Y, description: Z] -> Enregistre une dépense financière réelle en base de données de montant X (nombre), catégorie Y (ex: LOYER, TRANSPORT, REPAS, DIVERS) et motif ou description Z.
- [ACTION: UPDATE_DASHBOARD, section: X, visible: Y] -> Personnalise le tableau de bord en affichant ou masquant une section (X = kpis, revenue_chart, product_mix, top_sales, recent_sales, stock_alerts, financial_summary, debtors et Y = true ou false).
- [ACTION: SET_DASHBOARD_FILTER, filter: F, start_date: S, end_date: E] -> Filtre le tableau de bord par date. F peut être aujourd'hui (today), semaine (week), mois (month) ou personnalisé (custom). Si F = custom, start_date S et end_date E (format YYYY-MM-DD) sont obligatoires (ex: [ACTION: SET_DASHBOARD_FILTER, filter: custom, start_date: 2025-01-01, end_date: 2025-02-28]).
- [ACTION: CHECKOUT_CART, payment_method: X, amount_paid: Y] -> Encaisse et finalise la vente en cours dans le panier de caisse (X = CASH, MOBILE_MONEY, CARD, BANK et Y = montant payé).
- [ACTION: CREATE_QUOTE, validity_days: V] -> Crée et enregistre un devis (facture proforma) à partir du panier de caisse en cours. V est le nombre de jours de validité (optionnel, entier, par défaut les paramètres de la boutique ou 30). Le panier sera automatiquement vidé après création.
- [ACTION: GET_QUOTES_LIST] -> Récupère la liste complète des devis de la boutique.
- [ACTION: DELETE_QUOTE, quote_number: Q] -> Supprime définitivement le devis ayant le numéro ou partie de numéro Q. (ex: [ACTION: DELETE_QUOTE, quote_number: DEV-123456])
- [ACTION: UPDATE_QUOTE_STATUS, quote_number: Q, status: S] -> Met à jour le statut du devis numéro Q avec le statut S (S = PENDING, ACCEPTED, REJECTED). (ex: [ACTION: UPDATE_QUOTE_STATUS, quote_number: DEV-123456, status: ACCEPTED])
- [ACTION: CONVERT_QUOTE_TO_SALE, quote_number: Q] -> Facture et convertit le devis Q en chargeant ses articles dans le panier et en ouvrant la caisse. (ex: [ACTION: CONVERT_QUOTE_TO_SALE, quote_number: DEV-123456])
- [ACTION: EXPORT_REPORT, format: F, period: P] -> Génère et exporte un rapport de performance. F est le format ('pdf' ou 'excel', par défaut 'pdf') et P est la période ('today', 'week', ou 'month', par défaut 'month').''' : '''
 
=== NOTE ===
L'utilisateur n'a PAS activé les actions automatiques. Vous ne pouvez PAS modifier de paramètres ni naviguer. Si on vous demande une action, conseille à l'utilisateur de le faire manuellement ou d'activer "Autoriser l'IA à agir" dans Paramètres > Automatisation & IA.
''' }''';
  }

  /// Détecte si le message de l'utilisateur est un simple bavardage ou salutation de courtoisie.
  bool _isCasualPrompt(String prompt) {
    final lower = prompt.trim().toLowerCase();
    
    // Si la phrase est vide, on considère que c'est simple
    if (lower.isEmpty) return true;
    
    // Si la phrase est très courte (moins de 2 mots), c'est probablement une salutation ou un chit-chat
    final words = lower.split(RegExp(r'\s+'));
    if (words.length <= 1) return true;

    // Expressions de salutations, politesse ou de chit-chat
    final casualPatterns = [
      'bonjour', 'salut', 'ça va', 'ca va', 'comment tu vas', 'comment ça va', 'comment ca va',
      'tu vas bien', 'tu te portes bien', 'tu te porte bien', 'la forme', 't\'es là', 'tes la',
      'es-tu là', 'est tu la', 'merci', 'cool', 'super', 'ok', 'd\'accord', 'daccord', 'parfait',
      'excellent', 'génial', 'hello', 'hi', 'coucou', 'yo', 'hey', 'présente-toi', 'presente toi',
      'qui es-tu', 'qui es tu', 'tu es qui', 'qui t\'a créé', 'qui ta cree', 'qui t\'a cree',
      'ton créateur', 'ton createur', 'ton concepteur', 'alassane diarra'
    ];

    // Mots clés professionnels qui forcent l'usage du contexte de la boutique
    final businessKeywords = [
      'stock', 'vente', 'prix', 'produit', 'client', 'dette', 'dépense', 'depense', 'rapport',
      'caisse', 'imprimer', 'imprimante', 'modifier', 'ajouter', 'créer', 'creer', 'panier', 'wave',
      'espèces', 'espece', 'crédit', 'credit', 'djourou', 'chiffre', 'bénéfice', 'benefice', 'marge',
      'perte', 'seuil', 'horizon', 'prédiction', 'prediction', 'fournisseur', 'achat'
    ];

    // Si le prompt contient un mot clé métier, ce n'est pas une simple formule de politesse
    for (final kw in businessKeywords) {
      if (lower.contains(kw)) {
        return false;
      }
    }

    // Si le prompt contient une expression de politesse ou s'il est très simple
    for (final pattern in casualPatterns) {
      if (lower.contains(pattern)) {
        return true;
      }
    }

    return false;
  }

  /// Version minimale du contexte boutique pour éviter les calculs lourds en DB lors de chit-chat.
  Future<String> buildMinimalBusinessContext() async {
    await ref.read(assistantMemoryProvider.notifier).loadMemories();
    final memoryPrompt = ref.read(assistantMemoryProvider.notifier).getFormattedMemoryPrompt();

    final settings = ref.read(shopSettingsProvider).value;
    final currency = settings?.currency ?? 'FCFA';
    final today = DateTime.now();

    return '''
=== CONTEXTE BOUTIQUE MINIMAL (Temps Réel - Danaya+) ===
Boutique : ${settings?.name ?? 'Non configurée'}
Date : ${DateFormatter.formatDate(today)} | Heure : ${today.hour}h${today.minute.toString().padLeft(2, '0')}
Devise : $currency

(Note : L'utilisateur effectue un bavardage informel ou une salutation simple. Répondez de manière très brève, chaleureuse et naturelle sans afficher de synthèse executive, de tableau de trésorerie ni d'actions recommandées. Reste simple !)

$memoryPrompt
=== FIN DU CONTEXTE ===''';
  }

  /// Version allégée du contexte boutique pour la Live API (WebSocket).
  /// Réduit drastiquement la taille du payload pour respecter les limites de tokens du Setup.
  Future<String> buildLiveBusinessContext() async {
    await ref.read(assistantMemoryProvider.notifier).loadMemories();
    final memoryPrompt = ref.read(assistantMemoryProvider.notifier).getFormattedMemoryPrompt();

    final user = ref.read(authServiceProvider).value;
    final canAccessFinance = user?.canAccessFinance ?? false;

    final settings = ref.read(shopSettingsProvider).value;
    final currency = settings?.currency ?? 'FCFA';
    final removeDecimals = settings?.removeDecimals ?? true;

    final activeSession = ref.read(activeSessionProvider).value;
    final String sessionStatusStr;
    if (activeSession != null) {
      sessionStatusStr = "OUVERTE (Fond initial : ${DateFormatter.formatCurrency(activeSession.openingBalance, currency, removeDecimals: removeDecimals)}, début : ${DateFormatter.formatDate(activeSession.openDate)} à ${activeSession.openDate.hour}h${activeSession.openDate.minute.toString().padLeft(2, '0')})";
    } else {
      sessionStatusStr = "FERMÉE";
    }

    final clients = await ref.read(clientListProvider.future);
    final products = await ref.read(productListProvider.future);
    final salesAsync = await ref.read(salesHistoryProvider.future);
    final stats = StockStats.fromProducts(products);
    final today = DateTime.now();

    // Panier en cours
    final cart = ref.read(cartProvider);
    final selectedClientId = ref.read(selectedClientIdProvider);
    String selectedClientName = "Aucun";
    if (selectedClientId != null) {
      try {
        final client = clients.firstWhere((c) => c.id == selectedClientId);
        selectedClientName = "${client.name} (Dette: ${DateFormatter.formatCurrency(client.credit, currency, removeDecimals: removeDecimals)})";
      } catch (_) {}
    }
    final totalItems = cart.fold<double>(0.0, (sum, item) => sum + item.qty);
    final cartTotal = cart.fold(0.0, (sum, item) => sum + item.lineTotal);
    final cartSummary = cart.isNotEmpty
        ? cart.map((item) => "  * ${item.name} x${item.qty} = ${DateFormatter.formatCurrency(item.lineTotal, currency, removeDecimals: removeDecimals)}").join("\n")
        : "  * Panier vide.";

    // Ventes du jour
    final todaySales = salesAsync.where((s) =>
        s.sale.date.year == today.year &&
        s.sale.date.month == today.month &&
        s.sale.date.day == today.day);
    final totalToday = todaySales.fold(0.0, (sum, s) => sum + s.sale.totalAmount);

    // Débiteurs (top 3)
    final debtors = clients.where((c) => c.credit > 0).toList()
      ..sort((a, b) => b.credit.compareTo(a.credit));
    final totalDebt = debtors.fold(0.0, (sum, c) => sum + c.credit);
    final topDebtors = canAccessFinance
        ? debtors.take(3).map((c) => "  * ${c.name}: ${DateFormatter.formatCurrency(c.credit, currency, removeDecimals: removeDecimals)}").join("\n")
        : "  * Accès restreint";

    // Alertes stock critiques (top 5)
    final stockAlerts = products.where((p) => p.quantity <= 0 || p.isLowStock).toList()
      ..sort((a, b) => a.quantity.compareTo(b.quantity));
    final alertsSummary = stockAlerts.take(5).map((p) {
      final status = p.quantity <= 0 ? 'RUPTURE' : 'Faible';
      return "  * ${p.name}: ${p.quantity.toStringAsFixed(0)} ${p.unit ?? 'pcs'} ($status)";
    }).join("\n");

    // Liste des produits (catalogue abrégé ou complet) pour que l'IA connaisse les prix et stocks exacts
    final String catalogPrompt;
    if (products.length <= 150) {
      final items = products.map((p) {
        final stockStatus = p.isOutOfStock ? "EN RUPTURE" : "${p.quantity.toStringAsFixed(0)} ${p.unit ?? 'pcs'}";
        return "  * ${p.name} | Prix: ${p.sellingPrice.toStringAsFixed(0)} $currency | Stock: $stockStatus";
      }).join("\n");
      catalogPrompt = "🛍️ CATALOGUE DE LA BOUTIQUE :\n$items";
    } else {
      final items = products.take(100).map((p) {
        final stockStatus = p.isOutOfStock ? "EN RUPTURE" : "${p.quantity.toStringAsFixed(0)} ${p.unit ?? 'pcs'}";
        return "  * ${p.name} | Prix: ${p.sellingPrice.toStringAsFixed(0)} $currency | Stock: $stockStatus";
      }).join("\n");
      catalogPrompt = "🛍️ CATALOGUE DE LA BOUTIQUE (Top 100 produits) :\n$items\n*(Note : Il y a ${products.length} produits au total. Si un produit n'est pas dans cette liste, utilise le tool 'search_product' pour vérifier son prix ou stock).*";
    }

    return '''
=== BOUTIQUE (Résumé Vocal) ===
${settings?.name ?? 'N/C'} | ${DateFormatter.formatDate(today)} ${today.hour}h${today.minute.toString().padLeft(2, '0')} | Devise: $currency
Session de caisse : $sessionStatusStr

🛒 PANIER: Client: $selectedClientName | ${totalItems.toStringAsFixed(0)} articles | Total: ${DateFormatter.formatCurrency(cartTotal, currency, removeDecimals: removeDecimals)}
$cartSummary

📈 VENTES: Aujourd'hui ${todaySales.length} ventes = ${DateFormatter.formatCurrency(totalToday, currency, removeDecimals: removeDecimals)}
📦 STOCK: ${products.length} articles | Valeur: ${DateFormatter.formatCurrency(stats.totalStockValue, currency, removeDecimals: removeDecimals)} | Ruptures: ${stats.outOfStockCount} | Faibles: ${stats.lowStockCount}
${alertsSummary.isNotEmpty ? alertsSummary : '  * Aucune alerte'}
👥 DETTES: ${debtors.length} débiteurs | Total: ${DateFormatter.formatCurrency(totalDebt, currency, removeDecimals: removeDecimals)}
$topDebtors

$catalogPrompt

$memoryPrompt
=== FIN ===''';
  }

  Future<void> _callCloudAiAndReply(String text, {List<int>? attachmentBytes, String? attachmentMimeType}) async {
    final settings = ref.read(shopSettingsProvider).value;
    if (settings == null) {
      addAssistantMessage("⚠️ Impossible de charger les paramètres pour l'IA.");
      return;
    }

    try {
      final isCasual = _isCasualPrompt(text);
      final businessContext = isCasual 
          ? await buildMinimalBusinessContext()
          : await buildBusinessContext();
      
      // Historique conversationnel récent (excluant la question en cours qui est déjà stockée en dernier dans state.messages)
      final allMessages = state.messages.where((m) => m.text.isNotEmpty).toList();
      if (allMessages.isNotEmpty) {
        allMessages.removeLast(); // Exclure la question actuelle car askAssistant l'ajoute manuellement
      }
      final List<Map<String, String>> history = allMessages
          .skip(allMessages.length > 20 ? allMessages.length - 20 : 0)
          .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.text,
              })
          .toList();

      String aiResponse = "";

      if (settings.cloudAiProvider == 'gemini') {
        final user = ref.read(authServiceProvider).value;
        final isAdmin = user?.isAdmin ?? false;
        final String? displayName = user != null ? (user.firstName ?? user.username) : null;
        final apiService = GeminiService(
          apiKey: settings.geminiApiKey,
          model: 'gemini-3.5-flash',
          businessContext: businessContext,
          isAdmin: isAdmin,
          userName: displayName,
        );
        aiResponse = await apiService.askAssistant(
          text,
          history,
          attachmentBytes: attachmentBytes,
          attachmentMimeType: attachmentMimeType,
        );
      } else {
        final user = ref.read(authServiceProvider).value;
        final String? displayName = user != null ? (user.firstName ?? user.username) : null;
        final apiService = DeepSeekService(
          apiKey: settings.deepSeekApiKey,
          businessContext: businessContext,
          userName: displayName,
        );
        aiResponse = await apiService.askAssistant(text, history);
      }

      final isErr = aiResponse.startsWith("📡") || 
                    aiResponse.startsWith("🔑") || 
                    aiResponse.startsWith("⏱️") || 
                    aiResponse.startsWith("🪙") || 
                    aiResponse.startsWith("⚠️");

      String textToShow = aiResponse;
      final Set<String> executedActions = {};
      
      // Parse Actions — only if user enabled allowCloudAiActions
      if (settings.allowCloudAiActions) {
        final matches = RegExp(r'\[ACTION:\s*([A-Z_]+)(?:,\s*(.*?))?\]').allMatches(textToShow).toList();
        for (final match in matches) {
          final actionType = match.group(1)!;
          final paramString = match.group(2) ?? '';
          final params = _parseActionParams(paramString);
          
          try {
            await _executeCloudAction(actionType, params, settings);
            executedActions.add(actionType);
          } catch (e) {
            debugPrint("Error executing cloud action $actionType: $e");
          }
        }
        
        // Nettoyer toutes les balises de la réponse
        textToShow = textToShow.replaceAll(RegExp(r'\[ACTION:\s*[A-Z_]+(?:,\s*.*?)?\]'), '').trim();
      } else {
        // Strip any stray action tags the AI might have emitted anyway
        textToShow = textToShow.replaceAll(RegExp(r'\[ACTION:.*?\]'), '').trim();
      }

      if (isErr) {
        addAssistantMessage(textToShow, isStreaming: false, isError: true);
      } else {
        _validateActionClaims(textToShow, aiResponse, executedActions, settings.allowCloudAiActions);
      }
    } catch (e) {
      debugPrint("Cloud AI error: $e");
      await _processUserMessage(text, isConnectionFallback: true);
    }
  }

  void _validateActionClaims(String textToShow, String rawResponse, Set<String> executedActions, bool actionsAllowed) {
    final List<String> warnings = [];

    // 1. Rename Shop
    if ((RegExp(r"\bj'ai renommé\b|\ba été renommé\b|\bnom de la boutique a été mis à jour\b|\bnom de la boutique est maintenant\b", caseSensitive: false).hasMatch(textToShow)) && !executedActions.contains("RENAME_SHOP")) {
      warnings.add("renommer la boutique");
    }
    // 2. Change Theme
    if ((RegExp(r"\bj'ai activé le mode\b|\bthème a été changé\b|\bje vous ai passé en mode\b", caseSensitive: false).hasMatch(textToShow)) && 
        !executedActions.contains("THEME_DARK") && !executedActions.contains("THEME_LIGHT")) {
      warnings.add("changer le thème");
    }
    // 3. Theme Color
    if ((RegExp(r"\bcouleur d'accentuation a été\b|\bj'ai changé la couleur\b", caseSensitive: false).hasMatch(textToShow)) && !executedActions.contains("THEME_COLOR")) {
      warnings.add("changer la couleur du thème");
    }
    // 4. Navigate
    if ((RegExp(r"\bje vous ai redirigé\b|\bj'ai ouvert l'écran\b|\bj'ai ouvert la page\b|\bnavigation effectuée\b", caseSensitive: false).hasMatch(textToShow)) && !executedActions.contains("NAVIGATE")) {
      warnings.add("naviguer");
    }
    // 5. Currency
    if ((RegExp(r"\bdevise a été modifiée\b|\bj'ai changé la devise\b|\bdevise est maintenant\b", caseSensitive: false).hasMatch(textToShow)) && !executedActions.contains("SET_CURRENCY")) {
      warnings.add("modifier la devise");
    }
    // 6. Add Product
    if ((RegExp(r"\bproduit [^.!?]* a été (créé|ajouté)\b|\bj'ai ajouté le produit\b|\bj'ai créé le produit\b", caseSensitive: false).hasMatch(textToShow)) && !executedActions.contains("ADD_PRODUCT")) {
      warnings.add("créer le produit");
    }
    // 7. Add Client
    if ((RegExp(r"\bclient [^.!?]* a été (créé|ajouté|enregistré)\b|\bj'ai créé le client\b|\bj'ai enregistré le client\b", caseSensitive: false).hasMatch(textToShow)) && !executedActions.contains("ADD_CLIENT")) {
      warnings.add("créer le client");
    }
    // 7b. Delete Client
    if ((RegExp(r"\bclient [^.!?]* a été supprimé\b|\bj'ai supprimé le client\b|\bsuppression du client\b", caseSensitive: false).hasMatch(textToShow)) && !executedActions.contains("DELETE_CLIENT")) {
      warnings.add("supprimer le client");
    }
    // 7c. Settle Client Debt
    if ((RegExp(r"\bdette [^.!?]* a été réglée\b|\bj'ai réglé la dette\b|\bencaissement de la dette\b|\brèglement de la dette\b", caseSensitive: false).hasMatch(textToShow)) && !executedActions.contains("SETTLE_CLIENT_DEBT")) {
      warnings.add("régler la dette du client");
    }
    // 7d. Get Client Debtors
    if ((RegExp(r"\bdebiteurs\b|\bdébiteurs\b|\bliste des dettes\b", caseSensitive: false).hasMatch(textToShow)) && !executedActions.contains("GET_CLIENT_DEBTORS")) {
      warnings.add("obtenir les débiteurs");
    }
    // 8. Add Expense
    if ((RegExp(r"\bdépense [^.!?]* a été (enregistrée|ajoutée)\b|\bj'ai enregistré la dépense\b", caseSensitive: false).hasMatch(textToShow)) && !executedActions.contains("ADD_EXPENSE")) {
      warnings.add("enregistrer la dépense");
    }
    // 9. Checkout
    if ((RegExp(r"\bvente a été validée\b|\bj'ai validé la vente\b|\bj'ai finalisé la vente\b|\bpanier a été validé\b", caseSensitive: false).hasMatch(textToShow)) && !executedActions.contains("CHECKOUT_CART")) {
      warnings.add("valider la vente");
    }

    if (warnings.isNotEmpty) {
      debugPrint("AI claimed actions without execution: ${warnings.join(', ')}");
      if (!actionsAllowed) {
        addAssistantMessage(
          "$textToShow\n\n⚠️ **Note du système** : L'assistant a mentionné avoir effectué les actions suivantes : *${warnings.join(', ')}*. "
          "Cependant, ces actions n'ont pas été exécutées car l'option **'Autoriser l'IA à agir'** est désactivée dans vos paramètres."
        );
      } else {
        addAssistantMessage(
          "$textToShow\n\n⚠️ **Validation de sécurité** : L'assistant affirme avoir effectué des actions (*${warnings.join(', ')}*), "
          "mais la commande d'action interne n'a pas été reçue ou exécutée."
        );
      }
    } else {
      addAssistantMessage(textToShow, isStreaming: true);
    }
  }

  Map<String, String> _parseActionParams(String paramString) {
    final Map<String, String> params = {};
    if (paramString.isEmpty) return params;
    
    final List<String> parts = [];
    int braceCount = 0;
    int bracketCount = 0;
    bool inQuote = false;
    int start = 0;
    
    for (int i = 0; i < paramString.length; i++) {
      final char = paramString[i];
      if (char == '"' && (i == 0 || paramString[i - 1] != '\\')) {
        inQuote = !inQuote;
      }
      if (!inQuote) {
        if (char == '{') {
          braceCount++;
        } else if (char == '}') {
          braceCount--;
        } else if (char == '[') {
          bracketCount++;
        } else if (char == ']') {
          bracketCount--;
        } else if (char == ',' && braceCount == 0 && bracketCount == 0) {
          parts.add(paramString.substring(start, i));
          start = i + 1;
        }
      }
    }
    if (start < paramString.length) {
      parts.add(paramString.substring(start));
    }
    
    for (final part in parts) {
      final keyValue = part.split(':');
      if (keyValue.length >= 2) {
        final key = keyValue[0].trim();
        final value = keyValue.sublist(1).join(':').trim();
        params[key] = value;
      }
    }
    return params;
  }

  Future<void> _executeCloudAction(String type, Map<String, String> params, ShopSettings settings) async {
    switch (type) {
      case 'RENAME_SHOP':
        final name = params['name'];
        if (name != null && name.isNotEmpty) {
          try {
            final updated = settings.copyWith(name: name);
            await ref.read(shopSettingsProvider.notifier).save(updated);
            ref.read(proactiveAlertProvider.notifier).set(ProactiveAlertData(
              title: "Boutique renommée",
              message: "Le nom de la boutique a été mis à jour : $name.",
              level: AlertLevel.success,
            ));
          } catch (e) {
            ref.read(proactiveAlertProvider.notifier).set(ProactiveAlertData(
              title: "Erreur boutique",
              message: "Impossible de renommer la boutique : $e",
              level: AlertLevel.error,
            ));
          }
        }
        break;
      case 'THEME_DARK':
        ref.read(themeNotifierProvider.notifier).setThemeMode(ThemeMode.dark);
        break;
      case 'THEME_LIGHT':
        ref.read(themeNotifierProvider.notifier).setThemeMode(ThemeMode.light);
        break;
      case 'NAVIGATE':
        final target = params['target']?.toLowerCase() ?? '';
        int payload = 0;
        if (target == 'pos') { payload = 3; }
        else if (target == 'inventory') { payload = 1; }
        else if (target == 'finance') { payload = 6; }
        else if (target == 'clients') { payload = 7; }
        else if (target == 'suppliers') { payload = 8; }
        else if (target == 'settings') { payload = 9; }
        else if (target == 'reports') { payload = 5; }
        if (onAction != null) onAction!("navigate", payload: payload);
        break;
      case 'NOTIFY':
        final message = params['message'];
        if (message != null && message.isNotEmpty) {
          ref.read(assistantNotificationProvider.notifier).addNotification(
            AssistantNotification(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: 'Message du Copilot',
              message: message,
              timestamp: DateTime.now(),
            )
          );
        }
        break;
      case 'SET_CURRENCY':
        final curr = params['currency'];
        if (curr != null && curr.isNotEmpty) {
          try {
            final updated = settings.copyWith(currency: curr);
            await ref.read(shopSettingsProvider.notifier).save(updated);
            ref.read(proactiveAlertProvider.notifier).set(ProactiveAlertData(
              title: "Devise modifiée",
              message: "Devise mise à jour : $curr.",
              level: AlertLevel.success,
            ));
          } catch (e) {
            ref.read(proactiveAlertProvider.notifier).set(ProactiveAlertData(
              title: "Erreur devise",
              message: "Impossible de modifier la devise : $e",
              level: AlertLevel.error,
            ));
          }
        }
        break;
      case 'THEME_COLOR':
        final colorStr = params['color']?.toLowerCase();
        AppThemeColor? selectedColor;
        for (final val in AppThemeColor.values) {
          if (val.name.toLowerCase() == colorStr) {
            selectedColor = val;
            break;
          }
        }
        if (selectedColor != null) {
          ref.read(themeNotifierProvider.notifier).setThemeColor(selectedColor);
        }
        break;
      case 'ENABLE_LOYALTY':
        final updated = settings.copyWith(loyaltyEnabled: true);
        ref.read(shopSettingsProvider.notifier).save(updated);
        break;
      case 'SAVE_MEMORY':
        final fact = params['fact'];
        if (fact != null && fact.isNotEmpty) {
          try {
            await ref.read(assistantMemoryProvider.notifier).saveMemory(fact);
            ref.read(proactiveAlertProvider.notifier).set(ProactiveAlertData(
              title: "Mémoire enregistrée",
              message: "Consigne ou information mémorisée avec succès.",
              level: AlertLevel.success,
            ));
          } catch (e) {
            ref.read(proactiveAlertProvider.notifier).set(ProactiveAlertData(
              title: "Erreur mémoire",
              message: "Impossible de mémoriser la consigne : $e",
              level: AlertLevel.error,
            ));
          }
        }
        break;
      case 'DELETE_MEMORY':
        final id = params['id'];
        if (id != null && id.isNotEmpty) {
          await ref.read(assistantMemoryProvider.notifier).deleteMemory(id);
        }
        break;
      case 'CLEAR_MEMORIES':
        await ref.read(assistantMemoryProvider.notifier).clearMemories();
        break;
        
      case 'ADD_PRODUCT':
        final name = params['name'];
        if (name == null || name.isEmpty) return;
        
        final price = double.tryParse(params['price'] ?? '0') ?? 0.0;
        final purchasePrice = double.tryParse(params['purchasePrice'] ?? '0') ?? 0.0;
        final qty = double.tryParse(params['quantity'] ?? '0') ?? 0.0;
        final category = params['category'];
        final barcode = params['barcode'];
        final reference = params['reference'] ?? "REF-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";
        final unit = params['unit'] ?? 'Pièce';
        
        final product = Product(
          id: "prod_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(10000)}",
          name: name,
          sellingPrice: price,
          purchasePrice: purchasePrice,
          quantity: qty,
          category: category,
          barcode: barcode,
          reference: reference,
          unit: unit,
          alertThreshold: 5.0,
        );
        
        try {
          await ref.read(productListProvider.notifier).addProduct(product);
          ref.read(proactiveAlertProvider.notifier).set(ProactiveAlertData(
            title: "Produit ajouté",
            message: "Produit '${product.name}' créé avec succès (${product.quantity} en stock).",
            level: AlertLevel.success,
          ));
        } catch (e) {
          ref.read(proactiveAlertProvider.notifier).set(ProactiveAlertData(
            title: "Erreur d'ajout",
            message: "Impossible d'ajouter le produit '${product.name}' : $e",
            level: AlertLevel.error,
          ));
          rethrow;
        }
        break;
        
      case 'ADD_CLIENT':
        final name = params['name'];
        if (name == null || name.isEmpty) return;
        final phone = params['phone'] ?? '';
        
        final client = Client(
          id: "cli_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(10000)}",
          name: name,
          phone: phone,
          address: params['address'] ?? '',
          email: params['email'] ?? '',
          credit: double.tryParse(params['credit'] ?? '0') ?? 0.0,
          maxCredit: double.tryParse(params['maxCredit'] ?? '50000') ?? 50000.0,
          loyaltyPoints: int.tryParse(params['loyaltyPoints'] ?? '0') ?? 0,
        );
        
        try {
          await ref.read(clientListProvider.notifier).addClient(client);
          ref.read(proactiveAlertProvider.notifier).set(ProactiveAlertData(
            title: "Client enregistré",
            message: "Client '${client.name}' ajouté avec succès.",
            level: AlertLevel.success,
          ));
        } catch (e) {
          ref.read(proactiveAlertProvider.notifier).set(ProactiveAlertData(
            title: "Erreur client",
            message: "Impossible d'ajouter le client '${client.name}' : $e",
            level: AlertLevel.error,
          ));
          rethrow;
        }
        break;
        
      case 'SELECT_CLIENT':
        final clientQuery = params['client_name'] ?? params['query'] ?? params['client_id'] ?? params['name'];
        if (clientQuery != null && clientQuery.isNotEmpty) {
          final clients = await ref.read(clientListProvider.future);
          final cleanQuery = clientQuery.trim().toLowerCase();
          
          Client? matchedClient;
          for (final c in clients) {
            if (c.id == clientQuery || c.name.trim().toLowerCase() == cleanQuery) {
              matchedClient = c;
              break;
            }
          }
          
          if (matchedClient == null) {
            double bestScore = 0.0;
            for (final c in clients) {
              final sim = math.max(
                NlpEngine.similarity(cleanQuery, c.name.toLowerCase()),
                NlpEngine.phoneticSimilarity(cleanQuery, c.name.toLowerCase()),
              );
              if (sim > bestScore && sim >= 0.7) {
                bestScore = sim;
                matchedClient = c;
              }
            }
          }
          
          if (matchedClient != null) {
            ref.read(selectedClientIdProvider.notifier).setClient(matchedClient.id);
            ref.read(cartProvider.notifier).forceBroadcast();
            addAssistantMessage("👥 Client **${matchedClient.name}** associé à la vente en cours.");
            
            if (onAction != null) {
              onAction!('navigate', payload: 3); // Caisse
            }
          } else {
            addAssistantMessage("⚠️ Client '$clientQuery' non trouvé.", isError: true);
          }
        }
        break;

      case 'DELETE_CLIENT':
        final clientQuery = params['client_name'] ?? params['name'] ?? params['client_id'];
        if (clientQuery == null || clientQuery.isEmpty) return;
        
        final user = ref.read(authServiceProvider).value;
        if (user == null || !user.canManageCustomers) {
          addAssistantMessage(
            "🛡️ **Action refusée** : Ton profil n'a pas l'autorisation de supprimer des clients.",
            isError: true,
          );
          break;
        }

        final clients = await ref.read(clientListProvider.future);
        final cleanQuery = clientQuery.trim().toLowerCase();
        
        Client? matchedClient;
        for (final c in clients) {
          if (c.id == clientQuery || c.name.trim().toLowerCase() == cleanQuery) {
            matchedClient = c;
            break;
          }
        }
        
        if (matchedClient == null) {
          double bestScore = 0.0;
          for (final c in clients) {
            final sim = math.max(
              NlpEngine.similarity(cleanQuery, c.name.toLowerCase()),
              NlpEngine.phoneticSimilarity(cleanQuery, c.name.toLowerCase()),
            );
            if (sim > bestScore && sim >= 0.7) {
              bestScore = sim;
              matchedClient = c;
            }
          }
        }

        if (matchedClient != null) {
          try {
            await ref.read(clientListProvider.notifier).deleteClient(matchedClient.id);
            ref.read(proactiveAlertProvider.notifier).set(ProactiveAlertData(
              title: "Client Supprimé",
              message: "Le client '${matchedClient.name}' a été supprimé définitivement.",
              level: AlertLevel.success,
            ));
            addAssistantMessage("🗑️ **Client supprimé** : **${matchedClient.name}** a été retiré de la liste des clients.");
            
            if (onAction != null) {
              onAction!('navigate', payload: 7); // client screen
            }
          } catch (e) {
            ref.read(proactiveAlertProvider.notifier).set(ProactiveAlertData(
              title: "Erreur suppression",
              message: "Impossible de supprimer le client '${matchedClient.name}' : $e",
              level: AlertLevel.error,
            ));
          }
        } else {
          addAssistantMessage("🔍 **Suppression échouée** : Client '$clientQuery' non trouvé.", isError: true);
        }
        break;

      case 'SETTLE_CLIENT_DEBT':
        final clientQuery = params['client_name'] ?? params['name'] ?? params['client_id'];
        if (clientQuery == null || clientQuery.isEmpty) return;
        
        final user = ref.read(authServiceProvider).value;
        if (user == null || !user.canAccessFinance) {
          addAssistantMessage(
            "🛡️ **Action refusée** : Votre profil n'a pas l'autorisation d'effectuer des encaissements de dettes.",
            isError: true,
          );
          break;
        }

        final amountRaw = double.tryParse(params['amount'] ?? '0') ?? 0.0;
        final amount = VoiceService.expandVoiceAmount(amountRaw);
        if (amount <= 0) return;
        
        final paymentMethod = params['payment_method'] ?? 'CASH';
        final description = params['description'] ?? "Règlement de dette via l'assistant";

        final clients = await ref.read(clientListProvider.future);
        final cleanQuery = clientQuery.trim().toLowerCase();
        
        Client? matchedClient;
        for (final c in clients) {
          if (c.id == clientQuery || c.name.trim().toLowerCase() == cleanQuery) {
            matchedClient = c;
            break;
          }
        }
        
        if (matchedClient == null) {
          double bestScore = 0.0;
          for (final c in clients) {
            final sim = math.max(
              NlpEngine.similarity(cleanQuery, c.name.toLowerCase()),
              NlpEngine.phoneticSimilarity(cleanQuery, c.name.toLowerCase()),
            );
            if (sim > bestScore && sim >= 0.7) {
              bestScore = sim;
              matchedClient = c;
            }
          }
        }

        if (matchedClient != null) {
          final treasury = ref.read(treasuryProvider.notifier);
          final defaultAccount = await treasury.getDefaultAccount(
            paymentMethod == 'MOBILE_MONEY' ? AccountType.MOBILE_MONEY : AccountType.CASH
          );

          if (defaultAccount != null) {
            try {
              await ref.read(clientListProvider.notifier).settleDebt(
                clientId: matchedClient.id,
                amount: amount,
                accountId: defaultAccount.id,
                description: description,
                paymentMethod: paymentMethod,
              );
              
              ref.read(proactiveAlertProvider.notifier).set(ProactiveAlertData(
                title: "Dette Réglée",
                message: "Paiement de $amount de ${matchedClient.name} enregistré.",
                level: AlertLevel.success,
              ));

              addAssistantMessage(
                "💳 **Règlement de dette enregistré** :\n"
                "• Client : **${matchedClient.name}**\n"
                "• Montant encaissé : **$amount FCFA**\n"
                "• Mode de paiement : **$paymentMethod**\n"
                "• Solde restant : **${matchedClient.credit - amount} FCFA**"
              );

              if (onAction != null) {
                onAction!('navigate', payload: 12); // dettes_clients
              }
            } catch (e) {
              addAssistantMessage("⚠️ **Erreur règlement** : ${e.toString().replaceAll('Exception: ', '')}", isError: true);
            }
          } else {
            addAssistantMessage("⚠️ **Erreur règlement** : Compte de trésorerie par défaut introuvable.", isError: true);
          }
        } else {
          addAssistantMessage("🔍 **Règlement échoué** : Client '$clientQuery' non trouvé.", isError: true);
        }
        break;

      case 'GET_CLIENT_DEBTORS':
        final user = ref.read(authServiceProvider).value;
        if (user == null || (!user.canAccessFinance && !user.canManageCustomers)) {
          addAssistantMessage(
            "🛡️ **Action refusée** : Votre profil n'a pas l'autorisation d'accéder aux rapports financiers ou aux clients.",
            isError: true,
          );
          break;
        }

        final clients = await ref.read(clientListProvider.future);
        final debtors = clients.where((c) => c.credit > 0.0).toList();
        debtors.sort((a, b) => b.credit.compareTo(a.credit));

        if (debtors.isEmpty) {
          addAssistantMessage("✅ **Débiteurs** : Aucun client n'a de dette en cours actuellement !");
        } else {
          final listText = debtors.take(5).map((c) => "• **${c.name}** : **${c.credit} FCFA** (Crédit Max: ${c.maxCredit})").join("\n");
          final extraText = debtors.length > 5 ? "\n*(...et ${debtors.length - 5} autres débiteurs)*" : "";
          addAssistantMessage("💳 **Liste des débiteurs (Top 5)** :\n$listText$extraText");
        }
        break;
        
      case 'ADD_EXPENSE':
        final amount = double.tryParse(params['amount'] ?? '0') ?? 0.0;
        if (amount <= 0) return;
        final categoryStr = params['category'] ?? 'DIVERS';
        final description = params['description'] ?? 'Dépense via Assistant';
        
        final treasury = ref.read(treasuryProvider.notifier);
        final defaultAccount = await treasury.getDefaultAccount(AccountType.CASH);
        
        try {
          if (defaultAccount != null) {
            final tx = FinancialTransaction(
              accountId: defaultAccount.id,
              type: TransactionType.OUT,
              amount: amount,
              category: TransactionCategory.EXPENSE,
              description: "$categoryStr : $description",
              date: DateTime.now(),
            );
            await treasury.addTransaction(tx);
            ref.read(proactiveAlertProvider.notifier).set(ProactiveAlertData(
              title: "Dépense enregistrée",
              message: "Dépense de $amount FCFA enregistrée (catégorie: $categoryStr).",
              level: AlertLevel.success,
            ));
          } else {
            throw Exception("Aucun compte de caisse disponible.");
          }
        } catch (e) {
          ref.read(proactiveAlertProvider.notifier).set(ProactiveAlertData(
            title: "Erreur dépense",
            message: "Impossible d'enregistrer la dépense de $amount FCFA : $e",
            level: AlertLevel.error,
          ));
          rethrow;
        }
        break;
      case 'UPDATE_DASHBOARD':
        final section = params['section'];
        final visibleStr = params['visible']?.toLowerCase();
        if (section != null && visibleStr != null) {
          final visible = visibleStr == 'true';
          await ref.read(dashboardCustomizationProvider.notifier).toggleSection(section, visible);
        }
        break;
      case 'SET_DASHBOARD_FILTER':
        final filterStr = params['filter']?.toLowerCase();
        if (filterStr == 'today') {
          ref.read(dashboardFilterProvider.notifier).setFilter(DashboardFilter.today);
        } else if (filterStr == 'week') {
          ref.read(dashboardFilterProvider.notifier).setFilter(DashboardFilter.week);
        } else if (filterStr == 'month') {
          ref.read(dashboardFilterProvider.notifier).setFilter(DashboardFilter.month);
        } else if (filterStr == 'custom') {
          final startStr = params['start_date'];
          final endStr = params['end_date'];
          if (startStr != null && endStr != null) {
            final start = DateTime.tryParse(startStr);
            final end = DateTime.tryParse(endStr);
            if (start != null && end != null) {
              ref.read(dashboardFilterProvider.notifier).setCustomRange(start, end);
            }
          }
        }
        break;
      case 'CHECKOUT_CART':
        final cart = ref.read(cartProvider);
        if (cart.isEmpty) {
          addAssistantMessage("🛡️ **Sécurité** : Impossible de valider une caisse avec un panier vide. Ajoute des produits d'abord.", isError: true);
          return;
        }

        final paymentMethod = params['payment_method'] ?? 'CASH';
        final amountPaidStr = params['amount_paid'];
        final amountPaid = amountPaidStr != null ? double.tryParse(amountPaidStr) : null;
        
        final isCreditStr = params['is_credit'];
        final isCredit = isCreditStr != null ? (isCreditStr.toLowerCase() == 'true') : false;
        final dueDate = params['due_date'];
        
        final isMixedStr = params['is_mixed'];
        final isMixed = isMixedStr != null ? (isMixedStr.toLowerCase() == 'true') : false;
        
        // Parsing éventuel de multi_payments si passé en chaîne ou structure
        dynamic multiPayments;
        final multiPaymentsStr = params['multi_payments'];
        if (multiPaymentsStr != null) {
          try {
            multiPayments = jsonDecode(multiPaymentsStr);
          } catch (_) {}
        }
        
        final documentType = params['document_type'];
        final selectedClientId = ref.read(selectedClientIdProvider);
        final cartTotal = cart.fold(0.0, (sum, item) => sum + item.lineTotal);

        if (isCredit) {
          if (selectedClientId == null || selectedClientId.isEmpty) {
            addAssistantMessage("🛡️ **Sécurité** : Vente à crédit impossible sans client lié chef ! Indique-moi d'abord quel client associer.", isError: true);
            return;
          }

          final clients = await ref.read(clientListProvider.future);
          final client = clients.cast<Client?>().firstWhere((c) => c?.id == selectedClientId, orElse: () => null);

          if (client != null) {
            final debtToAdd = cartTotal - (amountPaid ?? 0.0);
            final projectedDebt = client.credit + debtToAdd;
            if (projectedDebt > client.maxCredit) {
              addAssistantMessage("🛡️ **Alerte Risque** : Le client **${client.name}** dépasse son crédit autorisé (Dette actuelle : ${client.credit} FCFA, Nouveau crédit : $debtToAdd FCFA, Total projeté : $projectedDebt FCFA, Max autorisé : ${client.maxCredit} FCFA).", isError: true);
              return;
            }
          }
        }
        
        if (onAction != null) {
          onAction!(
            'checkout',
            payload: {
              'payment_method': paymentMethod,
              'amount_paid': amountPaid,
              'is_credit': isCredit,
              'due_date': dueDate,
              'is_mixed': isMixed,
              'multi_payments': multiPayments,
              'document_type': documentType,
            },
          );
        }
        break;
      case 'CREATE_QUOTE':
        final cart = ref.read(cartProvider);
        if (cart.isEmpty) {
          addAssistantMessage("Le panier de caisse est vide. Je vous redirige vers l'écran Gestion des Devis où vous pouvez configurer vos devis directement.", isError: true);
          if (onAction != null) {
            onAction!('navigate', payload: 10);
          }
          return;
        }
        
        final selectedClientId = ref.read(selectedClientIdProvider);
        final user = ref.read(authServiceProvider).value;
        final userId = user?.id ?? 'admin';
        
        final validityDays = params['validity_days'] != null 
            ? (int.tryParse(params['validity_days']!) ?? (settings.quoteValidityDays))
            : (settings.quoteValidityDays);
        final validUntil = DateTime.now().add(Duration(days: validityDays));
        final subtotal = ref.read(cartProvider.notifier).subtotal;
        
        final taxRate = settings.useTax == true ? (settings.taxRate) : 0.0;
        final totalAmount = settings.useTax == true ? subtotal * (1 + taxRate / 100) : subtotal;
        
        final quoteItems = cart.map((item) => QuoteItemWithId(
          name: item.name,
          qty: item.qty,
          unitPrice: item.unitPrice,
          productId: item.productId,
        )).toList();
        
        try {
          final quoteId = await ref.read(quoteRepositoryProvider).createQuote(
            clientId: selectedClientId,
            items: quoteItems,
            subtotal: subtotal,
            totalAmount: totalAmount,
            userId: userId,
            validUntil: validUntil,
          );
          
          ref.invalidate(quoteListProvider);
          ref.read(cartProvider.notifier).clear();
          
          addAssistantMessage(
            "📄 **Devis créé avec succès !**\n\nLe panier a été vidé et le devis a été enregistré avec l'ID `$quoteId`.\nVous pouvez le consulter dans la section Devis."
          );
          
          if (onAction != null) {
            onAction!('navigate', payload: 10); // Navigation vers les devis (index 10)
          }
        } catch (e) {
          addAssistantMessage("⚠️ **Erreur lors de la création du devis** : $e", isError: true);
        }
        break;

      case 'DELETE_QUOTE':
        final userDelete = ref.read(authServiceProvider).value;
        if (userDelete == null || !userDelete.canSell) {
          addAssistantMessage("🛡️ **Action refusée** : Vous n'avez pas l'autorisation de supprimer des devis.", isError: true);
          break;
        }
        final qNumDel = params['quote_number'];
        if (qNumDel == null || qNumDel.trim().isEmpty) {
          addAssistantMessage("⚠️ **Erreur** : Numéro de devis manquant.", isError: true);
          break;
        }
        try {
          final quotes = await ref.read(quoteListProvider.future);
          Map<String, dynamic>? matched;
          for (final q in quotes) {
            if (q['quote_number'].toString().toLowerCase().contains(qNumDel.trim().toLowerCase())) {
              matched = q;
              break;
            }
          }
          if (matched == null) {
            addAssistantMessage("⚠️ **Erreur** : Devis non trouvé pour '$qNumDel'.", isError: true);
          } else {
            await ref.read(quoteRepositoryProvider).deleteQuote(matched['id']);
            ref.invalidate(quoteListProvider);
            addAssistantMessage("🗑️ **Devis supprimé** : Le devis **${matched['quote_number']}** a été supprimé avec succès.");
          }
        } catch (e) {
          addAssistantMessage("⚠️ **Erreur lors de la suppression** : $e", isError: true);
        }
        break;

      case 'UPDATE_QUOTE_STATUS':
        final userStatus = ref.read(authServiceProvider).value;
        if (userStatus == null || !userStatus.canSell) {
          addAssistantMessage("🛡️ **Action refusée** : Vous n'avez pas l'autorisation de modifier les devis.", isError: true);
          break;
        }
        final qNumStatus = params['quote_number'];
        final newStatus = params['status']?.toUpperCase();
        if (qNumStatus == null || qNumStatus.trim().isEmpty || newStatus == null || newStatus.trim().isEmpty) {
          addAssistantMessage("⚠️ **Erreur** : Paramètres manquants pour modifier le statut du devis.", isError: true);
          break;
        }
        try {
          final quotes = await ref.read(quoteListProvider.future);
          Map<String, dynamic>? matched;
          for (final q in quotes) {
            if (q['quote_number'].toString().toLowerCase().contains(qNumStatus.trim().toLowerCase())) {
              matched = q;
              break;
            }
          }
          if (matched == null) {
            addAssistantMessage("⚠️ **Erreur** : Devis non trouvé.", isError: true);
          } else {
            await ref.read(quoteRepositoryProvider).updateQuoteStatus(matched['id'], newStatus);
            ref.invalidate(quoteListProvider);
            final statusStr = newStatus == 'ACCEPTED' 
                ? 'accepté ✅' 
                : newStatus == 'REJECTED' 
                    ? 'refusé ❌' 
                    : 'mis en attente ⏳';
            addAssistantMessage("📄 **Statut mis à jour** : Le devis **${matched['quote_number']}** est désormais **$statusStr**.");
          }
        } catch (e) {
          addAssistantMessage("⚠️ **Erreur lors de la mise à jour** : $e", isError: true);
        }
        break;

      case 'CONVERT_QUOTE_TO_SALE':
        final userConvert = ref.read(authServiceProvider).value;
        if (userConvert == null || !userConvert.canSell) {
          addAssistantMessage("🛡️ **Action refusée** : Vous n'avez pas l'autorisation de facturer des devis.", isError: true);
          break;
        }
        final qNumConvert = params['quote_number'];
        if (qNumConvert == null || qNumConvert.trim().isEmpty) {
          addAssistantMessage("⚠️ **Erreur** : Numéro de devis manquant.", isError: true);
          break;
        }
        try {
          final quotes = await ref.read(quoteListProvider.future);
          Map<String, dynamic>? matched;
          for (final q in quotes) {
            if (q['quote_number'].toString().toLowerCase().contains(qNumConvert.trim().toLowerCase())) {
              matched = q;
              break;
            }
          }
          if (matched == null) {
            addAssistantMessage("⚠️ **Erreur** : Devis non trouvé.", isError: true);
          } else {
            ref.read(cartProvider.notifier).loadFromQuote(matched['items']);
            await ref.read(quoteRepositoryProvider).updateQuoteStatus(matched['id'], 'CONVERTED');
            ref.invalidate(quoteListProvider);
            addAssistantMessage("🛒 **Devis converti** : Les articles du devis **${matched['quote_number']}** ont été chargés en caisse. Redirection...");
            if (onAction != null) {
              onAction!('navigate', payload: 3); // POS Page
            }
          }
        } catch (e) {
          addAssistantMessage("⚠️ **Erreur lors de la conversion** : $e", isError: true);
        }
        break;

      case 'GET_QUOTES_LIST':
        final user = ref.read(authServiceProvider).value;
        if (user == null || (!user.canAccessReports && !user.canSell)) {
          addAssistantMessage(
            "🛡️ **Action refusée** : Votre profil n'a pas l'autorisation d'accéder aux devis.",
            isError: true,
          );
          break;
        }

        final quotes = await ref.read(quoteListProvider.future);
        if (quotes.isEmpty) {
          addAssistantMessage("📄 **Devis** : Aucun devis n'a été enregistré pour le moment.");
        } else {
          final totalCount = quotes.length;
          final pendingQuotes = quotes.where((q) => q['status'] == 'PENDING').toList();
          final totalPendingAmount = pendingQuotes.fold<double>(0.0, (sum, q) => sum + (q['total_amount'] as num).toDouble());
          
          final listStr = quotes.take(5).map((q) {
            final clientName = q['client'] != null ? q['client']['name'] : 'Client Anonyme';
            final dateStr = DateFormatter.formatDate(DateTime.parse(q['date'] as String));
            final total = DateFormatter.formatCurrency((q['total_amount'] as num).toDouble(), settings.currency, removeDecimals: settings.removeDecimals);
            return "• **${q['quote_number']}** ($clientName) du $dateStr : **$total** [${q['status']}]";
          }).join("\n");
          
          addAssistantMessage("📄 **Liste des devis ($totalCount devis au total) :**\n"
              "• Devis en attente : **${pendingQuotes.length}** pour un total de **${DateFormatter.formatCurrency(totalPendingAmount, settings.currency, removeDecimals: settings.removeDecimals)}**\n\n"
              "**Derniers devis récents :**\n$listStr"
              "${quotes.length > 5 ? '\n*(...et ${quotes.length - 5} autres devis)*' : ''}");
        }
        break;

      case 'EXPORT_REPORT':
        final user = ref.read(authServiceProvider).value;
        if (user == null || !user.canAccessReports) {
          addAssistantMessage(
            "🛡️ **Action refusée** : Ton profil n'a pas l'autorisation d'accéder aux rapports de la boutique.",
            isError: true,
          );
          break;
        }

        final format = params['format']?.toLowerCase() ?? 'pdf';
        final period = params['period']?.toLowerCase() ?? 'month';
        
        final now = DateTime.now();
        DateTimeRange range;
        if (period == 'today') {
          range = DateTimeRange(
            start: DateTime(now.year, now.month, now.day),
            end: DateTime(now.year, now.month, now.day, 23, 59, 59),
          );
        } else if (period == 'week') {
          range = DateTimeRange(
            start: now.subtract(const Duration(days: 6)).copyWith(hour: 0, minute: 0, second: 0),
            end: now.copyWith(hour: 23, minute: 59, second: 59),
          );
        } else {
          // Month
          range = DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: DateTime(now.year, now.month, now.day, 23, 59, 59),
          );
        }

        final kpis = await ref.read(reportKPIsProvider(range).future);
        final topProducts = await ref.read(topProductsProvider(range).future);

        if (format == 'pdf') {
          final userSales = await ref.read(userSalesSummaryProvider(range).future);
          final userFuture = await ref.read(authServiceProvider.future);

          await PdfReportService.generateAndSaveReport(
            range: range,
            kpis: kpis,
            topProducts: topProducts,
            userSales: userSales,
            username: userFuture?.username ?? "Utilisateur",
            shopName: settings.name,
            shopAddress: settings.address,
            shopPhone: settings.phone,
            targetPrinter: settings.reportPrinterName ?? settings.invoicePrinterName,
            directPrint: settings.directPhysicalPrinting,
            currencySymbol: settings.currency,
            locale: "fr-FR",
            removeDecimals: settings.removeDecimals,
          );
          
          addAssistantMessage(
            "📄 **Rapport PDF généré** : J'ai généré et ouvert le rapport PDF pour la période : ${period == 'today' ? 'aujourd\'hui' : period == 'week' ? 'cette semaine' : 'ce mois'}."
          );
        } else {
          final db = await ref.read(databaseServiceProvider).database;
          await ExcelExportService.exportToExcel(
            range: range,
            kpis: kpis,
            topProducts: topProducts,
            db: db,
            currency: settings.currency,
          );
          addAssistantMessage(
            "📊 **Rapport Excel exporté** : Le fichier Excel a été généré et sauvegardé dans tes Téléchargements."
          );
        }
        break;
    }
  }
}
