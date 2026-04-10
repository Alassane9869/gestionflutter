import 'package:flutter/foundation.dart';

enum ReferenceGenerationModel {
  categorical, // PREFIX-CAT-001
  timestamp, // REF-123456
  sequential, // REF-0001
  random, // REF-A1B2
}

enum BarcodeGenerationModel {
  ean13, // 200 + Timestamp + Checksum
  upcA, // 0 + Timestamp + Checksum
  code128, // Alphanumeric Random
  numeric9, // 9 Digit Sequential
}

enum ThermalPaperFormat {
  mm58, // Standard portable (160 pts)
  mm80, // Desktop wide (226 pts)
}

enum LabelPrintingFormat {
  a4Sheets, // Planches A4 (3 colonnes)
  singleLabel, // Étiquettes individuelles (Rouleau/Thermique)
}

enum NetworkMode { solo, server, client }

enum RoundingMode {
  none, // Pas d'arrondi (ex: 123.45)
  nearest5, // Arrondi à 5 près (ex: 120, 125, 130)
  nearest10, // Arrondi à 10 près
  nearest25, // Arrondi à 25 près
  nearest50, // Arrondi à 50 près
  nearest100, // Arrondi à 100 près
}

enum EmailBackupFrequency { daily, weekly, monthly }

enum AssistantPowerLevel {
  basic, // Niveau 1 : Recherche & Navigation
  analytical, // Niveau 2 : Analyses & Stats
  actionable, // Niveau 3 : Contrôle direct
  proactive, // Niveau 4 : Alertes & Surveillance
  titan, // Niveau 5 : Stratégie & Apprentissage
}

enum ReceiptTemplate { classic, modern, minimal, elite, prestige }

enum InvoiceTemplate {
  corporate,
  elegant,
  clean,
  noirEtBlanc,
  minimaliste,
  epure,
  style,
  prestige,
}

enum QuoteTemplate {
  minimaliste,
  style,
  prestige,
  modern,
  professional,
  clean,
  minimalist,
  corporate,
  supreme,
}

enum PurchaseOrderTemplate {
  classic,
  modern,
  professional,
  clean,
  compact,
  supreme,
}

@immutable
class ShopSettings {
  final String name;
  final String slogan;
  final String phone;
  final String whatsapp;
  final String address;
  final String email;
  final String rc;
  final String nif;
  final String bankAccount;
  final String currency;
  final bool removeDecimals;
  final ReceiptTemplate defaultReceipt;
  final InvoiceTemplate defaultInvoice;
  final QuoteTemplate defaultQuote;
  final PurchaseOrderTemplate defaultPurchaseOrder;
  final ThermalPaperFormat thermalFormat;
  final String receiptFooter;
  final String? logoPath;
  final LabelPrintingFormat labelFormat;
  final double labelWidth;
  final double labelHeight;
  final String taxName;
  final double taxRate;
  final bool useTax;
  final bool showQrCode;
  final List<String> paymentMethods;
  final bool isConfigured;
  final bool useAutoRef;
  final String refPrefix;
  final ReferenceGenerationModel refModel;
  final BarcodeGenerationModel barcodeModel;
  final bool autoBackupEnabled;
  final DateTime? lastAutoBackup;
  final String legalForm;
  final String capital;
  final String policyWarranty;
  final String policyReturns;
  final String policyPayments;
  final int quoteValidityDays;
  final String invoiceLegalNote;

  final String? thermalPrinterName;
  final String? invoicePrinterName;
  final String? quotePrinterName;
  final String? purchaseOrderPrinterName;
  final String? labelPrinterName;
  final String? contractPrinterName;
  final String? payrollPrinterName;
  final String? reportPrinterName;
  final String? proformaPrinterName;
  final String? deliveryPrinterName;

  final bool autoPrintTicket;
  final bool showPreviewBeforePrint;
  final bool autoPrintDeliveryNote;

  final bool showPriceOnLabels;
  final bool showNameOnLabels;
  final bool showSkuOnLabels;
  final bool autoPrintLabelsOnStockIn;
  final bool directPhysicalPrinting;
  final bool openCashDrawer;

  final String managerPin;
  final double maxDiscountThreshold;
  final double vipThreshold;
  final bool loyaltyEnabled;
  final double pointsPerAmount;
  final double amountPerPoint;

  final bool showAssistant;
  final NetworkMode networkMode;
  final String serverIp;
  final int serverPort;
  final String customerDisplayTheme;
  final String syncKey;
  final RoundingMode roundingMode;
  final List<String> customerDisplayMessages;
  final bool enableCustomerDisplayTicker;
  final Map<String, bool>? _templateFiscalSettings; // Stockage interne
  Map<String, bool> get templateFiscalSettings => _templateFiscalSettings ?? const {};

  final String labelHT;
  final String labelTTC;
  final String titleInvoice;
  final String titleReceipt;
  final String titleReceiptProforma;
  final String titleQuote;
  final String titleProforma;
  final String titleDeliveryNote;

  final double marginTicketTop;
  final double marginTicketBottom;
  final double marginTicketLeft;
  final double marginTicketRight;

  final double marginInvoiceTop;
  final double marginInvoiceBottom;
  final double marginInvoiceLeft;
  final double marginInvoiceRight;

  final double marginLabelX;
  final double marginLabelY;

  final String? cloudBackupPath;

  final bool emailBackupEnabled;
  final String backupEmailRecipient;
  final String smtpHost;
  final int smtpPort;
  final String smtpUser;
  final String smtpPassword;
  final DateTime? lastEmailBackup;
  final EmailBackupFrequency emailBackupFrequency;
  final int emailBackupHour;

  // Envoi automatique de rapports
  final bool reportEmailEnabled;
  final bool stockAlertsEnabled;
  final EmailBackupFrequency reportEmailFrequency;
  final int reportEmailHour;
  final int reportEmailDayOfWeek; // 1-7 (Lundi-Dimanche)
  final DateTime? lastReportEmailDate;

  final bool acceptedTos;
  final DateTime? tosAcceptedAt;

  final bool marketingEmailsEnabled;
  final bool inactivityReminderEnabled;
  final int inactivityDaysThreshold;
  final bool enableSounds;
  final bool enableAppSounds;
  final bool enableCustomerDisplaySounds;
  final bool useCustomerDisplay3D;
  final bool hrShowSignatureLines;
  final AssistantPowerLevel assistantLevel;

  // Audit Extreme : Auto-Lock Security
  final bool isAutoLockEnabled;
  final int autoLockMinutes;

  final bool isAiEnabled;
  final bool isVoiceEnabled;

  // Granular Tax Control
  final bool showTaxOnTickets;
  final bool showTaxOnInvoices;
  final bool showTaxOnQuotes;
  final bool useDetailedTaxOnTickets;
  final bool useDetailedTaxOnInvoices;
  final bool useDetailedTaxOnQuotes;
  final bool showTaxOnDeliveryNotes;
  final bool useDetailedTaxOnDeliveryNotes;

  const ShopSettings({
    this.name = 'Danaya+',
    this.slogan = '',
    this.phone = '',
    this.whatsapp = '',
    this.address = '',
    this.email = '',
    this.rc = '',
    this.nif = '',
    this.bankAccount = '',
    this.currency = 'FCFA',
    this.removeDecimals = true,
    this.defaultReceipt = ReceiptTemplate.modern,
    this.defaultInvoice = InvoiceTemplate.clean,
    this.defaultQuote = QuoteTemplate.prestige,
    this.defaultPurchaseOrder = PurchaseOrderTemplate.professional,
    this.thermalFormat = ThermalPaperFormat.mm58,
    this.receiptFooter = 'Merci de votre visite et à bientôt !',
    this.logoPath,
    this.labelFormat = LabelPrintingFormat.singleLabel,
    this.labelWidth = 50.0,
    this.labelHeight = 30.0,
    this.taxName = 'TVA',
    this.taxRate = 18.0,
    this.useTax = false,
    this.showQrCode = true,
    this.paymentMethods = const ['Espèces', 'Mobile Money', 'Wave', 'Chèque'],
    this.isConfigured = false,
    this.useAutoRef = false,
    this.refPrefix = 'REF',
    this.refModel = ReferenceGenerationModel.timestamp,
    this.barcodeModel = BarcodeGenerationModel.ean13,
    this.autoBackupEnabled = true,
    this.lastAutoBackup,
    this.legalForm = '',
    this.capital = '',
    this.policyWarranty = '',
    this.policyReturns = '',
    this.policyPayments = '',
    this.quoteValidityDays = 30,
    this.invoiceLegalNote = '',
    this.thermalPrinterName,
    this.invoicePrinterName,
    this.quotePrinterName,
    this.purchaseOrderPrinterName,
    this.labelPrinterName,
    this.contractPrinterName,
    this.payrollPrinterName,
    this.reportPrinterName,
    this.proformaPrinterName,
    this.deliveryPrinterName,
    this.autoPrintTicket = false,
    this.showPreviewBeforePrint = true,
    this.autoPrintDeliveryNote = false,
    this.showPriceOnLabels = true,
    this.showNameOnLabels = true,
    this.showSkuOnLabels = false,
    this.autoPrintLabelsOnStockIn = false,
    this.directPhysicalPrinting = false,
    this.openCashDrawer = false,
    this.managerPin = '0000',
    this.maxDiscountThreshold = 10.0,
    this.vipThreshold = 1000000.0,
    this.loyaltyEnabled = true,
    this.pointsPerAmount = 1000.0,
    this.amountPerPoint = 10.0,
    this.showAssistant = true,
    this.networkMode = NetworkMode.solo,
    this.serverIp = '',
    this.serverPort = 8080,
    this.customerDisplayTheme = 'theme-luxury',
    this.roundingMode = RoundingMode.none,
    this.marginTicketTop = 5.0,
    this.marginTicketBottom = 5.0,
    this.marginTicketLeft = 5.0,
    this.marginTicketRight = 5.0,
    this.marginInvoiceTop = 20.0,
    this.marginInvoiceBottom = 20.0,
    this.marginInvoiceLeft = 20.0,
    this.marginInvoiceRight = 20.0,
    this.marginLabelX = 0.0,
    this.marginLabelY = 0.0,
    this.cloudBackupPath,
    this.emailBackupEnabled = false,
    this.backupEmailRecipient = '',
    this.smtpHost = 'smtp.gmail.com',
    this.smtpPort = 587,
    this.smtpUser = '',
    this.smtpPassword = '',
    this.lastEmailBackup,
    this.emailBackupFrequency = EmailBackupFrequency.weekly,
    this.emailBackupHour = 22,
    this.reportEmailEnabled = false,
    this.stockAlertsEnabled = false,
    this.reportEmailFrequency = EmailBackupFrequency.daily,
    this.reportEmailHour = 20,
    this.reportEmailDayOfWeek = 1,
    this.lastReportEmailDate,
    this.acceptedTos = false,
    this.tosAcceptedAt,
    this.marketingEmailsEnabled = false,
    this.inactivityReminderEnabled = false,
    this.inactivityDaysThreshold = 30,
    this.enableSounds = true,
    this.enableAppSounds = true,
    this.enableCustomerDisplaySounds = true,
    this.useCustomerDisplay3D = false,
    this.syncKey = '',
    Map<String, bool>? templateFiscalSettings = const <String, bool>{},
    this.labelHT = 'TOTAL H.T.',
    this.labelTTC = 'TOTAL TTC',
    this.titleInvoice = 'FACTURE',
    this.titleReceipt = 'TICKET DE CAISSE',
    this.titleReceiptProforma = 'TICKET PROFORMA',
    this.titleQuote = 'DEVIS',
    this.titleProforma = 'FACTURE PROFORMA',
    this.titleDeliveryNote = 'BON DE LIVRAISON',
    this.hrShowSignatureLines = true,
    this.assistantLevel = AssistantPowerLevel.basic,
    this.customerDisplayMessages = const [
      '✨ BIENVENUE ✨',
      '🔥 NOUVELLE COLLECTION DISPONIBLE 🔥',
      '💎 PRODUITS DE HAUTE QUALITÉ 💎',
      '⚡ SERVICE RAPIDE & PROFESSIONNEL ⚡',
      '🌟 MERCI DE VOTRE FIDÉLITÉ 🌟',
    ],
    this.enableCustomerDisplayTicker = true,
    this.isAutoLockEnabled = false,
    this.autoLockMinutes = 5,
    this.isAiEnabled = true,
    this.isVoiceEnabled = false,
    this.showTaxOnTickets = true,
    this.showTaxOnInvoices = true,
    this.showTaxOnQuotes = true,
    this.useDetailedTaxOnTickets = false,
    this.useDetailedTaxOnInvoices = true,
    this.useDetailedTaxOnQuotes = true,
    this.showTaxOnDeliveryNotes = true,
    this.useDetailedTaxOnDeliveryNotes = false,
  }) : _templateFiscalSettings = templateFiscalSettings;


  ShopSettings copyWith({
    String? name,
    String? slogan,
    String? phone,
    String? whatsapp,
    String? address,
    String? email,
    String? rc,
    String? nif,
    String? bankAccount,
    String? currency,
    bool? removeDecimals,
    ReceiptTemplate? defaultReceipt,
    InvoiceTemplate? defaultInvoice,
    QuoteTemplate? defaultQuote,
    PurchaseOrderTemplate? defaultPurchaseOrder,
    ThermalPaperFormat? thermalFormat,
    String? receiptFooter,
    String? logoPath,
    LabelPrintingFormat? labelFormat,
    double? labelWidth,
    double? labelHeight,
    String? taxName,
    double? taxRate,
    bool? useTax,
    bool? showQrCode,
    List<String>? paymentMethods,
    bool? isConfigured,
    bool? useAutoRef,
    String? refPrefix,
    ReferenceGenerationModel? refModel,
    BarcodeGenerationModel? barcodeModel,
    bool? autoBackupEnabled,
    DateTime? lastAutoBackup,
    String? legalForm,
    String? capital,
    String? policyWarranty,
    String? policyReturns,
    String? policyPayments,
    int? quoteValidityDays,
    String? invoiceLegalNote,
    String? thermalPrinterName,
    String? invoicePrinterName,
    String? quotePrinterName,
    String? purchaseOrderPrinterName,
    String? labelPrinterName,
    String? contractPrinterName,
    String? payrollPrinterName,
    String? reportPrinterName,
    String? proformaPrinterName,
    String? deliveryPrinterName,
    bool? autoPrintTicket,
    bool? showPreviewBeforePrint,
    bool? autoPrintDeliveryNote,
    bool? showPriceOnLabels,
    bool? showNameOnLabels,
    bool? showSkuOnLabels,
    bool? autoPrintLabelsOnStockIn,
    bool? directPhysicalPrinting,
    bool? openCashDrawer,
    String? managerPin,
    double? maxDiscountThreshold,
    double? vipThreshold,
    bool? loyaltyEnabled,
    double? pointsPerAmount,
    double? amountPerPoint,
    bool? showAssistant,
    NetworkMode? networkMode,
    String? serverIp,
    int? serverPort,
    String? customerDisplayTheme,
    RoundingMode? roundingMode,
    double? marginTicketTop,
    double? marginTicketBottom,
    double? marginTicketLeft,
    double? marginTicketRight,
    double? marginInvoiceTop,
    double? marginInvoiceBottom,
    double? marginInvoiceLeft,
    double? marginInvoiceRight,
    double? marginLabelX,
    double? marginLabelY,
    String? cloudBackupPath,
    bool? emailBackupEnabled,
    String? backupEmailRecipient,
    String? smtpHost,
    int? smtpPort,
    String? smtpUser,
    String? smtpPassword,
    DateTime? lastEmailBackup,
    EmailBackupFrequency? emailBackupFrequency,
    int? emailBackupHour,
    bool? reportEmailEnabled,
    bool? stockAlertsEnabled,
    EmailBackupFrequency? reportEmailFrequency,
    int? reportEmailHour,
    int? reportEmailDayOfWeek,
    DateTime? lastReportEmailDate,
    bool? acceptedTos,
    DateTime? tosAcceptedAt,
    bool? marketingEmailsEnabled,
    bool? inactivityReminderEnabled,
    int? inactivityDaysThreshold,
    bool? enableSounds,
    bool? enableAppSounds,
    bool? enableCustomerDisplaySounds,
    bool? useCustomerDisplay3D,
    bool? hrShowSignatureLines,
    String? syncKey,
    AssistantPowerLevel? assistantLevel,
    List<String>? customerDisplayMessages,
    bool? enableCustomerDisplayTicker,
    bool? isAutoLockEnabled,
    int? autoLockMinutes,
    bool? isAiEnabled,
    bool? isVoiceEnabled,
    Map<String, bool>? templateFiscalSettings,
    String? labelHT,
    String? labelTTC,
    String? titleInvoice,
    String? titleReceipt,
    String? titleReceiptProforma,
    String? titleQuote,
    String? titleProforma,
    String? titleDeliveryNote,
    bool? showTaxOnTickets,
    bool? showTaxOnInvoices,
    bool? showTaxOnQuotes,
    bool? useDetailedTaxOnTickets,
    bool? useDetailedTaxOnInvoices,
    bool? useDetailedTaxOnQuotes,
    bool? showTaxOnDeliveryNotes,
    bool? useDetailedTaxOnDeliveryNotes,
  }) {
    return ShopSettings(
      name: name ?? this.name,
      slogan: slogan ?? this.slogan,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      address: address ?? this.address,
      email: email ?? this.email,
      rc: rc ?? this.rc,
      nif: nif ?? this.nif,
      bankAccount: bankAccount ?? this.bankAccount,
      currency: currency ?? this.currency,
      removeDecimals: removeDecimals ?? this.removeDecimals,
      defaultReceipt: defaultReceipt ?? this.defaultReceipt,
      defaultInvoice: defaultInvoice ?? this.defaultInvoice,
      defaultQuote: defaultQuote ?? this.defaultQuote,
      defaultPurchaseOrder: defaultPurchaseOrder ?? this.defaultPurchaseOrder,
      thermalFormat: thermalFormat ?? this.thermalFormat,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      logoPath: logoPath ?? this.logoPath,
      labelFormat: labelFormat ?? this.labelFormat,
      labelWidth: labelWidth ?? this.labelWidth,
      labelHeight: labelHeight ?? this.labelHeight,
      taxName: taxName ?? this.taxName,
      taxRate: taxRate ?? this.taxRate,
      useTax: useTax ?? this.useTax,
      showQrCode: showQrCode ?? this.showQrCode,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      isConfigured: isConfigured ?? this.isConfigured,
      useAutoRef: useAutoRef ?? this.useAutoRef,
      refPrefix: refPrefix ?? this.refPrefix,
      refModel: refModel ?? this.refModel,
      barcodeModel: barcodeModel ?? this.barcodeModel,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      lastAutoBackup: lastAutoBackup ?? this.lastAutoBackup,
      legalForm: legalForm ?? this.legalForm,
      capital: capital ?? this.capital,
      policyWarranty: policyWarranty ?? this.policyWarranty,
      policyReturns: policyReturns ?? this.policyReturns,
      policyPayments: policyPayments ?? this.policyPayments,
      quoteValidityDays: quoteValidityDays ?? this.quoteValidityDays,
      invoiceLegalNote: invoiceLegalNote ?? this.invoiceLegalNote,
      thermalPrinterName: thermalPrinterName ?? this.thermalPrinterName,
      invoicePrinterName: invoicePrinterName ?? this.invoicePrinterName,
      quotePrinterName: quotePrinterName ?? this.quotePrinterName,
      purchaseOrderPrinterName:
          purchaseOrderPrinterName ?? this.purchaseOrderPrinterName,
      labelPrinterName: labelPrinterName ?? this.labelPrinterName,
      contractPrinterName: contractPrinterName ?? this.contractPrinterName,
      payrollPrinterName: payrollPrinterName ?? this.payrollPrinterName,
      reportPrinterName: reportPrinterName ?? this.reportPrinterName,
      proformaPrinterName: proformaPrinterName ?? this.proformaPrinterName,
      deliveryPrinterName: deliveryPrinterName ?? this.deliveryPrinterName,
      autoPrintTicket: autoPrintTicket ?? this.autoPrintTicket,
      showPreviewBeforePrint:
          showPreviewBeforePrint ?? this.showPreviewBeforePrint,
      autoPrintDeliveryNote:
          autoPrintDeliveryNote ?? this.autoPrintDeliveryNote,
      showPriceOnLabels: showPriceOnLabels ?? this.showPriceOnLabels,
      showNameOnLabels: showNameOnLabels ?? this.showNameOnLabels,
      showSkuOnLabels: showSkuOnLabels ?? this.showSkuOnLabels,
      autoPrintLabelsOnStockIn:
          autoPrintLabelsOnStockIn ?? this.autoPrintLabelsOnStockIn,
      directPhysicalPrinting:
          directPhysicalPrinting ?? this.directPhysicalPrinting,
      openCashDrawer: openCashDrawer ?? this.openCashDrawer,
      managerPin: managerPin ?? this.managerPin,
      maxDiscountThreshold: maxDiscountThreshold ?? this.maxDiscountThreshold,
      vipThreshold: vipThreshold ?? this.vipThreshold,
      loyaltyEnabled: loyaltyEnabled ?? this.loyaltyEnabled,
      pointsPerAmount: pointsPerAmount ?? this.pointsPerAmount,
      amountPerPoint: amountPerPoint ?? this.amountPerPoint,
      showAssistant: showAssistant ?? this.showAssistant,
      networkMode: networkMode ?? this.networkMode,
      serverIp: serverIp ?? this.serverIp,
      serverPort: serverPort ?? this.serverPort,
      customerDisplayTheme: customerDisplayTheme ?? this.customerDisplayTheme,
      roundingMode: roundingMode ?? this.roundingMode,
      marginTicketTop: marginTicketTop ?? this.marginTicketTop,
      marginTicketBottom: marginTicketBottom ?? this.marginTicketBottom,
      marginTicketLeft: marginTicketLeft ?? this.marginTicketLeft,
      marginTicketRight: marginTicketRight ?? this.marginTicketRight,
      marginInvoiceTop: marginInvoiceTop ?? this.marginInvoiceTop,
      marginInvoiceBottom: marginInvoiceBottom ?? this.marginInvoiceBottom,
      marginInvoiceLeft: marginInvoiceLeft ?? this.marginInvoiceLeft,
      marginInvoiceRight: marginInvoiceRight ?? this.marginInvoiceRight,
      marginLabelX: marginLabelX ?? this.marginLabelX,
      marginLabelY: marginLabelY ?? this.marginLabelY,
      cloudBackupPath: cloudBackupPath ?? this.cloudBackupPath,
      emailBackupEnabled: emailBackupEnabled ?? this.emailBackupEnabled,
      backupEmailRecipient: backupEmailRecipient ?? this.backupEmailRecipient,
      smtpHost: smtpHost ?? this.smtpHost,
      smtpPort: smtpPort ?? this.smtpPort,
      smtpUser: smtpUser ?? this.smtpUser,
      smtpPassword: smtpPassword ?? this.smtpPassword,
      lastEmailBackup: lastEmailBackup ?? this.lastEmailBackup,
      emailBackupFrequency: emailBackupFrequency ?? this.emailBackupFrequency,
      emailBackupHour: emailBackupHour ?? this.emailBackupHour,
      reportEmailEnabled: reportEmailEnabled ?? this.reportEmailEnabled,
      stockAlertsEnabled: stockAlertsEnabled ?? this.stockAlertsEnabled,
      reportEmailFrequency: reportEmailFrequency ?? this.reportEmailFrequency,
      reportEmailHour: reportEmailHour ?? this.reportEmailHour,
      reportEmailDayOfWeek: reportEmailDayOfWeek ?? this.reportEmailDayOfWeek,
      lastReportEmailDate: lastReportEmailDate ?? this.lastReportEmailDate,
      acceptedTos: acceptedTos ?? this.acceptedTos,
      tosAcceptedAt: tosAcceptedAt ?? this.tosAcceptedAt,
      marketingEmailsEnabled:
          marketingEmailsEnabled ?? this.marketingEmailsEnabled,
      inactivityReminderEnabled:
          inactivityReminderEnabled ?? this.inactivityReminderEnabled,
      inactivityDaysThreshold:
          inactivityDaysThreshold ?? this.inactivityDaysThreshold,
      enableSounds: enableSounds ?? this.enableSounds,
      enableAppSounds: enableAppSounds ?? this.enableAppSounds,
      enableCustomerDisplaySounds:
          enableCustomerDisplaySounds ?? this.enableCustomerDisplaySounds,
      useCustomerDisplay3D: useCustomerDisplay3D ?? this.useCustomerDisplay3D,
      hrShowSignatureLines: hrShowSignatureLines ?? this.hrShowSignatureLines,
      syncKey: syncKey ?? this.syncKey,
      assistantLevel: assistantLevel ?? this.assistantLevel,
      customerDisplayMessages:
          customerDisplayMessages ?? this.customerDisplayMessages,
      enableCustomerDisplayTicker:
          enableCustomerDisplayTicker ?? this.enableCustomerDisplayTicker,
      isAutoLockEnabled: isAutoLockEnabled ?? this.isAutoLockEnabled,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      isAiEnabled: isAiEnabled ?? this.isAiEnabled,
      isVoiceEnabled: isVoiceEnabled ?? this.isVoiceEnabled,
      templateFiscalSettings:
          templateFiscalSettings ?? this.templateFiscalSettings,
      labelHT: labelHT ?? this.labelHT,
      labelTTC: labelTTC ?? this.labelTTC,
      titleInvoice: titleInvoice ?? this.titleInvoice,
      titleReceipt: titleReceipt ?? this.titleReceipt,
      titleReceiptProforma: titleReceiptProforma ?? this.titleReceiptProforma,
      titleQuote: titleQuote ?? this.titleQuote,
      titleProforma: titleProforma ?? this.titleProforma,
      titleDeliveryNote: titleDeliveryNote ?? this.titleDeliveryNote,
      showTaxOnTickets: showTaxOnTickets ?? this.showTaxOnTickets,
      showTaxOnInvoices: showTaxOnInvoices ?? this.showTaxOnInvoices,
      showTaxOnQuotes: showTaxOnQuotes ?? this.showTaxOnQuotes,
      useDetailedTaxOnTickets:
          useDetailedTaxOnTickets ?? this.useDetailedTaxOnTickets,
      useDetailedTaxOnInvoices:
          useDetailedTaxOnInvoices ?? this.useDetailedTaxOnInvoices,
      useDetailedTaxOnQuotes:
          useDetailedTaxOnQuotes ?? this.useDetailedTaxOnQuotes,
      showTaxOnDeliveryNotes:
          showTaxOnDeliveryNotes ?? this.showTaxOnDeliveryNotes,
      useDetailedTaxOnDeliveryNotes:
          useDetailedTaxOnDeliveryNotes ?? this.useDetailedTaxOnDeliveryNotes,
    );
  }

  // --- Helper Methods for Elite Matrix ---
  bool getTemplateShowTax(String type, String template) {
    final key = "${type}_${template}_show";
    return templateFiscalSettings[key] ?? _getGlobalDefaultShow(type);
  }

  bool getTemplateDetailed(String type, String template) {
    final key = "${type}_${template}_detailed";
    return templateFiscalSettings[key] ?? _getGlobalDefaultDetailed(type);
  }

  bool _getGlobalDefaultShow(String type) {
    if (type == 'invoice') return showTaxOnInvoices;
    if (type == 'ticket') return showTaxOnTickets;
    if (type == 'quote') return showTaxOnQuotes;
    if (type == 'delivery') return showTaxOnDeliveryNotes;
    return useTax;
  }

  bool _getGlobalDefaultDetailed(String type) {
    if (type == 'invoice') return useDetailedTaxOnInvoices;
    if (type == 'ticket') return useDetailedTaxOnTickets;
    if (type == 'quote') return useDetailedTaxOnQuotes;
    if (type == 'delivery') return useDetailedTaxOnDeliveryNotes;
    return false;
  }
}
