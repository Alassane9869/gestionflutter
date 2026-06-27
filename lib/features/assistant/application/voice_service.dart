import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'assistant_service.dart';
import 'horizon_engine.dart';
import 'gemini_service.dart';
import 'gemini_live_service.dart';
import 'google_cloud_voice_service.dart';
import 'nlp_engine.dart';
import 'assistant_memory_service.dart';
import '../../inventory/domain/models/product.dart';
import '../../clients/domain/models/client.dart';
import '../../inventory/providers/product_providers.dart';
import '../../clients/providers/client_providers.dart';
import '../../pos/providers/sales_history_providers.dart';
import '../../pos/providers/pos_providers.dart';
import '../../auth/domain/models/user.dart';
import '../../auth/application/auth_service.dart';
import '../../finance/providers/treasury_provider.dart';
import '../../finance/domain/models/financial_account.dart';
import '../../settings/providers/settings_ui_providers.dart';
import '../../srm/domain/models/supplier.dart';
import '../../srm/providers/supplier_providers.dart';
import '../../pos/providers/quote_providers.dart';
import '../../inventory/providers/warehouse_providers.dart';
import '../../finance/providers/session_providers.dart';
import 'package:danaya_plus/core/theme/theme_provider.dart';
import 'package:danaya_plus/core/theme/app_theme.dart';
import '../../inventory/providers/dashboard_customization_provider.dart';
import '../../inventory/providers/dashboard_providers.dart';
import 'package:danaya_plus/features/reports/providers/report_providers.dart';
import 'package:danaya_plus/features/reports/services/pdf_report_service.dart';
import 'package:danaya_plus/features/reports/services/excel_export_service.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:flutter/material.dart' show DateTimeRange, ThemeMode;

class VoiceState {
  final bool isListening;
  final String lastWords;
  final String error;
  final bool isAvailable;

  // Call Mode states
  final bool isCallActive;
  final bool isMuted;
  final bool isSpeaking;
  final String statusText;
  final String lastAiResponse;

  final String selectedVoice;
  final List<Map<String, String>> availableVoices;
  final bool isLiveMode; // Indique si l'appel en direct WebSocket est actif
  final String selectedLiveModel;
  final List<Map<String, String>> availableLiveModels;
  final String selectedLiveVoice;
  final List<Map<String, String>> availableLiveVoices;
  final DateTime? callStartTime;
  final int dictationDuration; // Durée de l'enregistrement en dictée standard

  VoiceState({
    this.isListening = false,
    this.lastWords = '',
    this.error = '',
    this.isAvailable = false,
    this.isCallActive = false,
    this.isMuted = false,
    this.isSpeaking = false,
    this.statusText = '',
    this.lastAiResponse = '',
    this.selectedVoice = 'google',
    this.availableVoices = const [
      {'id': 'google', 'name': 'Danaya En Ligne (Féminine)'}
    ],
    this.isLiveMode = false,
    this.selectedLiveModel = 'gemini-3.1-flash-live-preview',
    this.availableLiveModels = const [
      {'id': 'gemini-3.1-flash-live-preview',                'name': 'Danaya 3.1 Live (Recommandé)'},
    ],
    this.selectedLiveVoice = 'Kore',
    this.availableLiveVoices = const [
      {'id': 'Kore', 'name': 'Kore (Féminine expressive)'},
      {'id': 'Puck', 'name': 'Puck (Masculine expressive)'},
      {'id': 'Aoede', 'name': 'Aoede (Féminine calme)'},
      {'id': 'Charon', 'name': 'Charon (Masculine douce)'},
      {'id': 'Fenrir', 'name': 'Fenrir (Masculine profonde)'},
    ],
    this.callStartTime,
    this.dictationDuration = 0,
  });

  /// Durée d'appel formatée (MM:SS)
  String get callDuration {
    if (callStartTime == null) return '00:00';
    final elapsed = DateTime.now().difference(callStartTime!);
    final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  VoiceState copyWith({
    bool? isListening,
    String? lastWords,
    String? error,
    bool? isAvailable,
    bool? isCallActive,
    bool? isMuted,
    bool? isSpeaking,
    String? statusText,
    String? lastAiResponse,
    String? selectedVoice,
    List<Map<String, String>>? availableVoices,
    bool? isLiveMode,
    String? selectedLiveModel,
    List<Map<String, String>>? availableLiveModels,
    String? selectedLiveVoice,
    List<Map<String, String>>? availableLiveVoices,
    DateTime? callStartTime,
    bool resetCallStartTime = false,
    int? dictationDuration,
  }) {
    return VoiceState(
      isListening: isListening ?? this.isListening,
      lastWords: lastWords ?? this.lastWords,
      error: error ?? this.error,
      isAvailable: isAvailable ?? this.isAvailable,
      isCallActive: isCallActive ?? this.isCallActive,
      isMuted: isMuted ?? this.isMuted,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      statusText: statusText ?? this.statusText,
      lastAiResponse: lastAiResponse ?? this.lastAiResponse,
      selectedVoice: selectedVoice ?? this.selectedVoice,
      availableVoices: availableVoices ?? this.availableVoices,
      isLiveMode: isLiveMode ?? this.isLiveMode,
      selectedLiveModel: selectedLiveModel ?? this.selectedLiveModel,
      availableLiveModels: availableLiveModels ?? this.availableLiveModels,
      selectedLiveVoice: selectedLiveVoice ?? this.selectedLiveVoice,
      availableLiveVoices: availableLiveVoices ?? this.availableLiveVoices,
      callStartTime: resetCallStartTime ? null : (callStartTime ?? this.callStartTime),
      dictationDuration: dictationDuration ?? this.dictationDuration,
    );
  }
}

class SoundWavesNotifier extends Notifier<List<double>> {
  @override
  List<double> build() => const [];

  void set(List<double> waves) {
    state = waves;
  }
}

final soundWavesProvider = NotifierProvider<SoundWavesNotifier, List<double>>(() {
  return SoundWavesNotifier();
});

final voiceServiceProvider = NotifierProvider<VoiceService, VoiceState>(() {
  return VoiceService();
});

class VoiceService extends Notifier<VoiceState> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final FlutterTts _tts = FlutterTts();
  final HorizonEngine _horizonEngine = HorizonEngine();
  
  Timer? _waveTimer;
  Timer? _dictationTimer;
  double _waveTime = 0.0;
  double _smoothAmplitude = 0.08;
  bool _isTtsInitialized = false;
  Timer? _reconnectResetTimer;

  StreamSubscription<Amplitude>? _amplitudeSubscription;
  String? _recordingPath;

  // Windows WinMM Audio Player Dynamic Library
  late final DynamicLibrary _winmm;

  // Live WebSocket API Variables
  GeminiLiveService? _liveService;
  StreamSubscription<List<int>>? _recordStreamSubscription;
  final List<int> _livePcmBuffer = [];
  bool _isLiveMode = false;

  WaveOutPlayer? _waveOutPlayer;
  bool _liveTurnCompleteReceived = false;
  int _reconnectAttempts = 0;
  bool _isReconnecting = false;
  bool _isStartingLive = false; // Guard to prevent concurrent startListeningForLive
  bool _isCallStarting = false; // Guard to prevent concurrent startCall/reconnections
  Timer? _endUserTurnDebounce; // Debounce pour éviter les envois turnComplete en rafale
  Timer? _textThrottleTimer; // Throttle pour éviter le flood du thread principal par les tokens de l'IA
  Timer? _reconnectTimer; // Timer pour gérer les reconnexions avec backoff et éviter les boucles infinies

  // Local VAD (Voice Activity Detection) / Noise Gate variables
  // Équilibre parfait : exclusion des bruits ambiants/secs et latence minimale
  double _noiseFloorDb = -45.0; // Dynamic tracking of the noise floor to adapt to environmental noise

  @override
  VoiceState build() {
    // Initialiser les services vocaux après un délai pour ne pas ralentir le démarrage de l'app
    Future.delayed(const Duration(milliseconds: 1500), () {
      _initSpeech();
      _initTts();
      _initWinmm();
    });

    ref.listen(cartProvider, (previous, next) {
      _sendSilentContextUpdate();
    });

    ref.listen(selectedClientIdProvider, (previous, next) {
      _sendSilentContextUpdate();
    });

    ref.onDispose(() {
      _waveTimer?.cancel();
      _dictationTimer?.cancel();
      _amplitudeSubscription?.cancel();
      _recordStreamSubscription?.cancel();
      _endUserTurnDebounce?.cancel();
      _textThrottleTimer?.cancel();
      _reconnectTimer?.cancel();
      if (!Platform.isWindows) {
        _tts.stop();
      }
      _audioRecorder.dispose();
      _liveService?.disconnect();
      _waveOutPlayer?.close();
      _reconnectResetTimer?.cancel();
    });

    return VoiceState();
  }

  void _initWinmm() {
    try {
      _winmm = DynamicLibrary.open('winmm.dll');
    } catch (e) {
      if (kDebugMode) print("Failed to load winmm.dll: $e");
    }
  }

  Future<void> _initSpeech() async {
    if (Platform.isWindows) {
      state = state.copyWith(isAvailable: true);
      return;
    }
    try {
      final available = await _audioRecorder.hasPermission();
      state = state.copyWith(isAvailable: available);
    } catch (e) {
      state = state.copyWith(isAvailable: false, error: e.toString());
    }
  }

  Future<void> _initTts() async {
    if (_isTtsInitialized) return;
    if (Platform.isWindows) {
      debugPrint('[VoiceService] Platform is Windows. Bypassing flutter_tts SAPI initialization to prevent thread warnings.');
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedVoice = prefs.getString('danaya_selected_voice') ?? 'google';
        String savedLiveModel = prefs.getString('danaya_selected_live_model') ?? 'gemini-3.1-flash-live-preview';
        if (savedLiveModel != 'gemini-3.1-flash-live-preview') {
          savedLiveModel = 'gemini-3.1-flash-live-preview';
          await prefs.setString('danaya_selected_live_model', savedLiveModel);
        }
        final savedLiveVoice = prefs.getString('danaya_selected_live_voice') ?? 'Kore';

        state = state.copyWith(
          availableVoices: const [
            {'id': 'google', 'name': 'Danaya En Ligne (Féminine)'}
          ],
          selectedVoice: savedVoice,
          selectedLiveModel: savedLiveModel,
          selectedLiveVoice: savedLiveVoice,
        );
        _isTtsInitialized = true;
      } catch (e) {
        if (kDebugMode) print("Failed to init Windows dummy TTS state: $e");
      }
      return;
    }
    try {
      await _tts.setLanguage("fr-FR");
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      // Récupérer les voix système françaises disponibles
      final List<Map<String, String>> list = [
        {'id': 'google', 'name': 'Danaya En Ligne (Féminine)'}
      ];

      try {
        final dynamic voices = await _tts.getVoices;
        if (voices is List) {
          for (final v in voices) {
            String name = '';
            String locale = '';
            if (v is Map) {
              name = v['name']?.toString() ?? '';
              locale = v['locale']?.toString() ?? '';
            } else if (v is String) {
              name = v;
              locale = v;
            }

            if (name.isNotEmpty && (locale.toLowerCase().contains('fr') || name.toLowerCase().contains('french'))) {
              final cleanName = name
                  .replaceAll('Microsoft ', '')
                  .replaceAll(' Desktop', '')
                  .replaceAll(' - French (France)', '')
                  .replaceAll(' - French', '')
                  .trim();
              
              String gender = "Voix";
              final lowerName = cleanName.toLowerCase();
              if (lowerName.contains('paul') || lowerName.contains('guy') || lowerName.contains('henri') || lowerName.contains('jean') || lowerName.contains('maurice')) {
                gender = "Masculine";
              } else if (lowerName.contains('hortense') || lowerName.contains('julie') || lowerName.contains('elodie') || lowerName.contains('eloise') || lowerName.contains('denise')) {
                gender = "Féminine";
              }

              list.add({
                'id': name,
                'name': '$cleanName ($gender Windows)',
              });
            }
          }
        }
      } catch (e) {
        if (kDebugMode) print("Erreur chargement voix système: $e");
      }

      // Charger la voix préférée et le modèle live préféré
      final prefs = await SharedPreferences.getInstance();
      final savedVoice = prefs.getString('danaya_selected_voice') ?? 'google';
      String savedLiveModel = prefs.getString('danaya_selected_live_model') ?? 'gemini-3.1-flash-live-preview';
      if (savedLiveModel != 'gemini-3.1-flash-live-preview') {
        savedLiveModel = 'gemini-3.1-flash-live-preview';
        await prefs.setString('danaya_selected_live_model', savedLiveModel);
      }
      
      final savedLiveVoice = prefs.getString('danaya_selected_live_voice') ?? 'Kore';

      state = state.copyWith(
        availableVoices: list,
        selectedVoice: savedVoice,
        selectedLiveModel: savedLiveModel,
        selectedLiveVoice: savedLiveVoice,
      );

      if (savedVoice != 'google') {
        try {
          await _tts.setVoice({"name": savedVoice, "locale": "fr-FR"});
        } catch (_) {}
      }

      _tts.setStartHandler(() {
        state = state.copyWith(
          isSpeaking: true,
          isListening: false,
          statusText: "Danaya Copilot parle...",
        );
      });

      _tts.setCompletionHandler(() {
        state = state.copyWith(isSpeaking: false);
        if (state.isCallActive && !state.isMuted) {
          startListeningForLive();
        } else if (state.isCallActive && state.isMuted) {
          state = state.copyWith(statusText: "Micro coupé (Muet)");
        }
      });

      _tts.setErrorHandler((msg) {
        if (kDebugMode) print("TTS error: $msg");
        state = state.copyWith(isSpeaking: false);
        if (state.isCallActive && !state.isMuted) {
          startListeningForLive();
        }
      });

      _isTtsInitialized = true;
    } catch (e) {
      if (kDebugMode) print("Failed to init TTS: $e");
    }
  }

  Future<void> changeVoice(String voiceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('danaya_selected_voice', voiceId);
    
    state = state.copyWith(selectedVoice: voiceId);
    
    if (voiceId != 'google' && !Platform.isWindows) {
      try {
        await _tts.setVoice({"name": voiceId, "locale": "fr-FR"});
      } catch (_) {}
    }
  }

  Future<void> changeLiveModel(String modelId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('danaya_selected_live_model', modelId);

    state = state.copyWith(selectedLiveModel: modelId);

    // Si un appel en direct est actif, le relancer pour appliquer le changement de modèle
    if (state.isCallActive && _isLiveMode) {
      if (kDebugMode) print('[VoiceService] Changement de modèle vers $modelId. Redémarrage de l\'appel...');
      await startCall();
    }
  }

  Future<void> changeLiveVoice(String voiceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('danaya_selected_live_voice', voiceId);

    state = state.copyWith(selectedLiveVoice: voiceId);

    // Si un appel en direct est actif, le relancer pour appliquer le changement de voix
    if (state.isCallActive && _isLiveMode) {
      if (kDebugMode) print('[VoiceService] Changement de voix vers $voiceId. Redémarrage de l\'appel...');
      await startCall();
    }
  }

  // --- MODE APPEL VOCAL (Phone Call Mode) ---

  Future<void> startCall() async {
    if (_isCallStarting) {
      if (kDebugMode) print('[VoiceService] startCall déjà en cours d\'exécution, ignoré.');
      return;
    }
    _isCallStarting = true;

    try {
      final settings = ref.read(shopSettingsProvider).value;
      if (settings != null && (!settings.isAiEnabled || !settings.showAssistant)) {
        ref.read(assistantProvider.notifier).addAssistantMessage(
          "⚠️ **Service Désactivé** :\n\n"
          "L'assistant intelligent est désactivé sur ce système."
        );
        return;
      }

      final user = ref.read(authServiceProvider).value;
      if (user != null && !user.canUseAi) {
        ref.read(assistantProvider.notifier).addAssistantMessage(
          "⚠️ **Accès Refusé** :\n\n"
          "Votre profil n'est pas autorisé à utiliser l'assistant intelligent."
        );
        return;
      }

      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        ref.read(assistantProvider.notifier).addAssistantMessage(
          "🚨 **Erreur Micro (Windows)** :\n\n"
          "L'assistant n'arrive pas à accéder à votre microphone. Veuillez vérifier vos paramètres Windows."
        );
        return;
      }

      await _initTts();
      await _stopRecorderQuietly();
      _recordStreamSubscription?.cancel();
      _recordStreamSubscription = null;
      if (!Platform.isWindows) {
        await _tts.stop();
      }

      // Properly disconnect the previous live service if any (BUG 9 fix)
      if (_liveService != null) {
        _liveService!.disconnect();
        _liveService = null;
      }
      _waveOutPlayer?.close();
      _waveOutPlayer = null;
      _isLiveMode = false;
      _livePcmBuffer.clear();

      final useCloud = settings?.useCloudAi ?? false;
      final provider = settings?.cloudAiProvider ?? 'local';
      final apiKey = settings?.geminiApiKey ?? '';

      if (useCloud && provider == 'gemini' && apiKey.isNotEmpty) {
        await _startLiveCall(apiKey);
      } else {
        // Pas de mode standard - afficher une erreur explicite
        ref.read(assistantProvider.notifier).addAssistantMessage(
          "⚠️ **Mode Appel Live requis**\n\n"
          "L'appel vocal nécessite une clé API Danaya VIP.\n"
          "Configure-la dans **Paramètres → Automatisation & IA** pour activer l'appel."
        );
        state = state.copyWith(
          isCallActive: false,
          statusText: "Clé API requise",
        );
      }
    } finally {
      _isCallStarting = false;
    }
  }

  Future<void> _startLiveCall(String apiKey) async {
    final user = ref.read(authServiceProvider).value;
    final String userName;
    if (user != null) {
      if (user.firstName != null && user.firstName!.trim().isNotEmpty) {
        userName = user.firstName!.trim();
      } else {
        userName = user.username;
      }
    } else {
      userName = "patron";
    }

    final bool initialSpeaking = !_isReconnecting;

    state = state.copyWith(
      isAvailable: true,
      isListening: false,
      isCallActive: true,
      isMuted: false,
      isSpeaking: initialSpeaking,
      statusText: _isReconnecting ? "Reconnexion en cours..." : "Connexion Live...",
      lastWords: "",
      isLiveMode: true,
      callStartTime: state.isCallActive ? state.callStartTime : DateTime.now(),
    );

    ref.read(soundWavesProvider.notifier).set(List.generate(15, (index) => 0.1));

    _isLiveMode = true;
    _livePcmBuffer.clear();
    _liveTurnCompleteReceived = false;

    _waveOutPlayer ??= WaveOutPlayer(_winmm);
    _waveOutPlayer!.open(24000);
    _waveOutPlayer!.onPlaybackComplete = () {
      if (_liveTurnCompleteReceived) {
        _liveTurnCompleteReceived = false;
        state = state.copyWith(isSpeaking: false);
        if (state.isCallActive && !state.isMuted && _isLiveMode) {
          startListeningForLive();
        }
      }
    };

    _startWaveAnimation();

    if (!ref.read(assistantProvider).isOpen) {
      ref.read(assistantProvider.notifier).toggleOpen();
    }

    try {
      final baseBusinessContext = await ref.read(assistantProvider.notifier).buildLiveBusinessContext();
      final currentScreenStr = ref.read(assistantProvider).currentContext.name;
      final businessContext = "$baseBusinessContext\n\nÉcran actuel: $currentScreenStr";
      final systemInstruction = """
Tu es DANAYA, le copilote vocal intelligent officiel de l'application DANAYA+.
Tu es à la fois un expert en gestion d'entreprise PME et un assistant conversationnel naturel, chaleureux et professionnel.

╔══════════════════════════════════════════════════════╗
║  PERSONNALITÉ ET TON VOCAL (PRIORITÉ ABSOLUE)        ║
╚══════════════════════════════════════════════════════╝

Tu parles COMME UN HUMAIN PROFESSIONNEL — jamais comme un robot ni comme un manuel.

PHRASES NATURELLES DE RÉFLEXION (utilise-les quand tu analyses ou cherches) :
  ► "Voyons voir..." / "Laissez-moi vérifier ça..." / "Un instant chef..."
  ► "Bien, je regarde ça pour vous..." / "Je vérifie dans le catalogue..."
  ► "Hmm, permettez-moi de réfléchir à ça un instant..."
  ► "D'accord, je comprends ce que vous voulez..."
  ► "Très bien chef, c'est fait !" / "Parfait, voilà !"

RÈGLES DE NATURALITÉ :
1. Réponds en 1 à 2 phrases courtes pour les questions simples — sois direct et vivant.
2. Pour les questions complexes (analyse de marges, stratégie, conseils), prends le temps de réfléchir et donne une réponse élaborée et précieuse.
3. Vouvoie toujours. Prénom ou "Chef" / "Patron". Jamais "tu" ni "monsieur" froid.
4. Si quelque chose est ambigu, demande naturellement : "Vous voulez dire... ou plutôt... ?"
5. Si tu n'es pas sûr d'un produit ou d'un montant, dis-le honnêtement avant d'agir.
6. Varie tes formulations — n'utilise jamais deux fois la même phrase d'introduction.

NE FAIS JAMAIS :
  ✗ Réponses robotiques type "Bien sûr ! Je vais vous aider avec ça."
  ✗ Lire à voix haute des UUID, des codes internes ou des IDs techniques.
  ✗ Réciter des rapports complets quand une phrase suffit.
  ✗ Répéter mot pour mot ce que le patron vient de dire.
  ✗ Générer des tableaux Markdown, des barres verticales ou des puces complexes. Décris toujours les listes et les chiffres sous forme de phrases courtes et parlées (ex : 'Issa Diarra vous doit 899 998 FCFA...').

╔══════════════════════════════════════════════════════╗
║  MAÎTRISE COMPLÈTE DE L'APPLICATION DANAYA+          ║
╚══════════════════════════════════════════════════════╝

ARCHITECTURE DE L'APP (tu connais chaque écran par cœur) :

📊 DASHBOARD : Vue synthétique des KPIs — chiffre d'affaires, ventes du jour, stock global, alertes.
🏪 CAISSE (POS) : Point de vente principal. Gestion du panier, produits, clients, encaissement.
📦 STOCK : Catalogue produits, quantités, alertes rupture, historique des mouvements.
💰 FINANCES : Dépenses, revenus, trésorerie, résultats financiers.
👥 CLIENTS : Fiches clients, historique achats, dettes (djourou), programme fidélité.
🚚 FOURNISSEURS : Fiches fournisseurs, bons de commande, réceptions.
📑 RAPPORTS : Analyses ventes, marges, performances par période.
📋 DEVIS : Création et gestion des devis/proformas.
🏭 ENTREPÔTS : Gestion multi-dépôts et transferts de stock.
⚙️ PARAMÈTRES : Configuration complète boutique (tous les onglets disponibles).

OUTILS DISPONIBLES ET LEUR USAGE EXACT :

VENTES & CAISSE :
  • add_to_cart(name, quantity?) — Ajouter un produit au panier. NOM EXACT du catalogue obligatoire.
  • remove_from_cart(name) — Retirer un produit du panier.
  • clear_cart() — Vider entièrement le panier.
  • select_client(name) — Associer un client à la vente en cours.
  • checkout_cart(payment_method, amount_paid?) — Valider la vente. Demande TOUJOURS confirmation du total et du mode de paiement avant.
  • create_quote() — Créer un devis depuis le panier actuel.

PRODUITS & STOCK :
  • search_product(query) — Chercher un produit par nom.
  • add_product(name, selling_price, purchase_price?, quantity?, category?) — Ajouter un nouveau produit.
  • update_product(name, ...) — Modifier un produit existant.
  • get_stock_info() — Résumé global du stock.

CLIENTS :
  • add_client(name, phone?, address?) — Ajouter un client.
  • update_client(name, ...) — Modifier un client.
  • delete_client(name) — Supprimer un client (toujours demander confirmation).
  • settle_client_debt(name, amount, payment_method) — Enregistrer un remboursement de dette.
  • get_client_debtors() — Lister les clients débiteurs.

FINANCES :
  • add_expense(amount, description, category?) — Enregistrer une dépense.
  • get_financial_summary(period?) — Obtenir le résumé financier.

RAPPORTS & ANALYSES :
  • get_sales_report(period) — Rapport des ventes sur une période.
  • get_top_products(limit?) — Produits les plus vendus.
  • get_top_profitable_items(limit?) — Produits les plus rentables.
  • compare_periods(period1, period2) — Comparer deux périodes.

NAVIGATION & INTERFACE :
  • navigate(page, settings_tab?) — Naviguer vers n'importe quel écran.
  • change_theme(mode?, color?) — Changer le thème visuel.

PARAMÈTRES :
  • update_shop_settings(...) — Modifier n'importe quel paramètre boutique.

MÉMOIRE PERSISTANTE :
  • save_memory_fact(text) — Mémoriser une information importante.
  • delete_memory_fact(id) — Oublier un fait mémorisé.
  • clear_memory_facts() — Effacer toute la mémoire.

╔══════════════════════════════════════════════════════╗
║  RÈGLES DE PRÉCISION ABSOLUE (ZÉRO ERREUR)           ║
╚══════════════════════════════════════════════════════╝

AVANT CHAQUE ACTION, TU DOIS :
  1. VÉRIFIER que le produit existe exactement dans le catalogue fourni.
  2. VÉRIFIER le stock disponible (si 0 → rupture, ne pas ajouter).
  3. CONVERTIR tous les montants verbaux en chiffres complets (jamais d'abréviation).
  4. CONFIRMER avec le patron avant toute action irréversible (vente, suppression).
  5. N'EXÉCUTER un outil QUE sur ordre explicite et direct du patron.

CONVERSIONS MONTANTS OBLIGATOIRES :
  "1 million" → 1000000  |  "1,5 million" → 1500000  |  "3 millions" → 3000000
  "50 mille" / "50k" → 50000  |  "500k" → 500000  |  "100k" → 100000
  "Muga" (20 dôrômê) → 100 FCFA  |  "Keme" (100 dôrômê) → 500 FCFA
  "Baa kelen" (1000 dôrômê) → 5000 FCFA  |  "Baa tan" (10000 dôrômê) → 50000 FCFA

CATALOGUE : JAMAIS inventer un produit. Si absent du catalogue → "Ce produit n'est pas dans votre stock, chef."

╔══════════════════════════════════════════════════════╗
║  DIRECTIVES LANGUES & TRADUCTION                     ║
╚══════════════════════════════════════════════════════╝

PAR DÉFAUT : Français professionnel exclusivement. Vouvoiement permanent.

ADAPTATION CONTEXTUELLE : N'utilise des salutations locales (Bambara, Dioula, etc.) que si le patron les emploie en premier.

MODE TRADUCTION (si patron dit "mode traduction" / "il y a un client") :
  → Client parle langue locale → "Le client dit : [traduction française]"
  → Patron demande de répondre → traduire sa phrase dans la langue du client
  → Rester TRÈS court et direct en mode traduction.

╔══════════════════════════════════════════════════════╗
║  MISE À JOUR CONTEXTE SILENCIEUSE                    ║
╚══════════════════════════════════════════════════════╝

Messages commençant par "[CONTEXT_UPDATE]" : Lire silencieusement, mettre à jour ta connaissance du panier/contexte. NE PAS RÉPONDRE, NE PAS PARLER. Attendre que le patron s'adresse à toi directement.

╔══════════════════════════════════════════════════════╗
║  INTELLIGENCE LIBRE & STRATÉGIQUE                    ║
╚══════════════════════════════════════════════════════╝

TU PEUX ET TU DOIS :
  ► Donner des conseils de gestion élaborés, des analyses de marges, des stratégies commerciales.
  ► Faire des calculs financiers précis à la demande.
  ► Encourager, motiver, féliciter le patron dans son activité.
  ► Proposer des idées proactives basées sur le contexte de la boutique.
  ► Répondre aux questions générales d'entreprise avec intelligence et profondeur.
  ► Prendre le temps de réfléchir profondément avant de donner un conseil stratégique.

SI LE PATRON EST FATIGUÉ OU STRESSÉ : Sois bienveillant, use d'humour léger, encourage-le.
IDENTITÉ : "J'ai été conçu et développé par l'ingénieur Alassane Diarra, fondateur de DANAYA+."

RÈGLES FINALES :
  • Prénom de l'utilisateur : $userName — appelle-le par son prénom ou Chef/Patron.
  • Écran actuel : $currentScreenStr — adapte tes réponses au contexte visuel.
  • JAMAIS exécuter une action non explicitement demandée.
  • JAMAIS confirmer avoir fait quelque chose que tu n'as pas fait via un outil.
""";

      final modelId = state.selectedLiveModel;

      _liveService = GeminiLiveService(
        apiKey: apiKey, 
        model: modelId,
        voiceName: state.selectedLiveVoice,
      );
      
      String liveResponseText = "";

      _liveService!.onConnectionStateChanged = (connState) {
        if (connState == LiveConnectionState.connected) {
          state = state.copyWith(statusText: "Initialisation session...");
          if (kDebugMode) print('[VoiceService] WS connecté, en attente setupComplete...');
        } else if (connState == LiveConnectionState.error) {
          state = state.copyWith(statusText: "Erreur de connexion Live");
        } else if (connState == LiveConnectionState.disconnected) {
          if (kDebugMode) print('[VoiceService] WS déconnecté.');
          if (state.isCallActive) {
            _fallbackToStandardCall("Connexion WebSocket fermée");
          }
        }
      };

      // CRITIQUE: Démarrer le micro SEULEMENT après que le serveur confirme setupComplete
      _liveService!.onSetupComplete = () async {
        if (kDebugMode) print('[VoiceService] setupComplete reçu! Démarrage micro + salutation...');
        _reconnectResetTimer?.cancel();
        _reconnectResetTimer = Timer(const Duration(seconds: 10), () {
          _reconnectAttempts = 0; // Reset reconnection counter only after 10s of stable connection
        });
        state = state.copyWith(statusText: "Prêt (Direct)");

        final wasReconnecting = _isReconnecting;
        _isReconnecting = false; // Reset reconnecting state immediately on success

        if (wasReconnecting) {
          if (kDebugMode) print('[VoiceService] Reconnexion après GoAway réussie. Reprise micro directe sans salutation.');
          startListeningForLive();
          return;
        }

        final initInstruction = "Bonjour ! Salue-moi chaleureusement et brièvement à haute voix en disant exactement : 'Salut $userName ! C'est Danaya, ton copilote. Comment puis-je t'aider aujourd'hui ?'";

        // Envoyer la consigne d'initialisation
        _liveService?.sendText(initInstruction);
        // Démarrer l'écoute du micro
        startListeningForLive();
      };

      _liveService!.onTextReceived = (text) {
        liveResponseText += text;
        
        // Mise à jour de l'état UI bridée (maximum toutes les 100ms) pour éviter de saturer la boucle de messages Win32
        _textThrottleTimer ??= Timer(const Duration(milliseconds: 100), () {
          _textThrottleTimer = null;
          if (state.isCallActive && _isLiveMode) {
            state = state.copyWith(lastAiResponse: liveResponseText);
            ref.read(assistantProvider.notifier).updateLiveResponse(liveResponseText, save: false);
          }
        });
      };

      _liveService!.onAudioReceived = (pcmChunk) {
        _handleLiveAudioChunk(pcmChunk);
      };

      _liveService!.onTurnComplete = () {
        _textThrottleTimer?.cancel();
        _textThrottleTimer = null;
        if (liveResponseText.isNotEmpty) {
          state = state.copyWith(lastAiResponse: liveResponseText);
          ref.read(assistantProvider.notifier).updateLiveResponse(liveResponseText, save: true);
        }
        _handleLiveTurnComplete();
        liveResponseText = ""; // Réinitialiser pour le prochain tour
      };

      _liveService!.onInterrupted = () {
        _textThrottleTimer?.cancel();
        _textThrottleTimer = null;
        if (liveResponseText.isNotEmpty) {
          state = state.copyWith(lastAiResponse: liveResponseText);
          ref.read(assistantProvider.notifier).updateLiveResponse(liveResponseText, save: true);
        }
        _handleLiveInterrupted();
        liveResponseText = "";
      };

      _liveService!.onToolCallReceived = (callId, name, args) {
        _handleLiveToolCall(callId, name, args);
      };

      _liveService!.onError = (err) {
        if (kDebugMode) print("Gemini Live Error callback: $err");
        _fallbackToStandardCall(err);
      };

      // Récupérer les permissions Copilot pour filtrer les outils côté API
      final shopSettings = ref.read(shopSettingsProvider).value;
      final enabledTools = shopSettings?.copilotPermissions;

      await _liveService!.connect(
        systemInstruction: systemInstruction,
        businessContext: businessContext,
        enabledTools: enabledTools,
      );

    } catch (e) {
      if (kDebugMode) print("Failed to start Live Call: $e");
      await _fallbackToStandardCall(e.toString());
    }
  }

  String _sanitizeUtf16(String input) {
    final units = input.codeUnits;
    final cleanUnits = <int>[];
    for (int i = 0; i < units.length; i++) {
      final val = units[i];
      if (val >= 0xD800 && val <= 0xDFFF) {
        if (val >= 0xD800 && val <= 0xDBFF) {
          if (i + 1 < units.length) {
            final next = units[i + 1];
            if (next >= 0xDC00 && next <= 0xDFFF) {
              cleanUnits.add(val);
              cleanUnits.add(next);
              i++;
              continue;
            }
          }
        }
        cleanUnits.add(0xFFFD);
      } else {
        cleanUnits.add(val);
      }
    }
    return String.fromCharCodes(cleanUnits);
  }

  Future<void> _fallbackToStandardCall(String reason) async {
    // GUARD: Prevent duplicate concurrent calls from onError + onConnectionStateChanged
    if (_isReconnecting) return;

    _reconnectResetTimer?.cancel();
    _endUserTurnDebounce?.cancel();

    // CRITICAL: Stop audio resources IMMEDIATELY to prevent orphaned PCM data
    // from flooding the Win32 message queue during backoff/reconnection
    await _stopRecorderQuietly();
    _recordStreamSubscription?.cancel();
    _recordStreamSubscription = null;
    _waveTimer?.cancel();
    _waveOutPlayer?.close();
    _liveTurnCompleteReceived = false;
    _textThrottleTimer?.cancel();
    _textThrottleTimer = null;

    _liveService?.disconnect();
    _liveService = null;
    _isLiveMode = false;
    _livePcmBuffer.clear();

    final sanitizedReason = _sanitizeUtf16(reason);

    final isQuotaOrAuth = sanitizedReason.toLowerCase().contains("quota") ||
        sanitizedReason.toLowerCase().contains("key") ||
        sanitizedReason.toLowerCase().contains("billing") ||
        sanitizedReason.toLowerCase().contains("api_key") ||
        sanitizedReason.contains("1011");

    final isExpired = sanitizedReason.contains("expiré") || sanitizedReason.contains("1008") || sanitizedReason.contains("GoAway");
    final isNotFoundError = sanitizedReason.toLowerCase().contains("not found") ||
        sanitizedReason.toLowerCase().contains("not supported") ||
        sanitizedReason.toLowerCase().contains("invalid");
    final isProtocolError = sanitizedReason.contains("1007") ||
        sanitizedReason.contains("1002") ||
        sanitizedReason.contains("1003") ||
        sanitizedReason.contains("1009");
    final shouldReconnect = !isQuotaOrAuth && !isNotFoundError && !isProtocolError && (isExpired || sanitizedReason.contains("fermée") || sanitizedReason.contains("WebSocket"));
    final maxAttempts = isExpired ? 100 : 3;

    if (shouldReconnect && _reconnectAttempts < maxAttempts) {
      _reconnectAttempts++;
      _isReconnecting = true;
      state = state.copyWith(
        statusText: "Reconnexion en cours...",
        isSpeaking: false,
        isListening: false,
      );

      if (!isExpired) {
        ref.read(assistantProvider.notifier).addAssistantMessage(
          "🔄 **Déconnexion détectée** : Reconnexion automatique de la session de discussion en cours (tentative $_reconnectAttempts/$maxAttempts)..."
        );
      }

      // BUG 8: Exponential backoff: 1s, 2s, 4s, 8s... capped at 15s
      final backoffSeconds = math.min(15, math.pow(2, _reconnectAttempts - 1).toInt());
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(Duration(seconds: backoffSeconds), () {
        if (_isReconnecting && state.isCallActive) {
          startCall();
        }
      });
      return;
    }

    // Normal fallback when attempts are exhausted or it's not a reconnectable error
    _isReconnecting = false;
    await _stopRecorderQuietly();
    _recordStreamSubscription?.cancel();
    _recordStreamSubscription = null;
    _amplitudeSubscription?.cancel();
    if (!Platform.isWindows) {
      await _tts.stop();
    }
    _waveTimer?.cancel();
    _waveOutPlayer?.close();
    _liveTurnCompleteReceived = false;

    String statusText = "Échec Connexion";
    if (isExpired) {
      statusText = "Session terminée";
    } else if (sanitizedReason.toLowerCase().contains("quota") || sanitizedReason.contains("1011")) {
      statusText = "Quota dépassé";
    } else if (sanitizedReason.toLowerCase().contains("key")) {
      statusText = "Clé API invalide";
    }

    state = state.copyWith(
      statusText: statusText,
      isLiveMode: false,
      isCallActive: false,
      isSpeaking: false,
      resetCallStartTime: true,
    );

    String friendlyMessage = "Veuillez vérifier votre connexion internet et votre clé d'accès Danaya VIP.";
    if (isExpired) {
      friendlyMessage = "Vous pouvez relancer l'appel vocal en direct quand vous le souhaitez en cliquant à nouveau sur le bouton.";
    } else if (isQuotaOrAuth) {
      friendlyMessage = "Il semble que vous ayez dépassé votre quota d'appels Gemini gratuit ou que votre facturation Google Cloud soit bloquée. Veuillez vérifier votre clé API et les détails de facturation de votre compte Google AI Studio.";
    }

    ref.read(assistantProvider.notifier).addAssistantMessage(
      "⚠️ **Session terminée** : $sanitizedReason\n\n$friendlyMessage"
    );
  }



  Future<void> endCall() async {
    _reconnectResetTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _endUserTurnDebounce?.cancel();
    _reconnectAttempts = 0;
    _isReconnecting = false;
    await _stopRecorderQuietly();
    _recordStreamSubscription?.cancel();
    _recordStreamSubscription = null;
    _amplitudeSubscription?.cancel();
    if (!Platform.isWindows) {
      await _tts.stop();
    }
    _waveTimer?.cancel();
    
    _liveService?.disconnect();
    _liveService = null;
    _isLiveMode = false;
    _isStartingLive = false;
    _livePcmBuffer.clear();
    _waveOutPlayer?.close();
    _liveTurnCompleteReceived = false;

    state = state.copyWith(
      isCallActive: false,
      isListening: false,
      isSpeaking: false,
      statusText: "",
      isLiveMode: false,
      resetCallStartTime: true,
    );
    ref.read(soundWavesProvider.notifier).set(const []);
  }

  void _sendBufferedAudio(Uint8List pcmRaw) {
    if (_liveService == null) return;
    _livePcmBuffer.addAll(pcmRaw);
    // 3200 bytes = 100ms of audio at 16000Hz, 16-bit Mono (2 bytes/sample)
    if (_livePcmBuffer.length >= 3200) {
      final chunkToSend = Uint8List.fromList(_livePcmBuffer);
      _liveService?.sendAudioChunk(chunkToSend);
      _livePcmBuffer.clear();
    }
  }



  Future<void> _sendSilentContextUpdate() async {
    if (state.isCallActive && _isLiveMode && _liveService != null) {
      try {
        final cartContext = await _buildLiveCartContext();
        if (kDebugMode) print('[VoiceService] Envoi mise à jour panier silencieuse: $cartContext');
        _liveService?.sendText(cartContext);
      } catch (e) {
        if (kDebugMode) print('[VoiceService] Erreur mise à jour panier: $e');
      }
    }
  }

  Future<String> _buildLiveCartContext() async {
    final settings = ref.read(shopSettingsProvider).value;
    final currency = settings?.currency ?? 'FCFA';
    final removeDecimals = settings?.removeDecimals ?? true;
    
    final clients = ref.read(clientListProvider).value ?? [];

    final cart = ref.read(cartProvider);
    final selectedClientId = ref.read(selectedClientIdProvider);
    String selectedClientName = "Aucun";
    if (selectedClientId != null && clients.isNotEmpty) {
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

    return '''[CONTEXT_UPDATE]
Mise à jour en temps réel du Panier de caisse :
- Client associé : $selectedClientName
- Articles dans le panier :
$cartSummary
- Total du panier : ${DateFormatter.formatCurrency(cartTotal, currency, removeDecimals: removeDecimals)} (${totalItems.toStringAsFixed(0)} articles)''';
  }

  void toggleMute() {
    if (!state.isCallActive) return;
    
    final nextMute = !state.isMuted;
    state = state.copyWith(isMuted: nextMute);

    if (nextMute) {
      _stopRecorderQuietly();
      _recordStreamSubscription?.cancel();
      _recordStreamSubscription = null;
      _amplitudeSubscription?.cancel();
      _waveOutPlayer?.reset();
      _liveTurnCompleteReceived = false;
      state = state.copyWith(
        isListening: false,
        statusText: "Micro coupé (Muet)",
      );
    } else {
      if (!state.isSpeaking && !(_waveOutPlayer?.isPlaying ?? false)) {
        startListeningForLive();
      }
    }
  }

  Future<void> startListeningForLive() async {
    if (!state.isCallActive || state.isMuted || !_isLiveMode) return;
    if (_isStartingLive) return; // Prevent concurrent invocations
    _isStartingLive = true;

    try {
      final isAlreadyRecording = _recordStreamSubscription != null && await _audioRecorder.isRecording();
      if (isAlreadyRecording) {
        if (!state.isListening) {
          state = state.copyWith(
            isListening: true,
            lastWords: '',
            statusText: "À votre écoute...",
          );
        }
        _isStartingLive = false;
        return;
      }

      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        state = state.copyWith(
          error: "Permission micro refusée",
          statusText: "Erreur micro",
        );
        return;
      }

      await _stopRecorderQuietly();
      _recordStreamSubscription?.cancel();
      _recordStreamSubscription = null;

      state = state.copyWith(
        isListening: true,
        lastWords: '',
        statusText: "À votre écoute...",
      );

      // Reset local VAD state
      _noiseFloorDb = -45.0;

      final stream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          numChannels: 1,
          sampleRate: 16000,
        ),
      );

      final List<int> streamInputBuffer = [];

      _recordStreamSubscription = stream.listen((data) {
        if (!state.isCallActive || state.isMuted) return;

        // Éviter le Larsen / l'écho acoustique (Acoustic Echo Feedback) :
        // Si l'assistant est en train de parler, on ignore le micro pour éviter qu'il ne s'interrompe lui-même.
        if (state.isSpeaking) {
          streamInputBuffer.clear();
          return;
        }

        // Buffer incoming audio chunks (minimum 640 bytes = 20ms at 16kHz/16bit)
        // to reduce the frequency of FFI calls and state updates
        streamInputBuffer.addAll(data);
        if (streamInputBuffer.length < 640) return;

        // Extract a chunk from the buffer for processing
        final pcmRaw = Uint8List.fromList(streamInputBuffer);
        streamInputBuffer.clear();

        _processAudioInputChunk(pcmRaw);
      });

    } catch (e) {
      if (kDebugMode) print("Erreur lancement streaming micro : $e");
      state = state.copyWith(statusText: "Erreur micro direct");
    } finally {
      _isStartingLive = false;
    }
  }

  void _handleLiveAudioChunk(Uint8List chunk) {
    if (state.isCallActive && _isLiveMode) {
      // CRITICAL: Ne mettre à jour le state qu'UNE SEULE FOIS lors de la transition vers isSpeaking
      // Éviter de flood le thread principal Windows avec des copyWith répétés
      if (!state.isSpeaking) {
        // Annuler tout endUserTurn en attente car l'IA a commencé à parler
        _endUserTurnDebounce?.cancel();
        state = state.copyWith(
          isSpeaking: true,
          isListening: false,
          statusText: "Danaya Copilot parle...",
        );
      }
      _waveOutPlayer?.write(chunk);
      
      // Mesurer le volume de la voix de l'IA pour synchroniser l'animation vocale en temps réel
      // Note: _updateAiSoundWaves ne fait PAS de state update, c'est le wave timer qui le fait
      final db = _calculatePcmDb(chunk);
      _updateAiSoundWaves(db);
    }
  }

  void _handleLiveTurnComplete() {
    _liveTurnCompleteReceived = true;
    if (_waveOutPlayer == null || !_waveOutPlayer!.isPlaying) {
      _liveTurnCompleteReceived = false;
      state = state.copyWith(isSpeaking: false);
      if (state.isCallActive && !state.isMuted && _isLiveMode) {
        startListeningForLive();
      }
    }
  }

  void _handleLiveInterrupted() {
    _waveOutPlayer?.reset();
    _liveTurnCompleteReceived = false;
    state = state.copyWith(
      isSpeaking: false,
      statusText: "Interrompu",
    );
    if (state.isCallActive && !state.isMuted && _isLiveMode) {
      startListeningForLive();
    }
  }

  void _processAudioInputChunk(Uint8List pcmRaw) {
    final db = _calculatePcmDb(pcmRaw);

    // Mettre à jour l'affichage des ondes sonores utilisateur
    _updateUserSoundWaves(db);

    // Mettre à jour le bruit de fond pour l'animation
    if (db < _noiseFloorDb) {
      _noiseFloorDb = _noiseFloorDb * 0.9 + db * 0.1;
    } else {
      _noiseFloorDb = _noiseFloorDb * 0.999 + db * 0.001;
    }
    _noiseFloorDb = _noiseFloorDb.clamp(-55.0, -35.0);

    // Si nous sommes en mode Live WebSocket, diffuser directement et laisser le VAD natif de Gemini décider du tour
    if (state.isCallActive && !state.isMuted && _isLiveMode) {
      _sendBufferedAudio(pcmRaw);

      // Mettre à jour le statut UI de manière douce selon que l'IA parle ou non
      final shouldBeListening = !state.isSpeaking;
      if (state.isListening != shouldBeListening) {
        state = state.copyWith(
          isListening: shouldBeListening,
          statusText: shouldBeListening ? "À votre écoute..." : "Danaya parle...",
        );
      }
    }
  }

  Product? _findBestProductMatch(List<Product> products, String query, {bool skipServices = false}) {
    final queryLower = query.toLowerCase().trim();
    if (queryLower.isEmpty) return null;

    Product? bestMatch;
    double bestScore = -1.0;

    final queryWords = queryLower.split(RegExp(r'\s+')).where((w) => w.length > 1).toList();

    for (final p in products) {
      if (skipServices && p.isService) continue;
      final pNameLower = p.name.toLowerCase().trim();

      // 1. Exact match (highest priority)
      if (pNameLower == queryLower) {
        return p;
      }

      double score = 0.0;

      // 2. Token-level matching (phonetic and Levenshtein)
      final pWords = pNameLower.split(RegExp(r'\s+')).where((w) => w.length > 1).toList();

      double totalWordSim = 0.0;
      for (final qw in queryWords) {
        double bestWordSim = 0.0;
        for (final pw in pWords) {
          if (pw == qw) {
            bestWordSim = 1.0;
            break;
          }
          if (pw.contains(qw) || qw.contains(pw)) {
            final ratio = pw.contains(qw) ? qw.length / pw.length : pw.length / qw.length;
            bestWordSim = math.max(bestWordSim, ratio * 0.9);
          }
          final sim = NlpEngine.similarity(qw, pw);
          final phoneSim = NlpEngine.phoneticSimilarity(qw, pw);
          bestWordSim = math.max(bestWordSim, math.max(sim, phoneSim));
        }
        if (bestWordSim >= 0.7) {
          totalWordSim += bestWordSim;
        }
      }

      final double wordScore = queryWords.isNotEmpty ? totalWordSim / queryWords.length : 0.0;
      score += wordScore * 2.0; // Strong weight on matching words

      // 3. Substring match
      final bool isSubstr = pNameLower.contains(queryLower) || queryLower.contains(pNameLower);
      final double lengthRatio = pNameLower.length > queryLower.length 
          ? queryLower.length / pNameLower.length 
          : pNameLower.length / queryLower.length;

      if (isSubstr) {
        score += 1.0;
        score += lengthRatio * 0.5;
      }

      // 4. Global similarity
      final globalSim = NlpEngine.similarity(queryLower, pNameLower);
      final globalPhoneSim = NlpEngine.phoneticSimilarity(queryLower, pNameLower);
      score += math.max(globalSim, globalPhoneSim) * 0.5;

      if (score > bestScore) {
        bestScore = score;
        bestMatch = p;
      }
    }

    // Minimum threshold check to prevent matching random unrelated products
    if (bestMatch != null && bestScore >= 0.8) {
      return bestMatch;
    }

    return null;
  }

  Client? _findBestClientMatch(List<Client> clients, String query) {
    final queryLower = query.toLowerCase().trim();
    if (queryLower.isEmpty) return null;

    Client? bestMatch;
    double bestScore = -1.0;

    final queryWords = queryLower.split(RegExp(r'\s+')).where((w) => w.length > 1).toList();

    for (final c in clients) {
      final cNameLower = c.name.toLowerCase().trim();

      // 1. Exact match (highest priority)
      if (cNameLower == queryLower) {
        return c;
      }

      double score = 0.0;

      // 2. Token-level matching (phonetic and Levenshtein)
      final cWords = cNameLower.split(RegExp(r'\s+')).where((w) => w.length > 1).toList();

      double totalWordSim = 0.0;
      for (final qw in queryWords) {
        double bestWordSim = 0.0;
        for (final cw in cWords) {
          if (cw == qw) {
            bestWordSim = 1.0;
            break;
          }
          if (cw.contains(qw) || qw.contains(cw)) {
            final ratio = cw.contains(qw) ? qw.length / cw.length : cw.length / qw.length;
            bestWordSim = math.max(bestWordSim, ratio * 0.9);
          }
          final sim = NlpEngine.similarity(qw, cw);
          final phoneSim = NlpEngine.phoneticSimilarity(qw, cw);
          bestWordSim = math.max(bestWordSim, math.max(sim, phoneSim));
        }
        if (bestWordSim >= 0.7) {
          totalWordSim += bestWordSim;
        }
      }

      final double wordScore = queryWords.isNotEmpty ? totalWordSim / queryWords.length : 0.0;
      score += wordScore * 2.0; // Strong weight on matching words

      // 3. Substring match
      final bool isSubstr = cNameLower.contains(queryLower) || queryLower.contains(cNameLower);
      final double lengthRatio = cNameLower.length > queryLower.length 
          ? queryLower.length / cNameLower.length 
          : cNameLower.length / queryLower.length;

      if (isSubstr) {
        score += 1.0;
        score += lengthRatio * 0.5;
      }

      // 4. Global similarity
      final globalSim = NlpEngine.similarity(queryLower, cNameLower);
      final globalPhoneSim = NlpEngine.phoneticSimilarity(queryLower, cNameLower);
      score += math.max(globalSim, globalPhoneSim) * 0.5;

      if (score > bestScore) {
        bestScore = score;
        bestMatch = c;
      }
    }

    // Minimum threshold check to prevent matching random unrelated clients
    if (bestMatch != null && bestScore >= 0.8) {
      return bestMatch;
    }

    return null;
  }

  String _getFriendlyToolName(String name, Map<String, dynamic> args) {
    switch (name) {
      case 'navigate':
        final page = args['page'] ?? '';
        return "Navigation vers la page '$page'";
      case 'change_theme':
        final mode = args['mode'] ?? '';
        final color = args['color'] ?? '';
        if (mode.isNotEmpty && color.isNotEmpty) {
          return "Changement du thème ($mode, couleur $color)";
        }
        return "Modification du thème/apparence";
      case 'update_shop_settings':
        return "Mise à jour des paramètres de la boutique";
      case 'add_product':
        final pName = args['name'] ?? '';
        return "Création du produit '$pName'";
      case 'search_product':
        final query = args['query'] ?? '';
        return "Recherche du produit '$query'";
      case 'get_stock_info':
        return "Consultation des statistiques de stock";
      case 'add_client':
        final cName = args['name'] ?? '';
        return "Création du client '$cName'";
      case 'get_client_info':
        final query = args['query'] ?? '';
        return "Recherche des informations de '$query'";
      case 'select_client':
        final cName = args['client_name'] ?? '';
        return "Sélection du client '$cName'";
      case 'get_sales_summary':
        return "Récupération du résumé des ventes";
      case 'adjust_stock':
        final pName = args['product_name'] ?? '';
        final qty = args['quantity'] ?? 0;
        return "Ajustement du stock de '$pName' ($qty)";
      case 'add_to_cart':
        final pName = args['product_name'] ?? '';
        final qty = args['quantity'] ?? 1;
        return "Ajout de '$pName' (x$qty) au panier";
      case 'update_product':
        final pName = args['product_name'] ?? '';
        return "Modification du produit '$pName'";
      case 'delete_product':
        final pName = args['product_name'] ?? '';
        return "Suppression du produit '$pName'";
      case 'update_client':
        final cName = args['client_name'] ?? '';
        return "Modification du client '$cName'";
      case 'delete_client':
        final cName = args['client_name'] ?? '';
        return "Suppression du client '$cName'";
      case 'settle_client_debt':
        final cName = args['client_name'] ?? '';
        final amount = args['amount'] ?? 0;
        return "Encaissement dette de '$cName' ($amount)";
      case 'filter_sales':
        return "Filtrage de l'historique des ventes";
      case 'manage_sale':
        final act = args['action'] ?? '';
        final target = args['sale_id_or_client'] ?? '';
        return "Action '$act' sur la vente '$target'";
      case 'compare_sales_periods':
        final p1 = args['period1'] ?? '';
        final p2 = args['period2'] ?? '';
        return "Comparaison des ventes entre $p1 et $p2";
      case 'get_top_profitable_items':
        return "Recherche des produits les plus rentables";
      case 'get_client_debtors':
        return "Consultation de la liste des débiteurs";
      case 'filter_clients':
        final tab = args['tab'] ?? '';
        final sort = args['sort'] ?? '';
        return "Filtrage des clients (onglet '$tab', tri '$sort')";
      case 'filter_suppliers':
        final tab = args['tab'] ?? '';
        final sort = args['sort'] ?? '';
        return "Filtrage des fournisseurs (onglet '$tab', tri '$sort')";
      case 'filter_products':
        final tab = args['tab'] ?? '';
        return "Filtrage des produits (état '$tab')";
      case 'manage_cash_session':
        final act = args['action'] ?? '';
        final amt = args['amount'] ?? 0;
        return "Gestion caisse ($act, fond: $amt)";
      case 'get_treasury_summary':
        return "Consultation du solde de trésorerie";
      case 'get_hr_summary':
        return "Résumé RH et fiches de paie";
      case 'send_client_message':
        final cName = args['client_name'] ?? '';
        final method = args['method'] ?? '';
        return "Envoi d'un message ($method) à '$cName'";
      case 'get_debt_report':
        return "Génération du rapport global des dettes";
      case 'remove_from_cart':
        final pName = args['product_name'] ?? '';
        return "Retrait de '$pName' du panier";
      case 'clear_cart':
        return "Vidage du panier de caisse";
      case 'get_low_stock_alerts':
        return "Vérification des alertes de stock faible";
      case 'save_memory_fact':
        return "Enregistrement d'une consigne en mémoire";
      case 'delete_memory_fact':
        return "Suppression d'un souvenir de la mémoire";
      case 'clear_memory_facts':
        return "Réinitialisation de la mémoire Danaya";
      case 'add_expense':
        final amount = args['amount'] ?? 0;
        final cat = args['category'] ?? 'divers';
        return "Enregistrement d'une dépense de $amount FCFA ($cat)";
      case 'update_dashboard':
        final sec = args['section'] ?? '';
        final vis = args['visible'] == true ? 'affichage' : 'masquage';
        return "Personnalisation du tableau de bord ($vis de $sec)";
      case 'set_dashboard_filter':
        final filter = args['filter'] ?? '';
        return "Filtrage du tableau de bord ($filter)";
      case 'checkout_cart':
        return "Validation et encaissement du panier";
      case 'export_report':
        final format = args['format'] ?? 'pdf';
        final period = args['period'] ?? '';
        return "Génération du rapport $format ($period)";
      case 'get_business_insights':
        return "Analyse prédictive de la boutique par Horizon Engine";
      default:
        return "Exécution de l'action : $name";
    }
  }

  Future<void> _handleLiveToolCall(String callId, String name, Map<String, dynamic> args) async {
    if (kDebugMode) print('[VoiceService] Tool Call reçu: $name avec $args');

    final friendlyName = _getFriendlyToolName(name, args);
    state = state.copyWith(statusText: "Exécution : $friendlyName...");
    
    ref.read(proactiveAlertProvider.notifier).set(
      ProactiveAlertData(
        title: "Action Danaya",
        message: "$friendlyName...",
        level: AlertLevel.info,
      ),
    );

    bool success = false;
    Map<String, dynamic> responseOutput = {};

    final settings = ref.read(shopSettingsProvider).value;
    final isCopilotActionEnabled = settings?.copilotPermissions[name] ?? true;

    if (!isCopilotActionEnabled) {
      responseOutput = {
        'success': false,
        'error': 'Cette action est désactivée dans les paramètres de Danaya Copilot.'
      };
      ref.read(proactiveAlertProvider.notifier).set(
        ProactiveAlertData(
          title: "Action Désactivée",
          message: "L'assistant a tenté d'exécuter l'action '$name', mais celle-ci est désactivée dans les paramètres.",
        ),
      );
      ref.read(assistantProvider.notifier).addAssistantMessage(
        "⚠️ **Action refusée** : L'action vocale **$name** est désactivée dans vos paramètres de contrôle."
      );
      _liveService?.sendToolResponse(callId, responseOutput);
      return;
    }

    final user = ref.read(authServiceProvider).value;
    bool hasPermission(bool Function(User u) check) {
      final u = user;
      if (u == null) return false;
      return check(u);
    }

    try {
      if (name == 'navigate') {
        final page = args['page'] as String?;
        int? panelPayload;
        bool allowed = true;
        switch (page) {
          case 'dashboard': panelPayload = 0; break;
          case 'stock':
            allowed = hasPermission((u) => u.canManageInventory);
            panelPayload = 1; break;
          case 'mouvements_stock':
            allowed = hasPermission((u) => u.canManageInventory);
            panelPayload = 2; break;
          case 'caisse': panelPayload = 3; break;
          case 'historique_ventes':
            allowed = hasPermission((u) => u.canAccessReports);
            panelPayload = 4; break;
          case 'rapports':
            allowed = hasPermission((u) => u.canAccessReports);
            panelPayload = 5; break;
          case 'finances':
            allowed = hasPermission((u) => u.canAccessFinance);
            panelPayload = 6; break;
          case 'clients':
            allowed = hasPermission((u) => u.canManageCustomers || u.canManageUsers);
            panelPayload = 7; break;
          case 'fournisseurs':
            allowed = hasPermission((u) => u.canManageSuppliers);
            panelPayload = 8; break;
          case 'parametres':
            allowed = hasPermission((u) => u.canAccessSettings);
            panelPayload = 9; 
            if (allowed) {
              final settingsTab = args['settings_tab'] as String?;
              if (settingsTab != null) {
                int tabIndex = 0;
                switch (settingsTab) {
                  case 'enseigne': tabIndex = 0; break;
                  case 'finance': tabIndex = 1; break;
                  case 'fidelite': tabIndex = 2; break;
                  case 'politique': tabIndex = 3; break;
                  case 'apparence': tabIndex = 4; break;
                  case 'imprimante': tabIndex = 5; break;
                  case 'afficheur': tabIndex = 6; break;
                  case 'son': tabIndex = 7; break;
                  case 'assistant': tabIndex = 8; break;
                  case 'smtp': tabIndex = 9; break;
                  case 'sauvegarde': tabIndex = 10; break;
                  case 'serveur': tabIndex = 11; break;
                  case 'logs': tabIndex = 12; break;
                  case 'personnalisation': tabIndex = 13; break;
                  case 'academy': tabIndex = 14; break;
                  case 'whatsapp': tabIndex = 15; break;
                }
                ref.read(settingsTabIndexProvider.notifier).setIndex(tabIndex);
              }
            }
            break;
          case 'devis': panelPayload = 10; break;
          case 'entrepots':
            allowed = hasPermission((u) => u.isAdmin || u.isManager);
            panelPayload = 11; break;
          case 'dettes_clients':
            allowed = hasPermission((u) => u.canAccessFinance);
            panelPayload = 12; break;
          case 'depenses':
            allowed = hasPermission((u) => u.canAccessFinance);
            panelPayload = 13; break;
          case 'alertes_stock':
            allowed = hasPermission((u) => u.canManageInventory);
            panelPayload = 14; break;
          case 'audit_stock':
            allowed = hasPermission((u) => u.isAdmin || u.isManager);
            panelPayload = 15; break;
        }

        if (!allowed) {
          responseOutput = {'success': false, 'error': 'Accès refusé par le profil de l\'utilisateur.'};
          ref.read(proactiveAlertProvider.notifier).set(
            ProactiveAlertData(
              title: "Accès Refusé",
              message: "Impossible de naviguer vers '$page' : permission insuffisante.",
            ),
          );
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "⚠️ **Navigation refusée** : Votre profil n'a pas l'autorisation d'accéder à la page **$page**."
          );
        } else if (panelPayload != null) {
          final assistantNotifier = ref.read(assistantProvider.notifier);
          if (assistantNotifier.onAction != null) {
            assistantNotifier.onAction!('navigate', payload: panelPayload);
            success = true;
          }
          responseOutput = {'success': success};
          if (success) {
            ref.read(proactiveAlertProvider.notifier).set(
              ProactiveAlertData(
                title: "Navigation Copilot",
                message: "Navigation vers la page '$page'",
              ),
            );
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🚀 Je navigue vers la page **$page** pour toi."
            );
          }
        }
      } else if (name == 'change_theme') {
        if (!hasPermission((u) => u.canAccessSettings)) {
          responseOutput = {'success': false, 'error': 'Accès refusé. Modification du thème non autorisée.'};
          ref.read(proactiveAlertProvider.notifier).set(
            ProactiveAlertData(
              title: "Accès Refusé",
              message: "Modification du thème refusée : permission insuffisante.",
            ),
          );
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "⚠️ **Thème refusé** : Ton profil n'a pas l'autorisation de modifier les paramètres."
          );
        } else {
          final mode = args['mode'] as String?;
          final colorStr = args['color'] as String?;
          
          String changesMsg = "";
          
          if (mode != null) {
            if (mode == 'sombre') {
              ref.read(themeNotifierProvider.notifier).setThemeMode(ThemeMode.dark);
              success = true;
              changesMsg += "mode sombre";
            } else if (mode == 'clair') {
              ref.read(themeNotifierProvider.notifier).setThemeMode(ThemeMode.light);
              success = true;
              changesMsg += "mode clair";
            }
          }
          
          if (colorStr != null) {
            AppThemeColor? selectedColor;
            for (final val in AppThemeColor.values) {
              if (val.name.toLowerCase() == colorStr.toLowerCase()) {
                selectedColor = val;
                break;
              }
            }
            if (selectedColor != null) {
              await ref.read(themeNotifierProvider.notifier).setThemeColor(selectedColor);
              success = true;
              if (changesMsg.isNotEmpty) changesMsg += " et le ";
              changesMsg += "thème ${selectedColor.label}";
            }
          }
          
          responseOutput = {'success': success};
          if (success) {
            ref.read(proactiveAlertProvider.notifier).set(
              ProactiveAlertData(
                title: "Apparence Modifiée",
                message: "L'apparence a été mise à jour ($changesMsg) par l'assistant.",
              ),
            );
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🎨 J'ai mis à jour l'apparence : **$changesMsg**."
            );
          }
        }
      } else if (name == 'update_shop_settings') {
        if (!hasPermission((u) => u.canAccessSettings)) {
          responseOutput = {'success': false, 'error': 'Accès refusé par le profil de l\'utilisateur.'};
          ref.read(proactiveAlertProvider.notifier).set(
            ProactiveAlertData(
              title: "Accès Refusé",
              message: "Impossible de modifier les paramètres : permission insuffisante.",
            ),
          );
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "⚠️ **Action refusée** : Votre profil n'a pas l'autorisation de modifier les paramètres."
          );
        } else {
          final settings = ref.read(shopSettingsProvider).value;
          if (settings != null) {
            var updated = settings;
            String changes = "";
            if (args.containsKey('name')) {
              updated = updated.copyWith(name: args['name'] as String);
              changes += "nom: ${args['name']}, ";
            }
            if (args.containsKey('slogan')) {
              updated = updated.copyWith(slogan: args['slogan'] as String);
              changes += "slogan: ${args['slogan']}, ";
            }
            if (args.containsKey('phone')) {
              updated = updated.copyWith(phone: args['phone'] as String);
              changes += "téléphone: ${args['phone']}, ";
            }
            if (args.containsKey('whatsapp')) {
              updated = updated.copyWith(whatsapp: args['whatsapp'] as String);
              changes += "WhatsApp: ${args['whatsapp']}, ";
            }
            if (args.containsKey('address')) {
              updated = updated.copyWith(address: args['address'] as String);
              changes += "adresse: ${args['address']}, ";
            }
            if (args.containsKey('email')) {
              updated = updated.copyWith(email: args['email'] as String);
              changes += "email: ${args['email']}, ";
            }
            if (args.containsKey('currency')) {
              updated = updated.copyWith(currency: args['currency'] as String);
              changes += "devise: ${args['currency']}, ";
            }
            if (args.containsKey('tax_rate')) {
              updated = updated.copyWith(taxRate: (args['tax_rate'] as num).toDouble(), useTax: true);
              changes += "taux de taxe: ${args['tax_rate']}%, ";
            }
            if (args.containsKey('use_tax')) {
              updated = updated.copyWith(useTax: args['use_tax'] as bool);
              changes += "application taxe: ${args['use_tax']}, ";
            }
            if (args.containsKey('thermal_printer_name')) {
              updated = updated.copyWith(thermalPrinterName: args['thermal_printer_name'] as String);
              changes += "imprimante ticket: ${args['thermal_printer_name']}, ";
            }
            if (args.containsKey('invoice_printer_name')) {
              updated = updated.copyWith(invoicePrinterName: args['invoice_printer_name'] as String);
              changes += "imprimante facture: ${args['invoice_printer_name']}, ";
            }
            if (args.containsKey('quote_printer_name')) {
              updated = updated.copyWith(quotePrinterName: args['quote_printer_name'] as String);
              changes += "imprimante devis: ${args['quote_printer_name']}, ";
            }
            if (args.containsKey('label_printer_name')) {
              updated = updated.copyWith(labelPrinterName: args['label_printer_name'] as String);
              changes += "imprimante étiquette: ${args['label_printer_name']}, ";
            }
            if (args.containsKey('open_cash_drawer')) {
              updated = updated.copyWith(openCashDrawer: args['open_cash_drawer'] as bool);
              changes += "tiroir-caisse automatique: ${args['open_cash_drawer']}, ";
            }
            if (args.containsKey('auto_print_ticket')) {
              updated = updated.copyWith(autoPrintTicket: args['auto_print_ticket'] as bool);
              changes += "impression auto ticket: ${args['auto_print_ticket']}, ";
            }
            if (args.containsKey('direct_physical_printing')) {
              updated = updated.copyWith(directPhysicalPrinting: args['direct_physical_printing'] as bool);
              changes += "impression physique directe: ${args['direct_physical_printing']}, ";
            }
            if (args.containsKey('show_preview_before_print')) {
              updated = updated.copyWith(showPreviewBeforePrint: args['show_preview_before_print'] as bool);
              changes += "aperçu avant impression: ${args['show_preview_before_print']}, ";
            }
            if (args.containsKey('customer_display_theme')) {
              updated = updated.copyWith(customerDisplayTheme: args['customer_display_theme'] as String);
              changes += "thème afficheur: ${args['customer_display_theme']}, ";
            }
            if (args.containsKey('enable_customer_display_sounds')) {
              updated = updated.copyWith(enableCustomerDisplaySounds: args['enable_customer_display_sounds'] as bool);
              changes += "sons afficheur: ${args['enable_customer_display_sounds']}, ";
            }
            if (args.containsKey('use_customer_display_3d')) {
              updated = updated.copyWith(useCustomerDisplay3D: args['use_customer_display_3d'] as bool);
              changes += "3D afficheur: ${args['use_customer_display_3d']}, ";
            }
            if (args.containsKey('is_voice_enabled')) {
              updated = updated.copyWith(isVoiceEnabled: args['is_voice_enabled'] as bool);
              changes += "voix afficheur: ${args['is_voice_enabled']}, ";
            }
            if (args.containsKey('enable_customer_display_ticker')) {
              updated = updated.copyWith(enableCustomerDisplayTicker: args['enable_customer_display_ticker'] as bool);
              changes += "bandeau défilant: ${args['enable_customer_display_ticker']}, ";
            }
            if (args.containsKey('customer_display_messages')) {
              final msgs = (args['customer_display_messages'] as List).map((e) => e.toString()).toList();
              updated = updated.copyWith(customerDisplayMessages: msgs);
              changes += "messages afficheur: ${msgs.join(' | ')}, ";
            }
            if (args.containsKey('rc')) {
              updated = updated.copyWith(rc: args['rc'] as String);
              changes += "RC: ${args['rc']}, ";
            }
            if (args.containsKey('nif')) {
              updated = updated.copyWith(nif: args['nif'] as String);
              changes += "NIF: ${args['nif']}, ";
            }
            if (args.containsKey('bank_account')) {
              updated = updated.copyWith(bankAccount: args['bank_account'] as String);
              changes += "coordonnées bancaires: ${args['bank_account']}, ";
            }
            if (args.containsKey('legal_form')) {
              updated = updated.copyWith(legalForm: args['legal_form'] as String);
              changes += "forme juridique: ${args['legal_form']}, ";
            }
            if (args.containsKey('capital')) {
              updated = updated.copyWith(capital: args['capital'] as String);
              changes += "capital: ${args['capital']}, ";
            }
            if (args.containsKey('tax_name')) {
              updated = updated.copyWith(taxName: args['tax_name'] as String);
              changes += "nom taxe: ${args['tax_name']}, ";
            }
            if (args.containsKey('receipt_footer')) {
              updated = updated.copyWith(receiptFooter: args['receipt_footer'] as String);
              changes += "pied ticket: ${args['receipt_footer']}, ";
            }
            if (args.containsKey('quote_validity_days')) {
              updated = updated.copyWith(quoteValidityDays: (args['quote_validity_days'] as num).toInt());
              changes += "validité devis: ${args['quote_validity_days']} jours, ";
            }
            if (args.containsKey('invoice_legal_note')) {
              updated = updated.copyWith(invoiceLegalNote: args['invoice_legal_note'] as String);
              changes += "note légale facture: ${args['invoice_legal_note']}, ";
            }
            if (args.containsKey('default_receipt')) {
              final val = args['default_receipt'] as String;
              for (final t in ReceiptTemplate.values) {
                if (t.name.toLowerCase() == val.toLowerCase()) {
                  updated = updated.copyWith(defaultReceipt: t);
                  changes += "modèle reçu: $val, ";
                  break;
                }
              }
            }
            if (args.containsKey('default_invoice')) {
              final val = args['default_invoice'] as String;
              for (final t in InvoiceTemplate.values) {
                if (t.name.toLowerCase() == val.toLowerCase()) {
                  updated = updated.copyWith(defaultInvoice: t);
                  changes += "modèle facture: $val, ";
                  break;
                }
              }
            }
            if (args.containsKey('default_quote')) {
              final val = args['default_quote'] as String;
              for (final t in QuoteTemplate.values) {
                if (t.name.toLowerCase() == val.toLowerCase()) {
                  updated = updated.copyWith(defaultQuote: t);
                  changes += "modèle devis: $val, ";
                  break;
                }
              }
            }
            if (args.containsKey('default_purchase_order')) {
              final val = args['default_purchase_order'] as String;
              for (final t in PurchaseOrderTemplate.values) {
                if (t.name.toLowerCase() == val.toLowerCase()) {
                  updated = updated.copyWith(defaultPurchaseOrder: t);
                  changes += "modèle commande: $val, ";
                  break;
                }
              }
            }
            if (args.containsKey('thermal_format')) {
              final val = args['thermal_format'] as String;
              if (val == 'mm58') {
                updated = updated.copyWith(thermalFormat: ThermalPaperFormat.mm58);
                changes += "format thermique: 58mm, ";
              } else if (val == 'mm80') {
                updated = updated.copyWith(thermalFormat: ThermalPaperFormat.mm80);
                changes += "format thermique: 80mm, ";
              }
            }
            if (args.containsKey('max_discount_threshold')) {
              updated = updated.copyWith(maxDiscountThreshold: (args['max_discount_threshold'] as num).toDouble());
              changes += "seuil remise max: ${args['max_discount_threshold']}%, ";
            }
            if (args.containsKey('vip_threshold')) {
              updated = updated.copyWith(vipThreshold: (args['vip_threshold'] as num).toDouble());
              changes += "seuil VIP: ${args['vip_threshold']} FCFA, ";
            }
            if (args.containsKey('loyalty_enabled')) {
              updated = updated.copyWith(loyaltyEnabled: args['loyalty_enabled'] as bool);
              changes += "fidélité activée: ${args['loyalty_enabled']}, ";
            }
            if (args.containsKey('points_per_amount')) {
              updated = updated.copyWith(pointsPerAmount: (args['points_per_amount'] as num).toDouble());
              changes += "montant pour 1 point: ${args['points_per_amount']} FCFA, ";
            }
            if (args.containsKey('amount_per_point')) {
              updated = updated.copyWith(amountPerPoint: (args['amount_per_point'] as num).toDouble());
              changes += "valeur du point: ${args['amount_per_point']} FCFA, ";
            }
            if (args.containsKey('is_auto_lock_enabled')) {
              updated = updated.copyWith(isAutoLockEnabled: args['is_auto_lock_enabled'] as bool);
              changes += "verrouillage automatique: ${args['is_auto_lock_enabled']}, ";
            }
            if (args.containsKey('auto_lock_minutes')) {
              updated = updated.copyWith(autoLockMinutes: (args['auto_lock_minutes'] as num).toInt());
              changes += "délai verrouillage: ${args['auto_lock_minutes']} min, ";
            }
            if (args.containsKey('show_tax_on_tickets')) {
              updated = updated.copyWith(showTaxOnTickets: args['show_tax_on_tickets'] as bool);
              changes += "taxe sur tickets: ${args['show_tax_on_tickets']}, ";
            }
            if (args.containsKey('show_tax_on_invoices')) {
              updated = updated.copyWith(showTaxOnInvoices: args['show_tax_on_invoices'] as bool);
              changes += "taxe sur factures: ${args['show_tax_on_invoices']}, ";
            }
            if (args.containsKey('show_tax_on_quotes')) {
              updated = updated.copyWith(showTaxOnQuotes: args['show_tax_on_quotes'] as bool);
              changes += "taxe sur devis: ${args['show_tax_on_quotes']}, ";
            }
            if (args.containsKey('use_detailed_tax_on_tickets')) {
              updated = updated.copyWith(useDetailedTaxOnTickets: args['use_detailed_tax_on_tickets'] as bool);
              changes += "taxe détaillée tickets: ${args['use_detailed_tax_on_tickets']}, ";
            }
            if (args.containsKey('use_detailed_tax_on_invoices')) {
              updated = updated.copyWith(useDetailedTaxOnInvoices: args['use_detailed_tax_on_invoices'] as bool);
              changes += "taxe détaillée factures: ${args['use_detailed_tax_on_invoices']}, ";
            }
            if (args.containsKey('use_detailed_tax_on_quotes')) {
              updated = updated.copyWith(useDetailedTaxOnQuotes: args['use_detailed_tax_on_quotes'] as bool);
              changes += "taxe détaillée devis: ${args['use_detailed_tax_on_quotes']}, ";
            }
            if (args.containsKey('allow_cloud_ai_actions')) {
              updated = updated.copyWith(allowCloudAiActions: args['allow_cloud_ai_actions'] as bool);
              changes += "actions IA cloud autorisées: ${args['allow_cloud_ai_actions']}, ";
            }
            if (args.containsKey('remove_decimals')) {
              updated = updated.copyWith(removeDecimals: args['remove_decimals'] as bool);
              changes += "masquer décimales: ${args['remove_decimals']}, ";
            }
            if (args.containsKey('show_qr_code')) {
              updated = updated.copyWith(showQrCode: args['show_qr_code'] as bool);
              changes += "afficher QR code: ${args['show_qr_code']}, ";
            }
            if (args.containsKey('use_auto_ref')) {
              updated = updated.copyWith(useAutoRef: args['use_auto_ref'] as bool);
              changes += "référence auto: ${args['use_auto_ref']}, ";
            }
            if (args.containsKey('ref_prefix')) {
              updated = updated.copyWith(refPrefix: args['ref_prefix'] as String);
              changes += "préfixe référence: ${args['ref_prefix']}, ";
            }
            if (args.containsKey('ref_model')) {
              final val = args['ref_model'] as String;
              for (final e in ReferenceGenerationModel.values) {
                if (e.name.toLowerCase() == val.toLowerCase()) {
                  updated = updated.copyWith(refModel: e);
                  changes += "modèle réf: $val, ";
                  break;
                }
              }
            }
            if (args.containsKey('barcode_model')) {
              final val = args['barcode_model'] as String;
              for (final e in BarcodeGenerationModel.values) {
                if (e.name.toLowerCase() == val.toLowerCase()) {
                  updated = updated.copyWith(barcodeModel: e);
                  changes += "modèle code-barres: $val, ";
                  break;
                }
              }
            }
            if (args.containsKey('auto_backup_enabled')) {
              updated = updated.copyWith(autoBackupEnabled: args['auto_backup_enabled'] as bool);
              changes += "sauvegarde auto locale: ${args['auto_backup_enabled']}, ";
            }
            if (args.containsKey('policy_warranty')) {
              updated = updated.copyWith(policyWarranty: args['policy_warranty'] as String);
              changes += "politique garantie: ${args['policy_warranty']}, ";
            }
            if (args.containsKey('policy_returns')) {
              updated = updated.copyWith(policyReturns: args['policy_returns'] as String);
              changes += "politique retours: ${args['policy_returns']}, ";
            }
            if (args.containsKey('policy_payments')) {
              updated = updated.copyWith(policyPayments: args['policy_payments'] as String);
              changes += "politique paiements: ${args['policy_payments']}, ";
            }
            if (args.containsKey('purchase_order_printer_name')) {
              updated = updated.copyWith(purchaseOrderPrinterName: args['purchase_order_printer_name'] as String);
              changes += "imprimante commande: ${args['purchase_order_printer_name']}, ";
            }
            if (args.containsKey('contract_printer_name')) {
              updated = updated.copyWith(contractPrinterName: args['contract_printer_name'] as String);
              changes += "imprimante contrat: ${args['contract_printer_name']}, ";
            }
            if (args.containsKey('payroll_printer_name')) {
              updated = updated.copyWith(payrollPrinterName: args['payroll_printer_name'] as String);
              changes += "imprimante paie: ${args['payroll_printer_name']}, ";
            }
            if (args.containsKey('report_printer_name')) {
              updated = updated.copyWith(reportPrinterName: args['report_printer_name'] as String);
              changes += "imprimante rapport: ${args['report_printer_name']}, ";
            }
            if (args.containsKey('proforma_printer_name')) {
              updated = updated.copyWith(proformaPrinterName: args['proforma_printer_name'] as String);
              changes += "imprimante proforma: ${args['proforma_printer_name']}, ";
            }
            if (args.containsKey('delivery_printer_name')) {
              updated = updated.copyWith(deliveryPrinterName: args['delivery_printer_name'] as String);
              changes += "imprimante livraison: ${args['delivery_printer_name']}, ";
            }
            if (args.containsKey('auto_print_delivery_note')) {
              updated = updated.copyWith(autoPrintDeliveryNote: args['auto_print_delivery_note'] as bool);
              changes += "impression auto livraison: ${args['auto_print_delivery_note']}, ";
            }
            if (args.containsKey('show_price_on_labels')) {
              updated = updated.copyWith(showPriceOnLabels: args['show_price_on_labels'] as bool);
              changes += "prix sur étiquettes: ${args['show_price_on_labels']}, ";
            }
            if (args.containsKey('show_name_on_labels')) {
              updated = updated.copyWith(showNameOnLabels: args['show_name_on_labels'] as bool);
              changes += "nom sur étiquettes: ${args['show_name_on_labels']}, ";
            }
            if (args.containsKey('show_sku_on_labels')) {
              updated = updated.copyWith(showSkuOnLabels: args['show_sku_on_labels'] as bool);
              changes += "référence sur étiquettes: ${args['show_sku_on_labels']}, ";
            }
            if (args.containsKey('auto_print_labels_on_stock_in')) {
              updated = updated.copyWith(autoPrintLabelsOnStockIn: args['auto_print_labels_on_stock_in'] as bool);
              changes += "impression auto étiquettes entrée: ${args['auto_print_labels_on_stock_in']}, ";
            }
            if (args.containsKey('show_assistant')) {
              updated = updated.copyWith(showAssistant: args['show_assistant'] as bool);
              changes += "afficher assistant: ${args['show_assistant']}, ";
            }
            if (args.containsKey('network_mode')) {
              final val = args['network_mode'] as String;
              for (final e in NetworkMode.values) {
                if (e.name.toLowerCase() == val.toLowerCase()) {
                  updated = updated.copyWith(networkMode: e);
                  changes += "mode réseau: $val, ";
                  break;
                }
              }
            }
            if (args.containsKey('server_ip')) {
              updated = updated.copyWith(serverIp: args['server_ip'] as String);
              changes += "serveur IP: ${args['server_ip']}, ";
            }
            if (args.containsKey('server_port')) {
              updated = updated.copyWith(serverPort: (args['server_port'] as num).toInt());
              changes += "serveur port: ${args['server_port']}, ";
            }
            if (args.containsKey('sync_key')) {
              updated = updated.copyWith(syncKey: args['sync_key'] as String);
              changes += "clé de sync: ${args['sync_key']}, ";
            }
            if (args.containsKey('rounding_mode')) {
              final val = args['rounding_mode'] as String;
              for (final e in RoundingMode.values) {
                if (e.name.toLowerCase() == val.toLowerCase()) {
                  updated = updated.copyWith(roundingMode: e);
                  changes += "mode arrondi: $val, ";
                  break;
                }
              }
            }
            if (args.containsKey('label_ht')) {
              updated = updated.copyWith(labelHT: args['label_ht'] as String);
              changes += "libellé HT: ${args['label_ht']}, ";
            }
            if (args.containsKey('label_ttc')) {
              updated = updated.copyWith(labelTTC: args['label_ttc'] as String);
              changes += "libellé TTC: ${args['label_ttc']}, ";
            }
            if (args.containsKey('title_invoice')) {
              updated = updated.copyWith(titleInvoice: args['title_invoice'] as String);
              changes += "titre facture: ${args['title_invoice']}, ";
            }
            if (args.containsKey('title_receipt')) {
              updated = updated.copyWith(titleReceipt: args['title_receipt'] as String);
              changes += "titre ticket: ${args['title_receipt']}, ";
            }
            if (args.containsKey('title_receipt_proforma')) {
              updated = updated.copyWith(titleReceiptProforma: args['title_receipt_proforma'] as String);
              changes += "titre ticket proforma: ${args['title_receipt_proforma']}, ";
            }
            if (args.containsKey('title_quote')) {
              updated = updated.copyWith(titleQuote: args['title_quote'] as String);
              changes += "titre devis: ${args['title_quote']}, ";
            }
            if (args.containsKey('title_proforma')) {
              updated = updated.copyWith(titleProforma: args['title_proforma'] as String);
              changes += "titre proforma: ${args['title_proforma']}, ";
            }
            if (args.containsKey('title_delivery_note')) {
              updated = updated.copyWith(titleDeliveryNote: args['title_delivery_note'] as String);
              changes += "titre bon livraison: ${args['title_delivery_note']}, ";
            }
            if (args.containsKey('margin_ticket_top')) {
              updated = updated.copyWith(marginTicketTop: (args['margin_ticket_top'] as num).toDouble());
              changes += "marge ticket sup: ${args['margin_ticket_top']}pt, ";
            }
            if (args.containsKey('margin_ticket_bottom')) {
              updated = updated.copyWith(marginTicketBottom: (args['margin_ticket_bottom'] as num).toDouble());
              changes += "marge ticket inf: ${args['margin_ticket_bottom']}pt, ";
            }
            if (args.containsKey('margin_ticket_left')) {
              updated = updated.copyWith(marginTicketLeft: (args['margin_ticket_left'] as num).toDouble());
              changes += "marge ticket gauche: ${args['margin_ticket_left']}pt, ";
            }
            if (args.containsKey('margin_ticket_right')) {
              updated = updated.copyWith(marginTicketRight: (args['margin_ticket_right'] as num).toDouble());
              changes += "marge ticket droite: ${args['margin_ticket_right']}pt, ";
            }
            if (args.containsKey('margin_invoice_top')) {
              updated = updated.copyWith(marginInvoiceTop: (args['margin_invoice_top'] as num).toDouble());
              changes += "marge facture sup: ${args['margin_invoice_top']}pt, ";
            }
            if (args.containsKey('margin_invoice_bottom')) {
              updated = updated.copyWith(marginInvoiceBottom: (args['margin_invoice_bottom'] as num).toDouble());
              changes += "marge facture inf: ${args['margin_invoice_bottom']}pt, ";
            }
            if (args.containsKey('margin_invoice_left')) {
              updated = updated.copyWith(marginInvoiceLeft: (args['margin_invoice_left'] as num).toDouble());
              changes += "marge facture gauche: ${args['margin_invoice_left']}pt, ";
            }
            if (args.containsKey('margin_invoice_right')) {
              updated = updated.copyWith(marginInvoiceRight: (args['margin_invoice_right'] as num).toDouble());
              changes += "marge facture droite: ${args['margin_invoice_right']}pt, ";
            }
            if (args.containsKey('margin_label_x')) {
              updated = updated.copyWith(marginLabelX: (args['margin_label_x'] as num).toDouble());
              changes += "marge étiquette horiz: ${args['margin_label_x']}pt, ";
            }
            if (args.containsKey('margin_label_y')) {
              updated = updated.copyWith(marginLabelY: (args['margin_label_y'] as num).toDouble());
              changes += "marge étiquette vert: ${args['margin_label_y']}pt, ";
            }
            if (args.containsKey('email_backup_enabled')) {
              updated = updated.copyWith(emailBackupEnabled: args['email_backup_enabled'] as bool);
              changes += "backup email activé: ${args['email_backup_enabled']}, ";
            }
            if (args.containsKey('backup_email_recipient')) {
              updated = updated.copyWith(backupEmailRecipient: args['backup_email_recipient'] as String);
              changes += "destinataire backup: ${args['backup_email_recipient']}, ";
            }
            if (args.containsKey('smtp_host')) {
              updated = updated.copyWith(smtpHost: args['smtp_host'] as String);
              changes += "serveur SMTP: ${args['smtp_host']}, ";
            }
            if (args.containsKey('smtp_port')) {
              updated = updated.copyWith(smtpPort: (args['smtp_port'] as num).toInt());
              changes += "port SMTP: ${args['smtp_port']}, ";
            }
            if (args.containsKey('smtp_user')) {
              updated = updated.copyWith(smtpUser: args['smtp_user'] as String);
              changes += "utilisateur SMTP: ${args['smtp_user']}, ";
            }
            if (args.containsKey('smtp_password')) {
              updated = updated.copyWith(smtpPassword: args['smtp_password'] as String);
              changes += "mot de passe SMTP mis à jour, ";
            }
            if (args.containsKey('email_backup_frequency')) {
              final val = args['email_backup_frequency'] as String;
              for (final e in EmailBackupFrequency.values) {
                if (e.name.toLowerCase() == val.toLowerCase()) {
                  updated = updated.copyWith(emailBackupFrequency: e);
                  changes += "fréquence backup email: $val, ";
                  break;
                }
              }
            }
            if (args.containsKey('email_backup_hour')) {
              updated = updated.copyWith(emailBackupHour: (args['email_backup_hour'] as num).toInt());
              changes += "heure backup: ${args['email_backup_hour']}h, ";
            }
            if (args.containsKey('report_email_enabled')) {
              updated = updated.copyWith(reportEmailEnabled: args['report_email_enabled'] as bool);
              changes += "rapports email activés: ${args['report_email_enabled']}, ";
            }
            if (args.containsKey('stock_alerts_enabled')) {
              updated = updated.copyWith(stockAlertsEnabled: args['stock_alerts_enabled'] as bool);
              changes += "alertes stock email: ${args['stock_alerts_enabled']}, ";
            }
            if (args.containsKey('report_email_frequency')) {
              final val = args['report_email_frequency'] as String;
              for (final e in EmailBackupFrequency.values) {
                if (e.name.toLowerCase() == val.toLowerCase()) {
                  updated = updated.copyWith(reportEmailFrequency: e);
                  changes += "fréquence rapports email: $val, ";
                  break;
                }
              }
            }
            if (args.containsKey('report_email_hour')) {
              updated = updated.copyWith(reportEmailHour: (args['report_email_hour'] as num).toInt());
              changes += "heure rapports email: ${args['report_email_hour']}h, ";
            }
            if (args.containsKey('report_email_day_of_week')) {
              updated = updated.copyWith(reportEmailDayOfWeek: (args['report_email_day_of_week'] as num).toInt());
              changes += "jour rapports email: ${args['report_email_day_of_week']}, ";
            }
            if (args.containsKey('marketing_emails_enabled')) {
              updated = updated.copyWith(marketingEmailsEnabled: args['marketing_emails_enabled'] as bool);
              changes += "campagnes emails activées: ${args['marketing_emails_enabled']}, ";
            }
            if (args.containsKey('inactivity_reminder_enabled')) {
              updated = updated.copyWith(inactivityReminderEnabled: args['inactivity_reminder_enabled'] as bool);
              changes += "relances inactivité: ${args['inactivity_reminder_enabled']}, ";
            }
            if (args.containsKey('inactivity_days_threshold')) {
              updated = updated.copyWith(inactivityDaysThreshold: (args['inactivity_days_threshold'] as num).toInt());
              changes += "seuil inactivité: ${args['inactivity_days_threshold']} jours, ";
            }
            if (args.containsKey('enable_sounds')) {
              updated = updated.copyWith(enableSounds: args['enable_sounds'] as bool);
              changes += "sons activés: ${args['enable_sounds']}, ";
            }
            if (args.containsKey('enable_app_sounds')) {
              updated = updated.copyWith(enableAppSounds: args['enable_app_sounds'] as bool);
              changes += "sons application: ${args['enable_app_sounds']}, ";
            }
            if (args.containsKey('hr_show_signature_lines')) {
              updated = updated.copyWith(hrShowSignatureLines: args['hr_show_signature_lines'] as bool);
              changes += "signatures documents RH: ${args['hr_show_signature_lines']}, ";
            }
            if (args.containsKey('assistant_level')) {
              final val = args['assistant_level'] as String;
              for (final e in AssistantPowerLevel.values) {
                if (e.name.toLowerCase() == val.toLowerCase()) {
                  updated = updated.copyWith(assistantLevel: e);
                  changes += "niveau assistant: $val, ";
                  break;
                }
              }
            }
            if (args.containsKey('is_ai_enabled')) {
              updated = updated.copyWith(isAiEnabled: args['is_ai_enabled'] as bool);
              changes += "IA activée: ${args['is_ai_enabled']}, ";
            }
            if (args.containsKey('enable_voice_config')) {
              updated = updated.copyWith(enableVoiceConfig: args['enable_voice_config'] as bool);
              changes += "configuration vocale activée: ${args['enable_voice_config']}, ";
            }
            if (args.containsKey('use_cloud_ai')) {
              updated = updated.copyWith(useCloudAi: args['use_cloud_ai'] as bool);
              changes += "IA cloud activée: ${args['use_cloud_ai']}, ";
            }
            if (args.containsKey('cloud_ai_provider')) {
              updated = updated.copyWith(cloudAiProvider: args['cloud_ai_provider'] as String);
              changes += "fournisseur IA cloud: ${args['cloud_ai_provider']}, ";
            }
            if (args.containsKey('deepseek_api_key')) {
              updated = updated.copyWith(deepSeekApiKey: args['deepseek_api_key'] as String);
              changes += "clé API DeepSeek mise à jour, ";
            }
            if (args.containsKey('gemini_api_key')) {
              updated = updated.copyWith(geminiApiKey: args['gemini_api_key'] as String);
              changes += "clé API Gemini mise à jour, ";
            }
            if (args.containsKey('elevenlabs_api_key')) {
              updated = updated.copyWith(elevenLabsApiKey: args['elevenlabs_api_key'] as String);
              changes += "clé API ElevenLabs mise à jour, ";
            }
            if (args.containsKey('elevenlabs_voice_id')) {
              updated = updated.copyWith(elevenLabsVoiceId: args['elevenlabs_voice_id'] as String);
              changes += "voix ElevenLabs: ${args['elevenlabs_voice_id']}, ";
            }
            if (args.containsKey('whatsapp_token')) {
              updated = updated.copyWith(whatsappToken: args['whatsapp_token'] as String);
              changes += "token WhatsApp mis à jour, ";
            }
            if (args.containsKey('whatsapp_phone_number_id')) {
              updated = updated.copyWith(whatsappPhoneNumberId: args['whatsapp_phone_number_id'] as String);
              changes += "id numéro WhatsApp: ${args['whatsapp_phone_number_id']}, ";
            }
            if (args.containsKey('show_tax_on_delivery_notes')) {
              updated = updated.copyWith(showTaxOnDeliveryNotes: args['show_tax_on_delivery_notes'] as bool);
              changes += "taxe bon livraison: ${args['show_tax_on_delivery_notes']}, ";
            }
            if (args.containsKey('use_detailed_tax_on_delivery_notes')) {
              updated = updated.copyWith(useDetailedTaxOnDeliveryNotes: args['use_detailed_tax_on_delivery_notes'] as bool);
              changes += "taxe détaillée livraison: ${args['use_detailed_tax_on_delivery_notes']}, ";
            }
            
            await ref.read(shopSettingsProvider.notifier).save(updated);
            success = true;
            responseOutput = {'success': true, 'changes': changes};
            ref.read(proactiveAlertProvider.notifier).set(
              ProactiveAlertData(
                title: "Paramètres Modifiés",
                message: "Changements de configuration appliqués par l'assistant.",
              ),
            );
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "⚙️ **Configuration mise à jour** : $changes"
            );
          }
        }
      } else if (name == 'add_product') {
        if (!hasPermission((u) => u.canManageInventory)) {
          responseOutput = {'success': false, 'error': 'Permission refusée. Impossible de créer un produit.'};
          ref.read(proactiveAlertProvider.notifier).set(
            ProactiveAlertData(
              title: "Permission Refusée",
              message: "Création de produit refusée : permission insuffisante.",
            ),
          );
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "⚠️ **Action refusée** : Votre profil n'a pas l'autorisation d'ajouter des produits au stock."
          );
        } else {
          final prodName = args['name'] as String;
          final sellingPrice = expandVoiceAmount((args['selling_price'] as num).toDouble());
          final purchasePrice = args['purchase_price'] != null 
              ? expandVoiceAmount((args['purchase_price'] as num).toDouble()) 
              : 0.0;
          final quantity = (args['quantity'] as num? ?? 0.0).toDouble();
          final category = args['category'] as String?;

          if (sellingPrice > 50000000.0) {
            responseOutput = {'success': false, 'error': 'Prix trop élevé. Limite de sécurité de 50 000 000 FCFA par produit vocal.'};
            ref.read(proactiveAlertProvider.notifier).set(
              ProactiveAlertData(
                title: "Prix Bloqué",
                message: "Le prix de $sellingPrice FCFA dépasse la limite de sécurité.",
              ),
            );
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🛡️ **Sécurité anti-bêtise** : Le prix de vente saisi (**$sellingPrice FCFA**) dépasse la limite de sécurité autorisée pour la création vocale (50 000 000 FCFA)."
            );
            _liveService?.sendToolResponse(callId, responseOutput);
            return;
          }

          final product = Product(
            id: "prod_${DateTime.now().millisecondsSinceEpoch}",
            name: prodName,
            sellingPrice: sellingPrice,
            purchasePrice: purchasePrice,
            quantity: quantity,
            category: category,
            alertThreshold: 5.0,
          );

          await ref.read(productListProvider.notifier).addProduct(product);
          success = true;
          responseOutput = {
            'success': true,
            'product_id': product.id,
            'name': product.name,
          };

          ref.read(proactiveAlertProvider.notifier).set(
            ProactiveAlertData(
              title: "Produit Ajouté",
              message: "Le produit '$prodName' a été ajouté avec succès au stock.",
            ),
          );

          ref.read(assistantProvider.notifier).addAssistantMessage(
            "📦 **Nouveau produit ajouté** :\n"
            "• Nom : **$prodName**\n"
            "• Prix de vente : **$sellingPrice FCFA**\n"
            "• Quantité initiale : **$quantity**\n"
            "• Catégorie : **${category ?? 'Non spécifiée'}**"
          );

          final assistantNotifier = ref.read(assistantProvider.notifier);
          if (assistantNotifier.onAction != null) {
            assistantNotifier.onAction!('navigate', payload: 1); // 1 = stock
          }
        }
      } else if (name == 'search_product') {
        if (!hasPermission((u) => u.canManageInventory || u.canSell)) {
          responseOutput = {'success': false, 'error': 'Permission refusée. Lecture des produits non autorisée.'};
        } else {
          final query = args['query'] as String;
          final products = await ref.read(productListProvider.future);
          final queryLower = query.toLowerCase();

          final matches = products.where((p) => p.name.toLowerCase().contains(queryLower)).toList();
          if (matches.isEmpty && queryLower.length > 3) {
            for (final p in products) {
              final sim = math.max(
                NlpEngine.similarity(queryLower, p.name.toLowerCase()),
                NlpEngine.phoneticSimilarity(queryLower, p.name.toLowerCase()),
              );
              if (sim >= 0.6) {
                matches.add(p);
              }
            }
          }

          final results = matches.map((p) => {
            'id': p.id,
            'name': p.name,
            'quantity': p.quantity,
            'selling_price': p.sellingPrice,
            'purchase_price': p.purchasePrice,
            'category': p.category,
            'unit': p.unit,
            'is_low_stock': p.isLowStock,
            'is_out_of_stock': p.isOutOfStock,
          }).toList();

          success = true;
          responseOutput = {
            'success': true,
            'products': results,
          };

          if (matches.isEmpty) {
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🔍 **Recherche produit** pour '$query' :\nAucun produit trouvé."
            );
          } else {
            final listText = matches.take(3).map((p) => "• **${p.name}** (${p.quantity} ${p.unit}) - PV: **${p.sellingPrice} FCFA**").join("\n");
            final extraText = matches.length > 3 ? "\n*(...et ${matches.length - 3} autres)*" : "";
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🔍 **Recherche produit** pour '$query' :\n$listText$extraText"
            );
          }
        }
      } else if (name == 'get_stock_info') {
        if (!hasPermission((u) => u.canManageInventory || u.canAccessReports)) {
          responseOutput = {'success': false, 'error': 'Permission refusée. Lecture des infos stock non autorisée.'};
        } else {
          final products = await ref.read(productListProvider.future);
          final stats = StockStats.fromProducts(products);
          success = true;
          responseOutput = {
            'success': true,
            'total_products': stats.totalProducts,
            'total_quantity': stats.totalQuantity,
            'total_stock_value': stats.totalStockValue,
            'low_stock_count': stats.lowStockCount,
            'out_of_stock_count': stats.outOfStockCount,
            'potential_revenue': stats.totalPotentialRevenue,
          };

          ref.read(assistantProvider.notifier).addAssistantMessage(
            "📊 **Résumé du stock** :\n"
            "• Total produits distincts : **${stats.totalProducts}**\n"
            "• Valeur d'achat totale : **${stats.totalStockValue.toStringAsFixed(0)} FCFA**\n"
            "• Produits en alerte stock faible : **${stats.lowStockCount}**\n"
            "• Produits en rupture complète : **${stats.outOfStockCount}**"
          );
        }
      } else if (name == 'add_client') {
        if (!hasPermission((u) => u.canManageCustomers)) {
          responseOutput = {'success': false, 'error': 'Permission refusée. Impossible d\'ajouter un client.'};
          ref.read(proactiveAlertProvider.notifier).set(
            ProactiveAlertData(
              title: "Permission Refusée",
              message: "Ajout de client refusé : permission insuffisante.",
            ),
          );
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "⚠️ **Action refusée** : Votre profil n'a pas l'autorisation d'ajouter des clients."
          );
        } else {
          final clientName = args['name'] as String;
          final phone = args['phone'] as String? ?? '';
          final address = args['address'] as String? ?? '';

          final client = Client(
            id: "cli_${DateTime.now().millisecondsSinceEpoch}",
            name: clientName,
            phone: phone,
            address: address,
            email: '',
            credit: 0.0,
            maxCredit: 50000.0,
            loyaltyPoints: 0,
          );

          await ref.read(clientListProvider.notifier).addClient(client);
          success = true;
          responseOutput = {
            'success': true,
            'client_id': client.id,
            'name': client.name,
          };

          ref.read(proactiveAlertProvider.notifier).set(
            ProactiveAlertData(
              title: "Client Ajouté",
              message: "Le client '$clientName' a été créé avec succès.",
            ),
          );

          final isPos = ref.read(assistantProvider).currentContext == AssistantContext.pos;
          if (isPos) {
            ref.read(selectedClientIdProvider.notifier).setClient(client.id);
            ref.read(cartProvider.notifier).forceBroadcast();
            
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "👥 **Client créé et associé à la vente** :\n"
              "• Nom : **$clientName**\n"
              "• Téléphone : **${phone.isNotEmpty ? phone : 'Non spécifié'}**\n"
              "• Adresse : **${address.isNotEmpty ? address : 'Non spécifiée'}**"
            );
          } else {
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "👥 **Nouveau client créé** :\n"
              "• Nom : **$clientName**\n"
              "• Téléphone : **${phone.isNotEmpty ? phone : 'Non spécifié'}**\n"
              "• Adresse : **${address.isNotEmpty ? address : 'Non spécifiée'}**"
            );

            final assistantNotifier = ref.read(assistantProvider.notifier);
            if (assistantNotifier.onAction != null) {
              assistantNotifier.onAction!('navigate', payload: 7); // 7 = clients
            }
          }
        }
      } else if (name == 'get_client_info') {
        if (!hasPermission((u) => u.canManageCustomers || u.canAccessFinance)) {
          responseOutput = {'success': false, 'error': 'Permission refusée. Lecture des infos client non autorisée.'};
        } else {
          final query = args['query'] as String;
          final clients = await ref.read(clientListProvider.future);
          final queryLower = query.toLowerCase();

          final matches = clients.where((c) => c.name.toLowerCase().contains(queryLower)).toList();
          if (matches.isEmpty && queryLower.length > 3) {
            for (final c in clients) {
              final sim = math.max(
                NlpEngine.similarity(queryLower, c.name.toLowerCase()),
                NlpEngine.phoneticSimilarity(queryLower, c.name.toLowerCase()),
              );
              if (sim >= 0.6) {
                matches.add(c);
              }
            }
          }

          final results = matches.map((c) => {
            'id': c.id,
            'name': c.name,
            'phone': c.phone,
            'address': c.address,
            'email': c.email,
            'credit': c.credit,
            'max_credit': c.maxCredit,
            'loyalty_points': c.loyaltyPoints,
          }).toList();

          success = true;
          responseOutput = {
            'success': true,
            'clients': results,
          };

          if (matches.isEmpty) {
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🔍 **Recherche client** pour '$query' :\nAucun client trouvé."
            );
          } else {
            final listText = matches.take(3).map((c) => "• **${c.name}** (Tél: ${c.phone != null && c.phone!.isNotEmpty ? c.phone! : 'N/A'}, Dette: **${c.credit} FCFA** - Points: ${c.loyaltyPoints})").join("\n");
            final extraText = matches.length > 3 ? "\n*(...et ${matches.length - 3} autres)*" : "";
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🔍 **Recherche client** pour '$query' :\n$listText$extraText"
            );
          }
        }
      } else if (name == 'select_client') {
        if (!hasPermission((u) => u.canSell)) {
          responseOutput = {'success': false, 'error': 'Permission refusée. Vente non autorisée.'};
        } else {
          final clientName = args['client_name'] as String;
          final clients = await ref.read(clientListProvider.future);
          final cleanQuery = clientName.trim().toLowerCase();
          
          Client? matchedClient;
          for (final c in clients) {
            if (c.name.trim().toLowerCase() == cleanQuery) {
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
            success = true;
            responseOutput = {
              'success': true,
              'client_id': matchedClient.id,
              'name': matchedClient.name,
            };
            
            ref.read(proactiveAlertProvider.notifier).set(
              ProactiveAlertData(
                title: "Client Associé",
                message: "Le client '${matchedClient.name}' a été lié à la vente.",
              ),
            );
            
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "👥 **Client associé** : Le client **${matchedClient.name}** a été lié à la vente en cours."
            );
            
            final assistantNotifier = ref.read(assistantProvider.notifier);
            if (assistantNotifier.onAction != null) {
              assistantNotifier.onAction!('navigate', payload: 3); // Caisse
            }
          } else {
            responseOutput = {'success': false, 'error': 'Client non trouvé.'};
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "⚠️ **Client non trouvé** : Je n'ai pas trouvé de client correspondant à '$clientName'."
            );
          }
        }
      } else if (name == 'get_sales_summary') {
        if (!hasPermission((u) => u.canAccessReports)) {
          responseOutput = {'success': false, 'error': 'Permission refusée. Lecture du résumé des ventes non autorisée.'};
        } else {
          final sales = await ref.read(salesHistoryProvider.future);
          final today = DateTime.now();
          final todaySales = sales.where((s) =>
              s.sale.date.year == today.year &&
              s.sale.date.month == today.month &&
              s.sale.date.day == today.day).toList();
          final totalToday = todaySales.fold(0.0, (sum, s) => sum + s.sale.totalAmount);

          final sevenDaysAgo = today.subtract(const Duration(days: 7));
          final salesLast7Days = sales.where((s) => s.sale.date.isAfter(sevenDaysAgo)).toList();
          final totalLast7Days = salesLast7Days.fold(0.0, (sum, s) => sum + s.sale.totalAmount);

          success = true;
          responseOutput = {
            'success': true,
            'sales_today_count': todaySales.length,
            'sales_today_total': totalToday,
            'sales_7days_count': salesLast7Days.length,
            'sales_7days_total': totalLast7Days,
          };

          ref.read(assistantProvider.notifier).addAssistantMessage(
            "💰 **Résumé des ventes** :\n"
            "• Aujourd'hui : **${totalToday.toStringAsFixed(0)} FCFA** (${todaySales.length} ventes)\n"
            "• 7 derniers jours : **${totalLast7Days.toStringAsFixed(0)} FCFA** (${salesLast7Days.length} ventes)"
          );
        }
      } else if (name == 'adjust_stock') {
        if (!hasPermission((u) => u.canManageInventory)) {
          responseOutput = {'success': false, 'error': 'Permission refusée. Ajustement de stock non autorisé.'};
          ref.read(proactiveAlertProvider.notifier).set(
            ProactiveAlertData(
              title: "Permission Refusée",
              message: "Ajustement de stock refusé : permission insuffisante.",
            ),
          );
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "⚠️ **Action refusée** : Votre profil n'a pas l'autorisation d'ajuster le stock."
          );
        } else {
          final prodName = args['product_name'] as String;
          final qty = (args['quantity'] as num).toDouble();

          // Guard: Limit stock adjustments to prevent "bêtises"
          if (qty.abs() > 100.0) {
            responseOutput = {'success': false, 'error': 'Ajustement trop élevé. Limite de sécurité de 100 unités par action vocale.'};
            ref.read(proactiveAlertProvider.notifier).set(
              ProactiveAlertData(
                title: "Ajustement Bloqué",
                message: "L'ajustement de $qty pour '$prodName' dépasse la limite de sécurité.",
              ),
            );
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🛡️ **Sécurité anti-erreur** : L'ajustement demandé de **$qty** pour **$prodName** dépasse la limite vocale autorisée (100 unités). Veuillez l'effectuer manuellement si nécessaire."
            );
            _liveService?.sendToolResponse(callId, responseOutput);
            return;
          }

          final products = await ref.read(productListProvider.future);

          final bestMatch = _findBestProductMatch(products, prodName, skipServices: true);

          if (bestMatch != null) {
            final updated = bestMatch.copyWith(quantity: bestMatch.quantity + qty);
            await ref.read(productListProvider.notifier).updateProduct(updated);
            success = true;
            responseOutput = {
              'success': true,
              'product_id': bestMatch.id,
              'name': bestMatch.name,
              'old_quantity': bestMatch.quantity,
              'new_quantity': updated.quantity,
            };

            ref.read(proactiveAlertProvider.notifier).set(
              ProactiveAlertData(
                title: "Stock Ajusté",
                message: "Le stock de '${bestMatch.name}' a été ajusté de $qty (Nouveau : ${updated.quantity}).",
              ),
            );

            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🔄 **Stock ajusté** :\n"
              "• Produit : **${bestMatch.name}**\n"
              "• Ajustement : **$qty**\n"
              "• Ancien stock : **${bestMatch.quantity}**\n"
              "• Nouveau stock : **${updated.quantity}**"
            );

            final assistantNotifier = ref.read(assistantProvider.notifier);
            if (assistantNotifier.onAction != null) {
              assistantNotifier.onAction!('navigate', payload: 1); // 1 = stock
            }
          } else {
            success = false;
            responseOutput = {
              'success': false,
              'error': 'Produit non trouvé en stock.',
            };
            ref.read(proactiveAlertProvider.notifier).set(
              ProactiveAlertData(
                title: "Erreur Stock",
                message: "Le produit '$prodName' n'a pas été trouvé pour ajustement.",
              ),
            );
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🔍 **Ajustement échoué** : Produit '$prodName' non trouvé en stock."
            );
          }
        }
      } else if (name == 'add_to_cart') {
        if (!hasPermission((u) => u.canSell)) {
          responseOutput = {'success': false, 'error': 'Permission refusée. Vente non autorisée.'};
          ref.read(proactiveAlertProvider.notifier).set(
            ProactiveAlertData(
              title: "Permission Refusée",
              message: "Ajout au panier refusé : permission insuffisante.",
            ),
          );
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "⚠️ **Action refusée** : Ton profil n'a pas l'autorisation de vendre."
          );
        } else {
          final prodName = args['product_name'] as String;
          final qty = (args['quantity'] as num? ?? 1.0).toDouble();
          final products = await ref.read(productListProvider.future);

          final bestMatch = _findBestProductMatch(products, prodName);

          if (bestMatch != null) {
            if (!bestMatch.isService && bestMatch.quantity < qty) {
              responseOutput = {
                'success': false,
                'error': 'Stock insuffisant pour ${bestMatch.name}. Disponible: ${bestMatch.quantity}.',
              };
              ref.read(proactiveAlertProvider.notifier).set(
                ProactiveAlertData(
                  title: "Stock Insuffisant",
                  message: "Stock insuffisant pour '${bestMatch.name}' (Disponible: ${bestMatch.quantity}).",
                ),
              );
              ref.read(assistantProvider.notifier).addAssistantMessage(
                "⚠️ **Stock insuffisant** : Je n'ai pas pu ajouter **${bestMatch.name}** car il n'en reste que **${bestMatch.quantity}** en stock."
              );
            } else {
              final cartNotifier = ref.read(cartProvider.notifier);
              cartNotifier.addProduct(bestMatch);
              if (qty != 1.0) {
                cartNotifier.updateQty(bestMatch.id, qty);
              }

              success = true;
              responseOutput = {
                'success': true,
                'product_id': bestMatch.id,
                'name': bestMatch.name,
                'quantity_added': qty,
              };

              ref.read(proactiveAlertProvider.notifier).set(
                ProactiveAlertData(
                  title: "Panier Mis à Jour",
                  message: "${bestMatch.name} (x$qty) ajouté au panier.",
                ),
              );

              ref.read(assistantProvider.notifier).addAssistantMessage(
                "🛒 **Panier de caisse** :\n"
                "• Ajouté : **${bestMatch.name}**\n"
                "• Quantité : **$qty**\n"
                "• Prix unitaire : **${bestMatch.sellingPrice} FCFA**"
              );

              final assistantNotifier = ref.read(assistantProvider.notifier);
              if (assistantNotifier.onAction != null) {
                assistantNotifier.onAction!('navigate', payload: 3); // 3 = POS / caisse
              }
            }
          } else {
            success = false;
            responseOutput = {
              'success': false,
              'error': 'Produit non trouvé.',
            };
            ref.read(proactiveAlertProvider.notifier).set(
              ProactiveAlertData(
                title: "Erreur Panier",
                message: "Le produit '$prodName' n'a pas été trouvé.",
              ),
            );
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🔍 **Ajout panier échoué** : Produit '$prodName' non trouvé dans l'inventaire."
            );
          }
        }
      } else if (name == 'update_product') {
        // ── MISE À JOUR PRODUIT (description, prix, catégorie, référence, etc.) ──
        if (!hasPermission((u) => u.canManageInventory)) {
          responseOutput = {'success': false, 'error': 'Permission refusée. Modification de produit non autorisée.'};
          ref.read(proactiveAlertProvider.notifier).set(
            ProactiveAlertData(title: "Permission Refusée", message: "Modification de produit refusée : permission insuffisante."),
          );
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "⚠️ **Action refusée** : Ton profil n'a pas l'autorisation de modifier les produits."
          );
        } else {
          final prodName = args['product_name'] as String;
          final products = await ref.read(productListProvider.future);

          final bestMatch = _findBestProductMatch(products, prodName);

          if (bestMatch != null) {
            final updated = bestMatch.copyWith(
              name: args['new_name'] as String? ?? bestMatch.name,
              description: args['description'] as String? ?? bestMatch.description,
              sellingPrice: args['selling_price'] != null 
                  ? expandVoiceAmount((args['selling_price'] as num).toDouble()) 
                  : bestMatch.sellingPrice,
              purchasePrice: args['purchase_price'] != null 
                  ? expandVoiceAmount((args['purchase_price'] as num).toDouble()) 
                  : bestMatch.purchasePrice,
              category: args['category'] as String? ?? bestMatch.category,
              reference: args['reference'] as String? ?? bestMatch.reference,
              barcode: args['barcode'] as String? ?? bestMatch.barcode,
              alertThreshold: args['alert_threshold'] != null ? (args['alert_threshold'] as num).toDouble() : bestMatch.alertThreshold,
              location: args['location'] as String? ?? bestMatch.location,
              unit: args['unit'] as String? ?? bestMatch.unit,
            );

            await ref.read(productListProvider.notifier).updateProduct(updated);
            success = true;

            // Construire la liste des champs modifiés
            final changes = <String>[];
            if (args.containsKey('new_name')) changes.add("Nom → **${args['new_name']}**");
            if (args.containsKey('description')) changes.add("Description → **${args['description']}**");
            if (args.containsKey('selling_price')) changes.add("Prix de vente → **${args['selling_price']} FCFA**");
            if (args.containsKey('purchase_price')) changes.add("Prix d'achat → **${args['purchase_price']} FCFA**");
            if (args.containsKey('category')) changes.add("Catégorie → **${args['category']}**");
            if (args.containsKey('reference')) changes.add("Référence → **${args['reference']}**");
            if (args.containsKey('barcode')) changes.add("Code-barres → **${args['barcode']}**");
            if (args.containsKey('alert_threshold')) changes.add("Seuil alerte → **${args['alert_threshold']}**");
            if (args.containsKey('location')) changes.add("Emplacement → **${args['location']}**");
            if (args.containsKey('unit')) changes.add("Unité → **${args['unit']}**");

            responseOutput = {
              'success': true,
              'product_id': bestMatch.id,
              'name': updated.name,
              'changes': changes.join(', '),
            };

            ref.read(proactiveAlertProvider.notifier).set(
              ProactiveAlertData(title: "Produit Modifié", message: "Le produit '${bestMatch.name}' a été mis à jour."),
            );
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "✏️ **Produit modifié** : **${bestMatch.name}**\n${changes.map((c) => '• $c').join('\n')}"
            );
          } else {
            responseOutput = {'success': false, 'error': 'Produit non trouvé.'};
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🔍 **Modification échouée** : Produit '$prodName' non trouvé en stock."
            );
          }
        }
      } else if (name == 'delete_product') {
        // ── SUPPRESSION PRODUIT ──
        if (!hasPermission((u) => u.canManageInventory)) {
          responseOutput = {'success': false, 'error': 'Permission refusée. Suppression de produit non autorisée.'};
          ref.read(proactiveAlertProvider.notifier).set(
            ProactiveAlertData(title: "Permission Refusée", message: "Suppression de produit refusée : permission insuffisante."),
          );
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "⚠️ **Action refusée** : Ton profil n'a pas l'autorisation de supprimer des produits."
          );
        } else {
          final prodName = args['product_name'] as String;
          final products = await ref.read(productListProvider.future);

          final bestMatch = _findBestProductMatch(products, prodName);

          if (bestMatch != null) {
            await ref.read(productListProvider.notifier).deleteProduct(bestMatch.id);
            success = true;
            responseOutput = {
              'success': true,
              'deleted_product': bestMatch.name,
            };

            ref.read(proactiveAlertProvider.notifier).set(
              ProactiveAlertData(title: "Produit Supprimé", message: "Le produit '${bestMatch.name}' a été supprimé définitivement."),
            );
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🗑️ **Produit supprimé** : **${bestMatch.name}** a été retiré de l'inventaire."
            );
          } else {
            responseOutput = {'success': false, 'error': 'Produit non trouvé.'};
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🔍 **Suppression échouée** : Produit '$prodName' non trouvé."
            );
          }
        }
      } else if (name == 'update_client') {
        // ── MISE À JOUR CLIENT ──
        if (!hasPermission((u) => u.canManageCustomers)) {
          responseOutput = {'success': false, 'error': 'Permission refusée. Modification de client non autorisée.'};
          ref.read(proactiveAlertProvider.notifier).set(
            ProactiveAlertData(title: "Permission Refusée", message: "Modification de client refusée : permission insuffisante."),
          );
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "⚠️ **Action refusée** : Ton profil n'a pas l'autorisation de modifier les clients."
          );
        } else {
          final clientName = args['client_name'] as String;
          final clients = await ref.read(clientListProvider.future);

          final bestMatch = _findBestClientMatch(clients, clientName);

          if (bestMatch != null) {
            final updated = bestMatch.copyWith(
              name: args['new_name'] as String? ?? bestMatch.name,
              phone: args['phone'] as String? ?? bestMatch.phone,
              email: args['email'] as String? ?? bestMatch.email,
              address: args['address'] as String? ?? bestMatch.address,
              maxCredit: args['max_credit'] != null ? (args['max_credit'] as num).toDouble() : bestMatch.maxCredit,
            );

            await ref.read(clientListProvider.notifier).updateClient(updated);
            success = true;

            final changes = <String>[];
            if (args.containsKey('new_name')) changes.add("Nom → **${args['new_name']}**");
            if (args.containsKey('phone')) changes.add("Téléphone → **${args['phone']}**");
            if (args.containsKey('email')) changes.add("Email → **${args['email']}**");
            if (args.containsKey('address')) changes.add("Adresse → **${args['address']}**");
            if (args.containsKey('max_credit')) changes.add("Crédit max → **${args['max_credit']} FCFA**");

            responseOutput = {
              'success': true,
              'client_id': bestMatch.id,
              'name': updated.name,
              'changes': changes.join(', '),
            };

            ref.read(proactiveAlertProvider.notifier).set(
              ProactiveAlertData(title: "Client Modifié", message: "Le client '${bestMatch.name}' a été mis à jour."),
            );
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "✏️ **Client modifié** : **${bestMatch.name}**\n${changes.map((c) => '• $c').join('\n')}"
            );
          } else {
            responseOutput = {'success': false, 'error': 'Client non trouvé.'};
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🔍 **Modification échouée** : Client '$clientName' non trouvé."
            );
          }
        }
      } else if (name == 'delete_client') {
        if (!hasPermission((u) => u.canManageCustomers)) {
          responseOutput = {'success': false, 'error': 'Permission refusée. Suppression de client non autorisée.'};
          ref.read(proactiveAlertProvider.notifier).set(
            ProactiveAlertData(title: "Permission Refusée", message: "Suppression de client refusée : permission insuffisante."),
          );
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "⚠️ **Action refusée** : Ton profil n'a pas l'autorisation de supprimer des clients."
          );
        } else {
          final clientName = args['client_name'] as String;
          final clients = await ref.read(clientListProvider.future);

          final bestMatch = _findBestClientMatch(clients, clientName);

          if (bestMatch != null) {
            await ref.read(clientListProvider.notifier).deleteClient(bestMatch.id);
            success = true;
            responseOutput = {
              'success': true,
              'deleted_client': bestMatch.name,
            };

            ref.read(proactiveAlertProvider.notifier).set(
              ProactiveAlertData(title: "Client Supprimé", message: "Le client '${bestMatch.name}' a été supprimé définitivement."),
            );
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🗑️ **Client supprimé** : **${bestMatch.name}** a été retiré de la liste des clients."
            );

            final assistantNotifier = ref.read(assistantProvider.notifier);
            if (assistantNotifier.onAction != null) {
              assistantNotifier.onAction!('navigate', payload: 7); // clients
            }
          } else {
            responseOutput = {'success': false, 'error': 'Client non trouvé.'};
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🔍 **Suppression échouée** : Client '$clientName' non trouvé."
            );
          }
        }
      } else if (name == 'settle_client_debt') {
        if (!hasPermission((u) => u.canAccessFinance)) {
          responseOutput = {'success': false, 'error': 'Permission refusée pour encaisser des dettes.'};
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "⚠️ **Action refusée** : Votre profil n'a pas l'autorisation d'effectuer des encaissements de dettes."
          );
        } else {
          final clientName = args['client_name'] as String;
          final amount = expandVoiceAmount((args['amount'] as num).toDouble());
          final paymentMethod = args['payment_method'] as String? ?? 'CASH';
          final description = args['description'] as String?;

          final clients = await ref.read(clientListProvider.future);
          final bestMatch = _findBestClientMatch(clients, clientName);

          if (bestMatch != null) {
            final treasury = ref.read(treasuryProvider.notifier);
            final defaultAccount = await treasury.getDefaultAccount(
              paymentMethod == 'MOBILE_MONEY' ? AccountType.MOBILE_MONEY : AccountType.CASH
            );

            if (defaultAccount != null) {
              try {
                await ref.read(clientListProvider.notifier).settleDebt(
                  clientId: bestMatch.id,
                  amount: amount,
                  accountId: defaultAccount.id,
                  description: description ?? "Règlement de dette via assistant vocal",
                  paymentMethod: paymentMethod,
                );
                success = true;
                responseOutput = {
                  'success': true,
                  'client_name': bestMatch.name,
                  'amount': amount,
                  'remaining_credit': bestMatch.credit - amount,
                };

                ref.read(proactiveAlertProvider.notifier).set(
                  ProactiveAlertData(
                    title: "Dette Réglée",
                    message: "Paiement de $amount de ${bestMatch.name} enregistré.",
                  ),
                );

                ref.read(assistantProvider.notifier).addAssistantMessage(
                  "💳 **Règlement de dette enregistré** :\n"
                  "• Client : **${bestMatch.name}**\n"
                  "• Montant encaissé : **$amount FCFA**\n"
                  "• Mode de paiement : **$paymentMethod**\n"
                  "• Solde restant : **${bestMatch.credit - amount} FCFA**"
                );

                final assistantNotifier = ref.read(assistantProvider.notifier);
                if (assistantNotifier.onAction != null) {
                  assistantNotifier.onAction!('navigate', payload: 12); // dettes_clients
                }
              } catch (e) {
                success = false;
                responseOutput = {'success': false, 'error': e.toString()};
                ref.read(assistantProvider.notifier).addAssistantMessage(
                  "⚠️ **Erreur règlement** : ${e.toString().replaceAll('Exception: ', '')}"
                );
              }
            } else {
              responseOutput = {'success': false, 'error': 'Compte de trésorerie par défaut introuvable.'};
            }
          } else {
            responseOutput = {'success': false, 'error': 'Client non trouvé.'};
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🔍 **Règlement échoué** : Client '$clientName' non trouvé."
            );
          }
        }
      } else if (name == 'get_client_debtors') {
        if (!hasPermission((u) => u.canAccessFinance || u.canManageCustomers)) {
          responseOutput = {'success': false, 'error': 'Permission refusée pour lire la liste des débiteurs.'};
        } else {
          final clients = await ref.read(clientListProvider.future);
          final debtors = clients.where((c) => c.credit > 0.0).toList();
          
          debtors.sort((a, b) => b.credit.compareTo(a.credit)); // Plus grande dette en premier

          final results = debtors.map((c) => {
            'id': c.id,
            'name': c.name,
            'phone': c.phone,
            'credit': c.credit,
            'max_credit': c.maxCredit,
          }).toList();

          success = true;
          responseOutput = {
            'success': true,
            'debtors': results,
          };

          if (debtors.isEmpty) {
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "✅ **Débiteurs** : Aucun client n'a de dette en cours actuellement !"
            );
          } else {
            final listText = debtors.take(5).map((c) => "• **${c.name}** : **${c.credit} FCFA** (Crédit Max: ${c.maxCredit})").join("\n");
            final extraText = debtors.length > 5 ? "\n*(...et ${debtors.length - 5} autres débiteurs)*" : "";
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "💳 **Liste des débiteurs (Top 5)** :\n$listText$extraText"
            );
          }
        }
      } else if (name == 'filter_clients') {
        if (!hasPermission((u) => u.canManageCustomers)) {
          responseOutput = {'success': false, 'error': 'Permission refusée. Accès aux clients non autorisé.'};
        } else {
          final tab = args['tab'] as String?;
          final sort = args['sort'] as String?;
          final searchQuery = args['search_query'] as String?;

          if (tab != null) {
            ref.read(clientsFilterTabProvider.notifier).update(tab);
          }
          if (sort != null) {
            ref.read(clientsSortByProvider.notifier).update(sort);
          }
          if (searchQuery != null) {
            ref.read(clientsSearchQueryProvider.notifier).update(searchQuery);
          }

          success = true;
          responseOutput = {
            'success': true,
            if (tab != null) 'tab': tab,
            if (sort != null) 'sort': sort,
            if (searchQuery != null) 'search_query': searchQuery,
          };

          String filterMsg = "Filtres clients mis à jour :";
          if (tab != null) filterMsg += "\n• Onglet : **$tab**";
          if (sort != null) filterMsg += "\n• Tri : **$sort**";
          if (searchQuery != null) filterMsg += "\n• Recherche : **$searchQuery**";

          ref.read(assistantProvider.notifier).addAssistantMessage(filterMsg);

          final assistantNotifier = ref.read(assistantProvider.notifier);
          if (assistantNotifier.onAction != null) {
            assistantNotifier.onAction!('navigate', payload: 7); // 7 = clients
          }
        }
      } else if (name == 'send_client_message') {
        if (!hasPermission((u) => u.canManageCustomers)) {
          responseOutput = {'success': false, 'error': 'Permission refusée pour contacter un client.'};
        } else {
          final clientName = args['client_name'] as String;
          final method = args['method'] as String;

          final clients = await ref.read(clientListProvider.future);
          final bestMatch = _findBestClientMatch(clients, clientName);

          if (bestMatch != null) {
            final phone = bestMatch.phone ?? '';
            final email = bestMatch.email ?? '';

            if (method == 'call' && phone.isEmpty) {
              responseOutput = {'success': false, 'error': 'Aucun numéro de téléphone disponible pour ce client.'};
              ref.read(assistantProvider.notifier).addAssistantMessage(
                "⚠️ **Erreur** : Impossible de téléphoner à **${bestMatch.name}** car aucun numéro de téléphone n'est renseigné."
              );
            } else if (method == 'whatsapp' && phone.isEmpty) {
              responseOutput = {'success': false, 'error': 'Aucun numéro de téléphone disponible pour WhatsApp.'};
              ref.read(assistantProvider.notifier).addAssistantMessage(
                "⚠️ **Erreur** : Impossible d'envoyer un message WhatsApp à **${bestMatch.name}** car aucun numéro de téléphone n'est renseigné."
              );
            } else if (method == 'email' && email.isEmpty) {
              responseOutput = {'success': false, 'error': 'Aucune adresse e-mail disponible pour ce client.'};
              ref.read(assistantProvider.notifier).addAssistantMessage(
                "⚠️ **Erreur** : Impossible d'envoyer un e-mail à **${bestMatch.name}** car aucune adresse e-mail n'est renseignée."
              );
            } else {
              final assistantNotifier = ref.read(assistantProvider.notifier);
              if (assistantNotifier.onAction != null) {
                assistantNotifier.onAction!(
                  'send_client_message',
                  payload: {
                    'clientId': bestMatch.id,
                    'method': method,
                    'phone': phone,
                    'email': email,
                    'name': bestMatch.name,
                    'credit': bestMatch.credit,
                  },
                );
                success = true;
                responseOutput = {
                  'success': true,
                  'client_name': bestMatch.name,
                  'method': method,
                };
                ref.read(assistantProvider.notifier).addAssistantMessage(
                  "💬 **Communication initiée** : Lancement de l'action **$method** pour le client **${bestMatch.name}**."
                );
              } else {
                responseOutput = {'success': false, 'error': 'Callback d\'action indisponible.'};
              }
            }
          } else {
            responseOutput = {'success': false, 'error': 'Client non trouvé.'};
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🔍 **Communication échouée** : Le client '$clientName' n'a pas été trouvé dans la base de données."
            );
          }
        }
      } else if (name == 'get_debt_report') {
        if (!hasPermission((u) => u.canAccessFinance || u.canManageCustomers)) {
          responseOutput = {'success': false, 'error': 'Permission refusée pour consulter le rapport des dettes.'};
        } else {
          final clients = await ref.read(clientListProvider.future);
          final debtors = clients.where((c) => c.credit > 0.0).toList();
          debtors.sort((a, b) => b.credit.compareTo(a.credit));

          final totalOutstanding = debtors.fold(0.0, (sum, c) => sum + c.credit);
          final topDebtors = debtors.take(5).map((c) => {
            'name': c.name,
            'credit': c.credit,
            'max_credit': c.maxCredit,
            'phone': c.phone ?? '',
          }).toList();

          success = true;
          responseOutput = {
            'success': true,
            'total_outstanding_debt': totalOutstanding,
            'debtors_count': debtors.length,
            'top_debtors': topDebtors,
          };

          final settings = ref.read(shopSettingsProvider).value;
          final currency = settings?.currency ?? 'FCFA';
          final formattedTotal = DateFormatter.formatCurrency(
            totalOutstanding,
            currency,
            removeDecimals: settings?.removeDecimals ?? true,
          );
          if (debtors.isEmpty) {
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "📊 **Rapport des Dettes** :\n"
              "• Aucune dette en cours dans la boutique actuellement. Le portefeuille est totalement sain ! 🎉"
            );
          } else {
            final topListText = debtors.take(5).map((c) {
              final formattedCredit = DateFormatter.formatCurrency(
                c.credit,
                currency,
                removeDecimals: settings?.removeDecimals ?? true,
              );
              return "• **${c.name}** : **$formattedCredit** (Tél: ${c.phone ?? 'N/A'})";
            }).join("\n");

            ref.read(assistantProvider.notifier).addAssistantMessage(
              "📊 **Rapport Global des Dettes** :\n"
              "• Total dû : **$formattedTotal**\n"
              "• Clients endettés : **${debtors.length}**\n\n"
              "📈 **Top 5 des plus grands débiteurs** :\n$topListText"
            );
          }
        }
      } else if (name == 'filter_suppliers') {
        if (!hasPermission((u) => u.canManageSuppliers)) {
          responseOutput = {'success': false, 'error': 'Permission refusée pour gérer les fournisseurs.'};
        } else {
          final tab = args['tab'] as String?;
          final sort = args['sort'] as String?;
          final searchQuery = args['search_query'] as String?;

          if (tab != null) {
            ref.read(suppliersFilterTabProvider.notifier).update(tab);
          }
          if (sort != null) {
            ref.read(suppliersSortByProvider.notifier).update(sort);
          }
          if (searchQuery != null) {
            ref.read(suppliersSearchQueryProvider.notifier).update(searchQuery);
          }

          success = true;
          responseOutput = {
            'success': true,
            if (tab != null) 'tab': tab,
            if (sort != null) 'sort': sort,
            if (searchQuery != null) 'search_query': searchQuery,
          };

          String filterMsg = "Filtres fournisseurs mis à jour :";
          if (tab != null) filterMsg += "\n• Onglet : **$tab**";
          if (sort != null) filterMsg += "\n• Tri : **$sort**";
          if (searchQuery != null) filterMsg += "\n• Recherche : **$searchQuery**";

          ref.read(assistantProvider.notifier).addAssistantMessage(filterMsg);

          final assistantNotifier = ref.read(assistantProvider.notifier);
          if (assistantNotifier.onAction != null) {
            assistantNotifier.onAction!('navigate', payload: 8); // 8 = fournisseurs
          }
        }
      } else if (name == 'filter_products') {
        if (!hasPermission((u) => u.canSell || u.canManageInventory)) {
          responseOutput = {'success': false, 'error': 'Permission refusée pour consulter l\'inventaire.'};
        } else {
          final tab = args['tab'] as String?;
          final searchQuery = args['search_query'] as String?;
          final warehouseName = args['warehouse_name'] as String?;

          if (tab != null) {
            ref.read(productsStockFilterProvider.notifier).update(tab);
          }
          if (searchQuery != null) {
            ref.read(productsSearchQueryProvider.notifier).update(searchQuery);
          }
          if (warehouseName != null) {
            final warehouses = await ref.read(warehouseListProvider.future);
            final match = warehouses.firstWhere(
              (w) => w.name.toLowerCase().contains(warehouseName.toLowerCase()),
              orElse: () => warehouses.first,
            );
            ref.read(selectedWarehouseIdProvider.notifier).setId(match.id);
          }

          success = true;
          responseOutput = {
            'success': true,
            if (tab != null) 'tab': tab,
            if (searchQuery != null) 'search_query': searchQuery,
          };

          String filterMsg = "Filtres stock mis à jour :";
          if (tab != null) filterMsg += "\n• Statut : **$tab**";
          if (searchQuery != null) filterMsg += "\n• Recherche : **$searchQuery**";
          if (warehouseName != null) filterMsg += "\n• Entrepôt : **$warehouseName**";

          ref.read(assistantProvider.notifier).addAssistantMessage(filterMsg);

          final assistantNotifier = ref.read(assistantProvider.notifier);
          if (assistantNotifier.onAction != null) {
            assistantNotifier.onAction!('navigate', payload: 1); // 1 = produits
          }
        }
      } else if (name == 'manage_cash_session') {
        if (!hasPermission((u) => u.canAccessFinance || u.canSell)) {
          responseOutput = {'success': false, 'error': 'Permission refusée pour gérer la caisse.'};
        } else {
          final action = args['action'] as String;
          final amount = expandVoiceAmount((args['amount'] as num).toDouble());
          final sessionService = ref.read(sessionServiceProvider);

          if (action == 'open') {
            try {
              final session = await sessionService.openSession(amount);
              success = true;
              responseOutput = {
                'success': true,
                'action': 'open',
                'opening_balance': amount,
                'session_id': session?.id,
              };
              ref.read(assistantProvider.notifier).addAssistantMessage(
                "🔓 **Caisse ouverte** : La session de caisse a été ouverte avec un fond initial de **$amount FCFA**."
              );
            } catch (e) {
              success = false;
              responseOutput = {'success': false, 'error': e.toString()};
              ref.read(assistantProvider.notifier).addAssistantMessage(
                "⚠️ **Erreur ouverture** : ${e.toString().replaceAll('Exception: ', '')}"
              );
            }
          } else {
            final activeSession = await ref.read(activeSessionProvider.future);
            if (activeSession != null) {
              try {
                await sessionService.closeSession(activeSession, amount);
                success = true;
                responseOutput = {
                  'success': true,
                  'action': 'close',
                  'closing_balance_actual': amount,
                };
                ref.read(assistantProvider.notifier).addAssistantMessage(
                  "🔒 **Caisse fermée** : La session de caisse a été clôturée avec un montant physique compté de **$amount FCFA**."
                );
              } catch (e) {
                success = false;
                responseOutput = {'success': false, 'error': e.toString()};
                ref.read(assistantProvider.notifier).addAssistantMessage(
                  "⚠️ **Erreur fermeture** : ${e.toString().replaceAll('Exception: ', '')}"
                );
              }
            } else {
              success = false;
              responseOutput = {'success': false, 'error': 'Aucune session active.'};
              ref.read(assistantProvider.notifier).addAssistantMessage(
                "⚠️ **Erreur** : Impossible de fermer la caisse car aucune session n'est ouverte."
              );
            }
          }
        }
      } else if (name == 'get_treasury_summary') {
        if (!hasPermission((u) => u.canAccessFinance)) {
          responseOutput = {'success': false, 'error': 'Permission refusée pour voir la trésorerie.'};
        } else {
          final accounts = await ref.read(treasuryProvider.future);
          final summary = accounts.map((a) => {
            'name': a.name,
            'balance': a.balance,
            'type': a.type.name,
          }).toList();

          final totalTreasury = accounts.fold(0.0, (sum, a) => sum + a.balance);

          success = true;
          responseOutput = {
            'success': true,
            'total_balance': totalTreasury,
            'accounts': summary,
          };

          final settings = ref.read(shopSettingsProvider).value;
          final currency = settings?.currency ?? 'FCFA';
          final formattedTotal = DateFormatter.formatCurrency(
            totalTreasury,
            currency,
            removeDecimals: settings?.removeDecimals ?? true,
          );

          final listText = accounts.map((a) {
            final formattedBalance = DateFormatter.formatCurrency(
              a.balance,
              currency,
              removeDecimals: settings?.removeDecimals ?? true,
            );
            return "• **${a.name}** (${a.type.name}) : **$formattedBalance**";
          }).join("\n");

          ref.read(assistantProvider.notifier).addAssistantMessage(
            "💰 **Résumé de la Trésorerie** :\n"
            "• Trésorerie Totale : **$formattedTotal**\n\n"
            "💳 **Détail des comptes** :\n$listText"
          );
        }
      } else if (name == 'get_hr_summary') {
        if (!hasPermission((u) => u.isAdmin || u.isManager || u.isAdminPlus)) {
          responseOutput = {'success': false, 'error': 'Permission refusée pour voir le résumé RH.'};
        } else {
          final db = await ref.read(databaseServiceProvider).database;
          
          final employeesCount = ((await db.rawQuery("SELECT COUNT(*) as cnt FROM users WHERE role != 'CASHIER'")).first['cnt'] as num?)?.toInt() ?? 0;
          final activeContracts = ((await db.rawQuery("SELECT COUNT(*) as cnt FROM employee_contracts WHERE status = 'ACTIVE'")).first['cnt'] as num?)?.toInt() ?? 0;
          final pendingLeaves = ((await db.rawQuery("SELECT COUNT(*) as cnt FROM leave_requests WHERE status = 'PENDING'")).first['cnt'] as num?)?.toInt() ?? 0;

          success = true;
          responseOutput = {
            'success': true,
            'employees_count': employeesCount,
            'active_contracts': activeContracts,
            'pending_leaves_count': pendingLeaves,
          };

          ref.read(assistantProvider.notifier).addAssistantMessage(
            "👥 **Résumé des Ressources Humaines (RH)** :\n"
            "• Collaborateurs enregistrés : **$employeesCount**\n"
            "• Contrats actifs : **$activeContracts**\n"
            "• Demandes de congés en attente : **$pendingLeaves** 📝"
          );
        }
      } else if (name == 'remove_from_cart') {
        // ── RETIRER DU PANIER ──
        if (!hasPermission((u) => u.canSell)) {
          responseOutput = {'success': false, 'error': 'Permission refusée.'};
        } else {
          final prodName = args['product_name'] as String;
          final cart = ref.read(cartProvider);

          PosCartItem? bestMatch;
          double bestScore = 0.0;
          for (final item in cart) {
            final score = math.max(
              NlpEngine.similarity(prodName.toLowerCase(), item.name.toLowerCase()),
              NlpEngine.phoneticSimilarity(prodName.toLowerCase(), item.name.toLowerCase()),
            );
            if (score > bestScore && score >= 0.6) {
              bestScore = score;
              bestMatch = item;
            }
          }

          if (bestMatch != null) {
            ref.read(cartProvider.notifier).removeProduct(bestMatch.productId);
            success = true;
            responseOutput = {'success': true, 'removed': bestMatch.name};

            ref.read(proactiveAlertProvider.notifier).set(
              ProactiveAlertData(title: "Panier Modifié", message: "'${bestMatch.name}' retiré du panier."),
            );
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🛒 **Retiré du panier** : **${bestMatch.name}**"
            );
          } else {
            responseOutput = {'success': false, 'error': 'Produit non trouvé dans le panier.'};
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🔍 Le produit '$prodName' n'est pas dans le panier actuel."
            );
          }
        }
      } else if (name == 'clear_cart') {
        // ── VIDER LE PANIER ──
        if (!hasPermission((u) => u.canSell)) {
          responseOutput = {'success': false, 'error': 'Permission refusée.'};
        } else {
          final cart = ref.read(cartProvider);
          final totalQty = cart.fold<double>(0.0, (sum, item) => sum + item.qty).toInt();
          ref.read(cartProvider.notifier).clear();
          success = true;
          responseOutput = {'success': true, 'items_removed': totalQty};

          ref.read(proactiveAlertProvider.notifier).set(
            ProactiveAlertData(title: "Panier Vidé", message: "Le panier a été vidé ($totalQty articles retirés)."),
          );
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "🗑️ **Panier vidé** : $totalQty article(s) retiré(s). Le panier est maintenant vide."
          );
        }
      } else if (name == 'get_low_stock_alerts') {
        // ── ALERTES DE STOCK BAS ──
        if (!hasPermission((u) => u.canManageInventory || u.canAccessReports)) {
          responseOutput = {'success': false, 'error': 'Permission refusée.'};
        } else {
          final products = await ref.read(productListProvider.future);
          final lowStock = products.where((p) => !p.isService && p.isLowStock).toList();
          final outOfStock = products.where((p) => !p.isService && p.isOutOfStock).toList();

          success = true;
          responseOutput = {
            'success': true,
            'low_stock_count': lowStock.length,
            'out_of_stock_count': outOfStock.length,
            'low_stock': lowStock.take(10).map((p) => {
              'name': p.name,
              'quantity': p.quantity,
              'threshold': p.alertThreshold,
              'category': p.category,
            }).toList(),
            'out_of_stock': outOfStock.take(10).map((p) => {
              'name': p.name,
              'category': p.category,
            }).toList(),
          };

          final lowText = lowStock.take(5).map((p) => "• ⚠️ **${p.name}** : ${p.quantity} restant(s) (seuil: ${p.alertThreshold})").join('\n');
          final outText = outOfStock.take(5).map((p) => "• 🔴 **${p.name}** : RUPTURE").join('\n');
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "🚨 **Alertes Stock** :\n"
            "${lowStock.isEmpty ? '✅ Aucun produit en stock bas.\n' : '**Stock bas (${lowStock.length})** :\n$lowText\n'}"
            "${outOfStock.isEmpty ? '✅ Aucune rupture de stock.' : '**En rupture (${outOfStock.length})** :\n$outText'}"
          );
        }
      } else if (name == 'save_memory_fact') {
        // ── ENREGISTRER UN SOUVENIR/RÈGLE ──
        final fact = args['fact'] as String;
        try {
          await ref.read(assistantMemoryProvider.notifier).saveMemory(fact);
          success = true;
          responseOutput = {'success': true, 'fact': fact};
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "🧠 **Souvenir enregistré** : \"$fact\""
          );
        } catch (e) {
          success = false;
          responseOutput = {'success': false, 'error': e.toString()};
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "⚠️ **Échec de mémorisation** : ${e.toString().replaceAll('Exception: ', '')}"
          );
        }
      } else if (name == 'delete_memory_fact') {
        // ── SUPPRIMER UN SOUVENIR ──
        final id = args['id'] as String;
        final memories = ref.read(assistantMemoryProvider);
        final toDelete = memories.cast<MemoryFact?>().firstWhere((m) => m?.id == id, orElse: () => null);
        if (toDelete != null) {
          await ref.read(assistantMemoryProvider.notifier).deleteMemory(id);
          success = true;
          responseOutput = {'success': true, 'id': id};
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "🗑️ **Souvenir effacé** : \"${toDelete.fact}\""
          );
        } else {
          success = false;
          responseOutput = {'success': false, 'error': 'ID de souvenir introuvable.'};
        }
      } else if (name == 'clear_memory_facts') {
        // ── EFFACER TOUS LES SOUVENIRS ──
        final count = ref.read(assistantMemoryProvider).length;
        await ref.read(assistantMemoryProvider.notifier).clearMemories();
        success = true;
        responseOutput = {'success': true, 'count_cleared': count};
        ref.read(assistantProvider.notifier).addAssistantMessage(
          "🧹 **Mémoire réinitialisée** : $count souvenir(s) effacé(s)."
        );
      } else if (name == 'add_expense') {
        if (!hasPermission((u) => u.canManageExpenses)) {
          responseOutput = {'success': false, 'error': 'Permission refusée pour enregistrer des dépenses.'};
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "⚠️ **Dépense refusée** : Votre profil n'a pas l'autorisation d'enregistrer des dépenses."
          );
        } else {
          final amount = expandVoiceAmount((args['amount'] as num).toDouble());
          final categoryStr = args['category'] as String? ?? 'DIVERS';
          final description = args['description'] as String? ?? 'Dépense vocale';
          
          final treasury = ref.read(treasuryProvider.notifier);
          final defaultAccount = await treasury.getDefaultAccount(AccountType.CASH);
          
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
            success = true;
            responseOutput = {'success': true, 'amount': amount, 'category': categoryStr};
            
            ref.read(proactiveAlertProvider.notifier).set(
              ProactiveAlertData(
                title: "Dépense Enregistrée",
                message: "Dépense de $amount enregistrée dans '${defaultAccount.name}'.",
              ),
            );
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "💸 **Dépense enregistrée** :\n"
              "• Montant : **$amount FCFA**\n"
              "• Catégorie : **$categoryStr**\n"
              "• Motif : **$description**"
            );
          } else {
            responseOutput = {'success': false, 'error': 'Compte de trésorerie par défaut introuvable.'};
          }
        }
      } else if (name == 'update_dashboard') {
        if (!hasPermission((u) => u.canAccessSettings || u.canAccessReports)) {
          responseOutput = {'success': false, 'error': 'Permission refusée pour modifier la personnalisation du dashboard.'};
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "⚠️ **Action refusée** : Ton profil n'a pas l'autorisation de personnaliser le tableau de bord."
          );
        } else {
          final section = args['section'] as String;
          final visible = args['visible'] as bool;
          
          await ref.read(dashboardCustomizationProvider.notifier).toggleSection(section, visible);
          success = true;
          responseOutput = {'success': true, 'section': section, 'visible': visible};
          
          ref.read(proactiveAlertProvider.notifier).set(
            ProactiveAlertData(
              title: "Dashboard Modifié",
              message: "La section '$section' a été ${visible ? 'affichée' : 'masquée'}.",
            ),
          );
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "📊 **Dashboard personnalisé** :\n"
            "• Section : **$section**\n"
            "• Statut : **${visible ? 'Affichée' : 'Masquée'}**"
          );
          
          final assistantNotifier = ref.read(assistantProvider.notifier);
          if (assistantNotifier.onAction != null) {
            assistantNotifier.onAction!('navigate', payload: 0); // 0 = Dashboard
          }
        }
      } else if (name == 'set_dashboard_filter') {
        if (!hasPermission((u) => u.canAccessReports)) {
          responseOutput = {'success': false, 'error': 'Permission refusée pour modifier le filtre du dashboard.'};
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "⚠️ **Action refusée** : Ton profil n'a pas l'autorisation de filtrer le tableau de bord."
          );
        } else {
          final filterStr = args['filter'] as String;
          final startStr = args['start_date'] as String?;
          final endStr = args['end_date'] as String?;
          
          if (filterStr == 'today') {
            ref.read(dashboardFilterProvider.notifier).setFilter(DashboardFilter.today);
            success = true;
            responseOutput = {'success': true, 'filter': 'today'};
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "📅 **Filtre appliqué** : Aujourd'hui"
            );
          } else if (filterStr == 'week') {
            ref.read(dashboardFilterProvider.notifier).setFilter(DashboardFilter.week);
            success = true;
            responseOutput = {'success': true, 'filter': 'week'};
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "📅 **Filtre appliqué** : Cette semaine"
            );
          } else if (filterStr == 'month') {
            ref.read(dashboardFilterProvider.notifier).setFilter(DashboardFilter.month);
            success = true;
            responseOutput = {'success': true, 'filter': 'month'};
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "📅 **Filtre appliqué** : Ce mois"
            );
          } else if (filterStr == 'custom') {
            if (startStr != null && endStr != null) {
              final start = DateTime.tryParse(startStr);
              final end = DateTime.tryParse(endStr);
              if (start != null && end != null) {
                ref.read(dashboardFilterProvider.notifier).setCustomRange(start, end);
                success = true;
                responseOutput = {
                  'success': true,
                  'filter': 'custom',
                  'start_date': startStr,
                  'end_date': endStr
                };
                
                final startFormatted = "${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year}";
                final endFormatted = "${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}/${end.year}";
                
                ref.read(assistantProvider.notifier).addAssistantMessage(
                  "📅 **Filtre appliqué** : Du $startFormatted au $endFormatted"
                );
              } else {
                responseOutput = {'success': false, 'error': 'Dates invalides.'};
              }
            } else {
              responseOutput = {'success': false, 'error': 'Dates start_date et end_date requises pour le filtre personnalisé.'};
            }
          } else {
            responseOutput = {'success': false, 'error': 'Filtre inconnu.'};
          }
          
          if (success) {
            ref.read(proactiveAlertProvider.notifier).set(
              ProactiveAlertData(
                title: "Filtre Dashboard Appliqué",
                message: "Le tableau de bord a été filtré avec succès.",
              ),
            );
            
            final assistantNotifier = ref.read(assistantProvider.notifier);
            if (assistantNotifier.onAction != null) {
              assistantNotifier.onAction!('navigate', payload: 0); // 0 = Dashboard
            }
          }
        }
      } else if (name == 'checkout_cart') {
        if (!hasPermission((u) => u.canSell)) {
          responseOutput = {'success': false, 'error': 'Permission refusée. Vente non autorisée.'};
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "⚠️ **Action refusée** : Ton profil n'a pas l'autorisation de vendre."
          );
        } else {
          final cart = ref.read(cartProvider);
          if (cart.isEmpty) {
            responseOutput = {'success': false, 'error': 'Le panier est vide.'};
            ref.read(proactiveAlertProvider.notifier).set(
              ProactiveAlertData(
                title: "Panier Vide",
                message: "Impossible de valider une caisse avec un panier vide.",
              ),
            );
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🛡️ **Sécurité caisse** : Le panier est vide chef ! Ajoute d'abord des produits avant de valider la vente."
            );
            _liveService?.sendToolResponse(callId, responseOutput);
            return;
          }

          final paymentMethod = args['payment_method'] as String? ?? 'CASH';
          final amountPaidRaw = args['amount_paid'] as num?;
          final cartTotal = cart.fold(0.0, (sum, item) => sum + item.lineTotal);
          final amountPaid = amountPaidRaw != null 
              ? expandVoiceAmount(amountPaidRaw.toDouble(), referenceTotal: cartTotal) 
              : null;
          final isCredit = args['is_credit'] as bool? ?? false;
          final dueDate = args['due_date'] as String?;
          final isMixed = args['is_mixed'] as bool? ?? false;
          final multiPayments = args['multi_payments'] as List?;
          final documentType = args['document_type'] as String?;

          final selectedClientId = ref.read(selectedClientIdProvider);

          if (isCredit) {
            if (selectedClientId == null || selectedClientId.isEmpty) {
              responseOutput = {'success': false, 'error': 'Aucun client sélectionné pour la vente à crédit.'};
              ref.read(proactiveAlertProvider.notifier).set(
                ProactiveAlertData(
                  title: "Client Manquant",
                  message: "Vente à crédit demandée sans associer de client.",
                ),
              );
              ref.read(assistantProvider.notifier).addAssistantMessage(
                "🛡️ **Sécurité caisse** : Vente à crédit impossible sans client lié chef ! Indique-moi d'abord quel client associer ou crée-le."
              );
              _liveService?.sendToolResponse(callId, responseOutput);
              return;
            }

            final clients = await ref.read(clientListProvider.future);
            final client = clients.cast<Client?>().firstWhere((c) => c?.id == selectedClientId, orElse: () => null);

            if (client != null) {
              final paid = amountPaid?.toDouble() ?? 0.0;
              final debtToAdd = cartTotal - paid;
              final projectedDebt = client.credit + debtToAdd;
              if (projectedDebt > client.maxCredit) {
                responseOutput = {'success': false, 'error': 'Limite de crédit dépassée pour ce client.'};
                ref.read(proactiveAlertProvider.notifier).set(
                  ProactiveAlertData(
                    title: "Dépassement de Crédit",
                    message: "Le crédit projeté ($projectedDebt FCFA) dépasse la limite autorisée (${client.maxCredit} FCFA) pour ${client.name}.",
                  ),
                );
                ref.read(assistantProvider.notifier).addAssistantMessage(
                  "🛡️ **Alerte Risque** : Le client **${client.name}** a déjà une dette de **${client.credit} FCFA**. Cette vente de **$cartTotal FCFA** (avec acompte de **$paid FCFA**, nouveau crédit : **$debtToAdd FCFA**) porterait son encours à **$projectedDebt FCFA**, ce qui dépasse son crédit maximal autorisé (**${client.maxCredit} FCFA**). Augmente sa limite dans sa fiche si tu veux forcer la vente."
                );
                _liveService?.sendToolResponse(callId, responseOutput);
                return;
              }
            }
          }

          final assistantNotifier = ref.read(assistantProvider.notifier);
          if (assistantNotifier.onAction != null) {
            assistantNotifier.onAction!(
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
            success = true;
            responseOutput = {
              'success': true,
              'payment_method': paymentMethod,
              'amount_paid': amountPaid,
              'is_credit': isCredit,
              if (dueDate != null) 'due_date': dueDate,
              'is_mixed': isMixed,
              if (documentType != null) 'document_type': documentType,
            };
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🛒 **Orchestration Vente** : Validation et encaissement de la caisse lancés..."
            );
          } else {
            responseOutput = {'success': false, 'error': 'Callback d\'action indisponible.'};
          }
        }
      } else if (name == 'export_report') {
        if (!hasPermission((u) => u.canAccessReports)) {
          responseOutput = {'success': false, 'error': 'Permission refusée. Accès aux rapports non autorisé.'};
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "⚠️ **Action refusée** : Ton profil n'a pas l'autorisation d'accéder aux rapports de la boutique."
          );
        } else {
          final format = args['format'] as String? ?? 'pdf';
          final period = args['period'] as String? ?? 'month';
          
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
          final settings = ref.read(shopSettingsProvider).value;

          if (format == 'pdf') {
            final userSales = await ref.read(userSalesSummaryProvider(range).future);
            final user = await ref.read(authServiceProvider.future);

            await PdfReportService.generateAndSaveReport(
              range: range,
              kpis: kpis,
              topProducts: topProducts,
              userSales: userSales,
              username: user?.username ?? "Utilisateur",
              shopName: settings?.name ?? "Mon Commerce",
              shopAddress: settings?.address,
              shopPhone: settings?.phone,
              targetPrinter: settings?.reportPrinterName ?? settings?.invoicePrinterName,
              directPrint: settings?.directPhysicalPrinting ?? false,
              currencySymbol: settings?.currency ?? "F",
              locale: "fr-FR",
              removeDecimals: settings?.removeDecimals ?? true,
            );
            
            success = true;
            responseOutput = {'success': true, 'format': 'pdf', 'period': period};
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "📄 **Rapport PDF généré** : J'ai généré et ouvert le rapport PDF pour la période : ${period == 'today' ? 'aujourd\'hui' : period == 'week' ? 'cette semaine' : 'ce mois'}."
            );
          } else {
            final db = await ref.read(databaseServiceProvider).database;
            await ExcelExportService.exportToExcel(
              range: range,
              kpis: kpis,
              topProducts: topProducts,
              db: db,
              currency: settings?.currency ?? 'FCFA',
            );
            success = true;
            responseOutput = {'success': true, 'format': 'excel', 'period': period};
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "📊 **Rapport Excel exporté** : Le fichier Excel a été généré et sauvegardé dans tes Téléchargements."
            );
          }
        }
      } else if (name == 'get_business_insights') {
        if (!hasPermission((u) => u.canAccessReports || u.canAccessFinance)) {
          responseOutput = {'success': false, 'error': 'Permission refusée. Accès aux analyses financières non autorisé.'};
        } else {
          final sales = await ref.read(salesHistoryProvider.future);
          final clients = await ref.read(clientListProvider.future);
          final products = await ref.read(productListProvider.future);
          final settings = ref.read(shopSettingsProvider).value;

          final insights = _horizonEngine.generateBusinessInsights(
            sales: sales,
            clients: clients,
            products: products,
            formatCurrency: (val) => DateFormatter.formatCurrency(
              val, 
              settings?.currency ?? "FCFA", 
              removeDecimals: settings?.removeDecimals ?? true
            ),
          );

          success = true;
          responseOutput = {
            'success': true,
            'insights': insights.map((i) => {
              'trend': i.trend,
              'suggestion': i.suggestion,
              'key': i.key,
            }).toList(),
          };

          final insightsList = insights.isEmpty 
              ? "✅ Aucun risque financier ou opérationnel détecté par Horizon Engine."
              : insights.map((i) => "• 🔮 **[${i.trend}]** ${i.suggestion}").join("\n");

          ref.read(assistantProvider.notifier).addAssistantMessage(
            "🔮 **Analyses Prédictives (Horizon Engine)** :\n$insightsList"
          );
        }
      } else if (name == 'add_supplier') {
        if (!hasPermission((u) => u.canManageSuppliers)) {
          responseOutput = {'success': false, 'error': 'Permission refusée pour SRM (Fournisseurs).'};
        } else {
          final sName = args['name'] as String;
          final contact = args['contact_name'] as String?;
          final phone = args['phone'] as String?;
          final email = args['email'] as String?;
          final address = args['address'] as String?;
          
          final supplier = Supplier(
            name: sName,
            contactName: contact,
            phone: phone,
            email: email,
            address: address,
          );
          
          await ref.read(supplierListProvider.notifier).addSupplier(supplier);
          success = true;
          responseOutput = {'success': true, 'supplier_id': supplier.id};
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "🚚 **Fournisseur ajouté** : $sName a bien été créé dans la base de données."
          );
        }
      } else if (name == 'get_suppliers_list') {
        if (!hasPermission((u) => u.canManageSuppliers)) {
          responseOutput = {'success': false, 'error': 'Permission refusée.'};
        } else {
          final suppliers = ref.read(supplierListProvider).value ?? [];
          success = true;
          responseOutput = {
            'success': true,
            'suppliers': suppliers.map((s) => {
              'id': s.id,
              'name': s.name,
              'contact_name': s.contactName,
              'phone': s.phone,
              'email': s.email,
              'address': s.address,
              'total_purchases': s.totalPurchases,
              'outstanding_debt': s.outstandingDebt,
            }).toList()
          };
          
          final listStr = suppliers.isEmpty 
              ? "Aucun fournisseur enregistré." 
              : suppliers.map((s) => "• **${s.name}** (${s.phone ?? 'Pas de numéro'})").join("\n");
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "🚚 **Liste des Fournisseurs** :\n$listStr"
          );
        }
      } else if (name == 'create_quote') {
        if (!hasPermission((u) => u.canSell)) {
          responseOutput = {'success': false, 'error': 'Permission refusée pour créer un devis.'};
        } else {
          final List<QuoteItemWithId> quoteItems = [];
          final customItems = args['items'];
          String? clientName = args['client_name'] as String?;
          String? clientId = ref.read(selectedClientIdProvider);

          if (clientName != null && clientName.trim().isNotEmpty) {
            final clients = await ref.read(clientListProvider.future);
            final matches = clients.where((c) => c.name.toLowerCase().contains(clientName.trim().toLowerCase())).toList();
            if (matches.isNotEmpty) {
              clientId = matches.first.id;
            }
          }

          if (customItems is List) {
            for (var item in customItems) {
              if (item is Map) {
                quoteItems.add(QuoteItemWithId(
                  name: item['name'] ?? 'Article personnalisé',
                  qty: (item['quantity'] ?? item['qty'] ?? 1.0).toDouble(),
                  unitPrice: (item['unit_price'] ?? item['unitPrice'] ?? 0.0).toDouble(),
                  description: item['description']?.toString(),
                ));
              }
            }
          } else {
            final cartItems = ref.read(cartProvider);
            if (cartItems.isNotEmpty) {
              quoteItems.addAll(cartItems.map((item) => QuoteItemWithId(
                name: item.name,
                qty: item.qty,
                unitPrice: item.unitPrice,
                productId: item.productId,
              )));
            }
          }

          if (quoteItems.isEmpty) {
            responseOutput = {'success': false, 'error': 'Le panier est vide ou aucun article n\'a été fourni.'};
          } else {
            final settings = ref.read(shopSettingsProvider).value;
            final user = ref.read(authServiceProvider).value;
            final userId = user?.id ?? 'admin';
            
            final validityDays = args['validity_days'] != null 
                ? (args['validity_days'] as num).toInt() 
                : (settings?.quoteValidityDays ?? 30);
            
            final validUntil = DateTime.now().add(Duration(days: validityDays));
            final double subtotal = quoteItems.fold(0.0, (sum, item) => sum + item.lineTotal);
            
            final taxRate = settings?.useTax == true ? (settings?.taxRate ?? 0.0) : 0.0;
            final totalAmount = settings?.useTax == true ? subtotal * (1 + taxRate / 100) : subtotal;
            
            final quoteId = await ref.read(quoteRepositoryProvider).createQuote(
              clientId: clientId,
              items: quoteItems,
              subtotal: subtotal,
              totalAmount: totalAmount,
              userId: userId,
              validUntil: validUntil,
            );
            
            ref.invalidate(quoteListProvider);
            if (customItems == null) {
              ref.read(cartProvider.notifier).clear();
            }
            
            success = true;
            responseOutput = {'success': true, 'quote_id': quoteId};
            
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "📄 **Devis créé avec succès** (ID: $quoteId).\n"
              "Le devis a été enregistré et est disponible dans la section Devis."
            );
          }
        }
      } else if (name == 'delete_quote') {
        if (!hasPermission((u) => u.canSell)) {
          responseOutput = {'success': false, 'error': 'Permission refusée.'};
        } else {
          final qNum = args['quote_number'] as String;
          final quotes = await ref.read(quoteListProvider.future);
          Map<String, dynamic>? matched;
          for (final q in quotes) {
            if (q['quote_number'].toString().toLowerCase().contains(qNum.toLowerCase())) {
              matched = q;
              break;
            }
          }
          if (matched == null) {
            responseOutput = {'success': false, 'error': 'Devis non trouvé.'};
          } else {
            await ref.read(quoteRepositoryProvider).deleteQuote(matched['id']);
            ref.invalidate(quoteListProvider);
            success = true;
            responseOutput = {'success': true, 'quote_id': matched['id']};
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🗑️ **Devis supprimé** : Le devis **${matched['quote_number']}** a été supprimé avec succès."
            );
          }
        }
      } else if (name == 'update_quote_status') {
        if (!hasPermission((u) => u.canSell)) {
          responseOutput = {'success': false, 'error': 'Permission refusée.'};
        } else {
          final qNum = args['quote_number'] as String;
          final newStatus = (args['status'] as String).toUpperCase();
          
          final quotes = await ref.read(quoteListProvider.future);
          Map<String, dynamic>? matched;
          for (final q in quotes) {
            if (q['quote_number'].toString().toLowerCase().contains(qNum.toLowerCase())) {
              matched = q;
              break;
            }
          }
          if (matched == null) {
            responseOutput = {'success': false, 'error': 'Devis non trouvé.'};
          } else {
            await ref.read(quoteRepositoryProvider).updateQuoteStatus(matched['id'], newStatus);
            ref.invalidate(quoteListProvider);
            success = true;
            responseOutput = {'success': true, 'quote_id': matched['id'], 'status': newStatus};
            
            final statusStr = newStatus == 'ACCEPTED' 
                ? 'accepté ✅' 
                : newStatus == 'REJECTED' 
                    ? 'refusé ❌' 
                    : 'mis en attente ⏳';
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "📄 **Statut mis à jour** : Le devis **${matched['quote_number']}** est maintenant **$statusStr**."
            );
          }
        }
      } else if (name == 'convert_quote_to_sale') {
        if (!hasPermission((u) => u.canSell)) {
          responseOutput = {'success': false, 'error': 'Permission refusée.'};
        } else {
          final qNum = args['quote_number'] as String;
          final quotes = await ref.read(quoteListProvider.future);
          Map<String, dynamic>? matched;
          for (final q in quotes) {
            if (q['quote_number'].toString().toLowerCase().contains(qNum.toLowerCase())) {
              matched = q;
              break;
            }
          }
          if (matched == null) {
            responseOutput = {'success': false, 'error': 'Devis non trouvé.'};
          } else {
            ref.read(cartProvider.notifier).loadFromQuote(matched['items']);
            await ref.read(quoteRepositoryProvider).updateQuoteStatus(matched['id'], 'CONVERTED');
            ref.invalidate(quoteListProvider);
            
            success = true;
            responseOutput = {'success': true, 'quote_id': matched['id']};
            
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🛒 **Devis converti** : Les articles du devis **${matched['quote_number']}** ont été chargés dans le panier. Redirection vers la caisse..."
            );
            ref.read(assistantProvider.notifier).onAction?.call('navigate', payload: 3); // POS Page
          }
        }
      } else if (name == 'get_quotes_list') {
        if (!hasPermission((u) => u.canSell)) {
          responseOutput = {'success': false, 'error': 'Permission refusée.'};
        } else {
          final quotes = await ref.read(quoteListProvider.future);
          success = true;
          responseOutput = {
            'success': true,
            'quotes': quotes.map((q) => {
              'id': q['id'],
              'quote_number': q['quote_number'],
              'client': q['client'] != null ? q['client']['name'] : 'Client Anonyme',
              'date': q['date'],
              'total_amount': q['total_amount'],
              'status': q['status'],
            }).toList()
          };
          
          final listStr = quotes.isEmpty
              ? "Aucun devis enregistré."
              : quotes.take(10).map((q) {
                  final clientName = q['client'] != null ? q['client']['name'] : 'Anonyme';
                  return "• **${q['quote_number']}** - Client: $clientName - Montant: ${q['total_amount']} FCFA (Statut: ${q['status']})";
                }).join("\n");
                
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "📄 **Liste des Devis** :\n$listStr"
          );
        }
      } else if (name == 'get_expenses_summary') {
        if (!hasPermission((u) => u.canAccessFinance)) {
          responseOutput = {'success': false, 'error': 'Permission refusée.'};
        } else {
          final txs = await ref.read(transactionHistoryProvider.future);
          final expenses = txs.where((t) => t.type == TransactionType.OUT).toList();
          
          double total = 0.0;
          final categoryTotals = <String, double>{};
          for (final ex in expenses) {
            total += ex.amount;
            final cat = ex.category.name;
            categoryTotals[cat] = (categoryTotals[cat] ?? 0.0) + ex.amount;
          }
          
          success = true;
          responseOutput = {
            'success': true,
            'total_expenses': total,
            'breakdown': categoryTotals,
          };
          
          final breakdownStr = categoryTotals.isEmpty
              ? "Aucune dépense enregistrée."
              : categoryTotals.entries.map((e) => "• **${e.key}** : ${e.value} FCFA").join("\n");
              
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "💸 **Résumé des Dépenses** :\n"
            "Total : **$total FCFA**\n\n"
            "Détail par catégorie :\n$breakdownStr"
          );
        }
      } else if (name == 'filter_sales') {
        if (!hasPermission((u) => u.canAccessReports)) {
          responseOutput = {'success': false, 'error': 'Permission refusée pour consulter les rapports.'};
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "⚠️ **Accès refusé** : Votre profil n'a pas l'autorisation d'accéder à l'historique des ventes."
          );
        } else {
          final status = args['status'] as String?;
          final paymentMethod = args['payment_method'] as String?;
          final searchQuery = args['search_query'] as String?;

          if (searchQuery != null) {
            ref.read(salesSearchQueryProvider.notifier).update(searchQuery);
          }
          if (status != null) {
            ref.read(salesStatusFilterProvider.notifier).update(status);
          }
          if (paymentMethod != null) {
            ref.read(salesPaymentFilterProvider.notifier).update(paymentMethod);
          }

          final assistantNotifier = ref.read(assistantProvider.notifier);
          if (assistantNotifier.onAction != null) {
            assistantNotifier.onAction!('navigate', payload: 4);
            success = true;
          }
          responseOutput = {'success': success};
          
          if (success) {
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🔍 J'ai filtré l'historique des ventes pour vous."
            );
          }
        }
      } else if (name == 'manage_sale') {
        final target = args['sale_id_or_client'] as String;
        final action = args['action'] as String;

        if (action == 'refund' && !hasPermission((u) => u.canRefund)) {
          responseOutput = {'success': false, 'error': 'Permission de remboursement insuffisante.'};
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "⚠️ **Accès refusé** : Votre profil n'a pas l'autorisation d'annuler ou rembourser des ventes."
          );
        } else if (!hasPermission((u) => u.canAccessReports)) {
          responseOutput = {'success': false, 'error': 'Permission d\'accès à l\'historique insuffisante.'};
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "⚠️ **Accès refusé** : Votre profil n'a pas l'autorisation de consulter l'historique des ventes."
          );
        } else {
          final sales = await ref.read(salesHistoryProvider.future);
          SaleWithDetails? bestMatch;
          
          for (final s in sales) {
            if (s.sale.id.toLowerCase() == target.toLowerCase() ||
                s.sale.id.toLowerCase().endsWith(target.toLowerCase()) ||
                s.sale.id.toLowerCase().startsWith(target.toLowerCase())) {
              bestMatch = s;
              break;
            }
          }
          
          if (bestMatch == null) {
            double bestScore = 0.0;
            for (final s in sales) {
              final clientName = s.clientName ?? 'passager';
              final score = NlpEngine.similarity(target.toLowerCase(), clientName.toLowerCase());
              if (score > bestScore) {
                bestScore = score;
                bestMatch = s;
              }
            }
            if (bestScore < 0.6) {
              bestMatch = null;
            }
          }

          if (bestMatch == null) {
            responseOutput = {'success': false, 'error': 'Aucune vente correspondante trouvée pour "$target".'};
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "❌ Impossible de trouver la vente associée à **$target**."
            );
          } else {
            final assistantNotifier = ref.read(assistantProvider.notifier);
            if (assistantNotifier.onAction != null) {
              assistantNotifier.onAction!('manage_sale', payload: {
                'saleId': bestMatch.sale.id,
                'action': action,
              });
              success = true;
            }
            responseOutput = {
              'success': success,
              'sale_id': bestMatch.sale.id,
              'client': bestMatch.clientName ?? 'Passager',
              'total': bestMatch.sale.totalAmount,
            };
            
            if (success) {
              final actionVerb = action == 'show_detail' ? 'affiché les détails de' : 
                                 action == 'print_ticket' ? 'lancé l\'impression du ticket de' : 
                                 action == 'print_invoice' ? 'lancé l\'impression de la facture de' : 
                                 'ouvert la boîte de remboursement pour';
              ref.read(assistantProvider.notifier).addAssistantMessage(
                "✅ J'ai $actionVerb la vente **#${bestMatch.sale.id.substring(0, 8).toUpperCase()}** (${bestMatch.clientName ?? 'Passager'})."
              );
            }
          }
        }
      } else if (name == 'compare_sales_periods') {
        if (!hasPermission((u) => u.canAccessReports)) {
          responseOutput = {'success': false, 'error': 'Permission insuffisante.'};
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "⚠️ **Accès refusé** : Votre profil n'a pas l'autorisation d'accéder aux rapports de ventes."
          );
        } else {
          final p1 = args['period1'] as String;
          final p2 = args['period2'] as String;

          DateTimeRange getPeriodRange(String p) {
            final now = DateTime.now();
            final todayStart = DateTime(now.year, now.month, now.day);
            final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
            
            switch (p) {
              case 'today':
                return DateTimeRange(start: todayStart, end: todayEnd);
              case 'yesterday':
                final yest = todayStart.subtract(const Duration(days: 1));
                return DateTimeRange(start: yest, end: DateTime(yest.year, yest.month, yest.day, 23, 59, 59, 999));
              case 'this_week':
                final weekday = now.weekday;
                final start = todayStart.subtract(Duration(days: weekday - 1));
                return DateTimeRange(start: start, end: todayEnd);
              case 'last_week':
                final weekday = now.weekday;
                final startThisWeek = todayStart.subtract(Duration(days: weekday - 1));
                final start = startThisWeek.subtract(const Duration(days: 7));
                final end = startThisWeek.subtract(const Duration(milliseconds: 1));
                return DateTimeRange(start: start, end: end);
              case 'this_month':
                final start = DateTime(now.year, now.month, 1);
                return DateTimeRange(start: start, end: todayEnd);
              case 'last_month':
                final firstOfThisMonth = DateTime(now.year, now.month, 1);
                final end = firstOfThisMonth.subtract(const Duration(milliseconds: 1));
                final start = DateTime(end.year, end.month, 1);
                return DateTimeRange(start: start, end: end);
              default:
                return DateTimeRange(start: todayStart, end: todayEnd);
            }
          }

          final r1 = getPeriodRange(p1);
          final r2 = getPeriodRange(p2);

          final db = await ref.read(databaseServiceProvider).database;
          
          Future<Map<String, dynamic>> getStats(DateTimeRange r) async {
            final startIso = r.start.toIso8601String();
            final endIso = r.end.toIso8601String();
            final res = await db.rawQuery('''
              SELECT COUNT(*) as count, SUM(total_amount) as total
              FROM sales
              WHERE date >= ? AND date <= ? AND status != 'REFUNDED'
            ''', [startIso, endIso]);
            final count = res.first['count'] as int? ?? 0;
            final total = (res.first['total'] as num?)?.toDouble() ?? 0.0;
            return {
              'count': count,
              'total': total,
              'average': count > 0 ? total / count : 0.0,
            };
          }

          final stats1 = await getStats(r1);
          final stats2 = await getStats(r2);

          final total1 = stats1['total'] as double;
          final total2 = stats2['total'] as double;
          final count1 = stats1['count'] as int;
          final count2 = stats2['count'] as int;
          final avg1 = stats1['average'] as double;
          final avg2 = stats2['average'] as double;

          double diffTotalPercent = 0.0;
          if (total2 > 0) {
            diffTotalPercent = ((total1 - total2) / total2) * 100.0;
          } else if (total1 > 0) {
            diffTotalPercent = 100.0;
          }

          success = true;
          responseOutput = {
            'success': true,
            'period1': {'name': p1, 'total': total1, 'count': count1, 'average': avg1},
            'period2': {'name': p2, 'total': total2, 'count': count2, 'average': avg2},
            'variation_percent': diffTotalPercent,
          };

          String formatPeriodName(String p) {
            switch (p) {
              case 'today': return "Aujourd'hui";
              case 'yesterday': return "Hier";
              case 'this_week': return "Cette semaine";
              case 'last_week': return "La semaine dernière";
              case 'this_month': return "Ce mois-ci";
              case 'last_month': return "Le mois dernier";
              default: return p;
            }
          }

          final settings = ref.read(shopSettingsProvider).value;
          final currency = settings?.currency ?? 'FCFA';
          final removeDec = settings?.removeDecimals ?? true;
          String formatAmt(double v) => DateFormatter.formatCurrency(v, currency, removeDecimals: removeDec);

          final sign = diffTotalPercent >= 0 ? '+' : '';
          final signEmoji = diffTotalPercent >= 0 ? '📈' : '📉';

          ref.read(assistantProvider.notifier).addAssistantMessage(
            "📊 **Comparaison de Périodes** :\n\n"
            "| Métrique | ${formatPeriodName(p1)} | ${formatPeriodName(p2)} | Variation |\n"
            "|---|---|---|---|\n"
            "| **Chiffre d'Affaires** | ${formatAmt(total1)} | ${formatAmt(total2)} | **$sign${diffTotalPercent.toStringAsFixed(1)}%** $signEmoji |\n"
            "| **Nombre de Ventes** | $count1 | $count2 | ${count2 > 0 ? '$sign${(((count1 - count2)/count2)*100).toStringAsFixed(1)}%' : '-'} |\n"
            "| **Panier Moyen** | ${formatAmt(avg1)} | ${formatAmt(avg2)} | ${avg2 > 0 ? '$sign${(((avg1 - avg2)/avg2)*100).toStringAsFixed(1)}%' : '-'} |\n"
          );
        }
      } else if (name == 'get_top_profitable_items') {
        if (!hasPermission((u) => u.canAccessReports)) {
          responseOutput = {'success': false, 'error': 'Permission insuffisante.'};
          ref.read(assistantProvider.notifier).addAssistantMessage(
            "⚠️ **Accès refusé** : Votre profil n'a pas l'autorisation d'accéder aux rapports de ventes."
          );
        } else {
          final limit = args['limit'] as int? ?? 5;
          final db = await ref.read(databaseServiceProvider).database;

          final results = await db.rawQuery('''
            SELECT 
              COALESCE(p.name, si.description, 'Article') as product_name, 
              SUM(si.quantity) as total_qty, 
              SUM(si.quantity * (si.unit_price * (1 - si.discount_percent / 100) - si.cost_price)) as total_profit,
              SUM(si.quantity * si.unit_price * (1 - si.discount_percent / 100)) as total_revenue
            FROM sale_items si
            JOIN sales s ON si.sale_id = s.id
            LEFT JOIN products p ON si.product_id = p.id
            WHERE s.status != 'REFUNDED'
            GROUP BY si.product_id, product_name
            ORDER BY total_profit DESC
            LIMIT ?
          ''', [limit]);

          success = true;
          responseOutput = {
            'success': true,
            'items': results,
          };

          if (results.isEmpty) {
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🏆 **Articles les plus rentables** :\n\nAucune vente enregistrée pour le moment."
            );
          } else {
            final settings = ref.read(shopSettingsProvider).value;
            final currency = settings?.currency ?? 'FCFA';
            final removeDec = settings?.removeDecimals ?? true;
            String formatAmt(double v) => DateFormatter.formatCurrency(v, currency, removeDecimals: removeDec);

            final listStr = results.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final r = entry.value;
              final pName = r['product_name'] as String;
              final profit = (r['total_profit'] as num?)?.toDouble() ?? 0.0;
              final rev = (r['total_revenue'] as num?)?.toDouble() ?? 0.0;
              final qty = (r['total_qty'] as num?)?.toDouble() ?? 0.0;
              return "$idx. **$pName** : **${formatAmt(profit)}** de bénéfice (CA: ${formatAmt(rev)} · Qté: ${DateFormatter.formatQuantity(qty)})";
            }).join("\n");

            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🏆 **Top $limit des articles les plus rentables** :\n\n$listStr"
            );
          }
        }
      } else {
        responseOutput = {'success': false, 'error': 'Outil inconnu.'};
      }
    } catch (e) {
      if (kDebugMode) print('[VoiceService] Erreur lors de l\'exécution du tool call: $e');
      responseOutput = {'success': false, 'error': e.toString()};
    }

    final currentAlert = ref.read(proactiveAlertProvider);
    if (currentAlert != null && currentAlert.title == "Action Danaya") {
      ref.read(proactiveAlertProvider.notifier).clear();
    }
    state = state.copyWith(statusText: "Danaya réfléchit...");

    _liveService?.sendToolResponse(callId, responseOutput);
  }

  static double expandVoiceAmount(double amount, {double? referenceTotal}) {
    if (amount <= 0.0) return amount;

    // Si nous avons un total de référence, vérifier en priorité si le montant prononcé
    // correspond à une version simplifiée (en milliers ou millions) de ce total.
    if (referenceTotal != null && referenceTotal > 0.0) {
      final scaledThousand = amount * 1000.0;
      if ((scaledThousand - referenceTotal).abs() / referenceTotal < 0.1) {
        return scaledThousand;
      }
      final scaledMillion = amount * 1000000.0;
      if ((scaledMillion - referenceTotal).abs() / referenceTotal < 0.1) {
        return scaledMillion;
      }
    }

    // Les montants >= 100 sont probablement déjà corrects (pas d'expansion nécessaire)
    // hors contexte de référence (ex: 500 FCFA, 1000 FCFA).
    if (amount >= 100.0) return amount;

    // Si le montant est très petit (<= 10.0), il s'agit probablement de millions.
    if (amount <= 10.0) {
      return amount * 1000000.0;
    }

    // Montants entre 10 et 100 : multipliés par 1000 par défaut (ex: 50 prononcé = 50 mille).
    return amount * 1000.0;
  }

  double _calculatePcmDb(Uint8List pcmData) {
    if (pcmData.isEmpty) return -120.0;
    double sum = 0.0;
    final count = pcmData.length ~/ 2;
    if (count == 0) return -120.0;

    for (int i = 0; i < count; i++) {
      final int low = pcmData[i * 2];
      final int high = pcmData[i * 2 + 1];
      int sample = (high << 8) | low;
      if (sample >= 32768) {
        sample -= 65536;
      }
      sum += sample * sample;
    }

    final double rms = math.sqrt(sum / count);
    if (rms == 0) return -120.0;
    return 20 * math.log(rms / 32767.0) / math.ln10;
  }

  void _updateUserSoundWaves(double db) {
    // Normalisation dB entre -50 et -10 pour un rendu de vague à l'écran
    double normalized = (db + 50) / 40.0;
    normalized = normalized.clamp(0.0, 1.0);
    // Lissage temporel de l'amplitude (moyenne mobile exponentielle) pour l'utilisateur
    _smoothAmplitude = _smoothAmplitude * 0.4 + normalized * 0.6;
  }

  void _updateAiSoundWaves(double db) {
    // Normalisation dB pour la voix de l'IA (seuil légèrement différent)
    double normalized = (db + 50) / 35.0;
    normalized = normalized.clamp(0.0, 1.0);
    // Lissage plus réactif pour suivre le rythme rapide de la voix de l'IA
    _smoothAmplitude = _smoothAmplitude * 0.3 + normalized * 0.7;
  }

  void _startWaveAnimation() {
    _waveTimer?.cancel();
    _waveTime = 0.0;
    // 80ms (12fps) au lieu de 40ms (25fps) — suffisant pour l'œil humain, réduit le flood Win32 de 60%
    _waveTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!state.isCallActive && !state.isListening && !state.isSpeaking) {
        timer.cancel();
        return;
      }

      _waveTime += 0.25; // Ajusté pour compenser l'intervalle plus long (mouvement visuellement identique)

      // Décroissance naturelle lente de l'amplitude si aucun son n'est capté
      _smoothAmplitude *= 0.88; // Ajusté pour 80ms (0.92^2 ≈ 0.85, on lisse à 0.88)
      if (_smoothAmplitude < 0.01) _smoothAmplitude = 0.0;

      final List<double> waves = List.generate(20, (i) {
        final double phase = _waveTime + i * 0.35;
        
        if (state.isSpeaking || state.isListening) {
          // Ondulation de base (respiration calme) + amplitude de la voix réelle (utilisateur ou assistant)
          final double standBy = math.sin(_waveTime * 0.5 + i * 0.25) * 0.02;
          final double voiceWave = _smoothAmplitude * 0.6 * math.sin(phase).abs();
          final double waveVal = 0.08 + (standBy + voiceWave);
          return waveVal.clamp(0.06, 0.95);
        } else if (state.statusText == "Réflexion en cours...") {
          // Réflexion : vague sinusoïdale rythmée régulière et élégante (effet Siri/Gemini)
          final double pulse = 0.15 + (math.sin(_waveTime * 1.2 + i * 0.3) * 0.06);
          return pulse.clamp(0.06, 0.95);
        } else {
          // Ligne de respiration au repos
          final double breathe = 0.08 + (math.sin(_waveTime * 0.3 + i * 0.15) * 0.01);
          return breathe.clamp(0.06, 0.95);
        }
      });

      ref.read(soundWavesProvider.notifier).set(waves);
    });
  }

  Future<void> _stopRecorderQuietly() async {
    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
    } catch (_) {}
  }

  // --- DICTÉE CLASSIQUE (Standard single-turn voice dictation) ---

  void toggleListening() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      ref.read(assistantProvider.notifier).addAssistantMessage(
        "🚨 **Erreur Micro (Windows)** :\n\n"
        "L'assistant n'arrive pas à accéder à votre microphone. Veuillez vérifier vos paramètres."
      );
      return;
    }

    if (state.isListening) {
      await stopListening();
    } else {
      await startListening();
    }
  }

  Future<void> cancelListening() async {
    if (!state.isListening) return;
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _dictationTimer?.cancel();
    _dictationTimer = null;
    await _stopRecorderQuietly();
    state = state.copyWith(
      isListening: false,
      statusText: "",
      dictationDuration: 0,
    );
  }

  Future<void> startListening() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      ref.read(assistantProvider.notifier).addAssistantMessage(
        "🚨 **Erreur Micro (Windows)** :\n\n"
        "L'assistant n'arrive pas à accéder à votre microphone. Veuillez vérifier vos paramètres."
      );
      return;
    }

    await _stopRecorderQuietly();
    _dictationTimer?.cancel();
    _dictationTimer = null;

    state = state.copyWith(
      isListening: true,
      lastWords: '',
      error: '',
      statusText: "Dictée en cours...",
      dictationDuration: 0,
    );

    ref.read(soundWavesProvider.notifier).set(List.generate(20, (_) => 0.08));

    _startWaveAnimation();

    _dictationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!state.isListening) {
        timer.cancel();
        return;
      }
      state = state.copyWith(dictationDuration: state.dictationDuration + 1);
    });

    try {
      final tempDir = await getTemporaryDirectory();
      _recordingPath = '${tempDir.path}/danaya_dictation_input.wav';

      final file = File(_recordingPath!);
      if (await file.exists()) {
        await file.delete();
      }

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          numChannels: 1,
          sampleRate: 16000,
        ),
        path: _recordingPath!,
      );

      _amplitudeSubscription?.cancel();
      _amplitudeSubscription = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 70))
          .listen((amp) {
        _updateUserSoundWaves(amp.current);
      });
    } catch (e) {
      _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;
      _dictationTimer?.cancel();
      _dictationTimer = null;
      state = state.copyWith(isListening: false, error: e.toString());
      ref.read(assistantProvider.notifier).addAssistantMessage(
        "🚨 **Erreur lors du démarrage du micro** :\n\n$e"
      );
    }
  }

  Future<void> stopListening() async {
    if (!state.isListening) return;

    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _dictationTimer?.cancel();
    _dictationTimer = null;

    state = state.copyWith(
      isListening: false, 
      statusText: "Transcription...",
      dictationDuration: 0,
    );

    try {
      await _audioRecorder.stop();
      
      final file = File(_recordingPath!);
      if (!await file.exists()) {
        ref.read(assistantProvider.notifier).addAssistantMessage(
          "⚠️ **Fichier audio introuvable ou vide**."
        );
        return;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        ref.read(assistantProvider.notifier).addAssistantMessage(
          "⚠️ **Enregistrement vide**."
        );
        return;
      }

      final settings = ref.read(shopSettingsProvider).value;
      final apiKey = settings?.geminiApiKey ?? "";

      if (apiKey.isEmpty) {
        ref.read(assistantProvider.notifier).addAssistantMessage(
          "⚠️ **Clé API Danaya VIP non configurée** pour la voix."
        );
        return;
      }

      // Utilisation du service Google Cloud Voice pour une transcription Bambara/Français précise
      final googleVoice = GoogleCloudVoiceService(apiKey: apiKey);
      String text = await googleVoice.transcribeBambara(bytes);

      // Si la transcription Google Cloud échoue (ex: quota, etc.), repli sur Gemini
      if (text.isEmpty) {
        final gemini = GeminiService(apiKey: apiKey);
        text = await gemini.transcribeAudio(bytes, 'audio/wav');
      }

      if (text.trim().isNotEmpty) {
        // Détecter si la transcription ressemble à une langue locale et la traduire automatiquement
        if (_isLikelyBambara(text)) {
          final translated = await googleVoice.translateBambaraToFrench(text);
          if (translated.isNotEmpty && translated != text) {
            ref.read(assistantProvider.notifier).addAssistantMessage(
              "🗣️ **Traduction** : \"$text\" ➔ \"$translated\""
            );
            text = translated;
          }
        }
        _processVoiceCommand(text);
      } else {
        ref.read(assistantProvider.notifier).addAssistantMessage(
          "ℹ️ **Aucune parole détectée**."
        );
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
      ref.read(assistantProvider.notifier).addAssistantMessage(
        "🚨 **Erreur lors de l'enregistrement ou de la transcription** :\n\n$e"
      );
    } finally {
      state = state.copyWith(statusText: "");
    }
  }

  bool _isLikelyBambara(String text) {
    // Nettoyer le texte pour ne garder que les mots et espaces
    final cleanText = text.toLowerCase().replaceAll(RegExp(r'[.,\/#!$%\^&\*;:{}=\-_`~()?🗣️]'), ' ');
    final words = cleanText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();

    // Liste de mots clés de langues locales fréquentes (Bambara/Dioula, Wolof, Peul, Baoulé)
    final localKeywords = {
      // Bambara / Dioula
      'wari', 'jago', 'diago', 'juru', 'djourou', 'feere', 'songo', 'sɔngɔ', 'tye', 'kene', 'toro', 'nyi',
      'ini', 'cɛ', 'aw', 'ni', 'taa', 'hake', 'sugui', 'bamanankan', 'sabali', 'dɔɔni', 'muso',
      // Wolof
      'xalis', 'khaliss', 'jaay', 'djaay', 'jënd', 'djeund', 'nanga', 'def', 'bor', 'waaw', 'deedeet',
      'jerejef', 'dieuredieuf', 'gnata', 'ñata',
      // Peul / Fula
      'kaalis', 'yeey', 'sood', 'nyaw', 'jarama',
      // Baoulé
      'sika', 'nani'
    };

    // Vérifier si au moins un mot de la phrase correspond EXACTEMENT à un mot-clé local
    for (final word in words) {
      if (localKeywords.contains(word)) {
        return true;
      }
    }
    return false;
  }

  void _processVoiceCommand(String words) {
    if (words.isEmpty) return;
    ref.read(assistantProvider.notifier).sendMessage(words);
  }
}

typedef MciSendStringC = Uint32 Function(
  Pointer<Utf16> lpszCommand,
  Pointer<Utf16> lpszReturnString,
  Uint32 cchReturn,
  IntPtr hwndCallback,
);

typedef MciSendStringDart = int Function(
  Pointer<Utf16> lpszCommand,
  Pointer<Utf16> lpszReturnString,
  int cchReturn,
  int hwndCallback,
);

// --- WIN32 WAVEOUT LOW-LATENCY AUDIO STREAMING PLAYER ---

final class WAVEFORMATEX extends Struct {
  @Uint16()
  external int wFormatTag;
  @Uint16()
  external int nChannels;
  @Uint32()
  external int nSamplesPerSec;
  @Uint32()
  external int nAvgBytesPerSec;
  @Uint16()
  external int nBlockAlign;
  @Uint16()
  external int wBitsPerSample;
  @Uint16()
  external int cbSize;
}

final class WAVEHDR extends Struct {
  external Pointer<Uint8> lpData;
  @Uint32()
  external int dwBufferLength;
  @Uint32()
  external int dwBytesRecorded;
  external Pointer<Void> dwUser;
  @Uint32()
  external int dwFlags;
  @Uint32()
  external int dwLoops;
  external Pointer<WAVEHDR> lpNext;
  external Pointer<Void> reserved;
}

typedef WaveOutOpenC = Uint32 Function(
  Pointer<IntPtr> phwo,
  Uint32 uDeviceID,
  Pointer<WAVEFORMATEX> pwfx,
  IntPtr dwCallback,
  IntPtr dwInstance,
  Uint32 fdwOpen
);
typedef WaveOutOpenDart = int Function(
  Pointer<IntPtr> phwo,
  int uDeviceID,
  Pointer<WAVEFORMATEX> pwfx,
  int dwCallback,
  int dwInstance,
  int fdwOpen
);

typedef WaveOutCloseC = Uint32 Function(IntPtr hwo);
typedef WaveOutCloseDart = int Function(int hwo);

typedef WaveOutPrepareHeaderC = Uint32 Function(
  IntPtr hwo,
  Pointer<WAVEHDR> pwh,
  Uint32 cbwh
);
typedef WaveOutPrepareHeaderDart = int Function(
  int hwo,
  Pointer<WAVEHDR> pwh,
  int cbwh
);

typedef WaveOutUnprepareHeaderC = Uint32 Function(
  IntPtr hwo,
  Pointer<WAVEHDR> pwh,
  Uint32 cbwh
);
typedef WaveOutUnprepareHeaderDart = int Function(
  int hwo,
  Pointer<WAVEHDR> pwh,
  int cbwh
);

typedef WaveOutWriteC = Uint32 Function(
  IntPtr hwo,
  Pointer<WAVEHDR> pwh,
  Uint32 cbwh
);
typedef WaveOutWriteDart = int Function(
  int hwo,
  Pointer<WAVEHDR> pwh,
  int cbwh
);

typedef WaveOutResetC = Uint32 Function(IntPtr hwo);
typedef WaveOutResetDart = int Function(int hwo);

class WaveOutPlayer {
  final DynamicLibrary _winmm;
  late final WaveOutOpenDart _waveOutOpen;
  late final WaveOutCloseDart _waveOutClose;
  late final WaveOutPrepareHeaderDart _waveOutPrepareHeader;
  late final WaveOutUnprepareHeaderDart _waveOutUnprepareHeader;
  late final WaveOutWriteDart _waveOutWrite;
  late final WaveOutResetDart _waveOutReset;

  int _hWaveOut = 0;
  bool _isOpen = false;
  final List<Pointer<WAVEHDR>> _activeHeaders = [];
  Timer? _cleanupTimer;
  void Function()? onPlaybackComplete;

  WaveOutPlayer(this._winmm) {
    _waveOutOpen = _winmm.lookupFunction<WaveOutOpenC, WaveOutOpenDart>('waveOutOpen');
    _waveOutClose = _winmm.lookupFunction<WaveOutCloseC, WaveOutCloseDart>('waveOutClose');
    _waveOutPrepareHeader = _winmm.lookupFunction<WaveOutPrepareHeaderC, WaveOutPrepareHeaderDart>('waveOutPrepareHeader');
    _waveOutUnprepareHeader = _winmm.lookupFunction<WaveOutUnprepareHeaderC, WaveOutUnprepareHeaderDart>('waveOutUnprepareHeader');
    _waveOutWrite = _winmm.lookupFunction<WaveOutWriteC, WaveOutWriteDart>('waveOutWrite');
    _waveOutReset = _winmm.lookupFunction<WaveOutResetC, WaveOutResetDart>('waveOutReset');
  }

  bool get isPlaying => _activeHeaders.isNotEmpty;

  void open(int sampleRate) {
    if (_isOpen) return;

    final phwo = calloc<IntPtr>();
    final pwfx = calloc<WAVEFORMATEX>();

    pwfx.ref.wFormatTag = 1; // WAVE_FORMAT_PCM
    pwfx.ref.nChannels = 1; // Mono
    pwfx.ref.nSamplesPerSec = sampleRate;
    pwfx.ref.wBitsPerSample = 16;
    pwfx.ref.nBlockAlign = 2;
    pwfx.ref.nAvgBytesPerSec = sampleRate * 2;
    pwfx.ref.cbSize = 0;

    final res = _waveOutOpen(phwo, -1, pwfx, 0, 0, 0);
    _hWaveOut = phwo.value;

    calloc.free(phwo);
    calloc.free(pwfx);

    if (res == 0) {
      _isOpen = true;
      _startCleanupTimer();
    } else {
      if (kDebugMode) print('[WaveOut] Failed to open waveOut device: $res');
    }
  }

  void write(Uint8List pcmData) {
    if (!_isOpen || _hWaveOut == 0) return;

    final dataPtr = calloc<Uint8>(pcmData.length);
    final dataList = dataPtr.asTypedList(pcmData.length);
    dataList.setAll(0, pcmData);

    final pwh = calloc<WAVEHDR>();
    pwh.ref.lpData = dataPtr;
    pwh.ref.dwBufferLength = pcmData.length;
    pwh.ref.dwBytesRecorded = pcmData.length;
    pwh.ref.dwFlags = 0;
    pwh.ref.dwLoops = 0;
    pwh.ref.lpNext = nullptr;
    pwh.ref.reserved = nullptr;

    final prepRes = _waveOutPrepareHeader(_hWaveOut, pwh, sizeOf<WAVEHDR>());
    if (prepRes != 0) {
      if (kDebugMode) print('[WaveOut] waveOutPrepareHeader failed: $prepRes');
      calloc.free(dataPtr);
      calloc.free(pwh);
      return;
    }

    final writeRes = _waveOutWrite(_hWaveOut, pwh, sizeOf<WAVEHDR>());
    if (writeRes != 0) {
      if (kDebugMode) print('[WaveOut] waveOutWrite failed: $writeRes');
      _waveOutUnprepareHeader(_hWaveOut, pwh, sizeOf<WAVEHDR>());
      calloc.free(dataPtr);
      calloc.free(pwh);
      return;
    }

    _activeHeaders.add(pwh);
  }

  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    // 100ms au lieu de 50ms — réduit la charge Win32 de moitié tout en gardant la réactivité
    _cleanupTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _cleanupFinishedBuffers();
    });
  }

  void _cleanupFinishedBuffers() {
    if (!_isOpen || _hWaveOut == 0) return;

    final List<Pointer<WAVEHDR>> toRemove = [];
    final bool wasPlaying = _activeHeaders.isNotEmpty;

    for (final pwh in _activeHeaders) {
      if ((pwh.ref.dwFlags & 1) != 0) {
        _waveOutUnprepareHeader(_hWaveOut, pwh, sizeOf<WAVEHDR>());
        calloc.free(pwh.ref.lpData);
        calloc.free(pwh);
        toRemove.add(pwh);
      }
    }

    for (final pwh in toRemove) {
      _activeHeaders.remove(pwh);
    }

    if (wasPlaying && _activeHeaders.isEmpty) {
      onPlaybackComplete?.call();
    }
  }

  void reset() {
    if (!_isOpen || _hWaveOut == 0) return;
    _waveOutReset(_hWaveOut);
    _cleanupFinishedBuffers();
  }

  void close() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;

    if (_isOpen && _hWaveOut != 0) {
      _waveOutReset(_hWaveOut);
      // Force clean up all remaining headers to avoid device locks
      for (final pwh in _activeHeaders) {
        _waveOutUnprepareHeader(_hWaveOut, pwh, sizeOf<WAVEHDR>());
        if (pwh.ref.lpData != nullptr) {
          calloc.free(pwh.ref.lpData);
        }
        calloc.free(pwh);
      }
      _activeHeaders.clear();
      _waveOutClose(_hWaveOut);
    }

    _hWaveOut = 0;
    _isOpen = false;
  }
}
