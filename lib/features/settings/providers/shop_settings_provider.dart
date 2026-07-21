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
      showAssistant: p.getBool('${_prefix}showAssistant') ?? false,
      networkMode: NetworkMode.values[p.getInt('${_prefix}networkMode') ?? 0],
      serverIp: p.getString('${_prefix}serverIp') ?? '',
      serverPort: p.getInt('${_prefix}serverPort') ?? 8080,
      cloudSyncKey: p.getString('${_prefix}cloudSyncKey') ?? '',
      cloudEndpoint: p.getString('${_prefix}cloudEndpoint') ?? 'https://danaya-plus-default-rtdb.firebaseio.com',
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
      copilotPermissions: _decodeMap(p.getString('${_prefix}copilotPermissions')),
      labelHT: p.getString('${_prefix}labelHT') ?? 'TOTAL H.T.',
      labelTTC: p.getString('${_prefix}labelTTC') ?? 'TOTAL TTC',
      titleInvoice: p.getString('${_prefix}titleInvoice') ?? 'FACTURE',
      titleQuote: p.getString('${_prefix}titleQuote') ?? 'DEVIS',
      titleProforma: p.getString('${_prefix}titleProforma') ?? 'PROFORMA',
      titleDeliveryNote: p.getString('${_prefix}titleDeliveryNote') ?? 'BON DE LIVRAISON',
      proformaPrinterName: p.getString('${_prefix}proformaPrinterName'),
      deliveryPrinterName: p.getString('${_prefix}deliveryPrinterName'),
      marginLabelX: p.getDouble('${_prefix}marginLabelX') ?? 0.0,
      marginLabelY: p.getDouble('${_prefix}marginLabelY') ?? 0.0,
      autoPrintDeliveryNote: p.getBool('${_prefix}autoPrintDeliveryNote') ?? false,
      isAutoLockEnabled: p.getBool('${_prefix}isAutoLockEnabled') ?? false,
      autoLockMinutes: p.getInt('${_prefix}autoLockMinutes') ?? 5,
      isAiEnabled: p.getBool('${_prefix}isAiEnabled') ?? false,
      isVoiceEnabled: p.getBool('${_prefix}isVoiceEnabled') ?? false,
      showTaxOnTickets: p.getBool('${_prefix}showTaxOnTickets') ?? true,
      showTaxOnInvoices: p.getBool('${_prefix}showTaxOnInvoices') ?? true,
      showTaxOnQuotes: p.getBool('${_prefix}showTaxOnQuotes') ?? true,
      showTaxOnDeliveryNotes: p.getBool('${_prefix}showTaxOnDeliveryNotes') ?? true,
      useDetailedTaxOnTickets: p.getBool('${_prefix}useDetailedTaxOnTickets') ?? false,
      useDetailedTaxOnInvoices: p.getBool('${_prefix}useDetailedTaxOnInvoices') ?? true,
      useDetailedTaxOnQuotes: p.getBool('${_prefix}useDetailedTaxOnQuotes') ?? true,
      useDetailedTaxOnDeliveryNotes: p.getBool('${_prefix}useDetailedTaxOnDeliveryNotes') ?? false,
      enableVoiceConfig: p.getBool('${_prefix}enableVoiceConfig') ?? false,
      useCloudAi: p.getBool('${_prefix}useCloudAi') ?? false,
      cloudAiProvider: p.getString('${_prefix}cloudAiProvider') ?? 'gemini',
      deepSeekApiKey: p.getString('${_prefix}deepSeekApiKey') ?? '',
      geminiApiKey: p.getString('${_prefix}geminiApiKey') ?? '',
      elevenLabsApiKey: p.getString('${_prefix}elevenLabsApiKey') ?? '',
      elevenLabsVoiceId: p.getString('${_prefix}elevenLabsVoiceId') ?? '',
      allowCloudAiActions: p.getBool('${_prefix}allowCloudAiActions') ?? false,
      enableAiStreaming: p.getBool('${_prefix}enableAiStreaming') ?? true,
      whatsappToken: p.getString('${_prefix}whatsappToken') ?? '',
      whatsappPhoneNumberId: p.getString('${_prefix}whatsappPhoneNumberId') ?? '',
      titleReceipt: p.getString('${_prefix}titleReceipt') ?? 'TICKET DE CAISSE',
      titleReceiptProforma: p.getString('${_prefix}titleReceiptProforma') ?? 'PROFORMA',
    );
  }

  Future<void> save(ShopSettings s) async {
    final p = await SharedPreferences.getInstance();
    final prev = state.value;

    // Audit Correction: Ensure managerPin is hashed before saving to SharedPreferences
    String pinToSave = s.managerPin;
    if (pinToSave.length != 64) {
      pinToSave = sha256.convert(utf8.encode("${pinToSave}danaya_manager_pepper_2024")).toString();
    }

    final writes = <Future<bool>>[];

    void setString(String key, String val, String? prevVal) {
      if (prev == null || val != prevVal) {
        writes.add(p.setString(key, val));
      }
    }

    void setStringNullable(String key, String? val, String? prevVal) {
      if (prev == null || val != prevVal) {
        if (val != null) {
          writes.add(p.setString(key, val));
        } else {
          writes.add(p.remove(key));
        }
      }
    }

    void setBool(String key, bool val, bool? prevVal) {
      if (prev == null || val != prevVal) {
        writes.add(p.setBool(key, val));
      }
    }

    void setInt(String key, int val, int? prevVal) {
      if (prev == null || val != prevVal) {
        writes.add(p.setInt(key, val));
      }
    }

    void setDouble(String key, double val, double? prevVal) {
      if (prev == null || val != prevVal) {
        writes.add(p.setDouble(key, val));
      }
    }

    bool isListEqual(List<String> a, List<String>? b) {
      if (b == null) return false;
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }

    void setStringList(String key, List<String> val, List<String>? prevVal) {
      if (prev == null || !isListEqual(val, prevVal)) {
        writes.add(p.setStringList(key, val));
      }
    }

    setString('${_prefix}name', s.name, prev?.name);
    setString('${_prefix}slogan', s.slogan, prev?.slogan);
    setString('${_prefix}phone', s.phone, prev?.phone);
    setString('${_prefix}whatsapp', s.whatsapp, prev?.whatsapp);
    setString('${_prefix}address', s.address, prev?.address);
    setString('${_prefix}email', s.email, prev?.email);
    setString('${_prefix}rc', s.rc, prev?.rc);
    setString('${_prefix}nif', s.nif, prev?.nif);
    setString('${_prefix}bankAccount', s.bankAccount, prev?.bankAccount);
    setString('${_prefix}currency', s.currency, prev?.currency);
    setBool('${_prefix}removeDecimals', s.removeDecimals, prev?.removeDecimals);
    setInt('${_prefix}receipt', s.defaultReceipt.index, prev?.defaultReceipt.index);
    setInt('${_prefix}invoice', s.defaultInvoice.index, prev?.defaultInvoice.index);
    setInt('${_prefix}quote', s.defaultQuote.index, prev?.defaultQuote.index);
    setInt('${_prefix}purchaseOrder', s.defaultPurchaseOrder.index, prev?.defaultPurchaseOrder.index);
    setInt('${_prefix}thermalFormat', s.thermalFormat.index, prev?.thermalFormat.index);
    setInt('${_prefix}labelFormat', s.labelFormat.index, prev?.labelFormat.index);
    setDouble('${_prefix}labelWidth', s.labelWidth, prev?.labelWidth);
    setDouble('${_prefix}labelHeight', s.labelHeight, prev?.labelHeight);
    setString('${_prefix}receiptFooter', s.receiptFooter, prev?.receiptFooter);
    setStringNullable('${_prefix}logoPath', s.logoPath, prev?.logoPath);
    setString('${_prefix}taxName', s.taxName, prev?.taxName);
    setDouble('${_prefix}taxRate', s.taxRate, prev?.taxRate);
    setBool('${_prefix}useTax', s.useTax, prev?.useTax);
    setBool('${_prefix}showQrCode', s.showQrCode, prev?.showQrCode);
    setStringList('${_prefix}paymentMethods', s.paymentMethods, prev?.paymentMethods);
    setBool('${_prefix}isConfigured', s.isConfigured, prev?.isConfigured);
    setBool('${_prefix}useAutoRef', s.useAutoRef, prev?.useAutoRef);
    setString('${_prefix}refPrefix', s.refPrefix, prev?.refPrefix);
    setInt('${_prefix}refModel', s.refModel.index, prev?.refModel.index);
    setInt('${_prefix}barcodeModel', s.barcodeModel.index, prev?.barcodeModel.index);
    setBool('${_prefix}autoBackupEnabled', s.autoBackupEnabled, prev?.autoBackupEnabled);
    
    // lastAutoBackup
    final sLastBackup = s.lastAutoBackup?.toIso8601String();
    final prevLastBackup = prev?.lastAutoBackup?.toIso8601String();
    if (prev == null || sLastBackup != prevLastBackup) {
      if (sLastBackup != null) {
        writes.add(p.setString('${_prefix}lastAutoBackup', sLastBackup));
      } else {
        writes.add(p.remove('${_prefix}lastAutoBackup'));
      }
    }

    setString('${_prefix}legalForm', s.legalForm, prev?.legalForm);
    setString('${_prefix}capital', s.capital, prev?.capital);
    setString('${_prefix}policyWarranty', s.policyWarranty, prev?.policyWarranty);
    setString('${_prefix}policyReturns', s.policyReturns, prev?.policyReturns);
    setString('${_prefix}policyPayments', s.policyPayments, prev?.policyPayments);
    setInt('${_prefix}quoteValidityDays', s.quoteValidityDays, prev?.quoteValidityDays);
    setString('${_prefix}invoiceLegalNote', s.invoiceLegalNote, prev?.invoiceLegalNote);
    setStringNullable('${_prefix}thermalPrinterName', s.thermalPrinterName, prev?.thermalPrinterName);
    setStringNullable('${_prefix}invoicePrinterName', s.invoicePrinterName, prev?.invoicePrinterName);
    setStringNullable('${_prefix}quotePrinterName', s.quotePrinterName, prev?.quotePrinterName);
    setStringNullable('${_prefix}purchaseOrderPrinterName', s.purchaseOrderPrinterName, prev?.purchaseOrderPrinterName);
    setStringNullable('${_prefix}labelPrinterName', s.labelPrinterName, prev?.labelPrinterName);
    setStringNullable('${_prefix}contractPrinterName', s.contractPrinterName, prev?.contractPrinterName);
    setStringNullable('${_prefix}payrollPrinterName', s.payrollPrinterName, prev?.payrollPrinterName);
    setStringNullable('${_prefix}reportPrinterName', s.reportPrinterName, prev?.reportPrinterName);
    setStringNullable('${_prefix}proformaPrinterName', s.proformaPrinterName, prev?.proformaPrinterName);
    setStringNullable('${_prefix}deliveryPrinterName', s.deliveryPrinterName, prev?.deliveryPrinterName);
    setBool('${_prefix}autoPrintTicket', s.autoPrintTicket, prev?.autoPrintTicket);
    setBool('${_prefix}showPreviewBeforePrint', s.showPreviewBeforePrint, prev?.showPreviewBeforePrint);
    setBool('${_prefix}showPriceOnLabels', s.showPriceOnLabels, prev?.showPriceOnLabels);
    setBool('${_prefix}showNameOnLabels', s.showNameOnLabels, prev?.showNameOnLabels);
    setBool('${_prefix}showSkuOnLabels', s.showSkuOnLabels, prev?.showSkuOnLabels);
    setBool('${_prefix}autoPrintLabelsOnStockIn', s.autoPrintLabelsOnStockIn, prev?.autoPrintLabelsOnStockIn);
    setBool('${_prefix}directPhysicalPrinting', s.directPhysicalPrinting, prev?.directPhysicalPrinting);
    setString('${_prefix}managerPin', pinToSave, prev != null ? pinToSave : null); // force rewrite managerPin if needed, or compare pinToSave with prev.managerPin
    setDouble('${_prefix}maxDiscountThreshold', s.maxDiscountThreshold, prev?.maxDiscountThreshold);
    setDouble('${_prefix}vipThreshold', s.vipThreshold, prev?.vipThreshold);
    setBool('${_prefix}loyaltyEnabled', s.loyaltyEnabled, prev?.loyaltyEnabled);
    setDouble('${_prefix}pointsPerAmount', s.pointsPerAmount, prev?.pointsPerAmount);
    setDouble('${_prefix}amountPerPoint', s.amountPerPoint, prev?.amountPerPoint);
    setBool('${_prefix}showAssistant', s.showAssistant, prev?.showAssistant);
    setInt('${_prefix}networkMode', s.networkMode.index, prev?.networkMode.index);
    setString('${_prefix}serverIp', s.serverIp, prev?.serverIp);
    setInt('${_prefix}serverPort', s.serverPort, prev?.serverPort);
    setString('${_prefix}cloudSyncKey', s.cloudSyncKey, prev?.cloudSyncKey);
    setString('${_prefix}cloudEndpoint', s.cloudEndpoint, prev?.cloudEndpoint);
    setString('${_prefix}customerDisplayTheme', s.customerDisplayTheme, prev?.customerDisplayTheme);
    setInt('${_prefix}roundingMode', s.roundingMode.index, prev?.roundingMode.index);
    setDouble('${_prefix}marginTicketTop', s.marginTicketTop, prev?.marginTicketTop);
    setDouble('${_prefix}marginTicketBottom', s.marginTicketBottom, prev?.marginTicketBottom);
    setDouble('${_prefix}marginTicketLeft', s.marginTicketLeft, prev?.marginTicketLeft);
    setDouble('${_prefix}marginTicketRight', s.marginTicketRight, prev?.marginTicketRight);
    setDouble('${_prefix}marginInvoiceTop', s.marginInvoiceTop, prev?.marginInvoiceTop);
    setDouble('${_prefix}marginInvoiceBottom', s.marginInvoiceBottom, prev?.marginInvoiceBottom);
    setDouble('${_prefix}marginInvoiceLeft', s.marginInvoiceLeft, prev?.marginInvoiceLeft);
    setDouble('${_prefix}marginInvoiceRight', s.marginInvoiceRight, prev?.marginInvoiceRight);
    setStringNullable('${_prefix}cloudBackupPath', s.cloudBackupPath, prev?.cloudBackupPath);
    setBool('${_prefix}emailBackupEnabled', s.emailBackupEnabled, prev?.emailBackupEnabled);
    setString('${_prefix}backupEmailRecipient', s.backupEmailRecipient, prev?.backupEmailRecipient);
    setString('${_prefix}smtpHost', s.smtpHost, prev?.smtpHost);
    setInt('${_prefix}smtpPort', s.smtpPort, prev?.smtpPort);
    setString('${_prefix}smtpUser', s.smtpUser, prev?.smtpUser);
    setString('${_prefix}smtpPassword', s.smtpPassword, prev?.smtpPassword);
    
    // lastEmailBackup
    final sLastEmail = s.lastEmailBackup?.toIso8601String();
    final prevLastEmail = prev?.lastEmailBackup?.toIso8601String();
    if (prev == null || sLastEmail != prevLastEmail) {
      if (sLastEmail != null) {
        writes.add(p.setString('${_prefix}lastEmailBackup', sLastEmail));
      } else {
        writes.add(p.remove('${_prefix}lastEmailBackup'));
      }
    }

    setInt('${_prefix}emailBackupFrequency', s.emailBackupFrequency.index, prev?.emailBackupFrequency.index);
    setInt('${_prefix}emailBackupHour', s.emailBackupHour, prev?.emailBackupHour);
    setBool('${_prefix}reportEmailEnabled', s.reportEmailEnabled, prev?.reportEmailEnabled);
    setBool('${_prefix}stockAlertsEnabled', s.stockAlertsEnabled, prev?.stockAlertsEnabled);
    setInt('${_prefix}reportEmailFrequency', s.reportEmailFrequency.index, prev?.reportEmailFrequency.index);
    setInt('${_prefix}reportEmailHour', s.reportEmailHour, prev?.reportEmailHour);
    setInt('${_prefix}reportEmailDayOfWeek', s.reportEmailDayOfWeek, prev?.reportEmailDayOfWeek);
    
    // lastReportEmailDate
    final sLastReport = s.lastReportEmailDate?.toIso8601String();
    final prevLastReport = prev?.lastReportEmailDate?.toIso8601String();
    if (prev == null || sLastReport != prevLastReport) {
      if (sLastReport != null) {
        writes.add(p.setString('${_prefix}lastReportEmailDate', sLastReport));
      } else {
        writes.add(p.remove('${_prefix}lastReportEmailDate'));
      }
    }

    setBool('${_prefix}acceptedTos', s.acceptedTos, prev?.acceptedTos);
    setBool('${_prefix}openCashDrawer', s.openCashDrawer, prev?.openCashDrawer);
    
    // tosAcceptedAt
    final sTosAccept = s.tosAcceptedAt?.toIso8601String();
    final prevTosAccept = prev?.tosAcceptedAt?.toIso8601String();
    if (prev == null || sTosAccept != prevTosAccept) {
      if (sTosAccept != null) {
        writes.add(p.setString('${_prefix}tosAcceptedAt', sTosAccept));
      } else {
        writes.add(p.remove('${_prefix}tosAcceptedAt'));
      }
    }

    setBool('${_prefix}marketingEmailsEnabled', s.marketingEmailsEnabled, prev?.marketingEmailsEnabled);
    setBool('${_prefix}inactivityReminderEnabled', s.inactivityReminderEnabled, prev?.inactivityReminderEnabled);
    setInt('${_prefix}inactivityDaysThreshold', s.inactivityDaysThreshold, prev?.inactivityDaysThreshold);
    setBool('${_prefix}enableSounds', s.enableSounds, prev?.enableSounds);
    setBool('${_prefix}enableAppSounds', s.enableAppSounds, prev?.enableAppSounds);
    setBool('${_prefix}enableCustomerDisplaySounds', s.enableCustomerDisplaySounds, prev?.enableCustomerDisplaySounds);
    setBool('${_prefix}useCustomerDisplay3D', s.useCustomerDisplay3D, prev?.useCustomerDisplay3D);
    setBool('${_prefix}hrShowSignatureLines', s.hrShowSignatureLines, prev?.hrShowSignatureLines);
    setString('${_prefix}syncKey', s.syncKey, prev?.syncKey);
    setInt('${_prefix}assistantLevel', s.assistantLevel.index, prev?.assistantLevel.index);
    setStringList('${_prefix}customerDisplayMessages', s.customerDisplayMessages, prev?.customerDisplayMessages);
    setBool('${_prefix}enableCustomerDisplayTicker', s.enableCustomerDisplayTicker, prev?.enableCustomerDisplayTicker);
    setDouble('${_prefix}marginLabelX', s.marginLabelX, prev?.marginLabelX);
    setDouble('${_prefix}marginLabelY', s.marginLabelY, prev?.marginLabelY);
    setBool('${_prefix}autoPrintDeliveryNote', s.autoPrintDeliveryNote, prev?.autoPrintDeliveryNote);
    setBool('${_prefix}isAutoLockEnabled', s.isAutoLockEnabled, prev?.isAutoLockEnabled);
    setInt('${_prefix}autoLockMinutes', s.autoLockMinutes, prev?.autoLockMinutes);
    setBool('${_prefix}isAiEnabled', s.isAiEnabled, prev?.isAiEnabled);
    setBool('${_prefix}isVoiceEnabled', s.isVoiceEnabled, prev?.isVoiceEnabled);
    setBool('${_prefix}showTaxOnTickets', s.showTaxOnTickets, prev?.showTaxOnTickets);
    setBool('${_prefix}showTaxOnInvoices', s.showTaxOnInvoices, prev?.showTaxOnInvoices);
    setBool('${_prefix}showTaxOnQuotes', s.showTaxOnQuotes, prev?.showTaxOnQuotes);
    setBool('${_prefix}showTaxOnDeliveryNotes', s.showTaxOnDeliveryNotes, prev?.showTaxOnDeliveryNotes);
    setBool('${_prefix}useDetailedTaxOnQuotes', s.useDetailedTaxOnQuotes, prev?.useDetailedTaxOnQuotes);
    setBool('${_prefix}useDetailedTaxOnDeliveryNotes', s.useDetailedTaxOnDeliveryNotes, prev?.useDetailedTaxOnDeliveryNotes);
    setBool('${_prefix}enableVoiceConfig', s.enableVoiceConfig, prev?.enableVoiceConfig);
    setBool('${_prefix}useCloudAi', s.useCloudAi, prev?.useCloudAi);
    setString('${_prefix}cloudAiProvider', s.cloudAiProvider, prev?.cloudAiProvider);
    setString('${_prefix}deepSeekApiKey', s.deepSeekApiKey, prev?.deepSeekApiKey);
    setString('${_prefix}geminiApiKey', s.geminiApiKey, prev?.geminiApiKey);
    setString('${_prefix}elevenLabsApiKey', s.elevenLabsApiKey, prev?.elevenLabsApiKey);
    setString('${_prefix}elevenLabsVoiceId', s.elevenLabsVoiceId, prev?.elevenLabsVoiceId);
    setBool('${_prefix}allowCloudAiActions', s.allowCloudAiActions, prev?.allowCloudAiActions);
    setBool('${_prefix}enableAiStreaming', s.enableAiStreaming, prev?.enableAiStreaming);
    setString('${_prefix}whatsappToken', s.whatsappToken, prev?.whatsappToken);
    setString('${_prefix}whatsappPhoneNumberId', s.whatsappPhoneNumberId, prev?.whatsappPhoneNumberId);
    setString('${_prefix}templateFiscalSettings', jsonEncode(s.templateFiscalSettings), prev != null ? jsonEncode(prev.templateFiscalSettings) : null);
    setString('${_prefix}copilotPermissions', jsonEncode(s.copilotPermissions), prev != null ? jsonEncode(prev.copilotPermissions) : null);
    setString('${_prefix}labelHT', s.labelHT, prev?.labelHT);
    setString('${_prefix}labelTTC', s.labelTTC, prev?.labelTTC);
    setString('${_prefix}titleInvoice', s.titleInvoice, prev?.titleInvoice);
    setString('${_prefix}titleQuote', s.titleQuote, prev?.titleQuote);
    setString('${_prefix}titleProforma', s.titleProforma, prev?.titleProforma);
    setString('${_prefix}titleDeliveryNote', s.titleDeliveryNote, prev?.titleDeliveryNote);
    setString('${_prefix}titleReceipt', s.titleReceipt, prev?.titleReceipt);
    setString('${_prefix}titleReceiptProforma', s.titleReceiptProforma, prev?.titleReceiptProforma);

    if (writes.isNotEmpty) {
      await Future.wait(writes);
    }

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
        'enableVoiceConfig': s.enableVoiceConfig,
      });
      server.broadcastEvent('settings_updated', {
        'currency': s.currency,
        'taxName': s.taxName,
        'taxRate': s.taxRate,
        'removeDecimals': s.removeDecimals,
        'use3D': s.useCustomerDisplay3D,
        'enableVoiceConfig': s.enableVoiceConfig,
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
