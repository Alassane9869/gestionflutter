import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

enum LiveConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

class GeminiLiveService {
  final String apiKey;
  final String model;
  final String voiceName;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  LiveConnectionState _connectionState = LiveConnectionState.disconnected;
  bool _setupComplete = false;

  // Callbacks pour l'application
  void Function(String text)? onTextReceived;
  void Function(Uint8List pcmChunk)? onAudioReceived;
  void Function()? onTurnComplete;
  void Function()? onInterrupted;
  void Function(LiveConnectionState state)? onConnectionStateChanged;
  void Function(String error)? onError;
  void Function()? onSetupComplete;
  void Function(String callId, String name, Map<String, dynamic> args)? onToolCallReceived;
  // ULTRA-PRO: Transcription temps réel (sous-titres) de la voix utilisateur et de l'IA
  void Function(String transcript, bool isFinal)? onInputTranscription;
  void Function(String transcript)? onOutputTranscription;
  // ULTRA-PRO: Token de reprise de session pour reconnexion instantanée
  String? _lastSessionToken;
  String? get lastSessionToken => _lastSessionToken;

  GeminiLiveService({
    required this.apiKey,
    // gemini-3.1-flash-live-preview est le modèle officiel supportant la Live API v1beta
    this.model = 'gemini-3.1-flash-live-preview',
    this.voiceName = 'Kore',
  });

  LiveConnectionState get connectionState => _connectionState;
  bool get isSetupComplete => _setupComplete;

  void _updateState(LiveConnectionState newState) {
    _connectionState = newState;
    onConnectionStateChanged?.call(newState);
  }

  /// Établit la connexion WebSocket et envoie la configuration initiale (Setup)
  Future<void> connect({
    required String systemInstruction,
    required String businessContext,
    Map<String, bool>? enabledTools,
  }) async {
    if (_connectionState == LiveConnectionState.connected ||
        _connectionState == LiveConnectionState.connecting) {
      return;
    }

    _updateState(LiveConnectionState.connecting);
    _setupComplete = false;

    // Endpoint officiel de la Live API de Gemini (v1beta)
    final uri = Uri.parse(
      'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=$apiKey',
    );

    try {
      if (kDebugMode) print('[GeminiLive] Connexion WebSocket vers: ${uri.host}');
      if (kIsWeb) {
        _channel = WebSocketChannel.connect(uri);
      } else {
        _channel = IOWebSocketChannel.connect(
          uri,
          pingInterval: const Duration(seconds: 10),
        );
      }
      await _channel!.ready;
      if (_channel == null || _connectionState == LiveConnectionState.disconnected) {
        if (kDebugMode) print('[GeminiLive] Connexion annulée/fermée pendant le chargement.');
        return;
      }
      if (kDebugMode) print('[GeminiLive] WebSocket connecté. Envoi du Setup...');
      _updateState(LiveConnectionState.connected);

      // S'abonner aux messages du serveur
      _subscription = _channel!.stream.listen(
        (message) => _handleIncomingMessage(message),
        onError: (err) {
          if (kDebugMode) print('[GeminiLive] WS Error: $err');
          _updateState(LiveConnectionState.error);
          onError?.call('Erreur WebSocket: $err');
          disconnect();
        },
        onDone: () {
          final code = _channel?.closeCode;
          final reason = _channel?.closeReason;
          if (kDebugMode) {
            print('[GeminiLive] WS Fermé. Code: $code, Raison: $reason');
          }
          _setupComplete = false;
          if (_connectionState != LiveConnectionState.error) {
            _updateState(LiveConnectionState.disconnected);
          }
          if (onError != null && code != null && code != 1000) {
            if (code == 1008) {
              onError!('Session expirée après la durée maximale d\'API Danaya Live (GoAway).');
            } else {
              onError!('Connexion fermée (Code: $code, Raison: $reason)');
            }
          }
          _cleanup();
        },
        cancelOnError: false,
      );

      // Envoyer le message de Setup initial
      _sendSetup(systemInstruction, businessContext, enabledTools: enabledTools);

    } catch (e) {
      if (kDebugMode) print('[GeminiLive] Connexion échouée: $e');
      _updateState(LiveConnectionState.error);
      onError?.call('Impossible de se connecter: $e');
      _cleanup();
    }
  }

  /// Ferme proprement la connexion
  void disconnect() {
    _cleanup();
    if (_connectionState != LiveConnectionState.error) {
      _updateState(LiveConnectionState.disconnected);
    }
  }

  void _cleanup() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _setupComplete = false;
  }

  /// Envoie le message d'initialisation Setup avec les configurations audio
  void _sendSetup(String systemInstruction, String businessContext, {Map<String, bool>? enabledTools}) {
    if (_channel == null || _connectionState != LiveConnectionState.connected) return;

    // Fusionner la consigne globale de Danaya Copilot avec le contexte boutique
    final fullInstructions = '$systemInstruction\n\n$businessContext';

    // Toutes les déclarations d'outils disponibles
    final allToolDeclarations = <Map<String, dynamic>>[
      {
        'name': 'navigate',
        'description': 'Navigue vers une page spécifique de l\'application.',
        'parameters': {
          'type': 'object',
          'properties': {
            'page': {
              'type': 'string',
              'description': 'La page ciblée.',
              'enum': ['dashboard', 'caisse', 'stock', 'finances', 'clients', 'fournisseurs', 'parametres', 'rapports', 'mouvements_stock', 'historique_ventes', 'devis', 'entrepots', 'dettes_clients', 'depenses', 'alertes_stock', 'audit_stock']
            },
            'settings_tab': {
              'type': 'string',
              'description': 'L\'onglet spécifique à ouvrir si la page est "parametres". Optionnel.',
              'enum': [
                'enseigne', 
                'finance', 
                'fidelite', 
                'politique', 
                'apparence', 
                'imprimante', 
                'afficheur', 
                'son', 
                'assistant', 
                'smtp', 
                'sauvegarde', 
                'serveur', 
                'logs', 
                'personnalisation', 
                'academy', 
                'whatsapp'
              ]
            }
          },
          'required': ['page']
        }
      },
      {
        'name': 'change_theme',
        'description': 'Change le thème (mode sombre/clair) et/ou la couleur d\'accentuation de l\'application.',
        'parameters': {
          'type': 'object',
          'properties': {
            'mode': {
              'type': 'string',
              'description': 'Le mode de thème visuel',
              'enum': ['sombre', 'clair']
            },
            'color': {
              'type': 'string',
              'description': 'La couleur d\'accentuation',
              'enum': ['blue', 'orange', 'green', 'purple', 'red', 'teal', 'pink', 'grey']
            }
          }
        }
      },
      {
        'name': 'update_shop_settings',
        'description': 'Modifie directement un ou plusieurs paramètres de configuration de la boutique (nom, tva, devise, slogan, imprimantes assignées, etc.).',
        'parameters': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'description': 'Le nouveau nom de la boutique.'},
            'slogan': {'type': 'string', 'description': 'Le nouveau slogan de la boutique.'},
            'phone': {'type': 'string', 'description': 'Le numéro de téléphone.'},
            'whatsapp': {'type': 'string', 'description': 'Le numéro WhatsApp.'},
            'address': {'type': 'string', 'description': 'L\'adresse de la boutique.'},
            'email': {'type': 'string', 'description': 'L\'adresse e-mail.'},
            'rc': {'type': 'string', 'description': 'Le registre du commerce (RCCM) de l\'entreprise.'},
            'nif': {'type': 'string', 'description': 'Le numéro d\'identification fiscale (NIF) de l\'entreprise.'},
            'bank_account': {'type': 'string', 'description': 'Les coordonnées bancaires de la boutique.'},
            'legal_form': {'type': 'string', 'description': 'La forme juridique de l\'entreprise (ex: SARL, SA, ETS).'},
            'capital': {'type': 'string', 'description': 'Le capital social de l\'entreprise.'},
            'currency': {'type': 'string', 'description': 'La devise de la boutique (ex: FCFA, GNF, EUR, USD).'},
            'tax_rate': {'type': 'number', 'description': 'Le taux de taxe / TVA en pourcentage (ex: 18.0).'},
            'use_tax': {'type': 'boolean', 'description': 'true pour activer la taxe, false pour la désactiver.'},
            'tax_name': {'type': 'string', 'description': 'Le nom de la taxe à appliquer (ex: TVA, TPS).'},
            'receipt_footer': {'type': 'string', 'description': 'Le message affiché en pied de page sur les tickets de caisse.'},
            'quote_validity_days': {'type': 'integer', 'description': 'Le nombre de jours de validité par défaut des devis (ex: 30).'},
            'invoice_legal_note': {'type': 'string', 'description': 'Les mentions légales ou remarques affichées sur les factures.'},
            'default_receipt': {'type': 'string', 'description': 'Le modèle de reçu par défaut.', 'enum': ['classic', 'modern', 'minimal', 'elite', 'prestige']},
            'default_invoice': {'type': 'string', 'description': 'Le modèle de facture par défaut.', 'enum': ['corporate', 'elegant', 'clean', 'noirEtBlanc', 'minimaliste', 'epure', 'style', 'prestige']},
            'default_quote': {'type': 'string', 'description': 'Le modèle de devis par défaut.', 'enum': ['minimaliste', 'style', 'prestige', 'modern', 'professional', 'clean', 'minimalist', 'corporate', 'supreme']},
            'default_purchase_order': {'type': 'string', 'description': 'Le modèle de bon de commande par défaut.', 'enum': ['classic', 'modern', 'professional', 'clean', 'compact', 'supreme']},
            'thermal_format': {'type': 'string', 'description': 'Le format du papier d\'impression thermique.', 'enum': ['mm58', 'mm80']},
            'thermal_printer_name': {'type': 'string', 'description': 'Le nom de l\'imprimante thermique pour les tickets de caisse.'},
            'invoice_printer_name': {'type': 'string', 'description': 'Le nom de l\'imprimante pour les factures A4.'},
            'quote_printer_name': {'type': 'string', 'description': 'Le nom de l\'imprimante pour les devis.'},
            'label_printer_name': {'type': 'string', 'description': 'Le nom de l\'imprimante pour les étiquettes code-barres.'},
            'open_cash_drawer': {'type': 'boolean', 'description': 'true pour ouvrir le tiroir-caisse automatiquement à la vente.'},
            'auto_print_ticket': {'type': 'boolean', 'description': 'true pour imprimer automatiquement le ticket après encaissement.'},
            'direct_physical_printing': {'type': 'boolean', 'description': 'true pour envoyer directement l\'impression physique sans dialogue Flutter.'},
            'show_preview_before_print': {'type': 'boolean', 'description': 'true pour afficher l\'aperçu PDF avant d\'imprimer.'},
            'max_discount_threshold': {'type': 'number', 'description': 'Le taux de remise maximal autorisé en caisse (en pourcentage, ex: 10.0).'},
            'vip_threshold': {'type': 'number', 'description': 'Le montant total d\'achat cumulé à partir duquel un client devient VIP.'},
            'loyalty_enabled': {'type': 'boolean', 'description': 'true pour activer le programme de fidélité, false pour le désactiver.'},
            'points_per_amount': {'type': 'number', 'description': 'Le montant d\'achat nécessaire pour obtenir un point de fidélité (ex: 1000.0).'},
            'amount_per_point': {'type': 'number', 'description': 'La valeur monétaire de réduction d\'un point de fidélité lors d\'un achat (ex: 10.0).'},
            'is_auto_lock_enabled': {'type': 'boolean', 'description': 'true pour activer le verrouillage automatique de la session caisse.'},
            'auto_lock_minutes': {'type': 'integer', 'description': 'Le nombre de minutes d\'inactivité avant le verrouillage automatique (ex: 5).'},
            'customer_display_theme': {'type': 'string', 'description': 'Le thème visuel de l\'afficheur client (ex: theme-kita, theme-luxury, theme-faso, etc.).'},
            'enable_customer_display_sounds': {'type': 'boolean', 'description': 'true pour activer les sons de l\'afficheur client, false pour les couper.'},
            'use_customer_display_3d': {'type': 'boolean', 'description': 'true pour activer le rendu 3D de l\'afficheur client, false pour le désactiver.'},
            'is_voice_enabled': {'type': 'boolean', 'description': 'true pour activer la synthèse vocale sur l\'afficheur client, false pour la désactiver.'},
            'enable_customer_display_ticker': {'type': 'boolean', 'description': 'true pour activer le bandeau défilant sur l\'afficheur client, false pour le masquer.'},
            'customer_display_messages': {'type': 'array', 'items': {'type': 'string'}, 'description': 'Liste des messages personnalisés défilants sur l\'afficheur client.'},
            'show_tax_on_tickets': {'type': 'boolean', 'description': 'true pour afficher la taxe sur les tickets de caisse.'},
            'show_tax_on_invoices': {'type': 'boolean', 'description': 'true pour afficher la taxe sur les factures.'},
            'show_tax_on_quotes': {'type': 'boolean', 'description': 'true pour afficher la taxe sur les devis.'},
            'use_detailed_tax_on_tickets': {'type': 'boolean', 'description': 'true pour afficher le détail de la taxe sur les tickets de caisse.'},
            'use_detailed_tax_on_invoices': {'type': 'boolean', 'description': 'true pour afficher le détail de la taxe sur les factures.'},
            'use_detailed_tax_on_quotes': {'type': 'boolean', 'description': 'true pour afficher le détail de la taxe sur les devis.'},
            'allow_cloud_ai_actions': {'type': 'boolean', 'description': 'true pour autoriser l\'IA Cloud à exécuter des actions sur la base de données.'},
            'remove_decimals': {'type': 'boolean', 'description': 'true pour masquer les décimales dans les prix (ex: 1000 au lieu de 1000.00).'},
            'show_qr_code': {'type': 'boolean', 'description': 'true pour afficher le QR code sur les documents.'},
            'use_auto_ref': {'type': 'boolean', 'description': 'true pour générer automatiquement les références des produits.'},
            'ref_prefix': {'type': 'string', 'description': 'Le préfixe utilisé pour les références automatiques (ex: PROD).'},
            'ref_model': {'type': 'string', 'description': 'Le modèle de génération de référence.', 'enum': ['categorical', 'timestamp', 'sequential', 'random']},
            'barcode_model': {'type': 'string', 'description': 'Le modèle de génération automatique de code-barres.', 'enum': ['ean13', 'upcA', 'code128', 'numeric9']},
            'auto_backup_enabled': {'type': 'boolean', 'description': 'true pour activer les sauvegardes automatiques locales.'},
            'policy_warranty': {'type': 'string', 'description': 'Conditions de garantie à afficher sur les documents.'},
            'policy_returns': {'type': 'string', 'description': 'Politique de retour et remboursement.'},
            'policy_payments': {'type': 'string', 'description': 'Conditions et modalités de paiement.'},
            'purchase_order_printer_name': {'type': 'string', 'description': 'Nom de l\'imprimante pour les bons de commande.'},
            'contract_printer_name': {'type': 'string', 'description': 'Nom de l\'imprimante pour les contrats de travail.'},
            'payroll_printer_name': {'type': 'string', 'description': 'Nom de l\'imprimante pour les fiches de paie.'},
            'report_printer_name': {'type': 'string', 'description': 'Nom de l\'imprimante pour les rapports d\'activité.'},
            'proforma_printer_name': {'type': 'string', 'description': 'Nom de l\'imprimante pour les factures proforma.'},
            'delivery_printer_name': {'type': 'string', 'description': 'Nom de l\'imprimante pour les bons de livraison.'},
            'auto_print_delivery_note': {'type': 'boolean', 'description': 'true pour imprimer automatiquement le bon de livraison après vente.'},
            'show_price_on_labels': {'type': 'boolean', 'description': 'true pour imprimer le prix sur les étiquettes de code-barres.'},
            'show_name_on_labels': {'type': 'boolean', 'description': 'true pour imprimer le nom du produit sur les étiquettes.'},
            'show_sku_on_labels': {'type': 'boolean', 'description': 'true pour imprimer la référence SKU sur les étiquettes.'},
            'auto_print_labels_on_stock_in': {'type': 'boolean', 'description': 'true pour imprimer automatiquement les étiquettes lors d\'une entrée en stock.'},
            'show_assistant': {'type': 'boolean', 'description': 'true pour afficher l\'affichette d\'assistant virtuel à l\'écran.'},
            'network_mode': {'type': 'string', 'description': 'Mode réseau de l\'application.', 'enum': ['solo', 'server', 'client']},
            'server_ip': {'type': 'string', 'description': 'IP du serveur principal en mode client.'},
            'server_port': {'type': 'integer', 'description': 'Port réseau de communication du serveur.'},
            'sync_key': {'type': 'string', 'description': 'Clé de sécurité pour la synchronisation réseau.'},
            'rounding_mode': {'type': 'string', 'description': 'Mode d\'arrondi des totaux en caisse.', 'enum': ['none', 'nearest5', 'nearest10', 'nearest25', 'nearest50', 'nearest100']},
            'label_ht': {'type': 'string', 'description': 'Libellé Hors Taxes (ex: HT).'},
            'label_ttc': {'type': 'string', 'description': 'Libellé Toutes Taxes Comprises (ex: TTC).'},
            'title_invoice': {'type': 'string', 'description': 'Titre affiché sur les factures (ex: FACTURE DE VENTE).'},
            'title_receipt': {'type': 'string', 'description': 'Titre affiché sur les tickets de caisse.'},
            'title_receipt_proforma': {'type': 'string', 'description': 'Titre affiché sur les tickets proforma.'},
            'title_quote': {'type': 'string', 'description': 'Titre affiché sur les devis.'},
            'title_proforma': {'type': 'string', 'description': 'Titre pour les factures proforma.'},
            'title_delivery_note': {'type': 'string', 'description': 'Titre pour les bons de livraison.'},
            'margin_ticket_top': {'type': 'number', 'description': 'Marge supérieure des tickets de caisse en points.'},
            'margin_ticket_bottom': {'type': 'number', 'description': 'Marge inférieure des tickets.'},
            'margin_ticket_left': {'type': 'number', 'description': 'Marge gauche des tickets.'},
            'margin_ticket_right': {'type': 'number', 'description': 'Marge droite des tickets.'},
            'margin_invoice_top': {'type': 'number', 'description': 'Marge supérieure des factures A4 en points.'},
            'margin_invoice_bottom': {'type': 'number', 'description': 'Marge inférieure des factures A4.'},
            'margin_invoice_left': {'type': 'number', 'description': 'Marge gauche des factures A4.'},
            'margin_invoice_right': {'type': 'number', 'description': 'Marge droite des factures A4.'},
            'margin_label_x': {'type': 'number', 'description': 'Marge horizontale des étiquettes.'},
            'margin_label_y': {'type': 'number', 'description': 'Marge verticale des étiquettes.'},
            'email_backup_enabled': {'type': 'boolean', 'description': 'true pour activer l\'envoi de la sauvegarde par email.'},
            'backup_email_recipient': {'type': 'string', 'description': 'Email de destination de la sauvegarde.'},
            'smtp_host': {'type': 'string', 'description': 'Serveur SMTP d\'envoi d\'emails (ex: smtp.gmail.com).'},
            'smtp_port': {'type': 'integer', 'description': 'Port SMTP (ex: 465, 587).'},
            'smtp_user': {'type': 'string', 'description': 'Nom d\'utilisateur SMTP.'},
            'smtp_password': {'type': 'string', 'description': 'Mot de passe SMTP.'},
            'email_backup_frequency': {'type': 'string', 'description': 'Fréquence d\'envoi du backup email.', 'enum': ['daily', 'weekly', 'monthly']},
            'email_backup_hour': {'type': 'integer', 'description': 'Heure d\'envoi du backup email (0-23).'},
            'report_email_enabled': {'type': 'boolean', 'description': 'true pour envoyer des rapports d\'activité automatiques.'},
            'stock_alerts_enabled': {'type': 'boolean', 'description': 'true pour inclure les alertes de stock bas dans le rapport email.'},
            'report_email_frequency': {'type': 'string', 'description': 'Fréquence du rapport email.', 'enum': ['daily', 'weekly', 'monthly']},
            'report_email_hour': {'type': 'integer', 'description': 'Heure d\'envoi du rapport email (0-23).'},
            'report_email_day_of_week': {'type': 'integer', 'description': 'Jour de la semaine pour le rapport email (1-7 pour Lundi-Dimanche).'},
            'marketing_emails_enabled': {'type': 'boolean', 'description': 'true pour autoriser l\'envoi automatique d\'emails marketing aux clients.'},
            'inactivity_reminder_enabled': {'type': 'boolean', 'description': 'true pour envoyer des relances automatiques aux clients inactifs.'},
            'inactivity_days_threshold': {'type': 'integer', 'description': 'Seuil en jours pour déclarer un client inactif (ex: 30).'},
            'enable_sounds': {'type': 'boolean', 'description': 'true pour activer les sons généraux de l\'application.'},
            'enable_app_sounds': {'type': 'boolean', 'description': 'true pour activer les notifications sonores internes.'},
            'hr_show_signature_lines': {'type': 'boolean', 'description': 'true pour imprimer les lignes de signature sur les documents RH.'},
            'assistant_level': {'type': 'string', 'description': 'Le niveau de puissance de l\'assistant Danaya.', 'enum': ['basic', 'analytical', 'actionable', 'proactive', 'titan']},
            'is_ai_enabled': {'type': 'boolean', 'description': 'true pour activer les fonctionnalités d\'intelligence artificielle.'},
            'enable_voice_config': {'type': 'boolean', 'description': 'true pour activer le contrôle vocal avancé de la boutique.'},
            'use_cloud_ai': {'type': 'boolean', 'description': 'true pour utiliser les modèles IA cloud (Gemini/DeepSeek), false pour local.'},
            'cloud_ai_provider': {'type': 'string', 'description': 'Le fournisseur IA cloud principal (gemini ou deepseek).'},
            'deepseek_api_key': {'type': 'string', 'description': 'Clé API DeepSeek.'},
            'gemini_api_key': {'type': 'string', 'description': 'Clé API Google Gemini.'},
            'elevenlabs_api_key': {'type': 'string', 'description': 'Clé API ElevenLabs pour synthèse vocale.'},
            'elevenlabs_voice_id': {'type': 'string', 'description': 'Identifiant de voix pour ElevenLabs.'},
            'whatsapp_token': {'type': 'string', 'description': 'Jeton d\'accès WhatsApp Cloud API.'},
            'whatsapp_phone_number_id': {'type': 'string', 'description': 'Identifiant de numéro WhatsApp.'},
            'show_tax_on_delivery_notes': {'type': 'boolean', 'description': 'true pour afficher la taxe sur les bons de livraison.'},
            'use_detailed_tax_on_delivery_notes': {'type': 'boolean', 'description': 'true pour afficher le détail des taxes sur les bons de livraison.'}
          }
        }
      },
      {
        'name': 'add_product',
        'description': 'Ajoute un nouveau produit au stock. Demande au minimum le nom et le prix de vente.',
        'parameters': {
          'type': 'object',
          'properties': {
            'name': {
              'type': 'string',
              'description': 'Le nom du produit'
            },
            'selling_price': {
              'type': 'number',
              'description': 'Le prix de vente complet en monnaie locale (ex: écris 3000000 pour 3 millions ou 3 millions de FCFA, 1500000 pour 1.5 million, ne jamais abréger en 3 ou 1.5).'
            },
            'purchase_price': {
              'type': 'number',
              'description': 'Le prix d\'achat complet en monnaie locale (ex: écris 1000000 pour 1 million, ne jamais abréger en 1).'
            },
            'quantity': {
              'type': 'number',
              'description': 'La quantité initiale en stock'
            },
            'category': {
              'type': 'string',
              'description': 'La catégorie du produit'
            }
          },
          'required': ['name', 'selling_price']
        }
      },
      {
        'name': 'search_product',
        'description': 'Cherche un produit par nom dans le stock et retourne ses informations.',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': 'Le nom ou partie du nom du produit à chercher'
            }
          },
          'required': ['query']
        }
      },
      {
        'name': 'get_stock_info',
        'description': 'Récupère le résumé complet du stock : nombre total de produits, valeur totale, produits en rupture, produits en alerte.',
        'parameters': {
          'type': 'object',
          'properties': {}
        }
      },
      {
        'name': 'add_client',
        'description': 'Ajoute un nouveau client. Le nom est obligatoire.',
        'parameters': {
          'type': 'object',
          'properties': {
            'name': {
              'type': 'string',
              'description': 'Le nom du client'
            },
            'phone': {
              'type': 'string',
              'description': 'Le numéro de téléphone'
            },
            'address': {
              'type': 'string',
              'description': 'L\'adresse du client'
            }
          },
          'required': ['name']
        }
      },
      {
        'name': 'get_client_info',
        'description': 'Cherche un client par nom et retourne ses informations (téléphone, achats, dette, points fidélité).',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': 'Le nom ou partie du nom du client'
            }
          },
          'required': ['query']
        }
      },
      {
        'name': 'select_client',
        'description': 'Associe / lie un client existant à la vente en cours (au panier de caisse). Cherche le client par son nom.',
        'parameters': {
          'type': 'object',
          'properties': {
            'client_name': {
              'type': 'string',
              'description': 'Le nom du client à associer.'
            }
          },
          'required': ['client_name']
        }
      },
      {
        'name': 'get_sales_summary',
        'description': 'Récupère un résumé des ventes : chiffre d\'affaires du jour, nombre de ventes, total de la semaine.',
        'parameters': {
          'type': 'object',
          'properties': {}
        }
      },
      {
        'name': 'adjust_stock',
        'description': 'Ajuste la quantité en stock d\'un produit (entrée ou sortie). Cherche le produit par nom.',
        'parameters': {
          'type': 'object',
          'properties': {
            'product_name': {
              'type': 'string',
              'description': 'Le nom du produit à ajuster'
            },
            'quantity': {
              'type': 'number',
              'description': 'La quantité à ajouter (positif) ou retirer (négatif)'
            }
          },
          'required': ['product_name', 'quantity']
        }
      },
      {
        'name': 'add_to_cart',
        'description': 'Ajoute un produit au panier de caisse (vente en cours). Cherche le produit par son nom.',
        'parameters': {
          'type': 'object',
          'properties': {
            'product_name': {
              'type': 'string',
              'description': 'Le nom du produit à ajouter au panier'
            },
            'quantity': {
              'type': 'number',
              'description': 'La quantité à ajouter (par défaut 1.0)'
            }
          },
          'required': ['product_name']
        }
      },
      // ──── NOUVEAUX OUTILS AVANCÉS ────
      {
        'name': 'update_product',
        'description': 'Modifie un ou plusieurs champs d\'un produit existant : description, prix, catégorie, référence, seuil d\'alerte, emplacement, unité, nom. Cherche par nom.',
        'parameters': {
          'type': 'object',
          'properties': {
            'product_name': {
              'type': 'string',
              'description': 'Le nom actuel du produit à modifier'
            },
            'new_name': {
              'type': 'string',
              'description': 'Le nouveau nom du produit (optionnel)'
            },
            'description': {
              'type': 'string',
              'description': 'La description du produit'
            },
            'selling_price': {
              'type': 'number',
              'description': 'Le nouveau prix de vente complet en monnaie locale (ex: écris 3000000 pour 3 millions, ne jamais abréger).'
            },
            'purchase_price': {
              'type': 'number',
              'description': 'Le nouveau prix d\'achat complet en monnaie locale (ex: écris 1000000 pour 1 million, ne jamais abréger).'
            },
            'category': {
              'type': 'string',
              'description': 'La nouvelle catégorie'
            },
            'reference': {
              'type': 'string',
              'description': 'La référence produit (code/SKU)'
            },
            'barcode': {
              'type': 'string',
              'description': 'Le code-barres du produit'
            },
            'alert_threshold': {
              'type': 'number',
              'description': 'Le seuil d\'alerte de stock bas'
            },
            'location': {
              'type': 'string',
              'description': 'L\'emplacement de stockage (étagère, rayon, etc.)'
            },
            'unit': {
              'type': 'string',
              'description': 'L\'unité de mesure (pièce, kg, litre, mètre, etc.)'
            }
          },
          'required': ['product_name']
        }
      },
      {
        'name': 'delete_product',
        'description': 'Supprime un produit du stock. Cherche par nom. ATTENTION : Action irréversible.',
        'parameters': {
          'type': 'object',
          'properties': {
            'product_name': {
              'type': 'string',
              'description': 'Le nom du produit à supprimer'
            }
          },
          'required': ['product_name']
        }
      },
      {
        'name': 'update_client',
        'description': 'Modifie les informations d\'un client existant : téléphone, email, adresse, crédit max. Cherche par nom.',
        'parameters': {
          'type': 'object',
          'properties': {
            'client_name': {
              'type': 'string',
              'description': 'Le nom actuel du client à modifier'
            },
            'new_name': {
              'type': 'string',
              'description': 'Le nouveau nom du client (optionnel)'
            },
            'phone': {
              'type': 'string',
              'description': 'Le nouveau numéro de téléphone'
            },
            'email': {
              'type': 'string',
              'description': 'Le nouvel email'
            },
            'address': {
              'type': 'string',
              'description': 'La nouvelle adresse'
            },
            'max_credit': {
              'type': 'number',
              'description': 'Le nouveau plafond de crédit autorisé'
            }
          },
          'required': ['client_name']
        }
      },
      {
        'name': 'delete_client',
        'description': 'Supprime définitivement un client de la base de données. Cherche par son nom exact ou similaire. ATTENTION : Action dangereuse et irréversible.',
        'parameters': {
          'type': 'object',
          'properties': {
            'client_name': {
              'type': 'string',
              'description': 'Le nom du client à supprimer.'
            }
          },
          'required': ['client_name']
        }
      },
      {
        'name': 'settle_client_debt',
        'description': 'Enregistre le remboursement partiel ou complet d\'une dette (crédit) par un client (encaissement de dette).',
        'parameters': {
          'type': 'object',
          'properties': {
            'client_name': {
              'type': 'string',
              'description': 'Le nom du client qui rembourse.'
            },
            'amount': {
              'type': 'number',
              'description': 'Le montant remboursé complet (ex: écris 50000 pour 50 mille, ne jamais abréger en 50).'
            },
            'payment_method': {
              'type': 'string',
              'description': 'Le moyen de paiement utilisé par le client (CASH par défaut).',
              'enum': ['CASH', 'MOBILE_MONEY', 'CARD', 'BANK']
            },
            'description': {
              'type': 'string',
              'description': 'Un commentaire ou motif facultatif.'
            }
          },
          'required': ['client_name', 'amount']
        }
      },
      {
        'name': 'get_client_debtors',
        'description': 'Récupère la liste de tous les clients débiteurs (ceux ayant une dette en cours) triés par montant.',
        'parameters': {
          'type': 'object',
          'properties': {}
        }
      },
      {
        'name': 'remove_from_cart',
        'description': 'Retire un produit du panier de caisse (vente en cours). Cherche par nom.',
        'parameters': {
          'type': 'object',
          'properties': {
            'product_name': {
              'type': 'string',
              'description': 'Le nom du produit à retirer du panier'
            }
          },
          'required': ['product_name']
        }
      },
      {
        'name': 'clear_cart',
        'description': 'Vide complètement le panier de caisse (annule la vente en cours).',
        'parameters': {
          'type': 'object',
          'properties': {}
        }
      },
      {
        'name': 'get_low_stock_alerts',
        'description': 'Récupère la liste des produits en alerte de stock bas ou en rupture de stock.',
        'parameters': {
          'type': 'object',
          'properties': {}
        }
      },
      {
        'name': 'save_memory_fact',
        'description': 'Enregistre une information importante, une préférence ou une règle spécifiée par l\'utilisateur pour ne pas l\'oublier (mémoire persistante). Garde-fou: interdit d\'enregistrer des informations de carte bancaire ou mots de passe.',
        'parameters': {
          'type': 'object',
          'properties': {
            'fact': {
              'type': 'string',
              'description': 'La règle ou préférence à mémoriser (ex: "Le client Robert a droit à 10% de réduction", "L\'utilisateur s\'appelle Amadou").'
            }
          },
          'required': ['fact']
        }
      },
      {
        'name': 'delete_memory_fact',
        'description': 'Supprime une information ou une règle mémorisée à partir de son identifiant ID unique.',
        'parameters': {
          'type': 'object',
          'properties': {
            'id': {
              'type': 'string',
              'description': 'L\'identifiant unique (UUID) du fait à supprimer.'
            }
          },
          'required': ['id']
        }
      },
      {
        'name': 'clear_memory_facts',
        'description': 'Efface tous les souvenirs et règles mémorisées de la mémoire persistante du Copilot.',
        'parameters': {
          'type': 'object',
          'properties': {}
        }
      },
      {
        'name': 'add_expense',
        'description': 'Enregistre une dépense financière réelle dans la comptabilité de la boutique. Le montant est obligatoire.',
        'parameters': {
          'type': 'object',
          'properties': {
            'amount': {
              'type': 'number',
              'description': 'Le montant de la dépense complet en monnaie locale (ex: écris 1000000 pour 1 million, 50000 pour 50 mille, ne jamais abréger).'
            },
            'category': {
              'type': 'string',
              'description': 'La catégorie de la dépense (ex: LOYER, TRANSPORT, REPAS, DIVERS).'
            },
            'description': {
              'type': 'string',
              'description': 'Une description ou motif facultatif de la dépense (ex: Achat carburant).'
            }
          },
          'required': ['amount']
        }
      },
      {
        'name': 'update_dashboard',
        'description': 'Modifie l\'affichage ou personnalise le tableau de bord (dashboard) en activant (affichant) ou masquant certaines sections.',
        'parameters': {
          'type': 'object',
          'properties': {
            'section': {
              'type': 'string',
              'description': 'Le nom de la section ou du widget du tableau de bord à modifier.',
              'enum': ['kpis', 'revenue_chart', 'product_mix', 'top_sales', 'recent_sales', 'stock_alerts', 'financial_summary', 'debtors']
            },
            'visible': {
              'type': 'boolean',
              'description': 'true pour afficher ou activer la section, false pour la masquer ou la désactiver.'
            }
          },
          'required': ['section', 'visible']
        }
      },
      {
        'name': 'set_dashboard_filter',
        'description': 'Modifie la plage de dates ou le filtre de période du tableau de bord (dashboard). Permet de filtrer par aujourd\'hui, semaine, mois ou sur une période personnalisée (par exemple de janvier à février 2025 ou de 2025 à 2026).',
        'parameters': {
          'type': 'object',
          'properties': {
            'filter': {
              'type': 'string',
              'description': 'Le type de filtre temporel.',
              'enum': ['today', 'week', 'month', 'custom']
            },
            'start_date': {
              'type': 'string',
              'description': 'La date de début au format YYYY-MM-DD (obligatoire si filter est custom).'
            },
            'end_date': {
              'type': 'string',
              'description': 'La date de fin au format YYYY-MM-DD (obligatoire si filter est custom).'
            }
          },
          'required': ['filter']
        }
      },
      {
        'name': 'checkout_cart',
        'description': 'Finalise et valide la vente en cours dans le panier. ATTENTION: Interdiction absolue d\'exécuter cet outil sans avoir préalablement demandé au patron et obtenu : 1) Le montant versé par le client, 2) Le moyen de paiement (cash, mobile money, crédit ou mixte), 3) Le modèle de document (facture ou reçu), 4) La date d\'échéance et le client si crédit. Tu dois poser ces questions à haute voix et obtenir une réponse avant de valider.',
        'parameters': {
          'type': 'object',
          'properties': {
            'payment_method': {
              'type': 'string',
              'description': 'Le moyen de paiement principal. Par défaut "CASH" (Espèces).',
              'enum': ['CASH', 'MOBILE_MONEY', 'CARD', 'BANK']
            },
            'amount_paid': {
              'type': 'number',
              'description': 'Le montant réel payé par le client complet en monnaie locale (ex: écris 3000000 pour 3 millions, 1500000 pour 1.5 million, 50000 pour 50 mille, ne jamais abréger).'
            },
            'is_credit': {
              'type': 'boolean',
              'description': 'true si la vente est à crédit (dette client), false sinon.'
            },
            'due_date': {
              'type': 'string',
              'description': 'La date d\'échéance du crédit si applicable, au format YYYY-MM-DD.'
            },
            'is_mixed': {
              'type': 'boolean',
              'description': 'true si la vente utilise plusieurs moyens de paiement (mixte), false sinon.'
            },
            'multi_payments': {
              'type': 'array',
              'description': 'La liste des paiements partiels si paiement mixte. Chaque élément doit être un objet contenant "method" (CASH, MOBILE_MONEY, CARD, BANK) et "amount" (nombre).',
              'items': {
                'type': 'object',
                'properties': {
                  'method': {
                    'type': 'string',
                    'enum': ['CASH', 'MOBILE_MONEY', 'CARD', 'BANK']
                  },
                  'amount': {
                    'type': 'number'
                  }
                },
                'required': ['method', 'amount']
              }
            },
            'document_type': {
              'type': 'string',
              'description': 'Le modèle de document à générer et afficher : "ticket" pour un reçu standard, "invoice" pour une facture complète.',
              'enum': ['ticket', 'invoice']
            }
          }
        }
      },
      {
        'name': 'export_report',
        'description': 'Génère et exporte le rapport de ventes de la boutique (format PDF ou EXCEL) pour une période donnée.',
        'parameters': {
          'type': 'object',
          'properties': {
            'format': {
              'type': 'string',
              'description': 'Le format du rapport à générer : "pdf" ou "excel".',
              'enum': ['pdf', 'excel']
            },
            'period': {
              'type': 'string',
              'description': 'La période du rapport : "today" (aujourd\'hui), "week" (cette semaine) ou "month" (ce mois). Par défaut "month".',
              'enum': ['today', 'week', 'month']
            }
          },
          'required': ['format']
        }
      },
      {
        'name': 'get_business_insights',
        'description': 'Récupère les analyses prédictives et conseils d\'intelligence d\'affaires issus d\'Horizon Engine (marges de catégories faibles, stocks dormants/immobilisés, clients inactifs à relancer, et alertes de rupture de stock imminentes).',
        'parameters': {
          'type': 'object',
          'properties': {}
        }
      },
      {
        'name': 'add_supplier',
        'description': 'Ajoute un nouveau fournisseur dans le système SRM (Supplier Relationship Management).',
        'parameters': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'description': 'Le nom du fournisseur/entreprise.'},
            'contact_name': {'type': 'string', 'description': 'Le nom de l\'interlocuteur ou contact physique.'},
            'phone': {'type': 'string', 'description': 'Le numéro de téléphone du fournisseur.'},
            'email': {'type': 'string', 'description': 'L\'adresse e-mail.'},
            'address': {'type': 'string', 'description': 'L\'adresse physique du fournisseur.'}
          },
          'required': ['name']
        }
      },
      {
        'name': 'get_suppliers_list',
        'description': 'Récupère la liste de tous les fournisseurs enregistrés.',
        'parameters': {
          'type': 'object',
          'properties': {}
        }
      },
      {
        'name': 'create_quote',
        'description': 'Génère et enregistre un devis officiel (proforma) soit à partir du panier de caisse actuel, soit directement avec des articles personnalisés/fictifs.',
        'parameters': {
          'type': 'object',
          'properties': {
            'validity_days': {'type': 'integer', 'description': 'Le nombre de jours de validité de ce devis (par défaut celui de la configuration).'},
            'client_name': {'type': 'string', 'description': 'Optionnel. Le nom du client pour qui créer le devis.'},
            'items': {
              'type': 'array',
              'description': 'Optionnel. Une liste d\'articles personnalisés/fictifs pour ce devis. S\'il est fourni, le devis est créé directement sans utiliser le panier de caisse.',
              'items': {
                'type': 'object',
                'properties': {
                  'name': {'type': 'string', 'description': 'Nom de l\'article personnalisé ou de la prestation.'},
                  'quantity': {'type': 'number', 'description': 'La quantité (ex: 2.0).'},
                  'unit_price': {'type': 'number', 'description': 'Le prix unitaire (ex: 15000.0).'},
                  'description': {'type': 'string', 'description': 'Description optionnelle de l\'article.'}
                },
                'required': ['name', 'quantity', 'unit_price']
              }
            }
          }
        }
      },
      {
        'name': 'get_quotes_list',
        'description': 'Récupère la liste complète des devis enregistrés avec leurs détails, numéros et statuts.',
        'parameters': {
          'type': 'object',
          'properties': {}
        }
      },
      {
        'name': 'delete_quote',
        'description': 'Supprime définitivement un devis existant à partir de son numéro ou identifiant unique.',
        'parameters': {
          'type': 'object',
          'properties': {
            'quote_number': {
              'type': 'string',
              'description': 'Le numéro du devis (ex: DEV-123456) ou portion de numéro à supprimer.'
            }
          },
          'required': ['quote_number']
        }
      },
      {
        'name': 'update_quote_status',
        'description': 'Met à jour le statut d\'un devis (en attente, accepté, refusé).',
        'parameters': {
          'type': 'object',
          'properties': {
            'quote_number': {
              'type': 'string',
              'description': 'Le numéro du devis à modifier.'
            },
            'status': {
              'type': 'string',
              'description': 'Le nouveau statut du devis.',
              'enum': ['PENDING', 'ACCEPTED', 'REJECTED']
            }
          },
          'required': ['quote_number', 'status']
        }
      },
      {
        'name': 'convert_quote_to_sale',
        'description': 'Convertit un devis accepté en vente réelle en chargeant ses articles dans le panier et en redirigeant l\'utilisateur vers la caisse (POS).',
        'parameters': {
          'type': 'object',
          'properties': {
            'quote_number': {
              'type': 'string',
              'description': 'Le numéro du devis à facturer/convertir.'
            }
          },
          'required': ['quote_number']
        }
      },
      {
        'name': 'get_expenses_summary',
        'description': 'Récupère le montant total des dépenses enregistrées sur la période actuelle et le résumé par catégorie.',
        'parameters': {
          'type': 'object',
          'properties': {}
        }
      },
      {
        'name': 'filter_clients',
        'description': 'Filtre l\'affichage de la liste des clients selon un onglet spécifique (tous, débiteurs, VIPs, ou anniversaire du mois), un ordre de tri (par nom, par dette, ou par chiffre d\'affaires total dépensé) ou un terme de recherche textuelle.',
        'parameters': {
          'type': 'object',
          'properties': {
            'tab': {
              'type': 'string',
              'description': 'L\'onglet à activer.',
              'enum': ['all', 'debtors', 'vips', 'birthdays']
            },
            'sort': {
              'type': 'string',
              'description': 'La clé de tri des clients.',
              'enum': ['name', 'credit', 'spent']
            },
            'search_query': {
              'type': 'string',
              'description': 'Recherche textuelle par nom, téléphone, email ou adresse.'
            }
          }
        }
      },
      {
        'name': 'send_client_message',
        'description': 'Initie une communication avec un client existant en utilisant une méthode spécifiée (appel téléphonique, message WhatsApp contenant les détails de sa dette s\'il en a une, ou envoi d\'un email).',
        'parameters': {
          'type': 'object',
          'properties': {
            'client_name': {
              'type': 'string',
              'description': 'Le nom ou partie du nom du client avec lequel communiquer.'
            },
            'method': {
              'type': 'string',
              'description': 'Le moyen de communication à utiliser.',
              'enum': ['call', 'whatsapp', 'email']
            }
          },
          'required': ['client_name', 'method']
        }
      },
      {
        'name': 'get_debt_report',
        'description': 'Génère un rapport global des comptes clients débiteurs de la boutique, incluant le montant total de la dette en cours, le nombre de clients endettés, et la liste des principaux débiteurs.',
        'parameters': {
          'type': 'object',
          'properties': {}
        }
      },
      {
        'name': 'filter_suppliers',
        'description': 'Filtre l\'affichage de la liste des fournisseurs de la boutique selon un onglet (tous, dettes impayées, situation à jour, ou top achats), un ordre de tri (par nom, par volume d\'achat, ou par dettes impayées) ou un terme de recherche textuelle.',
        'parameters': {
          'type': 'object',
          'properties': {
            'tab': {
              'type': 'string',
              'description': 'L\'onglet à activer.',
              'enum': ['ALL', 'DEBT', 'OK', 'TOP']
            },
            'sort': {
              'type': 'string',
              'description': 'La clé de tri des fournisseurs.',
              'enum': ['NAME', 'PURCHASES', 'DEBT']
            },
            'search_query': {
              'type': 'string',
              'description': 'Recherche textuelle par nom, contact ou téléphone.'
            }
          }
        }
      },
      {
        'name': 'filter_products',
        'description': 'Filtre l\'affichage de la liste des produits en stock selon l\'état de stock (tous, en stock, stock bas, rupture de stock), le nom de l\'entrepôt, ou un terme de recherche textuelle.',
        'parameters': {
          'type': 'object',
          'properties': {
            'tab': {
              'type': 'string',
              'description': 'Filtre de stock à appliquer.',
              'enum': ['all', 'inStock', 'lowStock', 'outOfStock']
            },
            'search_query': {
              'type': 'string',
              'description': 'Recherche textuelle par nom, référence ou code-barres.'
            },
            'warehouse_name': {
              'type': 'string',
              'description': 'Nom de l\'entrepôt à filtrer (ex: Entrepôt Principal).'
            }
          }
        }
      },
      {
        'name': 'manage_cash_session',
        'description': 'Gère l\'état de la session de caisse : ouverture ou fermeture.',
        'parameters': {
          'type': 'object',
          'properties': {
            'action': {
              'type': 'string',
              'description': 'L\'action de session à effectuer.',
              'enum': ['open', 'close']
            },
            'amount': {
              'type': 'number',
              'description': 'Le montant de fond de caisse initial (pour open) ou le montant physique compté (pour close).'
            }
          },
          'required': ['action', 'amount']
        }
      },
      {
        'name': 'get_treasury_summary',
        'description': 'Récupère le résumé et solde en temps réel de tous les comptes financiers de trésorerie (caisse physique, mobile money, banque, carte).',
        'parameters': {
          'type': 'object',
          'properties': {}
        }
      },
      {
        'name': 'get_hr_summary',
        'description': 'Récupère un résumé des effectifs, contrats de travail et congés des ressources humaines.',
        'parameters': {
          'type': 'object',
          'properties': {}
        }
      },
      {
        'name': 'filter_sales',
        'description': 'Filtre l\'affichage de l\'historique des ventes selon le statut (tous, complétés, crédits, annulés), la méthode de paiement (toutes, Espèces, Mobile Money, Wave, Chèque), ou un terme de recherche textuelle.',
        'parameters': {
          'type': 'object',
          'properties': {
            'status': {
              'type': 'string',
              'description': 'Filtre de statut.',
              'enum': ['all', 'success', 'credit', 'refunded']
            },
            'payment_method': {
              'type': 'string',
              'description': 'Filtre de méthode de paiement.',
              'enum': ['all', 'Espèces', 'Mobile Money', 'Wave', 'Chèque']
            },
            'search_query': {
              'type': 'string',
              'description': 'Recherche textuelle par numéro de ticket, nom de client ou produit.'
            }
          }
        }
      },
      {
        'name': 'manage_sale',
        'description': 'Effectue une action sur une vente spécifique de l\'historique : affiche les détails, réimprime le document (ticket ou facture) ou initie une annulation/remboursement.',
        'parameters': {
          'type': 'object',
          'properties': {
            'sale_id_or_client': {
              'type': 'string',
              'description': 'Le numéro de reçu/facture (ID) ou le nom du client.'
            },
            'action': {
              'type': 'string',
              'description': 'L\'action à effectuer sur la vente.',
              'enum': ['show_detail', 'print_ticket', 'print_invoice', 'refund']
            }
          },
          'required': ['sale_id_or_client', 'action']
        }
      },
      {
        'name': 'compare_sales_periods',
        'description': 'Compare le chiffre d\'affaires, le nombre de ventes et le panier moyen entre deux périodes distinctes.',
        'parameters': {
          'type': 'object',
          'properties': {
            'period1': {
              'type': 'string',
              'description': 'Première période à comparer.',
              'enum': ['today', 'yesterday', 'this_week', 'last_week', 'this_month', 'last_month']
            },
            'period2': {
              'type': 'string',
              'description': 'Deuxième période à comparer.',
              'enum': ['today', 'yesterday', 'this_week', 'last_week', 'this_month', 'last_month']
            }
          },
          'required': ['period1', 'period2']
        }
      },
      {
        'name': 'get_top_profitable_items',
        'description': 'Identifie et liste les produits les plus rentables (générant le plus de bénéfice ou de chiffre d\'affaires) vendus dans la boutique.',
        'parameters': {
          'type': 'object',
          'properties': {
            'limit': {
              'type': 'integer',
              'description': 'Le nombre maximum de produits à retourner (ex: 5).'
            }
          }
        }
      }
    ];

    // Filtrer les outils selon les permissions Copilot
    final filteredTools = enabledTools != null
        ? allToolDeclarations.where((tool) {
            final toolName = tool['name'] as String;
            return enabledTools[toolName] ?? true;
          }).toList()
        : allToolDeclarations;

    final isTranslate = model.contains('translate');

    final setupMessage = {
      'setup': {
        'model': 'models/$model',
        'generation_config': {
          'response_modalities': ['audio'],
          // La configuration de réflexion (thinking) n'est valide et envoyée que pour Gemini 3.x
          if (model.contains('3.'))
            'thinking_config': {
              'thinking_budget': 0, // Désactiver le surcoût de réflexion pour latence minimale
            },
          'temperature': 1.0, // Température naturelle
          if (isTranslate)
            'translation_config': {
              'target_language_code': 'fr',
              'echo_target_language': true,
            }
          else
            'speech_config': {
              'voice_config': {
                'prebuilt_voice_config': {
                  'voice_name': voiceName,
                }
              }
            }
        },
        if (!isTranslate)
          'realtime_input_config': {
            'automatic_activity_detection': {
              'disabled': false, // VAD automatique de Gemini (paramètres simplifiés conformes à l'API)
            },
          },
        if (!isTranslate)
          'tools': [
            {
              'function_declarations': filteredTools,
            },
          ],
        if (!isTranslate)
          'system_instruction': {
            'parts': [
              {'text': fullInstructions}
            ]
          },
        // ULTRA-PRO: Reprise de session pour reconnexion instantanée sans ré-initialisation
        'session_resumption': {},
      }
    };

    if (kDebugMode) print('[GeminiLive] Envoi du Setup (modèle: models/$model, outils: ${isTranslate ? 0 : filteredTools.length}/${allToolDeclarations.length}, VAD: natif Gemini)...');
    _channel!.sink.add(jsonEncode(setupMessage));
  }

  /// Envoie un message texte à l'IA (pour initier une conversation ou poser une question)
  void sendText(String text) {
    if (_channel == null || !_setupComplete) {
      if (kDebugMode) print('[GeminiLive] sendText ignoré: setup non complété');
      return;
    }

    final message = {
      'client_content': {
        'turns': [
          {
            'role': 'user',
            'parts': [
              {'text': text}
            ]
          }
        ],
        'turn_complete': true,
      }
    };

    if (kDebugMode) print('[GeminiLive] Envoi texte: "$text"');
    _channel!.sink.add(jsonEncode(message));
  }

  /// Envoie un paquet (chunk) audio PCM 16kHz Mono 16-bit brut encodé en Base64
  void sendAudioChunk(Uint8List pcmChunk) {
    if (_channel == null || !_setupComplete) return;

    final base64Data = base64Encode(pcmChunk);
    final inputMessage = {
      'realtime_input': {
        'audio': {
          'mime_type': 'audio/pcm;rate=16000',
          'data': base64Data,
        }
      }
    };

    _channel!.sink.add(jsonEncode(inputMessage));
  }

  /// Signale la fin du tour de parole de l'utilisateur pour déclencher immédiatement une réponse.
  /// Protégé contre les envois en rafale qui floodent le serveur et causent des réponses en boucle.
  DateTime? _lastEndUserTurn;
  void endUserTurn() {
    if (_channel == null || !_setupComplete) return;

    // Rate-limit: empêcher les envois en rafale (min 300ms entre chaque)
    final now = DateTime.now();
    if (_lastEndUserTurn != null && now.difference(_lastEndUserTurn!).inMilliseconds < 300) {
      if (kDebugMode) print('[GeminiLive] endUserTurn ignoré (rate-limit 300ms)');
      return;
    }
    _lastEndUserTurn = now;

    final message = {
      'client_content': {
        'turn_complete': true,
      }
    };

    if (kDebugMode) print('[GeminiLive] Envoi turnComplete (fin de parole utilisateur)');
    _channel!.sink.add(jsonEncode(message));
  }

  /// Envoie la réponse de fonction suite à un toolCall de l'IA
  void sendToolResponse(String callId, Map<String, dynamic> output) {
    if (_channel == null || !_setupComplete) return;

    final responseMessage = {
      'tool_response': {
        'function_responses': [
          {
            'response': {
              'output': output,
            },
            'id': callId,
          }
        ]
      }
    };

    if (kDebugMode) print('[GeminiLive] Envoi réponse toolCall: $callId -> $output');
    _channel!.sink.add(jsonEncode(responseMessage));
  }

  /// Traite les réponses provenant du serveur Gemini Live
  void _handleIncomingMessage(dynamic rawMessage) {
    try {
      String messageStr;
      if (rawMessage is String) {
        messageStr = rawMessage;
      } else if (rawMessage is List<int>) {
        final bytes = rawMessage is Uint8List ? rawMessage : Uint8List.fromList(rawMessage);
        try {
          final decoded = utf8.decode(bytes);
          final trimmed = decoded.trim();
          if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
            messageStr = decoded;
          } else {
            onAudioReceived?.call(bytes);
            return;
          }
        } catch (_) {
          onAudioReceived?.call(bytes);
          return;
        }
      } else {
        if (kDebugMode) print('[GeminiLive] Type de message inconnu: ${rawMessage.runtimeType}');
        return;
      }

      final Map<String, dynamic> data = jsonDecode(messageStr) as Map<String, dynamic>;

      // 1. TOOL CALLS (demandes d'actions de l'IA)
      final hasToolCall = data.containsKey('toolCall') || data.containsKey('tool_call');
      if (hasToolCall) {
        final toolCallData = (data['toolCall'] ?? data['tool_call']) as Map<String, dynamic>;
        final functionCalls = (toolCallData['functionCalls'] ?? toolCallData['function_calls']) as List? ?? [];
        for (final call in functionCalls) {
          if (call is Map<String, dynamic>) {
            final name = call['name'] as String? ?? '';
            final args = call['args'] as Map<String, dynamic>? ?? {};
            final id = call['id'] as String? ?? '';
            if (kDebugMode) print('[GeminiLive] Demande de fonction reçue: $name ($id)');
            onToolCallReceived?.call(id, name, args);
          }
        }
        return;
      }

      // 2. SETUP COMPLETE — le serveur confirme la session prête
      if (data.containsKey('setupComplete') || data.containsKey('setup_complete')) {
        if (kDebugMode) print('[GeminiLive] ✅ setupComplete reçu! Session active.');
        _setupComplete = true;
        onSetupComplete?.call();
        return;
      }

      // 2. Contenu du serveur (réponses de l'IA)
      final hasServerContent = data.containsKey('serverContent') || data.containsKey('server_content');
      if (hasServerContent) {
        final serverContent = (data['serverContent'] ?? data['server_content']) as Map<String, dynamic>;

        // Détection d'interruption (l'utilisateur a parlé pendant que l'IA répondait)
        if (serverContent['interrupted'] == true) {
          if (kDebugMode) print('[GeminiLive] ⚡ Interruption détectée');
          onInterrupted?.call();
          return;
        }

        // Réception de contenu textuel ou audio du modèle
        final hasModelTurn = serverContent.containsKey('modelTurn') || serverContent.containsKey('model_turn');
        if (hasModelTurn) {
          final modelTurn = (serverContent['modelTurn'] ?? serverContent['model_turn']) as Map<String, dynamic>;
          final parts = modelTurn['parts'] as List? ?? [];

          for (final part in parts) {
            if (part is Map<String, dynamic>) {
              // Texte
              if (part.containsKey('text')) {
                final text = part['text'] as String? ?? '';
                if (text.isNotEmpty) {
                  onTextReceived?.call(text);
                }
              }
              // Audio PCM (le serveur renvoie PCM 24kHz en base64)
              final hasInlineData = part.containsKey('inlineData') || part.containsKey('inline_data');
              if (hasInlineData) {
                final inlineData = (part['inlineData'] ?? part['inline_data']) as Map<String, dynamic>;
                final base64Audio = inlineData['data'] as String? ?? '';
                if (base64Audio.isNotEmpty) {
                  final decodedBytes = base64Decode(base64Audio);
                  onAudioReceived?.call(decodedBytes);
                }
              }
            }
          }
        }

        // Tour de parole terminé
        if (serverContent['turnComplete'] == true || serverContent['turn_complete'] == true) {
          if (kDebugMode) print('[GeminiLive] 🏁 Tour complet');
          onTurnComplete?.call();
        }

        // ULTRA-PRO: Transcription de la sortie audio de l'IA (sous-titres temps réel)
        final hasOutputTranscription = serverContent.containsKey('outputTranscription') || serverContent.containsKey('output_transcription');
        if (hasOutputTranscription) {
          final transcription = serverContent['outputTranscription'] ?? serverContent['output_transcription'];
          if (transcription is Map && transcription.containsKey('text')) {
            final text = transcription['text'] as String? ?? '';
            if (text.isNotEmpty) {
              onOutputTranscription?.call(text);
            }
          }
        }
      }

      // ULTRA-PRO: Transcription de la voix de l'utilisateur en temps réel
      final hasInputTranscription = data.containsKey('inputTranscription') || data.containsKey('input_transcription');
      if (hasInputTranscription) {
        final transcription = (data['inputTranscription'] ?? data['input_transcription']) as Map<String, dynamic>?;
        if (transcription != null) {
          final text = transcription['text'] as String? ?? '';
          final isFinal = (transcription['isFinal'] ?? transcription['is_final']) as bool? ?? false;
          if (text.isNotEmpty) {
            if (kDebugMode) print('[GeminiLive] 🎤 Transcription: "$text" (final: $isFinal)');
            onInputTranscription?.call(text, isFinal);
          }
        }
      }

      // ULTRA-PRO: Token de reprise de session pour reconnexion instantanée
      final hasSessionResumption = data.containsKey('sessionResumptionUpdate') || data.containsKey('session_resumption_update');
      if (hasSessionResumption) {
        final update = (data['sessionResumptionUpdate'] ?? data['session_resumption_update']) as Map<String, dynamic>?;
        if (update != null) {
          final token = (update['newHandle'] ?? update['new_handle']) as String?;
          if (token != null && token.isNotEmpty) {
            _lastSessionToken = token;
            if (kDebugMode) print('[GeminiLive] 🔑 Token de session mis à jour');
          }
        }
      }

      // 3. Erreur retournée par le serveur
      if (data.containsKey('error')) {
        final error = data['error'] as Map<String, dynamic>?;
        final message = error?['message'] as String? ?? 'Erreur inconnue du serveur';
        final code = error?['code'] ?? '';
        if (kDebugMode) print('[GeminiLive] ❌ Erreur serveur: $code — $message');
        onError?.call('Erreur Gemini: $message');
      }

    } catch (e, stack) {
      if (kDebugMode) {
        print('[GeminiLive] Erreur parsing message: $e');
        print(stack);
      }
    }
  }
}
