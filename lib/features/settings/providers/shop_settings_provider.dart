import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:danaya_plus/features/settings/domain/models/shop_settings_models.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:danaya_plus/core/network/server_service.dart';
import 'package:danaya_plus/core/services/pdf_resource_service.dart';

export 'package:danaya_plus/features/settings/domain/models/shop_settings_models.dart';

class ShopSettingsNotifier extends AsyncNotifier<ShopSettings> {
  static const _prefix = 'shop_v2_';

  @override
  Future<ShopSettings> build() async {
    final p = await SharedPreferences.getInstance();
    // managerPin (removed secure storage use)
    String? pin = p.getString('${_prefix}managerPin') ?? '0000';

    // Audit Correction: Auto-hash legacy 4-digit PINs on build for safety
    if (pin.length == 4) {
      final hashed = sha256.convert(utf8.encode("${pin}danaya_manager_pepper_2024")).toString();
      p.setString('${_prefix}managerPin', hashed);
      pin = hashed;
    }

    // smtpPassword (removed secure storage use)
    String? smtpPass = p.getString('${_prefix}smtpPassword') ?? '';

    return ShopSettings(
      name: p.getString('${_prefix}name') ?? p.getString('shop_name') ?? 'Danaya+',
      slogan: p.getString('${_prefix}slogan') ?? '',
      phone: p.getString('${_prefix}phone') ?? p.getString('shop_phone') ?? '',
      whatsapp: p.getString('${_prefix}whatsapp') ?? '',
      address: p.getString('${_prefix}address') ?? p.getString('shop_address') ?? '',
      email: p.getString('${_prefix}email') ?? p.getString('shop_email') ?? '',
      rc: p.getString('${_prefix}rc') ?? p.getString('shop_rc') ?? '',
      nif: p.getString('${_prefix}nif') ?? '',
      bankAccount: p.getString('${_prefix}bankAccount') ?? '',
      currency: p.getString('${_prefix}currency') ?? p.getString('shop_currency') ?? 'FCFA',
      removeDecimals: p.getBool('${_prefix}removeDecimals') ?? true,
      defaultReceipt: ReceiptTemplate.values[p.getInt('${_prefix}receipt') ?? p.getInt('shop_receipt') ?? ReceiptTemplate.modern.index],
      defaultInvoice: InvoiceTemplate.values[p.getInt('${_prefix}invoice') ?? p.getInt('shop_invoice') ?? InvoiceTemplate.clean.index],
      defaultQuote: QuoteTemplate.values[p.getInt('${_prefix}quote') ?? QuoteTemplate.prestige.index],
      defaultPurchaseOrder: PurchaseOrderTemplate.values[p.getInt('${_prefix}purchaseOrder') ?? PurchaseOrderTemplate.professional.index],
      thermalFormat: ThermalPaperFormat.values[p.getInt('${_prefix}thermalFormat') ?? ThermalPaperFormat.mm58.index],
      receiptFooter: p.getString('${_prefix}receiptFooter') ?? 'Merci de votre visite et à bientôt !',
      logoPath: p.getString('${_prefix}logoPath'),
      labelFormat: LabelPrintingFormat.values[p.getInt('${_prefix}labelFormat') ?? 0],
      labelWidth: p.getDouble('${_prefix}labelWidth') ?? 50.0,
      labelHeight: p.getDouble('${_prefix}labelHeight') ?? 30.0,
      taxName: p.getString('${_prefix}taxName') ?? 'TVA',
      taxRate: p.getDouble('${_prefix}taxRate') ?? 18.0,
      useTax: p.getBool('${_prefix}useTax') ?? false,
      showQrCode: p.getBool('${_prefix}showQrCode') ?? true,
      paymentMethods: p.getStringList('${_prefix}paymentMethods') ?? ['Espèces', 'Mobile Money', 'Wave', 'Chèque'],
      isConfigured: p.getBool('${_prefix}isConfigured') ?? false,
      useAutoRef: p.getBool('${_prefix}useAutoRef') ?? false,
      refPrefix: p.getString('${_prefix}refPrefix') ?? 'REF',
      refModel: ReferenceGenerationModel.values[p.getInt('${_prefix}refModel') ?? 1],
      barcodeModel: BarcodeGenerationModel.values[p.getInt('${_prefix}barcodeModel') ?? 0],
      autoBackupEnabled: p.getBool('${_prefix}autoBackupEnabled') ?? true,
      lastAutoBackup: p.getString('${_prefix}lastAutoBackup') != null ? DateTime.tryParse(p.getString('${_prefix}lastAutoBackup')!) : null,
      legalForm: p.getString('${_prefix}legalForm') ?? '',
      capital: p.getString('${_prefix}capital') ?? '',
      policyWarranty: p.getString('${_prefix}policyWarranty') ?? '',
      policyReturns: p.getString('${_prefix}policyReturns') ?? '',
      policyPayments: p.getString('${_prefix}policyPayments') ?? '',
      quoteValidityDays: p.getInt('${_prefix}quoteValidityDays') ?? 30,
      invoiceLegalNote: p.getString('${_prefix}invoiceLegalNote') ?? '',
      thermalPrinterName: p.getString('${_prefix}thermalPrinterName'),
      invoicePrinterName: p.getString('${_prefix}invoicePrinterName'),
      quotePrinterName: p.getString('${_prefix}quotePrinterName'),
      purchaseOrderPrinterName: p.getString('${_prefix}purchaseOrderPrinterName'),
      labelPrinterName: p.getString('${_prefix}labelPrinterName'),
      contractPrinterName: p.getString('${_prefix}contractPrinterName'),
      payrollPrinterName: p.getString('${_prefix}payrollPrinterName'),
      reportPrinterName: p.getString('${_prefix}reportPrinterName'),
      autoPrintTicket: p.getBool('${_prefix}autoPrintTicket') ?? false,
      showPreviewBeforePrint: p.getBool('${_prefix}showPreviewBeforePrint') ?? true,
      showPriceOnLabels: p.getBool('${_prefix}showPriceOnLabels') ?? true,
      showNameOnLabels: p.getBool('${_prefix}showNameOnLabels') ?? true,
      showSkuOnLabels: p.getBool('${_prefix}showSkuOnLabels') ?? false,
      autoPrintLabelsOnStockIn: p.getBool('${_prefix}autoPrintLabelsOnStockIn') ?? false,
      directPhysicalPrinting: p.getBool('${_prefix}directPhysicalPrinting') ?? false,
      managerPin: pin,
      maxDiscountThreshold: p.getDouble('${_prefix}maxDiscountThreshold') ?? 10.0,
      vipThreshold: p.getDouble('${_prefix}vipThreshold') ?? 1000000.0,
      loyaltyEnabled: p.getBool('${_prefix}loyaltyEnabled') ?? true,
      pointsPerAmount: p.getDouble('${_prefix}pointsPerAmount') ?? 1000.0,
      amountPerPoint: p.getDouble('${_prefix}amountPerPoint') ?? 10.0,
      showAssistant: p.getBool('${_prefix}showAssistant') ?? true,
      networkMode: NetworkMode.values[p.getInt('${_prefix}networkMode') ?? 0],
      serverIp: p.getString('${_prefix}serverIp') ?? '',
      serverPort: p.getInt('${_prefix}serverPort') ?? 8080,
      customerDisplayTheme: p.getString('${_prefix}customerDisplayTheme') ?? 'theme-luxury',
      roundingMode: RoundingMode.values[p.getInt('${_prefix}roundingMode') ?? 0],
      marginTicketTop: p.getDouble('${_prefix}marginTicketTop') ?? 5.0,
      marginTicketBottom: p.getDouble('${_prefix}marginTicketBottom') ?? 5.0,
      marginTicketLeft: p.getDouble('${_prefix}marginTicketLeft') ?? 5.0,
      marginTicketRight: p.getDouble('${_prefix}marginTicketRight') ?? 5.0,
      marginInvoiceTop: p.getDouble('${_prefix}marginInvoiceTop') ?? 20.0,
      marginInvoiceBottom: p.getDouble('${_prefix}marginInvoiceBottom') ?? 20.0,
      marginInvoiceLeft: p.getDouble('${_prefix}marginInvoiceLeft') ?? 20.0,
      marginInvoiceRight: p.getDouble('${_prefix}marginInvoiceRight') ?? 20.0,
      cloudBackupPath: p.getString('${_prefix}cloudBackupPath'),
      emailBackupEnabled: p.getBool('${_prefix}emailBackupEnabled') ?? false,
      backupEmailRecipient: p.getString('${_prefix}backupEmailRecipient') ?? '',
      smtpHost: p.getString('${_prefix}smtpHost') ?? 'smtp.gmail.com',
      smtpPort: p.getInt('${_prefix}smtpPort') ?? 587,
      smtpUser: p.getString('${_prefix}smtpUser') ?? '',
      smtpPassword: smtpPass,
      lastEmailBackup: p.getString('${_prefix}lastEmailBackup') != null ? DateTime.tryParse(p.getString('${_prefix}lastEmailBackup')!) : null,
      emailBackupFrequency: EmailBackupFrequency.values[p.getInt('${_prefix}emailBackupFrequency') ?? EmailBackupFrequency.weekly.index],
      emailBackupHour: p.getInt('${_prefix}emailBackupHour') ?? 22,
      reportEmailEnabled: p.getBool('${_prefix}reportEmailEnabled') ?? false,
      stockAlertsEnabled: p.getBool('${_prefix}stockAlertsEnabled') ?? false,
      reportEmailFrequency: EmailBackupFrequency.values[p.getInt('${_prefix}reportEmailFrequency') ?? 0],
      reportEmailHour: p.getInt('${_prefix}reportEmailHour') ?? 20,
      reportEmailDayOfWeek: p.getInt('${_prefix}reportEmailDayOfWeek') ?? 1,
      lastReportEmailDate: p.getString('${_prefix}lastReportEmailDate') != null ? DateTime.tryParse(p.getString('${_prefix}lastReportEmailDate')!) : null,
      openCashDrawer: p.getBool('${_prefix}openCashDrawer') ?? false,
      acceptedTos: p.getBool('${_prefix}acceptedTos') ?? false,
      tosAcceptedAt: p.getString('${_prefix}tosAcceptedAt') != null ? DateTime.tryParse(p.getString('${_prefix}tosAcceptedAt')!) : null,
      marketingEmailsEnabled: p.getBool('${_prefix}marketingEmailsEnabled') ?? false,
      inactivityReminderEnabled: p.getBool('${_prefix}inactivityReminderEnabled') ?? false,
      inactivityDaysThreshold: p.getInt('${_prefix}inactivityDaysThreshold') ?? 30,
      enableSounds: p.getBool('${_prefix}enableSounds') ?? true,
      enableAppSounds: p.getBool('${_prefix}enableAppSounds') ?? true,
      enableCustomerDisplaySounds: p.getBool('${_prefix}enableCustomerDisplaySounds') ?? true,
      useCustomerDisplay3D: p.getBool('${_prefix}useCustomerDisplay3D') ?? false,
      hrShowSignatureLines: p.getBool('${_prefix}hrShowSignatureLines') ?? true,
      syncKey: p.getString('${_prefix}syncKey') ?? '',
      assistantLevel: AssistantPowerLevel.values[p.getInt('${_prefix}assistantLevel') ?? 0],
      customerDisplayMessages: p.getStringList('${_prefix}customerDisplayMessages') ?? [
        '✨ BIENVENUE ✨',
        '🔥 NOUVELLE COLLECTION DISPONIBLE 🔥',
        '💎 PRODUITS DE HAUTE QUALITÉ 💎',
        '⚡ SERVICE RAPIDE & PROFESSIONNEL ⚡',
        '🌟 MERCI DE VOTRE FIDÉLITÉ 🌟'
      ],
      enableCustomerDisplayTicker: p.getBool('${_prefix}enableCustomerDisplayTicker') ?? true,
      templateFiscalSettings: _decodeMap(p.getString('${_prefix}templateFiscalSettings')),
      labelHT: p.getString('${_prefix}labelHT') ?? 'TOTAL H.T.',
      labelTTC: p.getString('${_prefix}labelTTC') ?? 'TOTAL TTC',
      titleInvoice: p.getString('${_prefix}titleInvoice') ?? 'FACTURE',
      titleQuote: p.getString('${_prefix}titleQuote') ?? 'DEVIS',
      titleProforma: p.getString('${_prefix}titleProforma') ?? 'PROFORMA',
      titleDeliveryNote: p.getString('${_prefix}titleDeliveryNote') ?? 'BON DE LIVRAISON',
      proformaPrinterName: p.getString('${_prefix}proformaPrinterName'),
      deliveryPrinterName: p.getString('${_prefix}deliveryPrinterName'),
      marginLabelX: p.getDouble('${_prefix}marginLabelX') ?? 0.0,
      autoPrintDeliveryNote: p.getBool('${_prefix}autoPrintDeliveryNote') ?? false,
      isAutoLockEnabled: p.getBool('${_prefix}isAutoLockEnabled') ?? false,
      autoLockMinutes: p.getInt('${_prefix}autoLockMinutes') ?? 5,
      isAiEnabled: p.getBool('${_prefix}isAiEnabled') ?? true,
      isVoiceEnabled: p.getBool('${_prefix}isVoiceEnabled') ?? false,
      showTaxOnTickets: p.getBool('${_prefix}showTaxOnTickets') ?? true,
      showTaxOnInvoices: p.getBool('${_prefix}showTaxOnInvoices') ?? true,
      showTaxOnQuotes: p.getBool('${_prefix}showTaxOnQuotes') ?? true,
      showTaxOnDeliveryNotes: p.getBool('${_prefix}showTaxOnDeliveryNotes') ?? true,
      useDetailedTaxOnTickets: p.getBool('${_prefix}useDetailedTaxOnTickets') ?? false,
      useDetailedTaxOnInvoices: p.getBool('${_prefix}useDetailedTaxOnInvoices') ?? true,
      useDetailedTaxOnQuotes: p.getBool('${_prefix}useDetailedTaxOnQuotes') ?? true,
      useDetailedTaxOnDeliveryNotes: p.getBool('${_prefix}useDetailedTaxOnDeliveryNotes') ?? false,
    );
  }


  Future<void> save(ShopSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('${_prefix}name', s.name);
    await p.setString('${_prefix}slogan', s.slogan);
    await p.setString('${_prefix}phone', s.phone);
    await p.setString('${_prefix}whatsapp', s.whatsapp);
    await p.setString('${_prefix}address', s.address);
    await p.setString('${_prefix}email', s.email);
    await p.setString('${_prefix}rc', s.rc);
    await p.setString('${_prefix}nif', s.nif);
    await p.setString('${_prefix}bankAccount', s.bankAccount);
    await p.setString('${_prefix}currency', s.currency);
    await p.setBool('${_prefix}removeDecimals', s.removeDecimals);
    await p.setInt('${_prefix}receipt', s.defaultReceipt.index);
    await p.setInt('${_prefix}invoice', s.defaultInvoice.index);
    await p.setInt('${_prefix}quote', s.defaultQuote.index);
    await p.setInt('${_prefix}purchaseOrder', s.defaultPurchaseOrder.index);
    await p.setInt('${_prefix}thermalFormat', s.thermalFormat.index);
    await p.setInt('${_prefix}labelFormat', s.labelFormat.index);
    await p.setDouble('${_prefix}labelWidth', s.labelWidth);
    await p.setDouble('${_prefix}labelHeight', s.labelHeight);
    await p.setString('${_prefix}receiptFooter', s.receiptFooter);
    if (s.logoPath != null) {
      await p.setString('${_prefix}logoPath', s.logoPath!);
    } else {
      await p.remove('${_prefix}logoPath');
    }
    await p.setString('${_prefix}taxName', s.taxName);
    await p.setDouble('${_prefix}taxRate', s.taxRate);
    await p.setBool('${_prefix}useTax', s.useTax);
    await p.setBool('${_prefix}showQrCode', s.showQrCode);
    await p.setStringList('${_prefix}paymentMethods', s.paymentMethods);
    await p.setBool('${_prefix}isConfigured', s.isConfigured);
    await p.setBool('${_prefix}useAutoRef', s.useAutoRef);
    await p.setString('${_prefix}refPrefix', s.refPrefix);
    await p.setInt('${_prefix}refModel', s.refModel.index);
    await p.setInt('${_prefix}barcodeModel', s.barcodeModel.index);
    await p.setBool('${_prefix}autoBackupEnabled', s.autoBackupEnabled);
    if (s.lastAutoBackup != null) {
      await p.setString('${_prefix}lastAutoBackup', s.lastAutoBackup!.toIso8601String());
    }
    await p.setString('${_prefix}legalForm', s.legalForm);
    await p.setString('${_prefix}capital', s.capital);
    await p.setString('${_prefix}policyWarranty', s.policyWarranty);
    await p.setString('${_prefix}policyReturns', s.policyReturns);
    await p.setString('${_prefix}policyPayments', s.policyPayments);
    await p.setInt('${_prefix}quoteValidityDays', s.quoteValidityDays);
    await p.setString('${_prefix}invoiceLegalNote', s.invoiceLegalNote);
    if (s.thermalPrinterName != null) {
      await p.setString('${_prefix}thermalPrinterName', s.thermalPrinterName!);
    } else {
      await p.remove('${_prefix}thermalPrinterName');
    }
    if (s.invoicePrinterName != null) {
      await p.setString('${_prefix}invoicePrinterName', s.invoicePrinterName!);
    } else {
      await p.remove('${_prefix}invoicePrinterName');
    }
    if (s.quotePrinterName != null) {
      await p.setString('${_prefix}quotePrinterName', s.quotePrinterName!);
    } else {
      await p.remove('${_prefix}quotePrinterName');
    }
    if (s.purchaseOrderPrinterName != null) {
      await p.setString('${_prefix}purchaseOrderPrinterName', s.purchaseOrderPrinterName!);
    } else {
      await p.remove('${_prefix}purchaseOrderPrinterName');
    }
    if (s.labelPrinterName != null) {
      await p.setString('${_prefix}labelPrinterName', s.labelPrinterName!);
    } else {
      await p.remove('${_prefix}labelPrinterName');
    }
    if (s.contractPrinterName != null) {
      await p.setString('${_prefix}contractPrinterName', s.contractPrinterName!);
    } else {
      await p.remove('${_prefix}contractPrinterName');
    }
    if (s.payrollPrinterName != null) {
      await p.setString('${_prefix}payrollPrinterName', s.payrollPrinterName!);
    } else {
      await p.remove('${_prefix}payrollPrinterName');
    }
    if (s.reportPrinterName != null) {
      await p.setString('${_prefix}reportPrinterName', s.reportPrinterName!);
    } else {
      await p.remove('${_prefix}reportPrinterName');
    }
    if (s.proformaPrinterName != null) {
      await p.setString('${_prefix}proformaPrinterName', s.proformaPrinterName!);
    } else {
      await p.remove('${_prefix}proformaPrinterName');
    }
    if (s.deliveryPrinterName != null) {
      await p.setString('${_prefix}deliveryPrinterName', s.deliveryPrinterName!);
    } else {
      await p.remove('${_prefix}deliveryPrinterName');
    }
    await p.setBool('${_prefix}autoPrintTicket', s.autoPrintTicket);
    await p.setBool('${_prefix}showPreviewBeforePrint', s.showPreviewBeforePrint);
    await p.setBool('${_prefix}showPriceOnLabels', s.showPriceOnLabels);
    await p.setBool('${_prefix}showNameOnLabels', s.showNameOnLabels);
    await p.setBool('${_prefix}showSkuOnLabels', s.showSkuOnLabels);
    await p.setBool('${_prefix}autoPrintLabelsOnStockIn', s.autoPrintLabelsOnStockIn);
    await p.setBool('${_prefix}directPhysicalPrinting', s.directPhysicalPrinting);
    
    // Audit Correction: Ensure managerPin is hashed before saving to SharedPreferences
    String pinToSave = s.managerPin;
    if (pinToSave.length != 64) {
      pinToSave = sha256.convert(utf8.encode("${pinToSave}danaya_manager_pepper_2024")).toString();
    }
    await p.setString('${_prefix}managerPin', pinToSave);

    await p.setDouble('${_prefix}maxDiscountThreshold', s.maxDiscountThreshold);
    await p.setDouble('${_prefix}vipThreshold', s.vipThreshold);
    await p.setBool('${_prefix}loyaltyEnabled', s.loyaltyEnabled);
    await p.setDouble('${_prefix}pointsPerAmount', s.pointsPerAmount);
    await p.setDouble('${_prefix}amountPerPoint', s.amountPerPoint);
    await p.setBool('${_prefix}showAssistant', s.showAssistant);
    await p.setInt('${_prefix}networkMode', s.networkMode.index);
    await p.setString('${_prefix}serverIp', s.serverIp);
    await p.setInt('${_prefix}serverPort', s.serverPort);
    await p.setString('${_prefix}customerDisplayTheme', s.customerDisplayTheme);
    await p.setInt('${_prefix}roundingMode', s.roundingMode.index);
    await p.setDouble('${_prefix}marginTicketTop', s.marginTicketTop);
    await p.setDouble('${_prefix}marginTicketBottom', s.marginTicketBottom);
    await p.setDouble('${_prefix}marginTicketLeft', s.marginTicketLeft);
    await p.setDouble('${_prefix}marginTicketRight', s.marginTicketRight);
    await p.setDouble('${_prefix}marginInvoiceTop', s.marginInvoiceTop);
    await p.setDouble('${_prefix}marginInvoiceBottom', s.marginInvoiceBottom);
    await p.setDouble('${_prefix}marginInvoiceLeft', s.marginInvoiceLeft);
    await p.setDouble('${_prefix}marginInvoiceRight', s.marginInvoiceRight);
    if (s.cloudBackupPath != null) {
      await p.setString('${_prefix}cloudBackupPath', s.cloudBackupPath!);
    } else {
      await p.remove('${_prefix}cloudBackupPath');
    }
    await p.setBool('${_prefix}emailBackupEnabled', s.emailBackupEnabled);
    await p.setString('${_prefix}backupEmailRecipient', s.backupEmailRecipient);
    await p.setString('${_prefix}smtpHost', s.smtpHost);
    await p.setInt('${_prefix}smtpPort', s.smtpPort);
    await p.setString('${_prefix}smtpUser', s.smtpUser);
    await p.setString('${_prefix}smtpPassword', s.smtpPassword);
    if (s.lastEmailBackup != null) {
      await p.setString('${_prefix}lastEmailBackup', s.lastEmailBackup!.toIso8601String());
    }
    await p.setInt('${_prefix}emailBackupFrequency', s.emailBackupFrequency.index);
    await p.setInt('${_prefix}emailBackupHour', s.emailBackupHour);
    await p.setBool('${_prefix}reportEmailEnabled', s.reportEmailEnabled);
    await p.setBool('${_prefix}stockAlertsEnabled', s.stockAlertsEnabled);
    await p.setInt('${_prefix}reportEmailFrequency', s.reportEmailFrequency.index);
    await p.setInt('${_prefix}reportEmailHour', s.reportEmailHour);
    await p.setInt('${_prefix}reportEmailDayOfWeek', s.reportEmailDayOfWeek);
    if (s.lastReportEmailDate != null) {
      await p.setString('${_prefix}lastReportEmailDate', s.lastReportEmailDate!.toIso8601String());
    }
    await p.setBool('${_prefix}acceptedTos', s.acceptedTos);
    await p.setBool('${_prefix}openCashDrawer', s.openCashDrawer);
    if (s.tosAcceptedAt != null) {
      await p.setString('${_prefix}tosAcceptedAt', s.tosAcceptedAt!.toIso8601String());
    }
    await p.setBool('${_prefix}marketingEmailsEnabled', s.marketingEmailsEnabled);
    await p.setBool('${_prefix}inactivityReminderEnabled', s.inactivityReminderEnabled);
    await p.setInt('${_prefix}inactivityDaysThreshold', s.inactivityDaysThreshold);
    await p.setBool('${_prefix}enableSounds', s.enableSounds);
    await p.setBool('${_prefix}enableAppSounds', s.enableAppSounds);
    await p.setBool('${_prefix}enableCustomerDisplaySounds', s.enableCustomerDisplaySounds);
    await p.setBool('${_prefix}useCustomerDisplay3D', s.useCustomerDisplay3D);
    await p.setBool('${_prefix}hrShowSignatureLines', s.hrShowSignatureLines);
    await p.setString('${_prefix}syncKey', s.syncKey);
    await p.setInt('${_prefix}assistantLevel', s.assistantLevel.index);
    await p.setStringList('${_prefix}customerDisplayMessages', s.customerDisplayMessages);
    await p.setBool('${_prefix}enableCustomerDisplayTicker', s.enableCustomerDisplayTicker);
    await p.setDouble('${_prefix}marginLabelX', s.marginLabelX);
    await p.setDouble('${_prefix}marginLabelY', s.marginLabelY);
    await p.setBool('${_prefix}autoPrintDeliveryNote', s.autoPrintDeliveryNote);
    await p.setBool('${_prefix}isAutoLockEnabled', s.isAutoLockEnabled);
    await p.setInt('${_prefix}autoLockMinutes', s.autoLockMinutes);
    await p.setBool('${_prefix}isAiEnabled', s.isAiEnabled);
    await p.setBool('${_prefix}isVoiceEnabled', s.isVoiceEnabled);
    await p.setBool('${_prefix}showTaxOnTickets', s.showTaxOnTickets);
    await p.setBool('${_prefix}showTaxOnInvoices', s.showTaxOnInvoices);
    await p.setBool('${_prefix}showTaxOnQuotes', s.showTaxOnQuotes);
    await p.setBool('${_prefix}showTaxOnDeliveryNotes', s.showTaxOnDeliveryNotes);
    await p.setBool('${_prefix}useDetailedTaxOnQuotes', s.useDetailedTaxOnQuotes);
    await p.setBool('${_prefix}useDetailedTaxOnDeliveryNotes', s.useDetailedTaxOnDeliveryNotes);

    await p.setString('${_prefix}templateFiscalSettings', jsonEncode(s.templateFiscalSettings));
    await p.setString('${_prefix}labelHT', s.labelHT);
    await p.setString('${_prefix}labelTTC', s.labelTTC);
    await p.setString('${_prefix}titleInvoice', s.titleInvoice);
    await p.setString('${_prefix}titleQuote', s.titleQuote);
    await p.setString('${_prefix}titleProforma', s.titleProforma);
    await p.setString('${_prefix}titleDeliveryNote', s.titleDeliveryNote);

    state = AsyncData(s);
    
    // 🔥 OPTIMISATION: Vider le cache d'images PDF car le logo a pu changer
    PdfResourceService.instance.clearImageCache();

    // Notification en temps réel aux afficheurs clients et tablettes
    try {
      final server = ref.read(serverServiceProvider);
      server.broadcastEvent('theme_updated', {
        'theme': s.customerDisplayTheme,
        'shopName': s.name,
        'enableTicker': s.enableCustomerDisplayTicker,
        'messages': s.customerDisplayMessages,
        'use3D': s.useCustomerDisplay3D,
      });
      server.broadcastEvent('settings_updated', {
        'currency': s.currency,
        'taxName': s.taxName,
        'taxRate': s.taxRate,
        'removeDecimals': s.removeDecimals,
        'use3D': s.useCustomerDisplay3D,
      });
    } catch (e) {
      // Le serveur n'est peut-être pas démarré, on ignore
    }
  }

  Map<String, bool> _decodeMap(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty || jsonString == 'null') return {};
    try {
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v == true));
      }
    } catch (_) {
      // Robustesse: on ignore et on retourne une map vide
    }
    return {};
  }
}

final shopSettingsProvider = AsyncNotifierProvider<ShopSettingsNotifier, ShopSettings>(() {
  return ShopSettingsNotifier();
});
