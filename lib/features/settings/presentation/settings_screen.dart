import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p_path;
import 'package:printing/printing.dart';
import 'dart:async';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:danaya_plus/core/utils/date_formatter.dart';
import 'package:danaya_plus/features/help/presentation/help_screen.dart';
import 'package:danaya_plus/features/settings/presentation/widgets/audit_section.dart';
import 'package:danaya_plus/features/settings/presentation/widgets/appearance_section.dart';
import 'package:danaya_plus/features/settings/presentation/widgets/system_maintenance_section.dart';
import 'package:danaya_plus/core/services/pdf_resource_service.dart';

import 'package:danaya_plus/features/settings/providers/shop_settings_provider.dart';
import 'package:danaya_plus/features/license/domain/license_service.dart';
import 'package:danaya_plus/core/database/database_service.dart';
import 'package:danaya_plus/features/settings/providers/backup_providers.dart';
import 'package:danaya_plus/core/widgets/enterprise_widgets.dart';
import 'package:danaya_plus/features/settings/providers/settings_ui_providers.dart';
import 'package:danaya_plus/features/pos/providers/pos_providers.dart';
import 'widgets/general_section.dart';
import 'widgets/finance_section.dart';
import 'widgets/printing_section.dart';
import 'widgets/automation_section.dart';
import 'widgets/backup_cloud_dashboard.dart';
import 'widgets/hardware_section.dart';
import 'package:danaya_plus/features/settings/providers/maintenance_providers.dart';
import 'package:danaya_plus/features/auth/application/auth_service.dart';
import 'package:danaya_plus/core/services/scheduled_report_service.dart';
import 'package:danaya_plus/core/services/marketing_email_service.dart';
import 'package:danaya_plus/core/services/marketing_automation_service.dart';
import 'widgets/customer_display_section.dart';
import 'package:danaya_plus/core/services/email_service.dart';
import 'package:danaya_plus/core/services/sound_service.dart';
import 'package:danaya_plus/core/widgets/access_denied_screen.dart';
import 'package:danaya_plus/core/services/hardware_service.dart';
import 'package:danaya_plus/features/inventory/providers/product_providers.dart';
import 'package:danaya_plus/features/clients/providers/client_providers.dart';
import 'widgets/multimedia_section.dart';
import 'package:danaya_plus/core/widgets/pin_pad_dialog.dart';


class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _selectedIndex = 0;
  bool _isInitialized = false;
  int? _daysRemaining;
  Timer? _saveTimer;

  // Général
  final _nameCtrl = TextEditingController();
  final _sloganCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String? _logoPath;

  // Légal & Finance
  final _rcCtrl = TextEditingController();
  final _nifCtrl = TextEditingController();
  final _bankAccountCtrl = TextEditingController();
  final _taxNameCtrl = TextEditingController();
  final _taxRateCtrl = TextEditingController();
  final _paymentMethodsCtrl = TextEditingController();
  String _currency = 'FCFA';
  bool _removeDecimals = true;
  bool _useTax = false;
  bool _showQrCode = true;
  bool _autoBackupEnabled = true;
  bool _useAutoRef = false;
  final _refPrefixCtrl = TextEditingController(text: 'REF');
  ReferenceGenerationModel _refModel = ReferenceGenerationModel.timestamp;
  BarcodeGenerationModel _barcodeModel = BarcodeGenerationModel.ean13;
  bool _loyaltyEnabled = true;
  final _pointsPerAmountCtrl = TextEditingController();
  final _amountPerPointCtrl = TextEditingController();

  // Ultra Pro : Centre de Politique
  final _legalFormCtrl = TextEditingController();
  final _capitalCtrl = TextEditingController();
  final _warrantyCtrl = TextEditingController();
  final _returnsCtrl = TextEditingController();
  final _paymentsPolicyCtrl = TextEditingController();
  final _validityCtrl = TextEditingController();
  final _legalNoteCtrl = TextEditingController();
  final _managerPinCtrl = TextEditingController();
  final _maxDiscountThresholdCtrl = TextEditingController();
  final _vipThresholdCtrl = TextEditingController();
  final _labelHTCtrl = TextEditingController();
  final _labelTTCCtrl = TextEditingController();
  final _titleInvoiceCtrl = TextEditingController();
  final _titleReceiptCtrl = TextEditingController();
  final _titleReceiptProformaCtrl = TextEditingController();
  final _titleQuoteCtrl = TextEditingController();
  final _titleProformaCtrl = TextEditingController();
  final _titleDeliveryNoteCtrl = TextEditingController();

  Map<String, Map<String, bool>> _templateFiscalSettings = {};

  final _autoLockMinutesCtrl = TextEditingController();
  bool _isAutoLockEnabled = false;

  // Impression
  ReceiptTemplate? _receipt;
  InvoiceTemplate? _invoice;
  QuoteTemplate? _quote;
  PurchaseOrderTemplate? _purchaseOrder;
  final _receiptFooterCtrl = TextEditingController();
  String? _thermalPrinter;
  String? _invoicePrinter;
  String? _quotePrinter;
  String? _purchaseOrderPrinter;
  String? _labelPrinter;
  String? _contractPrinter;
  String? _payrollPrinter;
  String? _reportPrinter;
  String? _proformaPrinter;
  String? _deliveryPrinter;
  bool _autoPrintTicket = false;
  bool _showPreviewBeforePrint = true;
  bool _autoPrintDeliveryNote = false;
  bool _showPriceOnLabels = true;
  bool _showNameOnLabels = true;
  bool _showSkuOnLabels = false;
  bool _autoPrintLabelsOnStockIn = false;
  bool _directPhysicalPrinting = false;
  bool _openCashDrawer = false;
  bool _enableSounds = true;
  bool _enableAppSounds = true;
  bool _enableCustomerDisplaySounds = true;
  bool _useCustomerDisplay3D = false;
  bool _showAssistant = true;
  LabelPrintingFormat _labelFormat = LabelPrintingFormat.a4Sheets;
  final _labelWidthCtrl = TextEditingController();
  final _labelHeightCtrl = TextEditingController();

  // -- Marges Imprimerie --
  final _marginTicketTopCtrl = TextEditingController();
  final _marginTicketBottomCtrl = TextEditingController();
  final _marginTicketLeftCtrl = TextEditingController();
  final _marginTicketRightCtrl = TextEditingController();

  final _marginInvoiceTopCtrl = TextEditingController();
  final _marginInvoiceBottomCtrl = TextEditingController();
  final _marginInvoiceLeftCtrl = TextEditingController();
  final _marginInvoiceRightCtrl = TextEditingController();
  final _marginLabelXCtrl = TextEditingController();
  final _marginLabelYCtrl = TextEditingController();
  
  // Réseau
  NetworkMode _networkMode = NetworkMode.solo;
  final _serverIpCtrl = TextEditingController();
  final _serverPortCtrl = TextEditingController();
  String _customerDisplayTheme = 'theme-luxury';
  bool _enableCustomerDisplayTicker = true;
  final _customerDisplayMessagesCtrl = TextEditingController();
  
  // Cloud & Email Backup
  String? _cloudBackupPath;
  bool _emailBackupEnabled = false;
  EmailBackupFrequency _emailBackupFrequency = EmailBackupFrequency.weekly;
  int _emailBackupHour = 22;
  final _backupEmailRecipientCtrl = TextEditingController();
  final _smtpHostCtrl = TextEditingController(text: 'smtp.gmail.com');
  final _smtpPortCtrl = TextEditingController(text: '587');
  final _smtpUserCtrl = TextEditingController();
  final _smtpPasswordCtrl = TextEditingController();
  
  final _syncKeyCtrl = TextEditingController();

  // Rapport par Email
  bool _reportEmailEnabled = false;
  bool _stockAlertsEnabled = false;
  EmailBackupFrequency _reportEmailFrequency = EmailBackupFrequency.daily;
  int _reportEmailHour = 20;
  int _reportEmailDayOfWeek = 1;

  // Marketing & CRM
  bool _inactivityReminderEnabled = true;
  int _inactivityDaysThreshold = 30;

  // Matrice Fiscale
  bool _showTaxOnTickets = true;
  bool _showTaxOnInvoices = true;
  bool _showTaxOnQuotes = true;
  bool _showTaxOnDeliveryNotes = true;
  bool _useDetailedTaxOnTickets = false;
  bool _useDetailedTaxOnInvoices = true;
  bool _useDetailedTaxOnQuotes = true;
  bool _useDetailedTaxOnDeliveryNotes = false;

  bool _marketingEmailsEnabled = true;

  List<Printer> _availablePrinters = [];

  Map<String, dynamic> _dbStats = {};
  List<FileSystemEntity> _autoBackups = [];
  RoundingMode _roundingMode = RoundingMode.none;
  AssistantPowerLevel _assistantLevel = AssistantPowerLevel.basic;
  List<Map<String, dynamic>> _logs = [];

  final List<IconData> _menuIcons = [
    FluentIcons.building_shop_24_regular,     // 0: Enseigne
    FluentIcons.money_24_regular,             // 1: Commerce
    FluentIcons.star_24_regular,              // 2: Fidélité
    FluentIcons.shield_lock_24_regular,       // 3: Politiques
    FluentIcons.document_pdf_24_regular,      // 4: Modèles
    FluentIcons.print_24_regular,             // 5: Matériel
    FluentIcons.phone_screen_time_24_regular,  // 6: Afficheur Client (TV)
    FluentIcons.speaker_2_24_regular,          // 7: Sons & Multimédia
    FluentIcons.flash_24_regular,              // 8: Automatisation & IA
    FluentIcons.shield_24_regular,             // 9: Sauvegardes & Cloud
    FluentIcons.wrench_24_regular,             // 10: Système & Réseau
    FluentIcons.clipboard_task_list_ltr_24_regular, // 11: Audit Trail
    FluentIcons.paint_brush_24_regular,       // 12: Personnalisation
    FluentIcons.learning_app_24_regular,      // 13: D+ Academy
  ];

  final List<String> _menuItems = [
    "Enseigne & Identité",       // 0
    "Commerce & Fiscalité",      // 1
    "Points & Fidélité",         // 2
    "Politiques & S.A.V",        // 3
    "Documents & Design PDF",    // 4
    "Matériel Hub (Printers)",   // 5
    "Afficheur Client (Pro)",   // 6
    "Sons & Multimédia",        // 7
    "Automatisation & IA",      // 8
    "Sauvegardes & Cloud",      // 9
    "Système & Maintenance",         // 10
    "Audit & Traçabilité",      // 11
    "Design Interface",         // 12
    "D+ Academy (Guide)",        // 13
  ];

  // Regroupement par Modules (Pôles d'expertise)
  final List<Map<String, dynamic>> _modules = [
    {
      "title": "BOUTIQUE & DESIGN",
      "items": [0, 1, 2, 3, 4],
    },
    {
      "title": "CONNECTIVITÉ & AUDIO",
      "items": [5, 6, 7],
    },
    {
      "title": "INTELLIGENCE & SÉCURITÉ",
      "items": [8, 9, 10, 11],
    },
    {
      "title": "EXPERTISE & AIDE",
      "items": [12, 13],
    },
  ];

  @override
  void initState() {
    super.initState();
    // Restaurer l'onglet actif
    _selectedIndex = ref.read(settingsTabIndexProvider);
    _loadLicense();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sloganCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _addressCtrl.dispose();
    _emailCtrl.dispose();
    _rcCtrl.dispose();
    _nifCtrl.dispose();
    _bankAccountCtrl.dispose();
    _taxNameCtrl.dispose();
    _taxRateCtrl.dispose();
    _paymentMethodsCtrl.dispose();
    _receiptFooterCtrl.dispose();
    _legalFormCtrl.dispose();
    _capitalCtrl.dispose();
    _warrantyCtrl.dispose();
    _returnsCtrl.dispose();
    _paymentsPolicyCtrl.dispose();
    _validityCtrl.dispose();
    _legalNoteCtrl.dispose();
    _managerPinCtrl.dispose();
    _maxDiscountThresholdCtrl.dispose();
    _vipThresholdCtrl.dispose();
    _labelHTCtrl.dispose();
    _labelTTCCtrl.dispose();
    _titleInvoiceCtrl.dispose();
    _titleReceiptCtrl.dispose();
    _titleReceiptProformaCtrl.dispose();
    _titleQuoteCtrl.dispose();
    _titleProformaCtrl.dispose();
    _titleDeliveryNoteCtrl.dispose();
    _pointsPerAmountCtrl.dispose();
    _amountPerPointCtrl.dispose();
    _labelWidthCtrl.dispose();
    _labelHeightCtrl.dispose();
    _refPrefixCtrl.dispose();
    _serverIpCtrl.dispose();
    _serverPortCtrl.dispose();
    _customerDisplayMessagesCtrl.dispose();

    _marginTicketTopCtrl.dispose();
    _marginTicketBottomCtrl.dispose();
    _marginTicketLeftCtrl.dispose();
    _marginTicketRightCtrl.dispose();
    _marginInvoiceTopCtrl.dispose();
    _marginInvoiceBottomCtrl.dispose();
    _marginInvoiceLeftCtrl.dispose();
    _marginInvoiceRightCtrl.dispose();
    _syncKeyCtrl.dispose();
    _smtpUserCtrl.dispose();
    _smtpPasswordCtrl.dispose();
    _backupEmailRecipientCtrl.dispose();

    _saveTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLicense() async {
    final licenseService = ref.read(licenseServiceProvider);
    final days = await licenseService.getDaysRemaining();
    if (mounted) {
      setState(() {
        _daysRemaining = days;
      });
    }
    _loadDbStats();
    _loadAutoBackups();
  }

  Future<void> _loadAutoBackups() async {
    final backups = await ref.read(backupServiceProvider).listAutoBackups();
    if (mounted) setState(() => _autoBackups = backups);
  }

  void _showTosDialog() {
    final settings = ref.read(shopSettingsProvider).value;
    final acceptedAt = settings?.tosAcceptedAt;
    
    showDialog(
      context: context,
      builder: (context) => EnterpriseWidgets.buildPremiumDialog(
        context,
        title: "Conditions d'Utilisation",
        icon: FluentIcons.document_text_24_regular,
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (acceptedAt != null)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(FluentIcons.checkmark_circle_20_filled, color: Colors.green, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Conditions acceptées le ${DateFormatter.formatPremium(acceptedAt)}",
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            const Text("1. Stockage Local", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            const Text("Toutes vos données sont stockées localement sur cet appareil. Danaya+ est une solution offline-first.", style: TextStyle(fontSize: 13)),
            const SizedBox(height: 20),
            const Text("2. Responsabilité", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            const Text("L'utilisateur est responsable de ses sauvegardes et de la sécurité physique de son matériel.", style: TextStyle(fontSize: 13)),
            const SizedBox(height: 20),
            const Text("3. Confidentialité", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            const Text("Aucune donnée commerciale n'est collectée ou transmise à des tiers par l'éditeur du logiciel.", style: TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("FERMER"),
          ),
        ],
      ),
    );
  }

  Future<void> _loadDbStats() async {
    try {
      final db = await ref.read(databaseServiceProvider).database;
      final stock = (await db.rawQuery(
        'SELECT COUNT(*) as c FROM products',
      ))[0]['c'];
      final sales = (await db.rawQuery(
        'SELECT COUNT(*) as c FROM sales',
      ))[0]['c'];
      final clients = (await db.rawQuery(
        'SELECT COUNT(*) as c FROM clients',
      ))[0]['c'];
      final movements = (await db.rawQuery(
        'SELECT COUNT(*) as c FROM stock_movements',
      ))[0]['c'];

      if (mounted) {
        setState(() {
          _dbStats = {
            'products': stock,
            'sales': sales,
            'clients': clients,
            'movements': movements,
            'path': db.path,
          };
        });
        _loadPrinters();
      }
    } catch (_) {}
  }


  Future<void> _testReportEmail() async {
    _showToast("Génération du rapport de test...", Colors.blue);
    try {
      final now = DateTime.now();
      final range = DateTimeRange(
        start: DateTime(now.year, now.month, now.day),
        end: DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
      
      final result = await ref.read(scheduledReportServiceProvider).sendManualReport(
        _backupEmailRecipientCtrl.text.trim(),
        range,
      );
      
      if (mounted) {
        _showToast(
          result.success ? "Test d'envoi terminé (Vérifiez : ${_backupEmailRecipientCtrl.text})" : "Échec : ${result.errorMessage}",
          result.success ? Colors.green : Colors.red,
        );
      }
    } catch (e) {
      _showToast("Erreur lors du test : $e", Colors.red);
    }
  }

  Future<void> _testMarketingNewProduct() async {
    _showToast("Simulation d'envoi Nouveauté...", Colors.blue);
    try {
      final products = await ref.read(productListProvider.future);
      if (products.isEmpty) {
        if (mounted) _showToast("Aucun produit trouvé pour le test.", Colors.orange);
        return;
      }
      final clients = await ref.read(clientListProvider.future);
      if (clients.isEmpty) {
        if (mounted) _showToast("Aucun client trouvé pour le test.", Colors.orange);
        return;
      }
      
      final result = await ref.read(marketingEmailServiceProvider).broadcastNewProduct(
        products.first,
        clients,
      );
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => EnterpriseWidgets.buildPremiumDialog(
            context,
            title: "Résultat Flash Nouveauté",
            icon: FluentIcons.flash_24_regular,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildResultStat("Total Clients", result.totalClients.toString()),
                _buildResultStat("Avec E-mail", result.clientsWithEmail.toString()),
                const Divider(),
                _buildResultStat("E-mails envoyés", result.emailsSent.toString(), color: Colors.green),
                _buildResultStat("Échecs d'envoi", result.emailsFailed.toString(), color: result.emailsFailed > 0 ? Colors.red : null),
                if (result.errorMessages.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text("Erreurs rencontrées :", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ...result.errorMessages.take(3).map((e) => Text("• $e", style: const TextStyle(fontSize: 11, color: Colors.red))),
                  if (result.errorMessages.length > 3) Text("... (+${result.errorMessages.length - 3})", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ],
            ),
            actions: [
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) _showToast("Erreur lors du test: $e", Colors.red);
    }
  }

  Future<void> _testMarketingInactivity() async {
    _showToast("Lancement de l'audit d'inactivité...", Colors.blue);
    try {
      final result = await ref.read(marketingAutomationServiceProvider).runDailyInactivityAudit(force: true);
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => EnterpriseWidgets.buildPremiumDialog(
            context,
            title: "Résultat Audit CRM",
            icon: FluentIcons.history_24_regular,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildResultStat("Clients analysés", result.totalClients.toString()),
                _buildResultStat("Cibles éligibles", result.inactiveClientsFound.toString()),
                const Divider(),
                _buildResultStat("Relances envoyées", result.emailsSent.toString(), color: Colors.green),
                _buildResultStat("Échecs d'envoi", result.emailsFailed.toString(), color: result.emailsFailed > 0 ? Colors.red : null),
                if (result.errorMessages.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text("Erreurs rencontrées :", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ...result.errorMessages.take(3).map((e) => Text("• $e", style: const TextStyle(fontSize: 11, color: Colors.red))),
                  if (result.errorMessages.length > 3) Text("... (+${result.errorMessages.length - 3})", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ],
            ),
            actions: [
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) _showToast("Erreur lors de l'audit: $e", Colors.red);
    }
  }

  Future<void> _showRecoveryKey() async {
    final authService = ref.read(authServiceProvider.notifier);
    final key = await authService.getAdminRecoveryKey();

    if (!mounted) return;

    if (key == null) {
      _showToast("Aucune clé de secours trouvée pour l'administrateur.", Colors.orange);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => EnterpriseWidgets.buildPremiumDialog(
        context,
        title: "Clé de Secours (Développeur)",
        icon: FluentIcons.shield_keyhole_24_regular,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Cette clé permet de réinitialiser le code PIN si l'utilisateur l'a oublié.",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
              ),
              child: Center(
                child: SelectableText(
                  key,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontFamily: 'monospace',
                    color: Colors.orange,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Note : Communiquez cette clé uniquement au responsable de la boutique.",
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("FERMER"),
          ),
        ],
      ),
    );
  }

  Future<void> _testEmailConn() async {
    _showToast("Test de connexion en cours...", Colors.blue);
    await _save(); // Sauver pour appliquer les réglages SMTP

    try {
      final result = await ref.read(emailServiceProvider).testConnection();
      if (mounted) {
        _showToast(
          result.success ? "Connexion SMTP RÉUSSIE ! Un email de test a été envoyé." : "ÉCHEC : ${result.errorMessage}",
          result.success ? Colors.green : Colors.red,
        );
      }
    } catch (e) {
      if (mounted) _showToast("Erreur fatale : $e", Colors.red);
    }
  }

  Future<void> _testEmailBackup() async {
    _showToast("Préparation de l'archive (Gzip) et envoi du backup...", Colors.blue);
    await _save(); // Sauver pour appliquer les réglages SMTP

    try {
      final dbPath = await ref.read(databaseServiceProvider).getDatabasePath();
      final dbFile = File(dbPath);
      
      final result = await ref.read(emailServiceProvider).sendDatabaseBackup(
        recipient: _backupEmailRecipientCtrl.text.trim(),
        backupFile: dbFile,
      );

      if (mounted) {
        if (result.success) {
          _showToast("SAUVEGARDE ENVOYÉE AVEC SUCCÈS !", Colors.green);
          showDialog(
            context: context,
            builder: (ctx) => EnterpriseWidgets.buildPremiumDialog(
              ctx,
              title: "Backup Réussi",
              icon: FluentIcons.checkmark_circle_24_filled,
              actions: [
                FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
              ],
              child: Text("La base de données a été compressée et envoyée avec succès à ${_backupEmailRecipientCtrl.text.trim()}."),
            ),
          );
        } else {
          _showToast("ÉCHEC : ${result.errorMessage ?? 'Vérifiez vos paramètres.'}", Colors.red);
        }
      }
    } catch (e) {
      if (mounted) _showToast("Erreur fatale lors du backup : $e", Colors.red);
    }
  }

  Future<void> _loadPrinters() async {
    try {
      final printers = await Printing.listPrinters();
      if (mounted) setState(() => _availablePrinters = printers);
    } catch (_) {}
  }

  Future<void> _loadLogs() async {
    final logs = await ref.read(databaseServiceProvider).getActivityLogs(limit: 100);
    if (mounted) setState(() => _logs = logs);
  }

  void _initControllers(ShopSettings s) {
    if (_isInitialized) return;
    _isInitialized = true;
    _loadLogs();
    _nameCtrl.text = s.name;
    _sloganCtrl.text = s.slogan;
    _phoneCtrl.text = s.phone;
    _whatsappCtrl.text = s.whatsapp;
    _addressCtrl.text = s.address;
    _emailCtrl.text = s.email;
    _rcCtrl.text = s.rc;
    _nifCtrl.text = s.nif;
    _bankAccountCtrl.text = s.bankAccount;
    _currency = s.currency;
    _removeDecimals = s.removeDecimals;
    _receipt = s.defaultReceipt;
    _invoice = s.defaultInvoice;
    _quote = s.defaultQuote;
    _purchaseOrder = s.defaultPurchaseOrder;
    _receiptFooterCtrl.text = s.receiptFooter;
    _logoPath = s.logoPath;
    _showQrCode = s.showQrCode;
    _thermalPrinter = s.thermalPrinterName;
    _invoicePrinter = s.invoicePrinterName;
    _quotePrinter = s.quotePrinterName;
    _purchaseOrderPrinter = s.purchaseOrderPrinterName;
    _labelPrinter = s.labelPrinterName;
    _contractPrinter = s.contractPrinterName;
    _payrollPrinter = s.payrollPrinterName;
    _reportPrinter = s.reportPrinterName;
    _autoPrintTicket = s.autoPrintTicket;
    _showPreviewBeforePrint = s.showPreviewBeforePrint;
    _taxNameCtrl.text = s.taxName;
    _taxRateCtrl.text = s.taxRate.toString();
    _useTax = s.useTax;
    _autoBackupEnabled = s.autoBackupEnabled;
    _useAutoRef = s.useAutoRef;
    _refPrefixCtrl.text = s.refPrefix;
    _refModel = s.refModel;
    _barcodeModel = s.barcodeModel;
    _labelFormat = s.labelFormat;
    _labelWidthCtrl.text = s.labelWidth.toString();
    _labelHeightCtrl.text = s.labelHeight.toString();
    _paymentMethodsCtrl.text = s.paymentMethods.join(', ');
    _showPriceOnLabels = s.showPriceOnLabels;
    _showNameOnLabels = s.showNameOnLabels;
    _showSkuOnLabels = s.showSkuOnLabels;
    _autoPrintLabelsOnStockIn = s.autoPrintLabelsOnStockIn;
    _directPhysicalPrinting = s.directPhysicalPrinting;
    _openCashDrawer = s.openCashDrawer;
    _enableSounds = s.enableSounds;
    _enableAppSounds = s.enableAppSounds;
    _enableCustomerDisplaySounds = s.enableCustomerDisplaySounds;
    _useCustomerDisplay3D = s.useCustomerDisplay3D;
    _showAssistant = s.showAssistant;
    _roundingMode = s.roundingMode;
    _assistantLevel = s.assistantLevel;
    
    _isAutoLockEnabled = s.isAutoLockEnabled;
    _autoLockMinutesCtrl.text = s.autoLockMinutes.toString();

    // Matrice Élite: Désaplatir (Unflatten) la Map plate du modèle vers la Map imbriquée de l'UI
    _templateFiscalSettings = {};
    s.templateFiscalSettings.forEach((key, value) {
      final parts = key.split('_');
      if (parts.length >= 3) {
        final type = parts[0]; // ticket, invoice, quote, delivery
        // Reconstruire templateOption (ex: "modern_show" ou "elite_detailed")
        final templateOption = parts.sublist(1).join('_');
        
        _templateFiscalSettings.putIfAbsent(type, () => {});
        _templateFiscalSettings[type]![templateOption] = value;
      }
    });
    
    // Titres de documents & Libellés (Simplifiés à un mot selon demande)
    _labelHTCtrl.text = s.labelHT.isEmpty ? "HT" : s.labelHT;
    _labelTTCCtrl.text = s.labelTTC.isEmpty ? "TTC" : s.labelTTC;
    _titleInvoiceCtrl.text = s.titleInvoice.isEmpty ? "FACTURE" : s.titleInvoice;
    _titleReceiptCtrl.text = s.titleReceipt.isEmpty ? "TICKET" : s.titleReceipt;
    _titleReceiptProformaCtrl.text = s.titleReceiptProforma.isEmpty ? "PROFORMA" : s.titleReceiptProforma;
    _titleQuoteCtrl.text = s.titleQuote.isEmpty ? "DEVIS" : s.titleQuote;
    _titleProformaCtrl.text = s.titleProforma.isEmpty ? "PROFORMA" : s.titleProforma;
    _titleDeliveryNoteCtrl.text = s.titleDeliveryNote.isEmpty ? "LIVRAISON" : s.titleDeliveryNote;
    
    _loadPrinters();
    
    // Ultra Pro
    _legalFormCtrl.text = s.legalForm;
    _capitalCtrl.text = s.capital;
    _warrantyCtrl.text = s.policyWarranty;
    _returnsCtrl.text = s.policyReturns;
    _paymentsPolicyCtrl.text = s.policyPayments;
    _validityCtrl.text = s.quoteValidityDays.toString();
    _legalNoteCtrl.text = s.invoiceLegalNote;
    _managerPinCtrl.text = s.managerPin;
    _maxDiscountThresholdCtrl.text = s.maxDiscountThreshold.toString();
    _vipThresholdCtrl.text = s.vipThreshold.toString();
    _loyaltyEnabled = s.loyaltyEnabled;
    _pointsPerAmountCtrl.text = s.pointsPerAmount.toString();
    _amountPerPointCtrl.text = s.amountPerPoint.toString();


    _marginTicketTopCtrl.text = s.marginTicketTop.toString();
    _marginTicketBottomCtrl.text = s.marginTicketBottom.toString();
    _marginTicketLeftCtrl.text = s.marginTicketLeft.toString();
    _marginTicketRightCtrl.text = s.marginTicketRight.toString();

    _marginInvoiceTopCtrl.text = s.marginInvoiceTop.toString();
    _marginInvoiceBottomCtrl.text = s.marginInvoiceBottom.toString();
    _marginInvoiceLeftCtrl.text = s.marginInvoiceLeft.toString();
    _marginInvoiceRightCtrl.text = s.marginInvoiceRight.toString();
    _networkMode = s.networkMode;
    _serverIpCtrl.text = s.serverIp;
    _serverPortCtrl.text = s.serverPort.toString();
    _customerDisplayTheme = s.customerDisplayTheme;
    _enableCustomerDisplayTicker = s.enableCustomerDisplayTicker;
    _customerDisplayMessagesCtrl.text = s.customerDisplayMessages.join('\n');

    _marginLabelXCtrl.text = s.marginLabelX.toString();
    _marginLabelYCtrl.text = s.marginLabelY.toString();

    // Cloud & Email Backup
    _cloudBackupPath = s.cloudBackupPath;
    _emailBackupEnabled = s.emailBackupEnabled;
    _emailBackupFrequency = s.emailBackupFrequency;
    _emailBackupHour = s.emailBackupHour;
    _backupEmailRecipientCtrl.text = s.backupEmailRecipient;
    _smtpHostCtrl.text = s.smtpHost;
    _smtpPortCtrl.text = s.smtpPort.toString();
    _smtpUserCtrl.text = s.smtpUser;
    _smtpPasswordCtrl.text = s.smtpPassword;

    _reportEmailEnabled = s.reportEmailEnabled;
    _stockAlertsEnabled = s.stockAlertsEnabled;
    _reportEmailFrequency = s.reportEmailFrequency;
    _reportEmailHour = s.reportEmailHour;
    _reportEmailDayOfWeek = s.reportEmailDayOfWeek;

    _marketingEmailsEnabled = s.marketingEmailsEnabled;
    _inactivityReminderEnabled = s.inactivityReminderEnabled;
    _inactivityDaysThreshold = s.inactivityDaysThreshold;

    _showTaxOnTickets = s.showTaxOnTickets;
    _showTaxOnInvoices = s.showTaxOnInvoices;
    _showTaxOnQuotes = s.showTaxOnQuotes;
    _showTaxOnDeliveryNotes = s.showTaxOnDeliveryNotes;
    _useDetailedTaxOnTickets = s.useDetailedTaxOnTickets;
    _useDetailedTaxOnInvoices = s.useDetailedTaxOnInvoices;
    _useDetailedTaxOnQuotes = s.useDetailedTaxOnQuotes;
    _useDetailedTaxOnQuotes = s.useDetailedTaxOnQuotes;
    _useDetailedTaxOnDeliveryNotes = s.useDetailedTaxOnDeliveryNotes;

  }

  void _saveDebounced() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      _save();
    });
  }

  Future<void> _save() async {
    final current = ref.read(shopSettingsProvider).value;
    if (current == null) return;
    final updated = current.copyWith(
      assistantLevel: _assistantLevel,
      name: _nameCtrl.text.trim(),
      slogan: _sloganCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      whatsapp: _whatsappCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      rc: _rcCtrl.text.trim(),
      nif: _nifCtrl.text.trim(),
      bankAccount: _bankAccountCtrl.text.trim(),
      currency: _currency,
      removeDecimals: _removeDecimals,
      defaultReceipt: _receipt,
      defaultInvoice: _invoice,
      defaultQuote: _quote,
      defaultPurchaseOrder: _purchaseOrder ?? PurchaseOrderTemplate.professional,
      receiptFooter: _receiptFooterCtrl.text.trim(),
      logoPath: _logoPath,
      taxName: _taxNameCtrl.text.trim(),
      taxRate: (double.tryParse(_taxRateCtrl.text) ?? 0).clamp(0, 100),
      autoBackupEnabled: _autoBackupEnabled,
      useTax: _useTax,
      showQrCode: _showQrCode,
      useAutoRef: _useAutoRef,
      refPrefix: _refPrefixCtrl.text.trim(),
      refModel: _refModel,
      barcodeModel: _barcodeModel,
      labelFormat: _labelFormat,
      labelWidth: double.tryParse(_labelWidthCtrl.text) ?? 50.0,
      labelHeight: double.tryParse(_labelHeightCtrl.text) ?? 30.0,
      thermalPrinterName: _thermalPrinter,
      invoicePrinterName: _invoicePrinter,
      quotePrinterName: _quotePrinter,
      purchaseOrderPrinterName: _purchaseOrderPrinter,
      labelPrinterName: _labelPrinter,
      contractPrinterName: _contractPrinter,
      payrollPrinterName: _payrollPrinter,
      reportPrinterName: _reportPrinter,
      proformaPrinterName: _proformaPrinter,
      deliveryPrinterName: _deliveryPrinter,
      autoPrintTicket: _autoPrintTicket,
      showPreviewBeforePrint: _showPreviewBeforePrint,
      autoPrintDeliveryNote: _autoPrintDeliveryNote,
      // Ultra Pro
      legalForm: _legalFormCtrl.text.trim(),
      capital: _capitalCtrl.text.trim(),
      policyWarranty: _warrantyCtrl.text.trim(),
      policyReturns: _returnsCtrl.text.trim(),
      policyPayments: _paymentsPolicyCtrl.text.trim(),
      quoteValidityDays: int.tryParse(_validityCtrl.text) ?? 30,
      invoiceLegalNote: _legalNoteCtrl.text.trim(),
      showPriceOnLabels: _showPriceOnLabels,
      showNameOnLabels: _showNameOnLabels,
      showSkuOnLabels: _showSkuOnLabels,
      autoPrintLabelsOnStockIn: _autoPrintLabelsOnStockIn,
      managerPin: _managerPinCtrl.text.trim(),
      maxDiscountThreshold: (double.tryParse(_maxDiscountThresholdCtrl.text) ?? 10).clamp(0, 100),
      vipThreshold: (double.tryParse(_vipThresholdCtrl.text) ?? 1000000).clamp(0, double.infinity),
      loyaltyEnabled: _loyaltyEnabled,
      pointsPerAmount: (double.tryParse(_pointsPerAmountCtrl.text) ?? current.pointsPerAmount).clamp(1, double.infinity),
      amountPerPoint: (double.tryParse(_amountPerPointCtrl.text) ?? current.amountPerPoint).clamp(0, double.infinity),
      showTaxOnTickets: _showTaxOnTickets,
      showTaxOnInvoices: _showTaxOnInvoices,
      showTaxOnQuotes: _showTaxOnQuotes,
      showTaxOnDeliveryNotes: _showTaxOnDeliveryNotes,
      useDetailedTaxOnTickets: _useDetailedTaxOnTickets,
      useDetailedTaxOnInvoices: _useDetailedTaxOnInvoices,
      useDetailedTaxOnQuotes: _useDetailedTaxOnQuotes,
      useDetailedTaxOnDeliveryNotes: _useDetailedTaxOnDeliveryNotes,
      showAssistant: _showAssistant,
      networkMode: _networkMode,
      serverIp: _serverIpCtrl.text.trim(),
      serverPort: int.tryParse(_serverPortCtrl.text) ?? 8080,
      customerDisplayTheme: _customerDisplayTheme,
      enableCustomerDisplayTicker: _enableCustomerDisplayTicker,
      customerDisplayMessages: _customerDisplayMessagesCtrl.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      roundingMode: _roundingMode,
      directPhysicalPrinting: _directPhysicalPrinting,
      openCashDrawer: _openCashDrawer,
      enableSounds: _enableSounds,
      enableAppSounds: _enableAppSounds,
      enableCustomerDisplaySounds: _enableCustomerDisplaySounds,
      useCustomerDisplay3D: _useCustomerDisplay3D,
      marginTicketTop: double.tryParse(_marginTicketTopCtrl.text) ?? 5.0,
      marginTicketBottom: double.tryParse(_marginTicketBottomCtrl.text) ?? 5.0,
      marginTicketLeft: double.tryParse(_marginTicketLeftCtrl.text) ?? 5.0,
      marginTicketRight: double.tryParse(_marginTicketRightCtrl.text) ?? 5.0,
      marginInvoiceTop: double.tryParse(_marginInvoiceTopCtrl.text) ?? 20.0,
      marginInvoiceBottom: double.tryParse(_marginInvoiceBottomCtrl.text) ?? 20.0,
      marginInvoiceLeft: double.tryParse(_marginInvoiceLeftCtrl.text) ?? 20.0,
      marginInvoiceRight: double.tryParse(_marginInvoiceRightCtrl.text) ?? 20.0,
      marginLabelX: double.tryParse(_marginLabelXCtrl.text) ?? 0.0,
      marginLabelY: double.tryParse(_marginLabelYCtrl.text) ?? 0.0,
      cloudBackupPath: _cloudBackupPath,
      emailBackupEnabled: _emailBackupEnabled,
      backupEmailRecipient: _backupEmailRecipientCtrl.text.trim(),
      smtpHost: _smtpHostCtrl.text.trim(),
      smtpPort: int.tryParse(_smtpPortCtrl.text) ?? 587,
      smtpUser: _smtpUserCtrl.text.trim(),
      smtpPassword: _smtpPasswordCtrl.text.trim(),
      emailBackupFrequency: _emailBackupFrequency,
      emailBackupHour: _emailBackupHour,
      reportEmailEnabled: _reportEmailEnabled,
      stockAlertsEnabled: _stockAlertsEnabled,
      reportEmailFrequency: _reportEmailFrequency,
      reportEmailHour: _reportEmailHour,
      reportEmailDayOfWeek: _reportEmailDayOfWeek,
      marketingEmailsEnabled: _marketingEmailsEnabled,
      inactivityReminderEnabled: _inactivityReminderEnabled,
      inactivityDaysThreshold: _inactivityDaysThreshold,
      isAutoLockEnabled: _isAutoLockEnabled,
      autoLockMinutes: int.tryParse(_autoLockMinutesCtrl.text) ?? 5,
      labelHT: _labelHTCtrl.text.trim(),
      labelTTC: _labelTTCCtrl.text.trim(),
      titleInvoice: _titleInvoiceCtrl.text.trim(),
      titleReceipt: _titleReceiptCtrl.text.trim(),
      titleReceiptProforma: _titleReceiptProformaCtrl.text.trim(),
      titleQuote: _titleQuoteCtrl.text.trim(),
      titleProforma: _titleProformaCtrl.text.trim(),
      titleDeliveryNote: _titleDeliveryNoteCtrl.text.trim(),
      // Matrice Élite: Aplatir (Flatten) la Map imbriquée de l'UI vers la Map plate du modèle
      templateFiscalSettings: _flattenFiscalSettings(),
    );
    await ref.read(shopSettingsProvider.notifier).save(updated);
    
    // Notification déjà gérée par le provider (broadcastEvent)
    
    // Log d'audit
    final user = ref.read(authServiceProvider).value;
    unawaited(ref.read(databaseServiceProvider).logActivity(
      userId: user?.id,
      actionType: 'SETTINGS_UPDATE',
      description: "Mise à jour des paramètres de la boutique",
    ));
  }

  Map<String, bool> _flattenFiscalSettings() {
    final Map<String, bool> flat = {};
    _templateFiscalSettings.forEach((type, options) {
      options.forEach((templateOption, value) {
        // templateOption est de la forme "template_show" ou "template_detailed"
        final key = "${type}_$templateOption";
        flat[key] = value;
      });
    });
    return flat;
  }

  void _showToast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).value;
    if (user == null || !user.canAccessSettings) {
      return const AccessDeniedScreen(
        message: "Paramètres Restreints",
        subtitle: "Seuls les administrateurs peuvent modifier les réglages système.",
      );
    }

    // Log access
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).logActivity(
            userId: user.id,
            actionType: 'VIEW_SETTINGS',
            description: 'Accès aux paramètres par ${user.username}',
          );
    });

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settingsAsync = ref.watch(shopSettingsProvider);

    final sidebarColor = isDark ? const Color(0xFF1A1C23) : Colors.white;
    final contentBg = isDark ? const Color(0xFF111318) : const Color(0xFFF7F8FA);
    final borderColor = isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: contentBg,
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (settings) {
          _initControllers(settings);
          return Row(
            children: [
              // ── SIDEBAR ULTRA PRO (Affinée) ──
              Container(
                width: 250,
                decoration: BoxDecoration(
                  color: sidebarColor,
                  border: Border(right: BorderSide(color: borderColor, width: 1)),
                ),
                child: Column(
                  children: [
                    // En-tête Sidebar compacte
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(FluentIcons.settings_20_filled, 
                              color: theme.colorScheme.primary, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("CONFIGURATION", 
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.0, color: theme.colorScheme.primary)),
                              Text("Boutique & Système", 
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                        children: _modules.map((module) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
                                child: Text(
                                  module["title"],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: theme.colorScheme.primary.withValues(alpha: 0.6),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              ... (module["items"] as List<int>).map((index) {
                                final isSelected = _selectedIndex == index;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () {
                                          setState(() {
                                            _selectedIndex = index;
                                            ref.read(settingsTabIndexProvider.notifier).setIndex(index);
                                          });
                                          if (index == 11) _loadLogs();
                                        },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: isSelected 
                                              ? theme.colorScheme.primary.withValues(alpha: 0.08)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              _menuIcons[index],
                                              size: 18,
                                              color: isSelected ? theme.colorScheme.primary : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                _menuItems[index],
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                                  color: isSelected ? theme.colorScheme.primary : (isDark ? Colors.white70 : Colors.black87),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isSelected) ...[
                                              Container(width: 3, height: 14, decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(2))),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(height: 8),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    // Footer Sidebar ultra compact
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(FluentIcons.save_16_regular, size: 16),
                        label: const Text("ENREGISTRER", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5, fontSize: 10)),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── CONTENT AREA (Scrollable & Responsive) ──
              Expanded(
                child: Column(
                  children: [
                    // Header Content Raffiné
                    Container(
                      padding: const EdgeInsets.fromLTRB(40, 32, 40, 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _menuItems[_selectedIndex].toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.2),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _getSectionSubtitle(_selectedIndex),
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          // Optionnel : Bouton d'aide ou état
                          if (_daysRemaining != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                              child: Text("Licence: $_daysRemaining j restants", style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    
                    Expanded(
                      child: _selectedIndex == 4
                        // Le Design PDF utilise son propre scroll interne → pas de SingleChildScrollView
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: _buildRightContent(context, settings),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(40),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 900),
                                child: _buildRightContent(context, settings),
                              ),
                            ),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getSectionSubtitle(int index) {
    switch (index) {
      case 0: return "Identité visuelle et coordonnées de votre enseigne.";
      case 1: return "Gestion fiscale, devises et conditions de vente.";
      case 2: return "Programmes de fidélité et VIP.";
      case 3: return "Politiques de garantie, retours et sécurité manager.";
      case 4: return "Choix des modèles visuels pour vos documents PDF.";
      case 5: return "Assignation des imprimantes et tiroir-caisse.";
      case 6: return "Thèmes, sons et 3D pour l'écran tourné vers le client.";
      case 7: return "Configuration des sons et alertes multimédia.";
      case 8: return "Logiques de génération automatique et Assistant IA.";
      case 9: return "Sauvegardes (Cloud/Local), Base de données et Emails.";
      case 10: return "Configuration multi-postes, Serveur et Accès distant.";
      case 11: return "Traçabilité complète des actions effectuées (Logs).";
      case 12: return "Personnalisation de l'interface graphique.";
      case 13: return "D+ Academy : Guide interactif et tutoriels.";
      default: return "";
    }
  }

  Widget _buildRightContent(BuildContext context, ShopSettings settings) {
    switch (_selectedIndex) {
      case 0: // Enseigne & Identité
        return GeneralSettingsSection(
          nameCtrl: _nameCtrl,
          sloganCtrl: _sloganCtrl,
          phoneCtrl: _phoneCtrl,
          whatsappCtrl: _whatsappCtrl,
          emailCtrl: _emailCtrl,
          addressCtrl: _addressCtrl,
          logoPath: _logoPath,
          onPickLogo: _pickLogo,
          onRemoveLogo: _removeLogo,
          onSaveDebounced: _saveDebounced,
        );
      case 1: // Commerce & Fiscalité
        return FinanceSettingsSection(
          legalFormCtrl: _legalFormCtrl,
          capitalCtrl: _capitalCtrl,
          rcCtrl: _rcCtrl,
          nifCtrl: _nifCtrl,
          bankAccountCtrl: _bankAccountCtrl,
          warrantyCtrl: _warrantyCtrl,
          returnsCtrl: _returnsCtrl,
          paymentsPolicyCtrl: _paymentsPolicyCtrl,
          validityCtrl: _validityCtrl,
          legalNoteCtrl: _legalNoteCtrl,
          currency: _currency,
          onCurrencyChanged: (v) => setState(() { _currency = v!; _saveDebounced(); }),
          removeDecimals: _removeDecimals,
          onRemoveDecimalsChanged: (v) => setState(() { _removeDecimals = v; _saveDebounced(); }),
          useTax: _useTax,
          onUseTaxChanged: (v) => setState(() { _useTax = v; _saveDebounced(); }),
          taxNameCtrl: _taxNameCtrl,
          taxRateCtrl: _taxRateCtrl,
          managerPinCtrl: _managerPinCtrl,
          maxDiscountThresholdCtrl: _maxDiscountThresholdCtrl,
          vipThresholdCtrl: _vipThresholdCtrl,
          loyaltyEnabled: _loyaltyEnabled,
          onLoyaltyEnabledChanged: (v) => setState(() { _loyaltyEnabled = v; _saveDebounced(); }),
          pointsPerAmountCtrl: _pointsPerAmountCtrl,
          amountPerPointCtrl: _amountPerPointCtrl,
          onSaveDebounced: _saveDebounced,
          isFinanceOnly: true,
          templateFiscalSettings: _templateFiscalSettings,
          onTemplateFiscalSettingChanged: (type, template, field, val) {
            setState(() {
              if (!_templateFiscalSettings.containsKey(type)) _templateFiscalSettings[type] = {};
              final key = '${template}_$field';
              _templateFiscalSettings[type]![key] = val;
              _saveDebounced();
            });
          },
          labelHTCtrl: _labelHTCtrl,
          labelTTCCtrl: _labelTTCCtrl,
          showTaxOnTickets: _showTaxOnTickets,
          onShowTaxOnTicketsChanged: (v) => setState(() { _showTaxOnTickets = v; _saveDebounced(); }),
          showTaxOnInvoices: _showTaxOnInvoices,
          onShowTaxOnInvoicesChanged: (v) => setState(() { _showTaxOnInvoices = v; _saveDebounced(); }),
          showTaxOnQuotes: _showTaxOnQuotes,
          onShowTaxOnQuotesChanged: (v) => setState(() { _showTaxOnQuotes = v; _saveDebounced(); }),
          showTaxOnDeliveryNotes: _showTaxOnDeliveryNotes,
          onShowTaxOnDeliveryNotesChanged: (v) => setState(() { _showTaxOnDeliveryNotes = v; _saveDebounced(); }),
          useDetailedTaxOnTickets: _useDetailedTaxOnTickets,
          onUseDetailedTaxOnTicketsChanged: (v) => setState(() { _useDetailedTaxOnTickets = v; _saveDebounced(); }),
          useDetailedTaxOnInvoices: _useDetailedTaxOnInvoices,
          onUseDetailedTaxOnInvoicesChanged: (v) => setState(() { _useDetailedTaxOnInvoices = v; _saveDebounced(); }),
          useDetailedTaxOnQuotes: _useDetailedTaxOnQuotes,
          onUseDetailedTaxOnQuotesChanged: (v) => setState(() { _useDetailedTaxOnQuotes = v; _saveDebounced(); }),
          useDetailedTaxOnDeliveryNotes: _useDetailedTaxOnDeliveryNotes,
          onUseDetailedTaxOnDeliveryNotesChanged: (v) => setState(() { _useDetailedTaxOnDeliveryNotes = v; _saveDebounced(); }),
        );
      case 2: // Points & Fidélité
        return FinanceSettingsSection(
          legalFormCtrl: _legalFormCtrl,
          capitalCtrl: _capitalCtrl,
          rcCtrl: _rcCtrl,
          nifCtrl: _nifCtrl,
          bankAccountCtrl: _bankAccountCtrl,
          warrantyCtrl: _warrantyCtrl,
          returnsCtrl: _returnsCtrl,
          paymentsPolicyCtrl: _paymentsPolicyCtrl,
          validityCtrl: _validityCtrl,
          legalNoteCtrl: _legalNoteCtrl,
          currency: _currency,
          onCurrencyChanged: (v) => setState(() { _currency = v!; _saveDebounced(); }),
          removeDecimals: _removeDecimals,
          onRemoveDecimalsChanged: (v) => setState(() { _removeDecimals = v; _saveDebounced(); }),
          useTax: _useTax,
          onUseTaxChanged: (v) => setState(() { _useTax = v; _saveDebounced(); }),
          taxNameCtrl: _taxNameCtrl,
          taxRateCtrl: _taxRateCtrl,
          managerPinCtrl: _managerPinCtrl,
          maxDiscountThresholdCtrl: _maxDiscountThresholdCtrl,
          vipThresholdCtrl: _vipThresholdCtrl,
          loyaltyEnabled: _loyaltyEnabled,
          onLoyaltyEnabledChanged: (v) => setState(() { _loyaltyEnabled = v; _saveDebounced(); }),
          pointsPerAmountCtrl: _pointsPerAmountCtrl,
          amountPerPointCtrl: _amountPerPointCtrl,
          onSaveDebounced: _saveDebounced,
          isLoyaltyOnly: true,
          templateFiscalSettings: _templateFiscalSettings,
          onTemplateFiscalSettingChanged: (type, template, field, val) {
            setState(() {
              if (!_templateFiscalSettings.containsKey(type)) _templateFiscalSettings[type] = {};
              final key = '${template}_$field';
              _templateFiscalSettings[type]![key] = val;
              _saveDebounced();
            });
          },
          labelHTCtrl: _labelHTCtrl,
          labelTTCCtrl: _labelTTCCtrl,
          showTaxOnTickets: _showTaxOnTickets,
          onShowTaxOnTicketsChanged: (v) => setState(() { _showTaxOnTickets = v; _saveDebounced(); }),
          showTaxOnInvoices: _showTaxOnInvoices,
          onShowTaxOnInvoicesChanged: (v) => setState(() { _showTaxOnInvoices = v; _saveDebounced(); }),
          showTaxOnQuotes: _showTaxOnQuotes,
          onShowTaxOnQuotesChanged: (v) => setState(() { _showTaxOnQuotes = v; _saveDebounced(); }),
          showTaxOnDeliveryNotes: _showTaxOnDeliveryNotes,
          onShowTaxOnDeliveryNotesChanged: (v) => setState(() { _showTaxOnDeliveryNotes = v; _saveDebounced(); }),
          useDetailedTaxOnTickets: _useDetailedTaxOnTickets,
          onUseDetailedTaxOnTicketsChanged: (v) => setState(() { _useDetailedTaxOnTickets = v; _saveDebounced(); }),
          useDetailedTaxOnInvoices: _useDetailedTaxOnInvoices,
          onUseDetailedTaxOnInvoicesChanged: (v) => setState(() { _useDetailedTaxOnInvoices = v; _saveDebounced(); }),
          useDetailedTaxOnQuotes: _useDetailedTaxOnQuotes,
          onUseDetailedTaxOnQuotesChanged: (v) => setState(() { _useDetailedTaxOnQuotes = v; _saveDebounced(); }),
          useDetailedTaxOnDeliveryNotes: _useDetailedTaxOnDeliveryNotes,
          onUseDetailedTaxOnDeliveryNotesChanged: (v) => setState(() { _useDetailedTaxOnDeliveryNotes = v; _saveDebounced(); }),
        );
      case 3: // Politiques & S.A.V
        return FinanceSettingsSection(
          legalFormCtrl: _legalFormCtrl,
          capitalCtrl: _capitalCtrl,
          rcCtrl: _rcCtrl,
          nifCtrl: _nifCtrl,
          bankAccountCtrl: _bankAccountCtrl,
          warrantyCtrl: _warrantyCtrl,
          returnsCtrl: _returnsCtrl,
          paymentsPolicyCtrl: _paymentsPolicyCtrl,
          validityCtrl: _validityCtrl,
          legalNoteCtrl: _legalNoteCtrl,
          currency: _currency,
          onCurrencyChanged: (v) => setState(() { _currency = v!; _saveDebounced(); }),
          removeDecimals: _removeDecimals,
          onRemoveDecimalsChanged: (v) => setState(() { _removeDecimals = v; _saveDebounced(); }),
          useTax: _useTax,
          onUseTaxChanged: (v) => setState(() { _useTax = v; _saveDebounced(); }),
          taxNameCtrl: _taxNameCtrl,
          taxRateCtrl: _taxRateCtrl,
          managerPinCtrl: _managerPinCtrl,
          maxDiscountThresholdCtrl: _maxDiscountThresholdCtrl,
          vipThresholdCtrl: _vipThresholdCtrl,
          loyaltyEnabled: _loyaltyEnabled,
          onLoyaltyEnabledChanged: (v) => setState(() { _loyaltyEnabled = v; _saveDebounced(); }),
          pointsPerAmountCtrl: _pointsPerAmountCtrl,
          amountPerPointCtrl: _amountPerPointCtrl,
          onSaveDebounced: _saveDebounced,
          isPolicyOnly: true,
          templateFiscalSettings: _templateFiscalSettings,
          onTemplateFiscalSettingChanged: (type, template, field, val) {
            setState(() {
              if (!_templateFiscalSettings.containsKey(type)) _templateFiscalSettings[type] = {};
              final key = '${template}_$field';
              _templateFiscalSettings[type]![key] = val;
              _saveDebounced();
            });
          },
          labelHTCtrl: _labelHTCtrl,
          labelTTCCtrl: _labelTTCCtrl,
          showTaxOnTickets: _showTaxOnTickets,
          onShowTaxOnTicketsChanged: (v) => setState(() { _showTaxOnTickets = v; _saveDebounced(); }),
          showTaxOnInvoices: _showTaxOnInvoices,
          onShowTaxOnInvoicesChanged: (v) => setState(() { _showTaxOnInvoices = v; _saveDebounced(); }),
          showTaxOnQuotes: _showTaxOnQuotes,
          onShowTaxOnQuotesChanged: (v) => setState(() { _showTaxOnQuotes = v; _saveDebounced(); }),
          showTaxOnDeliveryNotes: _showTaxOnDeliveryNotes,
          onShowTaxOnDeliveryNotesChanged: (v) => setState(() { _showTaxOnDeliveryNotes = v; _saveDebounced(); }),
          useDetailedTaxOnTickets: _useDetailedTaxOnTickets,
          onUseDetailedTaxOnTicketsChanged: (v) => setState(() { _useDetailedTaxOnTickets = v; _saveDebounced(); }),
          useDetailedTaxOnInvoices: _useDetailedTaxOnInvoices,
          onUseDetailedTaxOnInvoicesChanged: (v) => setState(() { _useDetailedTaxOnInvoices = v; _saveDebounced(); }),
          useDetailedTaxOnQuotes: _useDetailedTaxOnQuotes,
          onUseDetailedTaxOnQuotesChanged: (v) => setState(() { _useDetailedTaxOnQuotes = v; _saveDebounced(); }),
          useDetailedTaxOnDeliveryNotes: _useDetailedTaxOnDeliveryNotes,
          onUseDetailedTaxOnDeliveryNotesChanged: (v) => setState(() { _useDetailedTaxOnDeliveryNotes = v; _saveDebounced(); }),
        );
      case 4: // Centre de Design Universel (Modèles & Design PDF)
        return PrintingSettingsSection(
          receipt: _receipt,
          onReceiptChanged: (v) { setState(() => _receipt = v); _saveDebounced(); },
          invoice: _invoice,
          onInvoiceChanged: (v) { setState(() => _invoice = v); _saveDebounced(); },
          quote: _quote,
          onQuoteChanged: (v) { setState(() => _quote = v); _saveDebounced(); },
          purchaseOrder: _purchaseOrder,
          onPurchaseOrderChanged: (v) { setState(() => _purchaseOrder = v); _saveDebounced(); },
          receiptFooterCtrl: _receiptFooterCtrl,
          
          // Nouveaux paramètres de titres pour le Hub de Design
          titleInvoiceCtrl: _titleInvoiceCtrl,
          titleReceiptCtrl: _titleReceiptCtrl,
          titleQuoteCtrl: _titleQuoteCtrl,
          titleProformaCtrl: _titleProformaCtrl,
          titleDeliveryNoteCtrl: _titleDeliveryNoteCtrl,

          showQrCode: _showQrCode,
          onShowQrCodeChanged: (v) { setState(() => _showQrCode = v); _saveDebounced(); },
          directPhysicalPrinting: _directPhysicalPrinting,
          onDirectPhysicalPrintingChanged: (v) { setState(() => _directPhysicalPrinting = v); _saveDebounced(); },
          autoPrintTicket: _autoPrintTicket,
          onAutoPrintTicketChanged: (v) { setState(() => _autoPrintTicket = v); _saveDebounced(); },
          showPreviewBeforePrint: _showPreviewBeforePrint,
          onShowPreviewBeforePrintChanged: (v) { setState(() => _showPreviewBeforePrint = v); _saveDebounced(); },
          thermalPrinter: _thermalPrinter,
          onThermalPrinterChanged: (v) { setState(() => _thermalPrinter = v); _saveDebounced(); },
          invoicePrinter: _invoicePrinter,
          onInvoicePrinterChanged: (v) { setState(() => _invoicePrinter = v); _saveDebounced(); },
          quotePrinter: _quotePrinter,
          onQuotePrinterChanged: (v) { setState(() => _quotePrinter = v); _saveDebounced(); },
          purchaseOrderPrinter: _purchaseOrderPrinter,
          onPurchaseOrderPrinterChanged: (v) { setState(() => _purchaseOrderPrinter = v); _saveDebounced(); },
          labelPrinter: _labelPrinter,
          onLabelPrinterChanged: (v) { setState(() => _labelPrinter = v); _saveDebounced(); },
          reportPrinter: _reportPrinter,
          onReportPrinterChanged: (v) { setState(() => _reportPrinter = v); _saveDebounced(); },
          availablePrinters: _availablePrinters,
          onLoadPrinters: _loadPrinters,
          onTestPrint: _testPrint,
          openCashDrawer: _openCashDrawer,
          onOpenCashDrawerChanged: (v) { setState(() => _openCashDrawer = v); _saveDebounced(); },
          enableSounds: _enableSounds,
          onEnableSoundsChanged: (v) { setState(() => _enableSounds = v); _saveDebounced(); },
          enableAppSounds: _enableAppSounds,
          onEnableAppSoundsChanged: (v) { setState(() => _enableAppSounds = v); _saveDebounced(); },
          onTestSound: () => ref.read(soundServiceProvider).playTest(),
          labelFormat: _labelFormat,
          onLabelFormatChanged: (v) { if (v != null) { setState(() => _labelFormat = v); _saveDebounced(); } },
          labelWidthCtrl: _labelWidthCtrl,
          labelHeightCtrl: _labelHeightCtrl,
          showNameOnLabels: _showNameOnLabels,
          onShowNameOnLabelsChanged: (v) { setState(() => _showNameOnLabels = v); _saveDebounced(); },
          showPriceOnLabels: _showPriceOnLabels,
          onShowPriceOnLabelsChanged: (v) { setState(() => _showPriceOnLabels = v); _saveDebounced(); },
          showSkuOnLabels: _showSkuOnLabels,
          onShowSkuOnLabelsChanged: (v) { setState(() => _showSkuOnLabels = v); _saveDebounced(); },
          marginTicketTopCtrl: _marginTicketTopCtrl,
          marginTicketBottomCtrl: _marginTicketBottomCtrl,
          marginTicketLeftCtrl: _marginTicketLeftCtrl,
          marginTicketRightCtrl: _marginTicketRightCtrl,
          marginInvoiceTopCtrl: _marginInvoiceTopCtrl,
          marginInvoiceBottomCtrl: _marginInvoiceBottomCtrl,
          marginInvoiceLeftCtrl: _marginInvoiceLeftCtrl,
          marginInvoiceRightCtrl: _marginInvoiceRightCtrl,
          onSaveDebounced: _saveDebounced,
          enableCustomerDisplaySounds: _enableCustomerDisplaySounds,
          onEnableCustomerDisplaySoundsChanged: (v) { setState(() => _enableCustomerDisplaySounds = v); _saveDebounced(); },
          useCustomerDisplay3D: _useCustomerDisplay3D,
          onUseCustomerDisplay3DChanged: (v) { setState(() => _useCustomerDisplay3D = v); _saveDebounced(); },
          marginLabelXCtrl: _marginLabelXCtrl,
          marginLabelYCtrl: _marginLabelYCtrl,
          autoPrintDeliveryNote: _autoPrintDeliveryNote,
          onAutoPrintDeliveryNoteChanged: (v) { setState(() => _autoPrintDeliveryNote = v); _saveDebounced(); },

          // Synchronisation de l'identité
          nameCtrl: _nameCtrl,
          sloganCtrl: _sloganCtrl,
          addressCtrl: _addressCtrl,
          phoneCtrl: _phoneCtrl,
          logoPath: _logoPath,
        );
      case 5: // Matériel Hub
        return HardwareSettingsSection(
          thermalPrinter: _thermalPrinter,
          onThermalPrinterChanged: (v) { setState(() => _thermalPrinter = v); _saveDebounced(); },
          invoicePrinter: _invoicePrinter,
          onInvoicePrinterChanged: (v) { setState(() => _invoicePrinter = v); _saveDebounced(); },
          quotePrinter: _quotePrinter,
          onQuotePrinterChanged: (v) { setState(() => _quotePrinter = v); _saveDebounced(); },
          purchaseOrderPrinter: _purchaseOrderPrinter,
          onPurchaseOrderPrinterChanged: (v) { setState(() => _purchaseOrderPrinter = v); _saveDebounced(); },
          labelPrinter: _labelPrinter,
          onLabelPrinterChanged: (v) { setState(() => _labelPrinter = v); _saveDebounced(); },
          reportPrinter: _reportPrinter,
          onReportPrinterChanged: (v) { setState(() => _reportPrinter = v); _saveDebounced(); },
          contractPrinter: _contractPrinter,
          onContractPrinterChanged: (v) { setState(() => _contractPrinter = v); _saveDebounced(); },
          payrollPrinter: _payrollPrinter,
          onPayrollPrinterChanged: (v) { setState(() => _payrollPrinter = v); _saveDebounced(); },
          availablePrinters: _availablePrinters,
          onLoadPrinters: _loadPrinters,
          openCashDrawer: _openCashDrawer,
          onOpenCashDrawerChanged: (v) { setState(() => _openCashDrawer = v); _saveDebounced(); },
          onTestCashDrawer: _testCashDrawer,
          directPhysicalPrinting: _directPhysicalPrinting,
          onDirectPhysicalPrintingChanged: (v) { setState(() => _directPhysicalPrinting = v); _saveDebounced(); },
          autoPrintTicket: _autoPrintTicket,
          onAutoPrintTicketChanged: (v) { setState(() => _autoPrintTicket = v); _saveDebounced(); },
          showPreviewBeforePrint: _showPreviewBeforePrint,
          onShowPreviewBeforePrintChanged: (v) { setState(() => _showPreviewBeforePrint = v); _saveDebounced(); },
          proformaPrinter: _proformaPrinter,
          onProformaPrinterChanged: (v) { setState(() => _proformaPrinter = v); _saveDebounced(); },
          deliveryPrinter: _deliveryPrinter,
          onDeliveryPrinterChanged: (v) { setState(() => _deliveryPrinter = v); _saveDebounced(); },
        );
      case 6: // Afficheur Client (Pro)
        return CustomerDisplaySettingsSection(
          theme: _customerDisplayTheme,
          onThemeChanged: (v) { setState(() => _customerDisplayTheme = v); _saveDebounced(); },
          enableSounds: _enableCustomerDisplaySounds,
          onEnableSoundsChanged: (v) { setState(() => _enableCustomerDisplaySounds = v); _saveDebounced(); },
          use3D: _useCustomerDisplay3D,
          onUse3DChanged: (v) { setState(() => _useCustomerDisplay3D = v); _saveDebounced(); },
          enableTicker: _enableCustomerDisplayTicker,
          onEnableTickerChanged: (v) { setState(() => _enableCustomerDisplayTicker = v); _saveDebounced(); },
          messagesCtrl: _customerDisplayMessagesCtrl,
          onSaveDebounced: _saveDebounced,
          networkMode: _networkMode,
        );
      case 7: // Sons & Multimédia
        return MultimediaSettingsSection(
          enableSounds: _enableSounds,
          onEnableSoundsChanged: (v) { setState(() => _enableSounds = v); _saveDebounced(); },
          enableAppSounds: _enableAppSounds,
          onEnableAppSoundsChanged: (v) { setState(() => _enableAppSounds = v); _saveDebounced(); },
          enableCustomerDisplaySounds: _enableCustomerDisplaySounds,
          onEnableCustomerDisplaySoundsChanged: (v) { setState(() => _enableCustomerDisplaySounds = v); _saveDebounced(); },
          useCustomerDisplay3D: _useCustomerDisplay3D,
          onUseCustomerDisplay3DChanged: (v) { setState(() => _useCustomerDisplay3D = v); _saveDebounced(); },
          onTestSound: () => ref.read(soundServiceProvider).playTest(),
          onSaveDebounced: _saveDebounced,
        );
      case 8: // Automatisation & IA
        return AutomationSettingsSection(
          useAutoRef: _useAutoRef,
          onUseAutoRefChanged: (v) { setState(() => _useAutoRef = v); _saveDebounced(); },
          refPrefixCtrl: _refPrefixCtrl,
          refModel: _refModel,
          onRefModelChanged: (v) { if (v != null) { setState(() => _refModel = v); _saveDebounced(); } },
          barcodeModel: _barcodeModel,
          onBarcodeModelChanged: (v) { if (v != null) { setState(() => _barcodeModel = v); _saveDebounced(); } },
          autoPrintLabelsOnStockIn: _autoPrintLabelsOnStockIn,
          onAutoPrintLabelsOnStockInChanged: (v) { setState(() => _autoPrintLabelsOnStockIn = v); _saveDebounced(); },
          showAssistant: _showAssistant,
          onShowAssistantChanged: (v) { setState(() => _showAssistant = v); _saveDebounced(); },
          roundingMode: _roundingMode,
          onRoundingModeChanged: (v) { if (v != null) { setState(() => _roundingMode = v); _saveDebounced(); } },
          assistantLevel: _assistantLevel,
          onAssistantLevelChanged: (v) { if (v != null) { setState(() => _assistantLevel = v); _saveDebounced(); } },
          onSaveDebounced: _saveDebounced,
        );
      case 9: // Sauvegardes & Cloud
        return BackupCloudDashboard(
          dbStats: _dbStats,
          autoBackupEnabled: _autoBackupEnabled,
          onAutoBackupEnabledChanged: (v) { setState(() => _autoBackupEnabled = v); _saveDebounced(); },
          autoBackups: _autoBackups,
          onBackupDatabase: _backupDatabase,
          onRestoreDatabase: _restoreDatabase,
          onRestoreSpecificBackup: _restoreSpecificBackup,
          onConfirmResetDb: _confirmResetDb,
          onRecalculateWac: _recalculateWac,
          onCleanupImages: _cleanupImages,
          cloudBackupPath: _cloudBackupPath,
          onCloudBackupPathChanged: (path) { setState(() => _cloudBackupPath = path); _saveDebounced(); },
          emailBackupEnabled: _emailBackupEnabled,
          onEmailBackupEnabledChanged: (v) { setState(() => _emailBackupEnabled = v); _saveDebounced(); },
          emailBackupFrequency: _emailBackupFrequency,
          onEmailBackupFrequencyChanged: (v) { setState(() => _emailBackupFrequency = v); _saveDebounced(); },
          emailBackupHour: _emailBackupHour,
          onEmailBackupHourChanged: (v) { setState(() => _emailBackupHour = v); _saveDebounced(); },
          backupEmailRecipientCtrl: _backupEmailRecipientCtrl,
          smtpHostCtrl: _smtpHostCtrl,
          smtpPortCtrl: _smtpPortCtrl,
          smtpUserCtrl: _smtpUserCtrl,
          smtpPasswordCtrl: _smtpPasswordCtrl,
          onSaveDebounced: _saveDebounced,
          onTestEmail: _testEmailConn,
          onTestBackupEmail: _testEmailBackup,
          reportEmailEnabled: _reportEmailEnabled,
          onReportEmailEnabledChanged: (v) { setState(() => _reportEmailEnabled = v); _saveDebounced(); },
          stockAlertsEnabled: _stockAlertsEnabled,
          onStockAlertsEnabledChanged: (v) { setState(() => _stockAlertsEnabled = v); _saveDebounced(); },
          reportEmailFrequency: _reportEmailFrequency,
          onReportEmailFrequencyChanged: (v) { setState(() => _reportEmailFrequency = v); _saveDebounced(); },
          reportEmailHour: _reportEmailHour,
          onReportEmailHourChanged: (v) { setState(() => _reportEmailHour = v); _saveDebounced(); },
          reportEmailDayOfWeek: _reportEmailDayOfWeek,
          onReportEmailDayOfWeekChanged: (v) { setState(() => _reportEmailDayOfWeek = v); _saveDebounced(); },
          onTestReportEmail: _testReportEmail,
          marketingEmailsEnabled: _marketingEmailsEnabled,
          onMarketingEmailsEnabledChanged: (v) { setState(() => _marketingEmailsEnabled = v); _saveDebounced(); },
          inactivityReminderEnabled: _inactivityReminderEnabled,
          onInactivityReminderEnabledChanged: (v) { setState(() => _inactivityReminderEnabled = v); _saveDebounced(); },
          inactivityDaysThreshold: _inactivityDaysThreshold,
          onInactivityDaysThresholdChanged: (v) { setState(() => _inactivityDaysThreshold = v); _saveDebounced(); },
          onTestMarketingNewProduct: _testMarketingNewProduct,
          onTestMarketingInactivity: _testMarketingInactivity,
        );
      case 10: // Système & Réseau
        return SystemMaintenanceSection(
          daysRemaining: _daysRemaining ?? 0,
          onViewTos: _showTosDialog,
          onShowRecoveryKey: _showRecoveryKey,
          networkMode: _networkMode,
          onModeChanged: (NetworkMode? v) { if (v != null) { setState(() => _networkMode = v); _saveDebounced(); } },
          serverIpCtrl: _serverIpCtrl,
          serverPortCtrl: _serverPortCtrl,
          syncKeyCtrl: _syncKeyCtrl,
          onSaveDebounced: _saveDebounced,
          isAutoLockEnabled: _isAutoLockEnabled,
          onAutoLockEnabledChanged: (v) { setState(() => _isAutoLockEnabled = v); _saveDebounced(); },
          autoLockMinutesCtrl: _autoLockMinutesCtrl,
        );
      case 11: // Audit & Traçabilité
        return Column(
          children: [
             AuditSettingsSection(
                logs: _logs,
                onRefresh: _loadLogs,
             ),
          ],
        );
      case 12: // Design Interface
        return const AppearanceSettingsSection();
      case 13: // D+ Academy (Guide)
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 800, maxHeight: 1200),
          child: HelpScreen(embedded: true),
        );
      default:
        return const Center(child: Text("Module non implémenté"));
    }
  }

  Widget _buildResultStat(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (image == null) return;

    try {
      final appDir = await getApplicationSupportDirectory();
      await appDir.create(recursive: true);
      final fileName =
          'shop_logo_${DateTime.now().millisecondsSinceEpoch}${p_path.extension(image.path)}';
      final savedImage = File(p_path.join(appDir.path, fileName));
      await savedImage.writeAsBytes(await File(image.path).readAsBytes());

      setState(() {
        _logoPath = savedImage.path;
      });
    } catch (e) {
      _showToast("Erreur lors de l'enregistrement du logo: $e", Colors.red);
    }
  }

  Future<void> _removeLogo() async {
    final ok = await EnterpriseWidgets.showPremiumConfirmDialog(
      context,
      title: "Supprimer le logo",
      message: "Le logo sera retiré visuellement. Vous devrez Enregistrer pour confirmer.",
      isDestructive: true,
      onConfirm: () {},
    );
    if (ok == true && mounted) {
      setState(() {
        _logoPath = null;
      });
    }
  }

  Future<bool> _verifyAdminPin() async {
    final settings = ref.read(shopSettingsProvider).value;
    if (settings == null) return false;
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PinPadDialog(
        onVerify: (pin) async {
          // 1. Vérifier si c'est le PIN de sécurité boutique (si défini)
          if (settings.managerPin.isNotEmpty && pin == settings.managerPin) {
            return true;
          }
          // 2. Sinon, vérifier avec le compte administrateur système
          return await ref.read(authServiceProvider.notifier).verifyAdminPin(pin);
        },
        title: "Code Admin Requis",
      ),
    );
    return result ?? false;
  }

  Future<void> _backupDatabase() async {
    if (!await _verifyAdminPin()) return;
    
    final result = await ref.read(backupServiceProvider).exportDatabase();
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(result.success ? Icons.check_circle : Icons.error_outline,
                color: result.success ? Colors.green : Colors.red),
            const SizedBox(width: 10),
            Text(result.success ? 'Sauvegarde réussie' : 'Sauvegarde échouée',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          ],
        ),
        content: Text(result.message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreDatabase() async {
    // Demander confirmation avant restauration
    final confirmed = await EnterpriseWidgets.showPremiumConfirmDialog(
      context,
      title: "Restaurer la base de données",
      message: "⚠️ Cette opération remplacera TOUTES les données actuelles par celles du fichier sélectionné.\n\nL'application devra être redémarrée. Continuer ?",
      isDestructive: true,
      onConfirm: () {},
    );

    if (confirmed != true || !mounted) return;
    if (!await _verifyAdminPin()) return;

    final result = await ref.read(backupServiceProvider).importDatabase();
    if (!mounted) return;

    _showBackupResult(result);
  }

  Future<void> _restoreSpecificBackup(FileSystemEntity entity) async {
    if (entity is! File) return;
    
    final confirmed = await EnterpriseWidgets.showPremiumConfirmDialog(
      context,
      title: "Restaurer ce backup auto ?",
      message: "⚠️ Toutes les données actuelles seront remplacées par cette version du ${DateFormatter.formatDateTime(entity.statSync().modified)}.\\n\\nL'app devra redémarrer.",
      isDestructive: true,
      onConfirm: () {},
    );

    if (confirmed != true || !mounted) return;
    if (!await _verifyAdminPin()) return;

    final result = await ref.read(backupServiceProvider).restoreSpecificFile(entity);
    if (!mounted) return;

    _showBackupResult(result);
  }

  void _showBackupResult(BackupResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(result.success ? (result.filePath != null ? Icons.check_circle : Icons.restore) : Icons.error_outline,
                color: result.success ? (result.filePath != null ? Colors.green : Colors.orange) : Colors.red),
            const SizedBox(width: 10),
            Text(result.success ? (result.filePath != null ? 'Sauvegarde réussie' : 'Restauration réussie') : 'Échec de l\'opération',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          ],
        ),
        content: Text(result.message),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: result.success ? (result.filePath != null ? Colors.green : Colors.orange) : null),
            onPressed: () => Navigator.pop(context),
            child: Text(result.success ? (result.filePath != null ? 'OK' : 'OK — Je vais redémarrer') : 'Fermer',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _recalculateWac() async {
    final ok = await EnterpriseWidgets.showPremiumConfirmDialog(
      context,
      title: "Recalculer tous les CMUP ?",
      message: "Cette opération va reparcourir tout l'historique des achats pour corriger les Coûts Moyens Unitaires Pondérés de chaque produit.\n\nSouhaitez-vous continuer ?",
      onConfirm: () {},
    );

    if (ok != true) return;
    if (!await _verifyAdminPin()) return;

    _showToast("Recalcul en cours...", Colors.blue);
    try {
      await ref.read(maintenanceServiceProvider).recalculateAllWacs();
      if (mounted) {
        _showToast("CMUP recalculés avec succès !", Colors.green);
      }
    } catch (e) {
      if (mounted) {
        _showToast("Erreur lors du recalcul : $e", Colors.red);
      }
    }
  }

  Future<void> _cleanupImages() async {
    final ok = await EnterpriseWidgets.showPremiumConfirmDialog(
      context,
      title: "Nettoyer les images orphelines ?",
      message: "Cette action supprimera toutes les photos de produits sur le disque qui ne sont plus liées à aucun article en base de données.\n\nSouhaitez-vous continuer ?",
      onConfirm: () {},
    );

    if (ok != true) return;
    if (!await _verifyAdminPin()) return;

    _showToast("Nettoyage en cours...", Colors.blue);
    try {
      final count = await ref.read(maintenanceServiceProvider).cleanupOrphanImages();
      if (mounted) {
        _showToast("$count image(s) orpheline(s) supprimée(s) avec succès !", Colors.green);
      }
    } catch (e) {
      if (mounted) {
        _showToast("Erreur lors du nettoyage : $e", Colors.red);
      }
    }
  }

  Future<void> _confirmResetDb() async {
    final ok = await EnterpriseWidgets.showPremiumConfirmDialog(
      context,
      title: "Réinitialisation Partielle",
      message:
          "Voulez-vous vraiment effacer l'historique des ventes et les dettes ? Les articles seront conservés.",
      isDestructive: true,
      onConfirm: () {},
    );

    if (ok != true) return;
    if (!await _verifyAdminPin()) return;

    if (true) {
      try {
        final db = await ref.read(databaseServiceProvider).database;
        await db.transaction((txn) async {
          await txn.delete('sales');
          await txn.delete('sale_items');
          await txn.delete('financial_transactions');
          await txn.delete('stock_movements');
          // Reset client balances and purchases
          await txn.update('clients', {
            'total_purchases': 0,
            'total_spent': 0,
            'credit': 0,
          });
          // Note: Stock levels are NOT reset here as requested (efface ventes/dettes, garde articles)
        });

        ref.invalidate(todaySalesProvider);
        ref.invalidate(totalSalesCountProvider);

        if (mounted) {
          _showToast(
            "Base de données réinitialisée partiellement.",
            Colors.orange,
          );
        }
      } catch (e) {
        if (mounted) {
          _showToast("Erreur lors de la réinitialisation: $e", Colors.red);
        }
      }
    }
  }

  Future<void> _testPrint(String? printerName, String type) async {
    if (printerName == null) {
      _showToast("Aucune imprimante sélectionnée pour le test.", Colors.orange);
      return;
    }

    try {
      final font = PdfResourceService.instance.regular;
      final fontBold = PdfResourceService.instance.bold;
      final doc = pw.Document(
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
        ),
      );
      doc.addPage(
        pw.Page(
          pageFormat: type == 'ticket' ? PdfPageFormat.roll80 : PdfPageFormat.a4,
          build: (ctx) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text("TEST D'IMPRESSION - DANAYA PLUS",
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 16)),
                pw.SizedBox(height: 20),
                pw.Text("Type: ${type.toUpperCase()}"),
                pw.Text("Imprimante: $printerName"),
                pw.Text("Date: ${DateTime.now().toString()}"),
                pw.SizedBox(height: 20),
                pw.BarcodeWidget(
                  data: "DANAYAPLUS-TEST",
                  barcode: pw.Barcode.ean13(),
                  width: 100,
                  height: 50,
                ),
              ],
            ),
          ),
        ),
      );

      await Printing.directPrintPdf(
        printer: Printer(url: printerName, name: printerName),
        onLayout: (format) => doc.save(),
      );

      if (mounted) _showToast("Test d'impression envoyé à $printerName", Colors.green);
    } catch (e) {
      if (mounted) _showToast("Erreur lors du test: $e", Colors.red);
    }
  }

  Future<void> _testCashDrawer(String? printerName) async {
    if (printerName == null) {
      _showToast("Aucune imprimante sélectionnée pour le test du tiroir.", Colors.orange);
      return;
    }

    try {
      await ref.read(hardwareServiceProvider).kickDrawer(printerName);
      if (mounted) _showToast("Impulsion d'ouverture envoyée à $printerName", Colors.blue);
    } catch (e) {
      if (mounted) _showToast("Erreur lors du test du tiroir: $e", Colors.red);
    }
  }
}
